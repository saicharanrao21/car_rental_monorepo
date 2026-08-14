import { ConfigService } from '@nestjs/config';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BadRequestException } from '@nestjs/common';
import { PaymentStatus, RefundStatus } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import * as crypto from 'crypto';

describe('PaymentsService — Phase 3B Refund & Cancellation Tests', () => {
  let service: PaymentsService;
  let mockPrisma: any;
  let mockConfigService: any;
  let mockNotifications: any;

  const testWebhookSecret = 'test_webhook_secret_key_12345';

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
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_mockId';
        if (key === 'RAZORPAY_KEY_SECRET') return 'rzp_test_secret';
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

  describe('refund', () => {
    const bookingId = 'booking_refund_123';
    const paymentId = 'pay_record_456';
    const razorpayPaymentId = 'pay_rzp_gateway_789';

    const mockPaidPayment = {
      id: paymentId,
      bookingId,
      razorpayOrderId: 'order_123',
      razorpayPaymentId,
      amount: new Decimal(5000.0),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      refundAmount: null,
      razorpayRefundId: null,
    };

    it('should successfully execute partial refund (75%) with X-Refund-Idempotency header', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue(mockPaidPayment);
      mockPrisma.payment.update.mockResolvedValue({
        ...mockPaidPayment,
        status: PaymentStatus.REFUNDED,
        razorpayRefundId: 'rfnd_gateway_111',
        refundAmount: new Decimal(3750.0),
        refundStatus: RefundStatus.PROCESSED,
      });

      const mockRefundFn = jest.fn().mockResolvedValue({
        id: 'rfnd_gateway_111',
        entity: 'refund',
        amount: 375000,
        currency: 'INR',
        payment_id: razorpayPaymentId,
        status: 'processed',
      });

      (service as any).razorpay = {
        payments: {
          refund: mockRefundFn,
        },
      };

      const result = await service.refund(
        bookingId,
        375000, // 3750 INR in paise
        'Moderate cancellation (25% fee)',
        'MODERATE_CANCELLATION',
      );

      expect(result.refundId).toBe('rfnd_gateway_111');
      expect(result.refundAmount.toNumber()).toBe(3750);
      expect(result.refundStatus).toBe(RefundStatus.PROCESSED);

      expect(mockRefundFn).toHaveBeenCalledWith(
        razorpayPaymentId,
        {
          amount: 375000,
          notes: {
            bookingId,
            reason: 'Moderate cancellation (25% fee)',
            cancellationTier: 'MODERATE_CANCELLATION',
          },
        },
        {
          'X-Refund-Idempotency': `refund_${bookingId}_${paymentId}`,
        },
      );

      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: paymentId },
        data: {
          status: PaymentStatus.REFUNDED,
          razorpayRefundId: 'rfnd_gateway_111',
          refundAmount: new Decimal(3750.0),
          refundStatus: RefundStatus.PROCESSED,
        },
      });
    });

    it('should handle pending status from Razorpay refund', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue(mockPaidPayment);
      mockPrisma.payment.update.mockResolvedValue({
        ...mockPaidPayment,
        razorpayRefundId: 'rfnd_gateway_pending',
        refundAmount: new Decimal(5000.0),
        refundStatus: RefundStatus.PENDING,
      });

      (service as any).razorpay = {
        payments: {
          refund: jest.fn().mockResolvedValue({
            id: 'rfnd_gateway_pending',
            status: 'pending',
          }),
        },
      };

      const result = await service.refund(bookingId, 500000);
      expect(result.refundStatus).toBe(RefundStatus.PENDING);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: paymentId },
        data: {
          status: PaymentStatus.PAID, // Remains PAID until settlement confirmed via webhook
          razorpayRefundId: 'rfnd_gateway_pending',
          refundAmount: new Decimal(5000.0),
          refundStatus: RefundStatus.PENDING,
        },
      });
    });

    it('should handle 0% refund without making any gateway API call', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue(mockPaidPayment);

      const mockRefundFn = jest.fn();
      (service as any).razorpay = {
        payments: {
          refund: mockRefundFn,
        },
      };

      const result = await service.refund(bookingId, 0, 'No-show cancellation');

      expect(result.refundId).toBeNull();
      expect(result.refundAmount.toNumber()).toBe(0);
      expect(result.refundStatus).toBe(RefundStatus.NONE);
      expect(mockRefundFn).not.toHaveBeenCalled();
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: paymentId },
        data: {
          refundAmount: new Decimal(0),
          refundStatus: RefundStatus.NONE,
        },
      });
    });

    it('should reject refund if requested paise exceeds payment amount', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue(mockPaidPayment);

      await expect(
        service.refund(bookingId, 600000), // 6000 INR vs 5000 INR paid
      ).rejects.toThrow(BadRequestException);
    });

    it('should safely skip refund if payment is not in PAID status', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        ...mockPaidPayment,
        status: PaymentStatus.CREATED,
      });

      const result = await service.refund(bookingId, 500000);
      expect(result.refundId).toBeNull();
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });
  });

  describe('handleWebhook — Refund Events', () => {
    const refundId = 'rfnd_webhook_123';
    const paymentId = 'pay_webhook_456';
    const bookingId = 'booking_webhook_789';

    it('should process refund.processed webhook and mark Payment as REFUNDED and notify customer', async () => {
      const payload = JSON.stringify({
        event: 'refund.processed',
        payload: {
          refund: {
            entity: {
              id: refundId,
              payment_id: paymentId,
              amount: 375000,
              currency: 'INR',
              status: 'processed',
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(payload);

      const mockPayment = {
        id: 'payment_row_id',
        bookingId,
        razorpayPaymentId: paymentId,
        razorpayRefundId: refundId,
        refundStatus: RefundStatus.PENDING,
        amount: new Decimal(5000.0),
        booking: {
          id: bookingId,
          customerId: 'customer_user_999',
        },
      };

      mockPrisma.payment.findFirst.mockResolvedValue(mockPayment);
      mockPrisma.payment.update.mockResolvedValue({
        ...mockPayment,
        refundStatus: RefundStatus.PROCESSED,
        status: PaymentStatus.REFUNDED,
      });

      const result = await service.handleWebhook(payload, signature);
      expect(result.received).toBe(true);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: mockPayment.id },
        data: {
          status: PaymentStatus.REFUNDED,
          razorpayRefundId: refundId,
          refundAmount: new Decimal(3750.0),
          refundStatus: RefundStatus.PROCESSED,
        },
      });
      expect(mockNotifications.notifyUser).toHaveBeenCalledWith(
        'customer_user_999',
        'Refund Processed',
        expect.stringContaining('INR 3750'),
      );
    });

    it('should idempotently skip duplicate refund.processed webhook', async () => {
      const payload = JSON.stringify({
        event: 'refund.processed',
        payload: {
          refund: {
            entity: {
              id: refundId,
              payment_id: paymentId,
              amount: 375000,
              currency: 'INR',
              status: 'processed',
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(payload);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'payment_row_id',
        bookingId,
        razorpayPaymentId: paymentId,
        razorpayRefundId: refundId,
        refundStatus: RefundStatus.PROCESSED,
        status: PaymentStatus.REFUNDED,
      });

      const result = await service.handleWebhook(payload, signature);
      expect(result.received).toBe(true);
      expect(result.alreadyProcessed).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });

    it('should update refundStatus to FAILED on refund.failed webhook', async () => {
      const payload = JSON.stringify({
        event: 'refund.failed',
        payload: {
          refund: {
            entity: {
              id: refundId,
              payment_id: paymentId,
            },
          },
        },
      });

      const signature = generateValidWebhookSignature(payload);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'payment_row_id',
        bookingId,
        razorpayPaymentId: paymentId,
        refundStatus: RefundStatus.PENDING,
      });

      const result = await service.handleWebhook(payload, signature);
      expect(result.received).toBe(true);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'payment_row_id' },
        data: {
          refundStatus: RefundStatus.FAILED,
        },
      });
    });
  });
});
