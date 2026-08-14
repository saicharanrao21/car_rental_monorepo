import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
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
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { NotificationsService } from '../notifications/notifications.service';
import { VerifyPaymentDto } from './dto/verify-payment.dto';

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
   * Creates a Razorpay Order for a PENDING booking.
   */
  async createOrder(bookingId: string, customerId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
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

    const amountInPaise = Math.round(booking.totalFare.toNumber() * 100);

    let orderId: string;

    if (this.useMock) {
      orderId = `order_mock_${Math.random().toString(36).substring(2, 15)}`;
      this.logger.log(
        `[RAZORPAY-MOCK] Created mock order ${orderId} for booking ${bookingId} of amount ${amountInPaise} paise`,
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

    // Create Payment row in CREATED status
    await this.prisma.payment.create({
      data: {
        bookingId,
        razorpayOrderId: orderId,
        amount: booking.totalFare,
        status: PaymentStatus.CREATED,
      },
    });

    return {
      orderId,
      amount: amountInPaise,
      currency: 'INR',
      keyId: this.keyId,
    };
  }

  /**
   * Verifies Razorpay payment signature, validates authoritative booking amount,
   * currency, and order-booking binding, and marks Payment as PAID and Booking as CONFIRMED.
   */
  async verifyPayment(dto: VerifyPaymentDto, customerId: string) {
    const { bookingId, razorpayOrderId, razorpayPaymentId, razorpaySignature } =
      dto;

    // 1. Authoritative Booking existence & Ownership check
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
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
        !payment.razorpayPaymentId
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

        // Verify amount
        const expectedAmountInPaise = Math.round(
          booking.totalFare.toNumber() * 100,
        );
        if (Number(razorpayPayment.amount) !== expectedAmountInPaise) {
          this.logger.error(
            `CRITICAL PAYMENT FRAUD ATTEMPT: Expected ${expectedAmountInPaise} paise, but received ${razorpayPayment.amount} paise for booking ${bookingId}!`,
          );
          throw new BadRequestException(
            `Payment amount mismatch: expected ${expectedAmountInPaise} paise, but received ${razorpayPayment.amount} paise.`,
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
    }

    // 7. Atomic Transactional Confirmation
    const updatedBooking = await this.prisma.$transaction(async (tx) => {
      await tx.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.PAID,
          razorpayPaymentId,
        },
      });

      const b = await tx.booking.findUnique({
        where: { id: bookingId },
      });

      if (b && b.status === BookingStatus.PENDING) {
        const confirmedBooking = await tx.booking.update({
          where: { id: b.id },
          data: { status: BookingStatus.CONFIRMED },
        });
        this.logger.log(
          `Booking ${b.id} status updated to CONFIRMED via server-side payment verification`,
        );
        return confirmedBooking;
      }
      return b;
    });

    // 8. Asynchronous Customer Notification
    if (updatedBooking) {
      this.notificationsService
        .notifyUser(
          updatedBooking.customerId,
          'Payment Confirmed',
          `Your payment of INR ${payment.amount} for booking ${updatedBooking.id} was successfully verified and confirmed.`,
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
   * Verifies signature and handles webhook events from Razorpay.
   */
  async handleWebhook(rawBody: string, signature: string) {
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
          `No payment record found for razorpayOrderId: ${orderId}`,
        );
        return { received: true };
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

        if (b && b.status === BookingStatus.PENDING) {
          const updated = await tx.booking.update({
            where: { id: b.id },
            data: { status: BookingStatus.CONFIRMED },
          });
          this.logger.log(
            `Booking ${b.id} status updated to CONFIRMED due to payment capture`,
          );
          return updated;
        }
        return b;
      });

      if (booking) {
        this.notificationsService
          .notifyUser(
            booking.customerId,
            'Payment Confirmed',
            `Your payment of INR ${payment.amount} for booking ${booking.id} was confirmed.`,
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
  ): Promise<{
    refundId: string | null;
    refundAmount: Decimal;
    refundStatus: RefundStatus;
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

    const idempotencyKey = `refund_${bookingId}_${payment.id}`;
    let refundId: string;
    let initialRefundStatus: RefundStatus = RefundStatus.PROCESSED;

    this.logger.log(
      `Initiating refund of ${refundAmountInPaise} paise for booking ${bookingId}, paymentId: ${payment.razorpayPaymentId}, idempotencyKey: ${idempotencyKey}`,
    );

    if (this.useMock) {
      refundId = `rfnd_mock_${Math.random().toString(36).substring(2, 12)}`;
      this.logger.log(
        `[RAZORPAY-MOCK] Processed mock refund ${refundId} of ${refundAmountInRupees} for booking ${bookingId}`,
      );
    } else {
      if (!payment.razorpayPaymentId) {
        throw new BadRequestException(
          'Cannot refund a payment without a Razorpay payment ID',
        );
      }

      try {
        const refundResponse: any = await (
          this.razorpay!.payments as any
        ).refund(
          payment.razorpayPaymentId,
          {
            amount: refundAmountInPaise,
            notes: {
              bookingId,
              reason: reason || 'Booking cancelled',
              cancellationTier: cancellationTier || 'N/A',
            },
          },
          {
            'X-Refund-Idempotency': idempotencyKey,
          },
        );

        refundId = refundResponse.id;
        if (refundResponse.status === 'pending') {
          initialRefundStatus = RefundStatus.PENDING;
        } else if (refundResponse.status === 'failed') {
          initialRefundStatus = RefundStatus.FAILED;
        } else {
          initialRefundStatus = RefundStatus.PROCESSED;
        }
      } catch (err: any) {
        this.logger.error('Razorpay refund API call failed:', err);
        throw new BadRequestException(
          `Failed to initiate refund with Razorpay: ${err.message || err}`,
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
        refundAmount: refundAmountInRupees,
        refundStatus: initialRefundStatus,
      },
    });

    return {
      refundId,
      refundAmount: refundAmountInRupees,
      refundStatus: initialRefundStatus,
    };
  }

  /**
   * Retrieves payment details for customer/admin lookup.
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

    return this.prisma.payment.findUnique({
      where: { bookingId },
    });
  }
}
