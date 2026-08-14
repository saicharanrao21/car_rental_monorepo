import { ConfigService } from '@nestjs/config';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PaymentStatus, BookingStatus, Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import * as crypto from 'crypto';

describe('PaymentsService — Phase 3A Payment Verification & Integrity Tests', () => {
  let service: PaymentsService;
  let mockPrisma: any;
  let mockConfigService: any;
  let mockNotifications: any;

  const testKeySecret = 'test_razorpay_secret_key_12345';
  const testWebhookSecret = 'test_webhook_secret_key_12345';

  function generateValidSignature(orderId: string, paymentId: string): string {
    const payload = `${orderId}|${paymentId}`;
    return crypto
      .createHmac('sha256', testKeySecret)
      .update(payload)
      .digest('hex');
  }

  function generateValidWebhookSignature(rawBody: string): string {
    return crypto
      .createHmac('sha256', testWebhookSecret)
      .update(rawBody)
      .digest('hex');
  }

  beforeEach(() => {
    mockPrisma = {
      booking: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      $transaction: jest.fn(async (callback) => {
        return callback(mockPrisma);
      }),
    };

    mockConfigService = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'development';
        if (key === 'RAZORPAY_USE_MOCK') return 'false';
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_mockId123456';
        if (key === 'RAZORPAY_KEY_SECRET') return testKeySecret;
        if (key === 'RAZORPAY_WEBHOOK_SECRET') return testWebhookSecret;
        return null;
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    service = new PaymentsService(
      mockPrisma as PrismaService,
      mockConfigService as ConfigService,
      mockNotifications as NotificationsService,
    );
  });

  describe('verifyPayment', () => {
    const bookingId = 'booking_abc_123';
    const customerId = 'cust_user_456';
    const orderId = 'order_rzp_789';
    const paymentId = 'pay_rzp_999';

    const mockBooking = {
      id: bookingId,
      customerId,
      totalFare: new Decimal(5000.0),
      status: BookingStatus.PENDING,
    };

    const mockPayment = {
      id: 'pay_record_1',
      bookingId,
      razorpayOrderId: orderId,
      razorpayPaymentId: null,
      amount: new Decimal(5000.0),
      status: PaymentStatus.CREATED,
    };

    it('should successfully verify payment with valid signature and match booking amount', async () => {
      const signature = generateValidSignature(orderId, paymentId);

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);
      mockPrisma.payment.update.mockResolvedValue({
        ...mockPayment,
        status: PaymentStatus.PAID,
        razorpayPaymentId: paymentId,
      });
      mockPrisma.booking.update.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.CONFIRMED,
      });

      // Mock Razorpay SDK payments.fetch
      (service as any).razorpay = {
        payments: {
          fetch: jest.fn().mockResolvedValue({
            id: paymentId,
            order_id: orderId,
            amount: 500000, // 5000.00 INR in paise
            currency: 'INR',
            status: 'captured',
          }),
        },
      };

      const result = await service.verifyPayment(
        {
          bookingId,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        },
        customerId,
      );

      expect(result.success).toBe(true);
      expect(result.status).toBe(PaymentStatus.PAID);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: mockPayment.id },
        data: {
          status: PaymentStatus.PAID,
          razorpayPaymentId: paymentId,
        },
      });
      expect(mockPrisma.booking.update).toHaveBeenCalledWith({
        where: { id: bookingId },
        data: { status: BookingStatus.CONFIRMED },
      });
      expect(mockNotifications.notifyUser).toHaveBeenCalled();
    });

    it('should throw BadRequestException if signature is invalid/tampered', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: 'invalid_tampered_signature_999999',
          },
          customerId,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ForbiddenException if customer is not the booking owner', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: 'sig',
          },
          'unauthorized_attacker_user',
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw NotFoundException if booking does not exist', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(null);

      await expect(
        service.verifyPayment(
          {
            bookingId: 'non_existent_booking',
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: 'sig',
          },
          customerId,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if razorpayOrderId does not match booking payment order', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue({
        ...mockPayment,
        razorpayOrderId: 'order_different_order_999',
      });

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: 'sig',
          },
          customerId,
        ),
      ).rejects.toThrow(/Payment order mismatch/);
    });

    it('should throw BadRequestException if fetched Razorpay amount does not match authoritative booking totalFare', async () => {
      const signature = generateValidSignature(orderId, paymentId);

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      // Razorpay entity has tampered amount (e.g. ₹100 instead of ₹5000)
      (service as any).razorpay = {
        payments: {
          fetch: jest.fn().mockResolvedValue({
            id: paymentId,
            order_id: orderId,
            amount: 10000, // ₹100 in paise instead of ₹5000
            currency: 'INR',
            status: 'captured',
          }),
        },
      };

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          },
          customerId,
        ),
      ).rejects.toThrow(/Payment amount mismatch/);
    });

    it('should throw BadRequestException if fetched Razorpay currency is not INR', async () => {
      const signature = generateValidSignature(orderId, paymentId);

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      (service as any).razorpay = {
        payments: {
          fetch: jest.fn().mockResolvedValue({
            id: paymentId,
            order_id: orderId,
            amount: 500000,
            currency: 'USD',
            status: 'captured',
          }),
        },
      };

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          },
          customerId,
        ),
      ).rejects.toThrow(/Payment currency mismatch/);
    });

    it('should be idempotent if payment is already marked PAID with the same payment ID', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue({
        ...mockPayment,
        status: PaymentStatus.PAID,
        razorpayPaymentId: paymentId,
      });

      const result = await service.verifyPayment(
        {
          bookingId,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: 'any_sig',
        },
        customerId,
      );

      expect(result.success).toBe(true);
      expect(result.status).toBe(PaymentStatus.PAID);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException and refuse to confirm booking if Razorpay status is authorized', async () => {
      const signature = generateValidSignature(orderId, paymentId);

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      (service as any).razorpay = {
        payments: {
          fetch: jest.fn().mockResolvedValue({
            id: paymentId,
            order_id: orderId,
            amount: 500000,
            currency: 'INR',
            status: 'authorized',
          }),
        },
      };

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          },
          customerId,
        ),
      ).rejects.toThrow(
        /Payment is authorized but not yet captured. Please wait for payment confirmation./,
      );

      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if Razorpay status is neither captured nor authorized', async () => {
      const signature = generateValidSignature(orderId, paymentId);

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);

      (service as any).razorpay = {
        payments: {
          fetch: jest.fn().mockResolvedValue({
            id: paymentId,
            order_id: orderId,
            amount: 500000,
            currency: 'INR',
            status: 'created',
          }),
        },
      };

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          },
          customerId,
        ),
      ).rejects.toThrow(/Payment status is not captured: created/);

      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });

    it('should throw ConflictException if booking is already paid with a different payment ID', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue({
        ...mockPayment,
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_different_confirmed_id',
      });

      await expect(
        service.verifyPayment(
          {
            bookingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: 'any_sig',
          },
          customerId,
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('handleWebhook', () => {
    const orderId = 'order_webhook_123';
    const paymentId = 'pay_webhook_456';
    const bookingId = 'booking_webhook_789';

    it('should process payment.captured event and confirm booking', async () => {
      const webhookPayload = JSON.stringify({
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
              amount: 500000,
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(webhookPayload);

      const mockPayment = {
        id: 'payment_rec_123',
        bookingId,
        razorpayOrderId: orderId,
        amount: new Decimal(5000.0),
        status: PaymentStatus.CREATED,
      };

      const mockBooking = {
        id: bookingId,
        customerId: 'cust_webhook_user',
        status: BookingStatus.PENDING,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(mockPayment);
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.update.mockResolvedValue({
        ...mockPayment,
        status: PaymentStatus.PAID,
      });
      mockPrisma.booking.update.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.CONFIRMED,
      });

      const result = await service.handleWebhook(webhookPayload, signature);
      expect(result.received).toBe(true);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: mockPayment.id },
        data: {
          status: PaymentStatus.PAID,
          razorpayPaymentId: paymentId,
        },
      });
      expect(mockPrisma.booking.update).toHaveBeenCalledWith({
        where: { id: bookingId },
        data: { status: BookingStatus.CONFIRMED },
      });
    });

    it('should reject webhook with invalid signature', async () => {
      const webhookPayload = JSON.stringify({
        event: 'payment.captured',
      });

      await expect(
        service.handleWebhook(webhookPayload, 'invalid_webhook_signature'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should be idempotent when payment.captured webhook arrives for already PAID payment', async () => {
      const webhookPayload = JSON.stringify({
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
              amount: 500000,
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(webhookPayload);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'payment_rec_123',
        bookingId,
        razorpayOrderId: orderId,
        amount: new Decimal(5000.0),
        status: PaymentStatus.PAID,
      });

      const result = await service.handleWebhook(webhookPayload, signature);
      expect(result.received).toBe(true);
      expect(result.alreadyProcessed).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });

    it('should not confirm payment if webhook amount does not match database payment amount', async () => {
      const webhookPayload = JSON.stringify({
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
              amount: 10000, // ₹100 instead of ₹5000
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(webhookPayload);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'payment_rec_123',
        bookingId,
        razorpayOrderId: orderId,
        amount: new Decimal(5000.0),
        status: PaymentStatus.CREATED,
      });

      const result = await service.handleWebhook(webhookPayload, signature);
      expect(result.received).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });

    it('should mark payment as FAILED when payment.failed webhook event arrives', async () => {
      const webhookPayload = JSON.stringify({
        event: 'payment.failed',
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(webhookPayload);

      const mockPayment = {
        id: 'payment_rec_123',
        bookingId,
        razorpayOrderId: orderId,
        status: PaymentStatus.CREATED,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(mockPayment);

      const result = await service.handleWebhook(webhookPayload, signature);
      expect(result.received).toBe(true);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: mockPayment.id },
        data: {
          status: PaymentStatus.FAILED,
          razorpayPaymentId: paymentId,
        },
      });
    });
  });
});
