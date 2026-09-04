import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
  Inject,
  forwardRef,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import Razorpay from 'razorpay';
import { validatePaymentVerification } from 'razorpay/dist/utils/razorpay-utils';
import {
  Role,
  PaymentStatus,
  BookingStatus,
  RefundStatus,
  SecurityDepositStatus,
  WalletStatus,
  LedgerEntryType,
  WalletBucketType,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { NotificationsService } from '../notifications/notifications.service';
import { VerifyPaymentDto } from './dto/verify-payment.dto';
import { InvoicesService } from '../invoices/invoices.service';
import { WalletsService } from '../wallets/wallets.service';
import { AuditLogService } from '../admin/audit-log.service';
import { AdminRefundDto } from './dto/admin-refund.dto';
import * as crypto from 'crypto';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly razorpay: Razorpay | null = null;
  private readonly useMock: boolean;
  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly notificationsService: NotificationsService,
    @Optional() private readonly invoicesService?: InvoicesService,
    @Optional()
    @Inject(forwardRef(() => WalletsService))
    private readonly walletsService?: WalletsService,
    @Optional() private readonly auditLogService?: AuditLogService,
  ) {
    this.keyId =
      this.configService.get<string>('RAZORPAY_KEY_ID') ||
      'rzp_test_placeholderKeyId';
    this.keySecret =
      this.configService.get<string>('RAZORPAY_KEY_SECRET') ||
      'placeholderKeySecret';
    this.webhookSecret =
      this.configService.get<string>('RAZORPAY_WEBHOOK_SECRET') ||
      'placeholderWebhookSecret';
    this.useMock =
      this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';

    if (
      this.useMock &&
      this.configService.get<string>('NODE_ENV') === 'production'
    ) {
      throw new Error(
        'CRITICAL SECURITY CONFIGURATION ERROR: RAZORPAY_USE_MOCK is set to true, but NODE_ENV is production! Bypassing payment verification in production is forbidden.',
      );
    }

    if (!this.useMock) {
      try {
        this.razorpay = new Razorpay({
          key_id: this.keyId,
          key_secret: this.keySecret,
        });
      } catch (err: any) {
        if (this.configService.get<string>('NODE_ENV') === 'production') {
          throw new Error(
            `CRITICAL PRODUCTION PAYMENT ERROR: Failed to initialize Razorpay SDK in production: ${err.message}`,
          );
        }
        this.logger.error(
          'Failed to initialize Razorpay SDK. Falling back to mock mode in non-production environment.',
          err,
        );
        this.useMock = true;
      }
    }
  }

  /**
   * Creates a payment order for a PENDING booking with server-authoritative wallet & split-payment support.
   */
  async createOrder(
    bookingId: string,
    customerId: string,
    useWallet = false,
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { securityDeposit: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (booking.customerId !== customerId) {
      throw new ForbiddenException(
        'Access denied: You can only pay for your own bookings.',
      );
    }

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException('Only pending bookings can be paid for.');
    }

    // Check for existing Payment row
    const existingPayment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (existingPayment) {
      if (
        existingPayment.status === PaymentStatus.PAID ||
        existingPayment.status === PaymentStatus.REFUNDED
      ) {
        throw new ConflictException('This booking has already been paid for.');
      }
      // Allow retry by deleting existing CREATED or FAILED payment
      await this.prisma.payment.delete({
        where: { id: existingPayment.id },
      });
    }

    const tripFare = booking.totalFare;
    const depositAmount = booking.securityDeposit?.amount || new Decimal(0);
    const totalAmount = tripFare.add(depositAmount);

    let walletApplied = new Decimal(0);
    let promoApplied = new Decimal(0);
    let realApplied = new Decimal(0);
    let gatewayAmount = totalAmount;

    if (useWallet && this.walletsService) {
      const wallet = await this.walletsService.getOrCreateWallet(customerId);
      if (wallet.status === WalletStatus.ACTIVE && wallet.availableBalance.gt(0)) {
        walletApplied = Decimal.min(wallet.availableBalance, totalAmount);
        promoApplied = Decimal.min(wallet.promoBalance, walletApplied);
        realApplied = walletApplied.sub(promoApplied);
        gatewayAmount = totalAmount.sub(walletApplied);
      }
    }

    const isFullWallet = gatewayAmount.lte(0);
    let orderId: string;
    let amountInPaise: number;

    if (isFullWallet) {
      orderId = `order_wallet_full_${bookingId}`;
      amountInPaise = 0;
      this.logger.log(
        `[WALLET-FULL] Created full wallet order ${orderId} for booking ${bookingId} (Total: ₹${totalAmount}, Wallet: ₹${walletApplied})`,
      );
    } else {
      amountInPaise = Math.round(gatewayAmount.toNumber() * 100);

      if (this.useMock) {
        const walletPaise = Math.round(walletApplied.toNumber() * 100);
        orderId = walletPaise > 0
          ? `order_mock_split_${walletPaise}_${Math.random().toString(36).substring(2, 11)}`
          : `order_mock_${Math.random().toString(36).substring(2, 15)}`;
        this.logger.log(
          `[RAZORPAY-MOCK] Created mock order ${orderId} for booking ${bookingId} of amount ${amountInPaise} paise (Total: ${totalAmount}, Wallet: ${walletApplied}, Gateway: ${gatewayAmount})`,
        );
      } else {
        try {
          const order = await this.razorpay!.orders.create({
            amount: amountInPaise,
            currency: 'INR',
            receipt: bookingId,
          });
          orderId = order.id;
        } catch (err) {
          this.logger.error('Razorpay Order creation failed:', err);
          throw new BadRequestException(
            'Failed to create payment order with Razorpay. Try again.',
          );
        }
      }
    }

    // Create Payment row in CREATED status
    await this.prisma.payment.create({
      data: {
        bookingId,
        razorpayOrderId: orderId,
        amount: totalAmount,
        status: PaymentStatus.CREATED,
      },
    });

    return {
      orderId,
      amount: amountInPaise,
      currency: 'INR',
      keyId: this.keyId,
      isFullWallet,
      breakdown: {
        tripFare: tripFare.toNumber(),
        securityDeposit: depositAmount.toNumber(),
        totalAmount: totalAmount.toNumber(),
        walletApplied: walletApplied.toNumber(),
        promoApplied: promoApplied.toNumber(),
        realApplied: realApplied.toNumber(),
        gatewayAmount: gatewayAmount.toNumber(),
      },
    };
  }

  /**
   * Verifies payment signature and/or settles wallet contributions, validates authoritative booking amount,
   * and atomically marks Payment as PAID.
   */
  async verifyPayment(dto: VerifyPaymentDto, customerId: string) {
    const { bookingId, razorpayOrderId, razorpayPaymentId, razorpaySignature } =
      dto;

    // 1. Authoritative Booking existence & Ownership check
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { securityDeposit: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (booking.customerId !== customerId) {
      throw new ForbiddenException(
        'Access denied: You can only verify payments for your own bookings.',
      );
    }

    // 2. Authoritative Payment record lookup
    const payment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (!payment) {
      throw new NotFoundException('No payment order found for this booking.');
    }

    // 3. Order ID binding verification
    if (payment.razorpayOrderId !== razorpayOrderId) {
      this.logger.warn(
        `Payment verification order mismatch for booking ${bookingId}. Expected: ${payment.razorpayOrderId}, Received: ${razorpayOrderId}`,
      );
      throw new BadRequestException(
        'Payment order mismatch: provided order ID does not match booking payment order.',
      );
    }

    // 4. Idempotency & Duplicate Request Protection
    if (payment.status === PaymentStatus.PAID) {
      if (
        payment.razorpayPaymentId === razorpayPaymentId ||
        !payment.razorpayPaymentId ||
        razorpayOrderId.startsWith('order_wallet_full_')
      ) {
        this.logger.log(
          `Payment for booking ${bookingId} already marked PAID (idempotent verification return).`,
        );
        return {
          success: true,
          bookingId: booking.id,
          paymentId: payment.id,
          status: PaymentStatus.PAID,
          message: 'Payment already verified and booking confirmed.',
        };
      } else {
        throw new ConflictException(
          'This booking has already been paid with a different payment ID.',
        );
      }
    }

    if (payment.status === PaymentStatus.REFUNDED) {
      throw new BadRequestException(
        'This payment has already been refunded and cannot be confirmed.',
      );
    }

    const totalExpected = booking.totalFare.add(
      booking.securityDeposit?.amount || new Decimal(0),
    );
    const expectedAmountInPaise = Math.round(totalExpected.toNumber() * 100);

    const isFullWalletOrder =
      payment.razorpayOrderId?.startsWith('order_wallet_full_') ||
      razorpayOrderId.startsWith('order_wallet_full_');

    let gatewayPaid = new Decimal(0);
    let walletRequired = new Decimal(0);

    if (isFullWalletOrder) {
      walletRequired = totalExpected;
      gatewayPaid = new Decimal(0);
    } else {
      // 5. Cryptographic Signature Verification
      if (this.useMock && razorpaySignature === 'mock_signature') {
        this.logger.log(
          `[RAZORPAY-MOCK] Verified mock payment signature for booking ${bookingId}`,
        );
      } else {
        let isSignatureValid = false;
        try {
          isSignatureValid = validatePaymentVerification(
            { order_id: razorpayOrderId, payment_id: razorpayPaymentId },
            razorpaySignature,
            this.keySecret,
          );
        } catch (err) {
          this.logger.warn(
            'Razorpay signature verification encountered an error:',
            err,
          );
          isSignatureValid = false;
        }

        if (!isSignatureValid) {
          this.logger.warn(
            `Invalid payment signature detected for booking ${bookingId}, order ${razorpayOrderId}`,
          );
          throw new BadRequestException(
            'Invalid payment signature. Verification failed.',
          );
        }
      }

      // 6. Authoritative Razorpay API Validation (Amount, Currency, Status, Order Binding)
      if (!this.useMock) {
        try {
          const razorpayPayment: any =
            await this.razorpay!.payments.fetch(razorpayPaymentId);

          if (!razorpayPayment) {
            throw new BadRequestException(
              'Payment record not found on Razorpay.',
            );
          }

          // Verify order binding on payment entity
          if (
            razorpayPayment.order_id &&
            razorpayPayment.order_id !== razorpayOrderId
          ) {
            this.logger.warn(
              `Razorpay payment entity order_id mismatch. Expected: ${razorpayOrderId}, Found on Razorpay: ${razorpayPayment.order_id}`,
            );
            throw new BadRequestException(
              'Razorpay payment is not associated with the provided order ID.',
            );
          }

          // Verify currency
          if (
            razorpayPayment.currency &&
            razorpayPayment.currency.toUpperCase() !== 'INR'
          ) {
            throw new BadRequestException(
              `Payment currency mismatch. Expected INR, got ${razorpayPayment.currency}.`,
            );
          }

          // Verify status
          if (razorpayPayment.status === 'failed') {
            await this.prisma.payment.update({
              where: { id: payment.id },
              data: {
                status: PaymentStatus.FAILED,
                razorpayPaymentId,
              },
            });
            throw new BadRequestException(
              'Payment status on Razorpay is failed.',
            );
          }

          if (razorpayPayment.status === 'authorized') {
            throw new BadRequestException(
              'Payment is authorized but not yet captured. Please wait for payment confirmation.',
            );
          }

          if (razorpayPayment.status !== 'captured') {
            throw new BadRequestException(
              `Payment status is not captured: ${razorpayPayment.status}`,
            );
          }

          gatewayPaid = new Decimal(razorpayPayment.amount).div(100);
          walletRequired = totalExpected.sub(gatewayPaid);

          if (
            Number(razorpayPayment.amount) !== expectedAmountInPaise &&
            !this.walletsService
          ) {
            this.logger.error(
              `CRITICAL PAYMENT FRAUD ATTEMPT: Expected ${expectedAmountInPaise} paise, but received ${razorpayPayment.amount} paise for booking ${bookingId}!`,
            );
            throw new BadRequestException(
              `Payment amount mismatch: expected ${expectedAmountInPaise} paise, but received ${razorpayPayment.amount} paise.`,
            );
          }

          if (walletRequired.lt(0)) {
            throw new BadRequestException(
              'Payment amount exceeds total booking payable.',
            );
          }
        } catch (err: any) {
          if (
            err instanceof BadRequestException ||
            err instanceof ForbiddenException ||
            err instanceof NotFoundException ||
            err instanceof ConflictException
          ) {
            throw err;
          }
          this.logger.error(
            'Failed to fetch payment details from Razorpay API:',
            err,
          );
          throw new BadRequestException(
            `Unable to verify payment with Razorpay: ${err.message || err}`,
          );
        }
      } else {
        // Derive split / full amounts in mock mode from order structure
        if (razorpayOrderId.startsWith('order_mock_split_')) {
          const parts = razorpayOrderId.split('_');
          const walletPaise = parseInt(parts[3], 10) || 0;
          walletRequired = new Decimal(walletPaise).div(100);
          gatewayPaid = totalExpected.sub(walletRequired);
        } else {
          gatewayPaid = totalExpected;
          walletRequired = new Decimal(0);
        }
      }
    }

    // 7. Atomic Transactional Finalization & Wallet Debit
    const resolvedPaymentId =
      razorpayPaymentId ||
      (isFullWalletOrder ? `pay_wallet_${bookingId}` : `pay_mock_${Date.now()}`);

    const updatedBooking = await this.prisma.$transaction(async (tx) => {
      // Settle wallet contribution if needed
      if (walletRequired.gt(0)) {
        if (!this.walletsService) {
          throw new BadRequestException('Wallet service unavailable to settle checkout debit.');
        }

        const userWallet = await this.walletsService.getOrCreateWallet(
          booking.customerId,
          tx,
        );

        if (userWallet.availableBalance.lt(walletRequired)) {
          throw new BadRequestException(
            `Insufficient wallet balance to complete payment. Available: ₹${userWallet.availableBalance}, Required: ₹${walletRequired}`,
          );
        }

        await this.walletsService.debitWallet(
          userWallet.id,
          walletRequired,
          LedgerEntryType.CHECKOUT_DEBIT,
          'BOOKING',
          booking.id,
          `wallet_checkout_debit_${booking.id}`,
          isFullWalletOrder
            ? `Full wallet payment for booking ${booking.id}`
            : `Split wallet payment for booking ${booking.id}`,
          {
            bookingId: booking.id,
            isFullWallet: isFullWalletOrder,
            walletAmount: walletRequired.toNumber(),
            gatewayAmount: gatewayPaid.toNumber(),
          },
          tx,
        );
      }

      await tx.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.PAID,
          razorpayPaymentId: resolvedPaymentId,
        },
      });

      // Update Security Deposit Status to HELD if deposit exists
      if (booking.securityDeposit) {
        await tx.securityDeposit.update({
          where: { id: booking.securityDeposit.id },
          data: {
            status: SecurityDepositStatus.HELD,
            razorpayPaymentId: resolvedPaymentId,
            heldAt: new Date(),
          },
        });
      }

      // Keep Booking in PENDING status - Payment does NOT confirm booking (Phase 23A Owner Confirmation Gate)
      const b = await tx.booking.findUnique({
        where: { id: booking.id },
        include: { car: true, customer: true },
      });

      if (!b) return null;

      // Handle coupon usage recording idempotently
      if (b.couponId) {
        const existingUsage = await tx.couponUsage.findFirst({
          where: { bookingId: b.id },
        });

        if (!existingUsage) {
          await tx.$queryRaw`
            SELECT id FROM "Coupon" WHERE id = ${b.couponId} FOR UPDATE
          `;

          const couponRecord = await tx.coupon.findUnique({
            where: { id: b.couponId },
          });

          if (!couponRecord || !couponRecord.isActive) {
            throw new BadRequestException('Coupon is no longer available.');
          }

          if (
            couponRecord.globalUsageLimit !== null &&
            couponRecord.globalUsageLimit !== undefined &&
            couponRecord.usageCount >= couponRecord.globalUsageLimit
          ) {
            throw new BadRequestException('Coupon global usage limit reached.');
          }

          const perCustomerLimit = couponRecord.perCustomerLimit ?? 1;
          const customerUsageCount = await tx.couponUsage.count({
            where: {
              couponId: b.couponId,
              customerId: b.customerId,
            },
          });

          if (customerUsageCount >= perCustomerLimit) {
            throw new BadRequestException(
              'You have reached the maximum redemptions for this coupon.',
            );
          }

          await tx.coupon.update({
            where: { id: b.couponId },
            data: { usageCount: { increment: 1 } },
          });

          await tx.couponUsage.create({
            data: {
              couponId: b.couponId,
              customerId: b.customerId,
              bookingId: b.id,
              discountAmount: b.discountAmount!,
            },
          });
        }
      }

      if (this.invoicesService) {
        try {
          await this.invoicesService.generateInvoiceForBooking(b.id, tx);
        } catch (invErr: any) {
          this.logger.warn(
            `Failed to generate invoice during payment verification: ${invErr.message}`,
          );
        }
      }

      return b;
    });

    // 8. Asynchronous Customer Notification
    if (updatedBooking) {
      this.notificationsService
        .notifyUser(
          updatedBooking.customerId,
          'Payment Received',
          `Your payment of INR ${payment.amount} for booking ${updatedBooking.id} was successfully verified. Awaiting host confirmation.`,
        )
        .catch((err) =>
          this.logger.error(
            'Failed to notify customer of verified payment',
            err,
          ),
        );
    }

    return {
      success: true,
      bookingId: booking.id,
      paymentId: payment.id,
      status: PaymentStatus.PAID,
    };
  }

  /**
   * Verifies signature and handles webhook events from Razorpay with persistent WebhookEvent deduplication.
   */
  async handleWebhook(rawBody: string, signature: string, headers?: any) {
    if (this.useMock && signature === 'mock_signature') {
      this.logger.log(
        '[RAZORPAY-MOCK] Skipping signature verification for mock_signature',
      );
    } else {
      const isValid = Razorpay.validateWebhookSignature(
        rawBody,
        signature,
        this.webhookSecret,
      );
      if (!isValid) {
        this.logger.warn(
          'Invalid signature detected in Razorpay Webhook request',
        );
        throw new BadRequestException('Invalid webhook signature');
      }
    }

    const payload = JSON.parse(rawBody);
    const event = payload.event;

    // Persistent deduplication & idempotency via WebhookEvent table
    const eventId =
      (headers && (headers['x-razorpay-event-id'] || headers['x-event-id'])) ||
      payload.event_id ||
      payload.id ||
      crypto.createHash('sha256').update(rawBody).digest('hex');

    if (this.prisma.webhookEvent) {
      try {
        await this.prisma.webhookEvent.create({
          data: {
            gateway: 'RAZORPAY',
            eventId: String(eventId),
            eventType: String(event),
            payload: payload,
            signature,
            status: 'RECEIVED',
          },
        });
      } catch (err: any) {
        if (
          err.code === 'P2002' ||
          err.message?.includes('Unique constraint') ||
          err.message?.includes('duplicate key')
        ) {
          this.logger.log(
            `[WEBHOOK-DEDUPLICATION] Duplicate webhook event ${eventId} already received. Skipping.`,
          );
          return { received: true, duplicate: true, alreadyProcessed: true };
        }
        this.logger.warn(`Failed to insert WebhookEvent: ${err.message}`);
      }
    }

    if (event === 'payment.captured' || event === 'order.paid') {
      const paymentEntity = payload.payload?.payment?.entity;
      if (!paymentEntity) {
        this.logger.warn('Webhook received without payment entity');
        return { received: true };
      }

      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;
      const amount = paymentEntity.amount;
      const currency = paymentEntity.currency;

      this.logger.log(
        `Processing captured payment ${paymentId} for order ${orderId}`,
      );

      const payment = await this.prisma.payment.findFirst({
        where: { razorpayOrderId: orderId },
      });

      if (!payment) {
        this.logger.warn(
          `Payment record not found for razorpayOrderId: ${orderId}`,
        );
        return { received: true, error: 'Payment not found' };
      }

      // Validate currency
      if (currency && currency.toUpperCase() !== 'INR') {
        this.logger.error(
          `Webhook currency mismatch for payment ${paymentId}: expected INR, got ${currency}`,
        );
        return { received: true };
      }

      // Validate amount
      const expectedAmountInPaise = Math.round(payment.amount.toNumber() * 100);
      if (amount && Number(amount) !== expectedAmountInPaise) {
        this.logger.error(
          `Webhook amount mismatch for payment ${paymentId}: expected ${expectedAmountInPaise} paise, got ${amount} paise`,
        );
        return { received: true };
      }

      // Idempotency check
      if (payment.status === PaymentStatus.PAID) {
        this.logger.log(
          `Payment for order ${orderId} already marked PAID (idempotent skip)`,
        );
        if (this.prisma.webhookEvent) {
          try {
            await this.prisma.webhookEvent.update({
              where: { eventId: String(eventId) },
              data: { status: 'PROCESSED', processedAt: new Date() },
            });
          } catch (_) {}
        }
        return { received: true, alreadyProcessed: true };
      }

      const booking = await this.prisma.$transaction(async (tx) => {
        await tx.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.PAID,
            razorpayPaymentId: paymentId,
          },
        });

        const b = await tx.booking.findUnique({
          where: { id: payment.bookingId },
        });

        return b;
      });

      if (this.prisma.webhookEvent) {
        try {
          await this.prisma.webhookEvent.update({
            where: { eventId: String(eventId) },
            data: { status: 'PROCESSED', processedAt: new Date() },
          });
        } catch (_) {}
      }

      if (booking) {
        this.notificationsService
          .notifyUser(
            booking.customerId,
            'Payment Received',
            `Your payment of INR ${payment.amount} for booking ${booking.id} was received. Awaiting host confirmation.`,
          )
          .catch((err) =>
            this.logger.error(
              'Failed to notify customer of payment capture',
              err,
            ),
          );
      }
    } else if (event === 'payment.failed') {
      const paymentEntity = payload.payload?.payment?.entity;
      if (!paymentEntity) return { received: true };

      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      this.logger.log(
        `Processing failed payment ${paymentId} for order ${orderId}`,
      );

      const payment = await this.prisma.payment.findFirst({
        where: { razorpayOrderId: orderId },
      });

      if (payment && payment.status !== PaymentStatus.PAID) {
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.FAILED,
            razorpayPaymentId: paymentId,
          },
        });
      }
    } else if (event === 'refund.processed') {
      const refundEntity = payload.payload?.refund?.entity;
      if (!refundEntity) return { received: true };

      const refundId = refundEntity.id;
      const paymentId = refundEntity.payment_id;
      const amountPaise = refundEntity.amount;

      this.logger.log(
        `Processing refund.processed event for refund ${refundId}, payment ${paymentId}`,
      );

      const payment = await this.prisma.payment.findFirst({
        where: {
          OR: [
            { razorpayRefundId: refundId },
            { razorpayPaymentId: paymentId },
          ],
        },
        include: { booking: true },
      });

      if (payment) {
        if (payment.refundStatus === RefundStatus.PROCESSED) {
          this.logger.log(
            `Refund ${refundId} for payment ${paymentId} already marked PROCESSED (idempotent skip)`,
          );
          return { received: true, alreadyProcessed: true };
        }

        const refundRupees = new Decimal((amountPaise / 100).toFixed(2));

        await this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.REFUNDED,
            razorpayRefundId: refundId,
            refundAmount: refundRupees,
            refundStatus: RefundStatus.PROCESSED,
          },
        });

        if (payment.booking?.customerId) {
          this.notificationsService
            .notifyUser(
              payment.booking.customerId,
              'Refund Processed',
              `Your refund of INR ${refundRupees} for booking ${payment.bookingId} has been credited to your bank account.`,
            )
            .catch((err) =>
              this.logger.error(
                'Failed to notify customer of refund settlement',
                err,
              ),
            );
        }
      }
    } else if (event === 'refund.created') {
      const refundEntity = payload.payload?.refund?.entity;
      if (!refundEntity) return { received: true };

      const refundId = refundEntity.id;
      const paymentId = refundEntity.payment_id;
      const amountPaise = refundEntity.amount;

      this.logger.log(
        `Processing refund.created event for refund ${refundId}, payment ${paymentId}`,
      );

      const payment = await this.prisma.payment.findFirst({
        where: {
          OR: [
            { razorpayRefundId: refundId },
            { razorpayPaymentId: paymentId },
          ],
        },
      });

      if (payment && payment.refundStatus !== RefundStatus.PROCESSED) {
        const refundRupees = new Decimal((amountPaise / 100).toFixed(2));
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            razorpayRefundId: refundId,
            refundAmount: refundRupees,
            refundStatus: RefundStatus.PENDING,
          },
        });
      }
    } else if (event === 'refund.failed') {
      const refundEntity = payload.payload?.refund?.entity;
      if (!refundEntity) return { received: true };

      const refundId = refundEntity.id;
      const paymentId = refundEntity.payment_id;

      this.logger.error(
        `CRITICAL: refund.failed event received for refund ${refundId}, payment ${paymentId}`,
      );

      const payment = await this.prisma.payment.findFirst({
        where: {
          OR: [
            { razorpayRefundId: refundId },
            { razorpayPaymentId: paymentId },
          ],
        },
      });

      if (payment) {
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            refundStatus: RefundStatus.FAILED,
          },
        });
      }
    }

    return { received: true };
  }

  /**
   * Performs partial or full refund on PAID payment for a booking with deterministic idempotency.
   */
  async refund(
    bookingId: string,
    refundAmountInPaise: number,
    reason?: string,
    cancellationTier?: string,
    idempotencyKeyParam?: string,
    requestedByUserId?: string,
  ): Promise<{
    refundId: string | null;
    refundAmount: Decimal;
    refundStatus: RefundStatus;
    paymentRefundId?: string;
    isDuplicate?: boolean;
  }> {
    const payment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (!payment) {
      this.logger.log(
        `No payment record found for booking ${bookingId}, skipping refund`,
      );
      return {
        refundId: null,
        refundAmount: new Decimal(0),
        refundStatus: RefundStatus.NONE,
      };
    }

    if (payment.status !== PaymentStatus.PAID) {
      this.logger.log(
        `Payment status for booking ${bookingId} is ${payment.status}, skipping refund`,
      );
      return {
        refundId: payment.razorpayRefundId || null,
        refundAmount: payment.refundAmount || new Decimal(0),
        refundStatus: payment.refundStatus,
      };
    }

    const refundAmountInRupees = new Decimal(
      (refundAmountInPaise / 100).toFixed(2),
    );

    // Handle 0% refund (e.g. cancellation after trip start)
    if (refundAmountInPaise <= 0) {
      this.logger.log(
        `Zero refund amount for booking ${bookingId} (Tier: ${cancellationTier || 'N/A'}). No gateway call needed.`,
      );
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          refundAmount: new Decimal(0),
          refundStatus: RefundStatus.NONE,
        },
      });
      return {
        refundId: null,
        refundAmount: new Decimal(0),
        refundStatus: RefundStatus.NONE,
      };
    }

    const maxRefundPaise = Math.round(payment.amount.toNumber() * 100);
    if (refundAmountInPaise > maxRefundPaise) {
      throw new BadRequestException(
        `Refund amount (${refundAmountInPaise} paise) cannot exceed payment amount (${maxRefundPaise} paise).`,
      );
    }

    // 1. Determine Wallet vs Gateway contribution from checkout debits
    const walletDebits = this.prisma.walletLedgerEntry
      ? await this.prisma.walletLedgerEntry.findMany({
          where: {
            referenceType: 'BOOKING',
            referenceId: bookingId,
            type: LedgerEntryType.CHECKOUT_DEBIT,
          },
        })
      : [];

    const totalWalletPaid = walletDebits.reduce(
      (sum, entry) => sum.add(entry.amount),
      new Decimal(0),
    );
    const totalGatewayPaid = payment.amount.sub(totalWalletPaid);

    // 2. Allocate Refund: Gateway first (refund to source), remainder to Wallet
    const totalRefundRupees = refundAmountInRupees;
    const gatewayRefundRupees = Decimal.min(totalRefundRupees, totalGatewayPaid);
    const walletRefundRupees = totalRefundRupees.sub(gatewayRefundRupees);

    const gatewayRefundInPaise = Math.round(gatewayRefundRupees.toNumber() * 100);
    const idempotencyKey = idempotencyKeyParam || `refund_${bookingId}_${payment.id}`;

    // Persistent deduplication check via PaymentRefund table
    if (this.prisma.paymentRefund) {
      try {
        const existingRefund = await this.prisma.paymentRefund.findUnique({
          where: { idempotencyKey },
        });
        if (existingRefund) {
          this.logger.log(
            `[REFUND-IDEMPOTENT] Existing refund record found for key ${idempotencyKey}. Returning idempotently.`,
          );
          return {
            refundId: existingRefund.gatewayRefundId,
            refundAmount:
              existingRefund.processedAmount || existingRefund.requestedAmount,
            refundStatus: existingRefund.status,
            paymentRefundId: existingRefund.id,
            isDuplicate: true,
          };
        }
      } catch (_) {}
    }

    let refundId: string | null = null;
    let initialRefundStatus: RefundStatus = RefundStatus.PROCESSED;

    // 3. Process Gateway Refund if applicable
    if (gatewayRefundInPaise > 0) {
      this.logger.log(
        `Initiating gateway refund of ${gatewayRefundInPaise} paise for booking ${bookingId}, paymentId: ${payment.razorpayPaymentId}, idempotencyKey: ${idempotencyKey}`,
      );

      if (this.useMock) {
        refundId = `rfnd_mock_${Math.random().toString(36).substring(2, 12)}`;
        this.logger.log(
          `[RAZORPAY-MOCK] Processed mock gateway refund ${refundId} of ${gatewayRefundRupees} for booking ${bookingId}`,
        );
      } else {
        if (!payment.razorpayPaymentId) {
          throw new BadRequestException(
            'Cannot refund a gateway payment without a Razorpay payment ID',
          );
        }

        try {
          const refundResponse: any = await (
            this.razorpay!.payments as any
          ).refund(payment.razorpayPaymentId, {
            amount: gatewayRefundInPaise,
            speed: 'normal',
            notes: {
              bookingId,
              reason: reason || 'Booking cancelled',
              cancellationTier: cancellationTier || 'N/A',
            },
            receipt: idempotencyKey,
          });

          refundId = refundResponse.id;
          if (refundResponse.status === 'pending') {
            initialRefundStatus = RefundStatus.PENDING;
          } else if (refundResponse.status === 'failed') {
            initialRefundStatus = RefundStatus.FAILED;
          } else {
            initialRefundStatus = RefundStatus.PROCESSED;
          }
        } catch (err: any) {
          const errorDesc =
            err?.error?.description || err?.message || String(err);
          const isAlreadyRefunded =
            typeof errorDesc === 'string' &&
            errorDesc.toLowerCase().includes('already');

          if (isAlreadyRefunded) {
            this.logger.warn(
              `Payment ${payment.razorpayPaymentId} was already refunded at Razorpay. Fetching existing refund details for idempotent recovery...`,
            );
            const refundsList = await (
              this.razorpay!.payments as any
            ).fetchMultipleRefund(payment.razorpayPaymentId);
            if (refundsList && refundsList.items && refundsList.items.length > 0) {
              const existingRefund = refundsList.items[0];
              refundId = existingRefund.id;
              initialRefundStatus =
                existingRefund.status === 'pending'
                  ? RefundStatus.PENDING
                  : existingRefund.status === 'failed'
                    ? RefundStatus.FAILED
                    : RefundStatus.PROCESSED;
              this.logger.log(
                `Recovered existing Razorpay refund ${refundId} (status: ${initialRefundStatus}) for booking ${bookingId}`,
              );
            } else {
              this.logger.error('Razorpay refund API call failed:', err);
              throw new BadRequestException(
                `Failed to initiate refund with Razorpay: ${errorDesc}`,
              );
            }
          } else {
            this.logger.error('Razorpay refund API call failed:', err);
            throw new BadRequestException(
              `Failed to initiate refund with Razorpay: ${errorDesc}`,
            );
          }
        }
      }
    } else {
      // Full wallet refund or zero gateway refund
      refundId = `rfnd_wlt_${bookingId.slice(-8)}`;
      initialRefundStatus = RefundStatus.PROCESSED;
    }

    // 4. Process Wallet Refund if applicable
    if (walletRefundRupees.gt(0) && this.walletsService) {
      const booking = await this.prisma.booking.findUnique({
        where: { id: bookingId },
        select: { customerId: true },
      });

      if (booking?.customerId) {
        const customerWallet = await this.walletsService.getOrCreateWallet(
          booking.customerId,
        );

        await this.walletsService.creditWallet(
          customerWallet.id,
          walletRefundRupees,
          LedgerEntryType.BOOKING_REFUND,
          WalletBucketType.REFUND_CREDIT,
          'BOOKING',
          bookingId,
          `refund_wallet_${bookingId}_${payment.id}`,
          `Refund for cancelled booking ${bookingId} (${cancellationTier || 'N/A'})`,
          undefined,
          {
            bookingId,
            cancellationTier,
            reason,
            gatewayRefund: gatewayRefundRupees.toNumber(),
            walletRefund: walletRefundRupees.toNumber(),
          },
        );

        this.logger.log(
          `[WALLET REFUND] Credited ₹${walletRefundRupees.toFixed(2)} to User ${booking.customerId} Wallet for cancelled booking ${bookingId}`,
        );
      }
    }

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status:
          initialRefundStatus === RefundStatus.PROCESSED
            ? PaymentStatus.REFUNDED
            : PaymentStatus.PAID,
        razorpayRefundId: refundId,
        refundAmount: totalRefundRupees,
        refundStatus: initialRefundStatus,
      },
    });

    let paymentRefundId: string | undefined;
    if (this.prisma.paymentRefund) {
      try {
        const pr = await this.prisma.paymentRefund.create({
          data: {
            paymentId: payment.id,
            bookingId,
            gatewayRefundId: refundId,
            idempotencyKey,
            requestedAmount: refundAmountInRupees,
            processedAmount:
              initialRefundStatus === RefundStatus.PROCESSED
                ? refundAmountInRupees
                : null,
            currency: 'INR',
            reason: reason || 'Booking cancellation',
            requestedByUserId,
            status: initialRefundStatus,
          },
        });
        paymentRefundId = pr.id;
      } catch (err: any) {
        this.logger.warn(`Failed to persist PaymentRefund record: ${err.message}`);
      }
    }

    return {
      refundId,
      refundAmount: totalRefundRupees,
      refundStatus: initialRefundStatus,
      paymentRefundId,
      isDuplicate: false,
    };
  }

  /**
   * Administrative override for issuing manual refunds with full audit logging.
   */
  async adminRefund(
    bookingId: string,
    dto: AdminRefundDto,
    requestingUser: { userId: string; role: Role },
  ) {
    if (requestingUser.role !== Role.ADMIN) {
      throw new ForbiddenException('Only administrators can issue manual refunds.');
    }

    const payment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (!payment) {
      throw new NotFoundException('Payment not found for booking.');
    }

    if (
      payment.status !== PaymentStatus.PAID &&
      payment.status !== PaymentStatus.REFUNDED &&
      payment.status !== PaymentStatus.PARTIALLY_REFUNDED
    ) {
      throw new BadRequestException(`Cannot refund payment in ${payment.status} status.`);
    }

    const currentRefunded = payment.refundAmount || new Decimal(0);
    const maxRefundable = payment.amount.sub(currentRefunded);

    if (maxRefundable.lte(0)) {
      throw new BadRequestException('Payment has already been fully refunded.');
    }

    const maxRefundablePaise = Math.round(maxRefundable.toNumber() * 100);
    const targetRefundPaise = dto.amountInPaise || maxRefundablePaise;

    if (targetRefundPaise > maxRefundablePaise) {
      throw new BadRequestException(
        `Requested refund amount (${targetRefundPaise} paise) exceeds remaining refundable amount (${maxRefundablePaise} paise).`,
      );
    }

    const effectiveKey =
      dto.idempotencyKey || `admin_rfnd_${bookingId}_${targetRefundPaise}_${Date.now()}`;

    const result = await this.refund(
      bookingId,
      targetRefundPaise,
      dto.reason,
      'ADMIN_MANUAL_OVERRIDE',
      effectiveKey,
      requestingUser.userId,
    );

    if (this.auditLogService) {
      await this.auditLogService.log(
        requestingUser.userId,
        'ADMIN_PAYMENT_REFUND',
        'Payment',
        payment.id,
        {
          bookingId,
          refundAmountPaise: targetRefundPaise,
          reason: dto.reason,
          refundId: result.refundId,
          status: result.refundStatus,
        },
      );
    }

    return {
      success: true,
      bookingId,
      paymentId: payment.id,
      refundId: result.refundId,
      refundAmount: result.refundAmount,
      refundStatus: result.refundStatus,
    };
  }

  /**
   * Retrieves payment details for customer/admin lookup with refund history and gateway timeline.
   */
  async getPaymentByBookingId(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAuthorizedStaff =
      requestingUser.role === Role.ADMIN ||
      requestingUser.role === Role.SUPPORT_AGENT;
    const isCustomer = booking.customerId === requestingUser.userId;

    if (!isAuthorizedStaff && !isCustomer) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view this payment.',
      );
    }

    const payment = await this.prisma.payment.findUnique({
      where: { bookingId },
      include: {
        refunds: {
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!payment) {
      return null;
    }

    return {
      ...payment,
      keyId: this.keyId,
      currency: 'INR',
      amountInPaise: Math.round(payment.amount.toNumber() * 100),
      refunds: (payment as any).refunds || [],
    };
  }
}
