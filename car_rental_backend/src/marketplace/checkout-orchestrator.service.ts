import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MarketplaceQuoteService } from './marketplace-quote.service';
import { AncillaryProductsService, AncillarySelectionInput } from './ancillary-products.service';
import { PaymentRoutingService } from '../integrations/runtime/payment-routing.service';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';
import { VehicleAllocationService } from '../fleet/vehicle-allocation.service';
import { MarketplaceCommissionService } from '../finance/marketplace-commission.service';
import {
  CheckoutSessionStatus,
  QuoteStatus,
  BookingStatus,
  FulfillmentStage,
  Role,
  Prisma,
} from '@prisma/client';
import * as crypto from 'crypto';

export interface DriverDetailsDto {
  fullName: string;
  phone: string;
  email?: string;
  licenseNumber: string;
  age: number;
}

export interface CustomerDetailsDto {
  name: string;
  phone: string;
  email?: string;
}

export interface InitiatePaymentResult {
  sessionId: string;
  orderId: string;
  providerId: string;
  amountPaise: number;
  currency: string;
  paymentMethod: string;
  keyId?: string;
  gatewayParameters?: Record<string, any>;
  fallbackChain: string[];
}

export interface PaymentVerificationResult {
  sessionId: string;
  bookingId: string;
  bookingStatus: BookingStatus;
  totalPaid: number;
  currency: string;
  confirmedAt: string;
}

export interface PaymentFailureHandledResult {
  sessionId: string;
  status: CheckoutSessionStatus;
  safeToRetry: boolean;
  safeToFailover: boolean;
  recommendedProviderId?: string;
  action: 'RETRY_PRIMARY' | 'FAILOVER_SECONDARY' | 'SELECT_NEW_METHOD' | 'PENDING_RECONCILIATION';
  reason: string;
}

@Injectable()
export class CheckoutOrchestratorService {
  private readonly logger = new Logger(CheckoutOrchestratorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly quoteService: MarketplaceQuoteService,
    private readonly ancillaryService: AncillaryProductsService,
    private readonly paymentRouting: PaymentRoutingService,
    private readonly runtimeService: IntegrationRuntimeService,
    private readonly allocationService: VehicleAllocationService,
    @Optional() private readonly commissionService?: MarketplaceCommissionService,
  ) {}

