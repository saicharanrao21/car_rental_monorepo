import { 
  Injectable, 
  NotFoundException, 
  ForbiddenException, 
  BadRequestException, 
  ConflictException,
  Logger
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import Razorpay from 'razorpay';
import { Role, PaymentStatus, BookingStatus } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';

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
    this.keyId = this.configService.get<string>('RAZORPAY_KEY_ID') || 'rzp_test_placeholderKeyId';
    this.keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET') || 'placeholderKeySecret';
    this.webhookSecret = this.configService.get<string>('RAZORPAY_WEBHOOK_SECRET') || 'placeholderWebhookSecret';
    this.useMock = this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';

    if (this.useMock && this.configService.get<string>('NODE_ENV') === 'production') {
      throw new Error('CRITICAL SECURITY CONFIGURATION ERROR: RAZORPAY_USE_MOCK is set to true, but NODE_ENV is production! Bypassing payment verification in production is forbidden.');
    }

    if (!this.useMock) {
      try {
        this.razorpay = new Razorpay({
          key_id: this.keyId,
          key_secret: this.keySecret,
        });
      } catch (err) {
        this.logger.error('Failed to initialize Razorpay SDK. Falling back to mock mode.', err);
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
      throw new ForbiddenException('Access denied: You can only pay for your own bookings.');
    }

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException('Only pending bookings can be paid for.');
    }

    // Check for existing Payment row
    const existingPayment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (existingPayment) {
      if (existingPayment.status === PaymentStatus.PAID || existingPayment.status === PaymentStatus.REFUNDED) {
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
      this.logger.log(`[RAZORPAY-MOCK] Created mock order ${orderId} for booking ${bookingId} of amount ${amountInPaise} paise`);
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
        throw new BadRequestException('Failed to create payment order with Razorpay. Try again.');
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
   * Verifies signature and handles webhook events from Razorpay.
   */
  async handleWebhook(rawBody: string, signature: string) {
    if (this.useMock && signature === 'mock_signature') {
      this.logger.log('[RAZORPAY-MOCK] Skipping signature verification for mock_signature');
    } else {
      const isValid = Razorpay.validateWebhookSignature(rawBody, signature, this.webhookSecret);
      if (!isValid) {
        this.logger.warn('Invalid signature detected in Razorpay Webhook request');
        throw new BadRequestException('Invalid webhook signature');
      }
    }

    const payload = JSON.parse(rawBody);
    const event = payload.event;

    if (event === 'payment.captured') {
      const paymentEntity = payload.payload.payment.entity;
      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      this.logger.log(`Processing captured payment ${paymentId} for order ${orderId}`);

      const payment = await this.prisma.payment.findFirst({
        where: { razorpayOrderId: orderId },
      });

      if (!payment) {
        this.logger.warn(`No payment record found for razorpayOrderId: ${orderId}`);
        return { received: true };
      }

      if (payment.status === PaymentStatus.PAID) {
        this.logger.log(`Payment for order ${orderId} already marked PAID (idempotent skip)`);
        return { received: true };
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
          this.logger.log(`Booking ${b.id} status updated to CONFIRMED due to payment capture`);
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
          .catch((err) => this.logger.error('Failed to notify customer of payment capture', err));
      }
    } else if (event === 'payment.failed') {
      const paymentEntity = payload.payload.payment.entity;
      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      this.logger.log(`Processing failed payment ${paymentId} for order ${orderId}`);

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
    }

    return { received: true };
  }

  /**
   * Performs refund on PAID payment for a booking.
   */
  async refund(bookingId: string, reason?: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { bookingId },
    });

    if (!payment) {
      this.logger.log(`No payment record found for booking ${bookingId}, skipping refund`);
      return;
    }

    if (payment.status !== PaymentStatus.PAID) {
      this.logger.log(`Payment status for booking ${bookingId} is ${payment.status}, skipping refund`);
      return;
    }

    this.logger.log(`Initiating refund for booking ${bookingId}, paymentId: ${payment.razorpayPaymentId}`);

    if (this.useMock) {
      this.logger.log(`[RAZORPAY-MOCK] Processed mock refund of ${payment.amount} for booking ${bookingId}`);
    } else {
      if (!payment.razorpayPaymentId) {
        throw new BadRequestException('Cannot refund a payment without a Razorpay payment ID');
      }

      try {
        await this.razorpay!.payments.refund(payment.razorpayPaymentId, {
          notes: {
            bookingId,
            reason: reason || 'Booking cancelled',
          },
        });
      } catch (err) {
        this.logger.error('Razorpay refund API call failed:', err);
        throw new BadRequestException('Failed to initiate refund with Razorpay');
      }
    }

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.REFUNDED,
      },
    });
  }

  /**
   * Retrieves payment details for customer/admin lookup.
   */
  async getPaymentByBookingId(bookingId: string, requestingUser: { userId: string; role: Role }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isCustomer = booking.customerId === requestingUser.userId;

    if (!isAdmin && !isCustomer) {
      throw new ForbiddenException('Access denied: You are not authorized to view this payment.');
    }

    return this.prisma.payment.findUnique({
      where: { bookingId },
    });
  }
}
