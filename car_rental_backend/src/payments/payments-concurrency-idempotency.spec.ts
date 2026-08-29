import { PaymentsService } from './payments.service';
import { PaymentStatus, BookingStatus, RefundStatus, SecurityDepositStatus, Prisma } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('PaymentsConcurrencyIdempotency (Phase 27.6)', () => {
  let service: PaymentsService;
  let mockPrisma: any;
  let mockConfig: any;
  let mockNotifications: any;
  let mockInvoices: any;
  let mockWallets: any;

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
      },
      securityDeposit: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    mockConfig = {
      get: jest.fn((key: string) => {
        if (key === 'RAZORPAY_USE_MOCK') return 'true';
        if (key === 'NODE_ENV') return 'test';
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_123';
        if (key === 'RAZORPAY_KEY_SECRET') return 'secret_123';
        if (key === 'RAZORPAY_WEBHOOK_SECRET') return 'wh_sec_123';
        return null;
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockInvoices = {
      generateInvoice: jest.fn().mockResolvedValue({ id: 'inv-1' }),
    };

    mockWallets = {
      debitForBooking: jest.fn().mockResolvedValue(undefined),
      refundToWallet: jest.fn().mockResolvedValue(undefined),
    };

    service = new PaymentsService(
      mockPrisma,
      mockConfig,
      mockNotifications,
      mockInvoices,
      mockWallets,
    );
  });

  describe('Webhook & Payment Verification Idempotency', () => {
    it('should safely return existing verified payment if already marked as PAID', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book-1',
        customerId: 'cust-1',
        status: BookingStatus.PENDING,
        totalFare: new Prisma.Decimal(5000),
      });

      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'book-1',
        amount: new Prisma.Decimal(5000),
        status: PaymentStatus.PAID,
        razorpayOrderId: 'order_123',
        razorpayPaymentId: 'pay_123',
      });

      const result = await service.verifyPayment(
        {
          bookingId: 'book-1',
          razorpayOrderId: 'order_123',
          razorpayPaymentId: 'pay_123',
          razorpaySignature: 'valid_sig',
        },
        'cust-1',
      );

      expect(result.status).toBe(PaymentStatus.PAID);
      expect(mockPrisma.booking.update).not.toHaveBeenCalled();
    });
  });

  describe('Refund Concurrency & Maximum Bounds', () => {
    it('should reject refund if requested amount exceeds total payment amount', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'book-1',
        amount: new Prisma.Decimal(5000),
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_123',
        booking: {
          id: 'book-1',
          customerId: 'cust-1',
          totalFare: new Prisma.Decimal(5000),
          walletDeduction: new Prisma.Decimal(0),
        },
      });

      // 600,000 paise = ₹6,000 which exceeds ₹5,000 (500,000 paise)
      await expect(
        service.refund('book-1', 600000, 'Cancellation refund'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should process refund within bounds successfully', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'book-1',
        amount: new Prisma.Decimal(5000),
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_123',
        refundAmount: new Prisma.Decimal(0),
        refundStatus: RefundStatus.NONE,
        booking: {
          id: 'book-1',
          customerId: 'cust-1',
          totalFare: new Prisma.Decimal(5000),
          walletDeduction: new Prisma.Decimal(0),
        },
      });

      mockPrisma.payment.update.mockImplementation((args: any) => ({
        id: 'pay-1',
        ...args.data,
      }));

      // 300,000 paise = ₹3,000
      const result = await service.refund(
        'book-1',
        300000,
        'Partial cancellation refund',
      );

      expect(result.refundAmount.toNumber()).toBe(3000);
      expect(result.refundStatus).toBe(RefundStatus.PROCESSED);
    });
  });
});