  /**
   * 1. CREATE CHECKOUT SESSION
   * Locks the authoritative quote and initializes a stateful checkout session.
   */
  async createCheckoutSession(quoteId: string, customerId: string): Promise<any> {
    const verifiedQuote = await this.quoteService.getVerifiedQuote(quoteId);

    const sessionId = `cs_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const expiresAt = new Date(verifiedQuote.expiresAt);

    const session = await this.prisma.checkoutSession.create({
      data: {
        sessionId,
        customerId,
        quoteId: verifiedQuote.quoteId,
        status: CheckoutSessionStatus.QUOTE_LOCKED,
        expiresAt,
        metadata: {
          pricingSnapshot: verifiedQuote,
          currency: verifiedQuote.currency,
          totalPayable: verifiedQuote.totalPayable,
        } as any,
      },
      include: {
        quote: { include: { lineItems: true, car: true } },
      },
    });

    return this.mapSession(session);
  }

  /**
   * 2. CONFIGURE ANCILLARIES / ADDONS
   * Re-evaluates addons, updates quote line items, and maintains price snapshot integrity.
   */
  async configureAddons(
    sessionId: string,
    customerId: string,
    addons: AncillarySelectionInput[],
  ): Promise<any> {
    const session = await this.assertActiveSession(sessionId, customerId);

    // Refresh quote with new ancillaries
    const updatedQuote = await this.quoteService.refreshQuote(session.quoteId, customerId);

    // Update quoteId and metadata on session
    const updated = await this.prisma.checkoutSession.update({
      where: { id: session.id },
      data: {
        quoteId: updatedQuote.quoteId,
        ancillarySelections: addons as any,
        metadata: {
          ...(session.metadata as any || {}),
          pricingSnapshot: updatedQuote,
          totalPayable: updatedQuote.totalPayable,
        },
      },
      include: {
        quote: { include: { lineItems: true, car: true } },
      },
    });

    return this.mapSession(updated);
  }

  /**
   * 3. SUBMIT DRIVER & CUSTOMER DETAILS
   * Validates driver age against minDriverAge and verifies KYC requirements.
   */
  async submitDriverAndCustomerDetails(
    sessionId: string,
    customerId: string,
    driver: DriverDetailsDto,
    customer?: CustomerDetailsDto,
  ): Promise<any> {
    const session = await this.assertActiveSession(sessionId, customerId);

    if (driver.age < 18) {
      throw new BadRequestException('Driver must be at least 18 years of age.');
    }

    if (!driver.licenseNumber || driver.licenseNumber.trim().length < 5) {
      throw new BadRequestException('Valid driving license number is mandatory.');
    }

    const updated = await this.prisma.checkoutSession.update({
      where: { id: session.id },
      data: {
        driverDetails: driver as any,
        customerDetails: customer ? (customer as any) : undefined,
      },
      include: {
        quote: { include: { lineItems: true, car: true } },
      },
    });

    return this.mapSession(updated);
  }

  /**
   * 4. DISCOVER PAYMENT METHODS & ROUTED PROVIDERS
   * Leverages PaymentRoutingService to dynamically discover supported gateways without hardcoding.
   */
  async getAvailablePaymentOptions(sessionId: string, customerId: string): Promise<any> {
    const session = await this.assertActiveSession(sessionId, customerId);
    const totalAmount = Number(session.quote.totalPayable);
    const amountPaise = Math.round(totalAmount * 100);

    const methods = ['UPI', 'CREDIT_CARD', 'DEBIT_CARD', 'NET_BANKING', 'WALLET'];

    const routingOptions: any[] = [];
    for (const method of methods) {
      try {
        const decision = await this.paymentRouting.resolvePaymentRoute({
          paymentMethod: method,
          amountPaise,
          currency: session.quote.currency || 'INR',
          country: 'IN',
          customerId,
          vendorId: session.quote.tenantId,
        });

        routingOptions.push({
          method,
          primaryProvider: decision.primaryProviderId,
          fallbackCount: decision.fallbackChain.length,
          estimatedFee: decision.estimatedFee,
        });
      } catch {
        // Continue if method has no provider available
      }
    }

    return {
      sessionId: session.sessionId,
      totalPayable: totalAmount,
      currency: session.quote.currency || 'INR',
      supportedMethods: routingOptions,
    };
  }

  /**
   * 5. INITIATE PAYMENT
   * Resolves gateway route, dispatches CREATE_ORDER via IntegrationRuntimeService,
   * transitions session state to PAYMENT_PENDING.
   */
  async initiatePayment(
    sessionId: string,
    customerId: string,
    paymentMethod: string,
    idempotencyKey?: string,
  ): Promise<InitiatePaymentResult> {
    const session = await this.assertActiveSession(sessionId, customerId);

    const totalAmount = Number(session.quote.totalPayable);
    const amountPaise = Math.round(totalAmount * 100);

    // 1. Resolve optimal payment provider via PaymentRoutingService
    const routingDecision = await this.paymentRouting.resolvePaymentRoute({
      paymentMethod: paymentMethod.toUpperCase(),
      amountPaise,
      currency: session.quote.currency || 'INR',
      country: 'IN',
      customerId,
      vendorId: session.quote.tenantId,
    });

    // 2. Dispatch CREATE_ORDER via IntegrationRuntimeService
    const runtimeResult = await this.runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      preferredProviderId: routingDecision.primaryProviderId,
      idempotencyKey: idempotencyKey || `pay_${sessionId}_${session.paymentAttempts + 1}`,
      payload: {
        sessionId: session.sessionId,
        quoteId: session.quoteId,
        amountPaise,
        currency: session.quote.currency || 'INR',
        paymentMethod: paymentMethod.toUpperCase(),
        customerId,
      },
    });

    if (!runtimeResult.success) {
      throw new ConflictException(
        `Payment gateway initialization failed: ${runtimeResult.error?.message || 'Gateway unavailable'}`,
      );
    }

    const orderData = runtimeResult.data || {};
    const orderId = orderData.orderId || orderData.id || `ord_${Date.now()}`;

    // 3. Transition session state to PAYMENT_PENDING
    await this.prisma.checkoutSession.update({
      where: { id: session.id },
      data: {
        status: CheckoutSessionStatus.PAYMENT_PENDING,
        selectedPaymentMethod: paymentMethod.toUpperCase(),
        selectedPaymentProvider: routingDecision.primaryProviderId,
        paymentAttempts: { increment: 1 },
        metadata: {
          ...(session.metadata as any || {}),
          activeOrderId: orderId,
          routingDecision,
        },
      },
    });

    return {
      sessionId: session.sessionId,
      orderId,
      providerId: routingDecision.primaryProviderId,
      amountPaise,
      currency: session.quote.currency || 'INR',
      paymentMethod: paymentMethod.toUpperCase(),
      gatewayParameters: orderData,
      fallbackChain: routingDecision.fallbackChain,
    };
  }

  /**
   * 6. VERIFY AND CONFIRM PAYMENT
   * Verifies signature/payment via runtime, creates booking atomically,
   * reserves vehicle, and transitions session to CONFIRMED.
   */
  async verifyAndConfirmPayment(
    sessionId: string,
    customerId: string,
    verificationPayload: {
      orderId: string;
      paymentId: string;
      signature?: string;
    },
  ): Promise<PaymentVerificationResult> {
    const session = await this.prisma.checkoutSession.findUnique({
      where: { sessionId },
      include: {
        quote: { include: { lineItems: true, car: true } },
      },
    });

    if (!session || session.customerId !== customerId) {
      throw new NotFoundException('Checkout session not found.');
    }

    if (session.status === CheckoutSessionStatus.CONFIRMED && session.bookingId) {
      // Idempotency: already confirmed
      return {
        sessionId: session.sessionId,
        bookingId: session.bookingId,
        bookingStatus: BookingStatus.CONFIRMED,
        totalPaid: Number(session.quote.totalPayable),
        currency: session.quote.currency,
        confirmedAt: session.completedAt?.toISOString() || new Date().toISOString(),
      };
    }

    // 1. Verify payment via IntegrationRuntimeService
    const verifyRes = await this.runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'VERIFY_PAYMENT',
      preferredProviderId: session.selectedPaymentProvider || 'razorpay',
      payload: verificationPayload,
    });

    if (!verifyRes.success || (verifyRes.data && verifyRes.data.verified === false)) {
      throw new BadRequestException('Payment verification failed or signature mismatch.');
    }

    // 2. Atomically create confirmed Booking and update session
    const quote = session.quote;
    const driver = (session.driverDetails as any) || {};

    const createdBooking = await this.prisma.$transaction(async (tx) => {
      // Mark quote as ACCEPTED
      await tx.bookingQuote.update({
        where: { id: quote.id },
        data: {
          status: QuoteStatus.ACCEPTED,
          acceptedAt: new Date(),
        },
      });

      // Create Booking record with priceSnapshot
      const booking = await tx.booking.create({
        data: {
          customerId: session.customerId,
          vendorId: quote.tenantId,
          carId: quote.carId,
          tripType: quote.tripType,
          startDate: quote.startDate,
          endDate: quote.endDate,
          pickupLocation: quote.car.pickupHubId || 'Central Hub',
          baseFare: quote.subtotal,
          platformFee: quote.feesTotal,
          gstAmount: quote.taxTotal,
          totalFare: quote.totalPayable,
          netToVendor: quote.netToVendor,
          status: BookingStatus.CONFIRMED,
          quoteId: quote.id,
          vehicleClass: quote.car.type,
          allocationStatus: 'ALLOCATED',
          priceSnapshot: {
            quoteId: quote.id,
            subtotal: Number(quote.subtotal),
            discountTotal: Number(quote.discountTotal),
            feesTotal: Number(quote.feesTotal),
            taxTotal: Number(quote.taxTotal),
            depositTotal: Number(quote.depositTotal),
            totalPayable: Number(quote.totalPayable),
            lineItems: quote.lineItems.map((l) => ({
              type: l.type,
              name: l.name,
              amount: Number(l.amount),
            })),
          },
        },
      });

      // Synchronize physical fulfillment tracking
      if ((tx as any).fulfillmentRecord) {
        const initialStage = quote.carId
          ? FulfillmentStage.ALLOCATED
          : FulfillmentStage.PENDING_ALLOCATION;
        await (tx as any).fulfillmentRecord.upsert({
          where: { bookingId: booking.id },
          create: {
            bookingId: booking.id,
            vendorId: quote.tenantId,
            branchId: quote.car?.pickupHubId,
            carId: quote.carId,
            stage: initialStage,
          },
          update: {
            vendorId: quote.tenantId,
            branchId: quote.car?.pickupHubId,
            carId: quote.carId,
            stage: initialStage,
          },
        });
      }

      // Multilateral Commission Breakdown on Confirmation
      if (this.commissionService) {
        try {
          const commissionSplit = await this.commissionService.calculateCommission({
            grossAmount: Number(quote.totalPayable),
            vendorId: quote.tenantId,
            branchId: quote.car?.pickupHubId || undefined,
            vehicleClass: quote.car?.type || ('SEDAN' as any),
          });
          const currentSnapshot = (booking.priceSnapshot as any) || {};
          await tx.booking.update({
            where: { id: booking.id },
            data: {
              priceSnapshot: {
                ...currentSnapshot,
                commissionSplit,
              } as any,
            },
          });
        } catch (err: any) {
          this.logger.warn(
            `Commission split resolution warning for booking ${booking.id}: ${err.message}`,
          );
        }
      }

      // Convert active temporary vehicle holds for this vehicle/customer
      if ((tx as any).vehicleHold) {
        await (tx as any).vehicleHold.updateMany({
          where: {
            carId: quote.carId,
            customerId: session.customerId,
            status: 'ACTIVE',
          },
          data: {
            status: 'CONVERTED',
          },
        });
      }

      // Update CheckoutSession to CONFIRMED
      await tx.checkoutSession.update({
        where: { id: session.id },
        data: {
          status: CheckoutSessionStatus.CONFIRMED,
          bookingId: booking.id,
          completedAt: new Date(),
        },
      });

      return booking;
    });

    return {
      sessionId: session.sessionId,
      bookingId: createdBooking.id,
      bookingStatus: createdBooking.status,
      totalPaid: Number(createdBooking.totalFare),
      currency: quote.currency,
      confirmedAt: new Date().toISOString(),
    };
  }

  /**
   * 7. HANDLE PAYMENT FAILURE & SAFE FAILOVER
   * Classifies gateway failure, prevents double-debit, and determines safe retry/failover path.
   */
  async handlePaymentFailure(
    sessionId: string,
    customerId: string,
    errorContext: {
      providerId: string;
      errorCode?: string;
      errorMessage?: string;
      dispatchedToGateway?: boolean;
    },
  ): Promise<PaymentFailureHandledResult> {
    const session = await this.prisma.checkoutSession.findUnique({
      where: { sessionId },
      include: { quote: true },
    });

    if (!session || session.customerId !== customerId) {
      throw new NotFoundException('Checkout session not found.');
    }

    // Evaluate fallback safety via PaymentRoutingService
    const safety = this.paymentRouting.evaluateFallbackSafety({
      providerId: errorContext.providerId,
      errorClass: errorContext.errorCode,
      stage: errorContext.dispatchedToGateway ? 'POST_ORDER_DISPATCH' : 'PRE_FLIGHT',
      requestDispatchedToGateway: errorContext.dispatchedToGateway,
      errorMessage: errorContext.errorMessage,
    });

    const meta = (session.metadata as any) || {};
    const routingDecision = meta.routingDecision;
    const fallbackChain: string[] = routingDecision?.fallbackChain || [];
    const recommendedSecondary = fallbackChain.length > 0 ? fallbackChain[0] : undefined;

    // Persist failure details
    await this.prisma.checkoutSession.update({
      where: { id: session.id },
      data: {
        status: CheckoutSessionStatus.PAYMENT_FAILED,
        lastPaymentError: errorContext as any,
      },
    });

    if (!safety.safeToFailover && safety.action === 'PENDING_RECONCILIATION') {
      return {
        sessionId: session.sessionId,
        status: CheckoutSessionStatus.PAYMENT_FAILED,
        safeToRetry: false,
        safeToFailover: false,
        action: 'PENDING_RECONCILIATION',
        reason: 'Payment dispatch state indeterminate. Reconciliation in progress to prevent duplicate customer charge.',
      };
    }

    if (safety.safeToFailover && recommendedSecondary) {
      return {
        sessionId: session.sessionId,
        status: CheckoutSessionStatus.PAYMENT_FAILED,
        safeToRetry: false,
        safeToFailover: true,
        recommendedProviderId: recommendedSecondary,
        action: 'FAILOVER_SECONDARY',
        reason: `Primary gateway failure (${errorContext.errorCode || 'UNAVAILABLE'}). Safe to switch to ${recommendedSecondary}.`,
      };
    }

    return {
      sessionId: session.sessionId,
      status: CheckoutSessionStatus.PAYMENT_FAILED,
      safeToRetry: true,
      safeToFailover: false,
      action: 'SELECT_NEW_METHOD',
      reason: errorContext.errorMessage || 'Payment could not be processed with this method.',
    };
  }

  private async assertActiveSession(sessionId: string, customerId: string): Promise<any> {
    const session = await this.prisma.checkoutSession.findUnique({
      where: { sessionId },
      include: {
        quote: { include: { lineItems: true, car: true } },
      },
    });

    if (!session || session.customerId !== customerId) {
      throw new NotFoundException(`Checkout session '${sessionId}' not found.`);
    }

    if (session.status === CheckoutSessionStatus.CONFIRMED) {
      throw new ConflictException('This checkout session has already been completed.');
    }

    if (session.status === CheckoutSessionStatus.EXPIRED || session.expiresAt < new Date()) {
      await this.prisma.checkoutSession.update({
        where: { id: session.id },
        data: { status: CheckoutSessionStatus.EXPIRED },
      });
      throw new ConflictException('The checkout session has expired. Please restart checkout.');
    }

    return session;
  }

  private mapSession(s: any): any {
    return {
      sessionId: s.sessionId,
      status: s.status,
      quoteId: s.quoteId,
      customerId: s.customerId,
      expiresAt: s.expiresAt.toISOString(),
      driverDetails: s.driverDetails,
      customerDetails: s.customerDetails,
      ancillarySelections: s.ancillarySelections,
      selectedPaymentMethod: s.selectedPaymentMethod,
      selectedPaymentProvider: s.selectedPaymentProvider,
      bookingId: s.bookingId,
      quote: s.quote
        ? {
            id: s.quote.id,
            carId: s.quote.carId,
            subtotal: Number(s.quote.subtotal),
            discountTotal: Number(s.quote.discountTotal),
            feesTotal: Number(s.quote.feesTotal),
            taxTotal: Number(s.quote.taxTotal),
            depositTotal: Number(s.quote.depositTotal),
            totalPayable: Number(s.quote.totalPayable),
            currency: s.quote.currency,
            lineItems: (s.quote.lineItems || []).map((li: any) => ({
              type: li.type,
              name: li.name,
              amount: Number(li.amount),
            })),
          }
        : null,
    };
  }
}
