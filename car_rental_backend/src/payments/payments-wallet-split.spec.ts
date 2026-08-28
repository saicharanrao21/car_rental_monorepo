import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from '../notifications/notifications.service';
import { InvoicesService } from '../invoices/invoices.service';
import { WalletsService } from '../wallets/wallets.service';
import { BadRequestException, ConflictException } from '@nestjs/common';
import {
  BookingStatus,
  PaymentStatus,
  RefundStatus,
  Role,
  WalletStatus,
  WalletBucketType,
  LedgerEntryType,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('PaymentsService - Wallet & Split Payment (Phase 24B)', () => {
  let service: PaymentsService;
  let prisma: any;
  let walletsService: any;
  let notificationsService: any;
  let invoicesService: any;

  const mockBooking = {
    id: 'booking_test_1',
    customerId: 'cust_test_1',
    totalFare: new Decimal(3000),
    status: BookingStatus.PENDING,
    startDate: new Date(Date.now() + 48 * 3600 * 1000),
    securityDeposit: {
      id: 'dep_test_1',
      amount: new Decimal(500),
      status: 'REQUIRED',
    },
    car: {
      id: 'car_test_1',
      make: 'Hyundai',
      model: 'Creta',
      registrationNumber: 'KA01AB1234',
    },
    customer: {
      id: 'cust_test_1',
      name: 'Alice',
      phone: '+919876543210',
      email: 'alice@example.com',
    },
  };

  const mockWallet = {
    id: 'wallet_cust_1',
    userId: 'cust_test_1',
    availableBalance: new Decimal(750),
    promoBalance: new Decimal(250),
    realBalance: new Decimal(500),
    lockedBalance: new Decimal(0),
    status: WalletStatus.ACTIVE,
  };

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn().mockResolvedValue(mockBooking),
        update: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({ ...mockBooking, ...data }),
        ),
      },
      payment: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({ id: 'pay_rec_1', ...data }),
        ),
        update: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({ id: 'pay_rec_1', ...data }),
        ),
        delete: jest.fn().mockResolvedValue({ id: 'pay_rec_1' }),
      },
      securityDeposit: {
        update: jest.fn().mockResolvedValue({ id: 'dep_test_1' }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      coupon: {
        findUnique: jest.fn().mockResolvedValue(null),
        update: jest.fn().mockResolvedValue({}),
      },
      couponUsage: {
        findFirst: jest.fn().mockResolvedValue(null),
        count: jest.fn().mockResolvedValue(0),
        create: jest.fn().mockResolvedValue({}),
      },
      walletLedgerEntry: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      $transaction: jest.fn().mockImplementation((cb) => cb(prisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    walletsService = {
      getOrCreateWallet: jest.fn().mockResolvedValue(mockWallet),
      debitWallet: jest.fn().mockResolvedValue({
        id: 'ledger_debit_1',
        amount: new Decimal(750),
      }),
      creditWallet: jest.fn().mockResolvedValue({
        id: 'ledger_credit_1',
        amount: new Decimal(750),
      }),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    invoicesService = {
      generateInvoiceForBooking: jest.fn().mockResolvedValue({ id: 'inv_1' }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'RAZORPAY_USE_MOCK') return 'true';
              if (key === 'NODE_ENV') return 'test';
              return 'test_val';
            }),
          },
        },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: InvoicesService, useValue: invoicesService },
        { provide: WalletsService, useValue: walletsService },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
  });

  describe('Scenario 1: No Wallet Usage (useWallet = false)', () => {
    it('creates full gateway order without deducting wallet', async () => {
      const res = await service.createOrder('booking_test_1', 'cust_test_1', false);

      expect(res.isFullWallet).toBe(false);
      // Fare 3000 + Deposit 500 = 3500 => 350000 paise
      expect(res.amount).toBe(350000);
      expect(res.breakdown.walletApplied).toBe(0);
      expect(res.breakdown.gatewayAmount).toBe(3500);
      expect(prisma.payment.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            amount: new Decimal(3500),
          }),
        }),
      );
    });

    it('verifies standard payment without wallet debit', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: 'order_mock_12345',
        amount: new Decimal(3500),
        status: PaymentStatus.CREATED,
      });

      const res = await service.verifyPayment(
        {
          bookingId: 'booking_test_1',
          razorpayOrderId: 'order_mock_12345',
          razorpayPaymentId: 'pay_mock_12345',
          razorpaySignature: 'mock_signature',
        },
        'cust_test_1',
      );

      expect(res.success).toBe(true);
      expect(res.status).toBe(PaymentStatus.PAID);
      expect(walletsService.debitWallet).not.toHaveBeenCalled();
      expect(prisma.payment.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: PaymentStatus.PAID,
          }),
        }),
      );
    });
  });

  describe('Scenario 2: Partial Wallet Payment (Split Payment)', () => {
    it('creates split order with wallet contribution deducted from gateway amount', async () => {
      const res = await service.createOrder('booking_test_1', 'cust_test_1', true);

      expect(res.isFullWallet).toBe(false);
      // Total 3500, Wallet available 750 (250 promo + 500 real) => Gateway 2750 => 275000 paise
      expect(res.amount).toBe(275000);
      expect(res.breakdown.walletApplied).toBe(750);
      expect(res.breakdown.promoApplied).toBe(250);
      expect(res.breakdown.realApplied).toBe(500);
      expect(res.breakdown.gatewayAmount).toBe(2750);
    });

    it('verifies split payment and atomically settles wallet checkout debit', async () => {
      // Mock order ID encodes split wallet amount 75000 paise (₹750)
      const mockSplitOrderId = 'order_mock_split_75000_abc123';
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: mockSplitOrderId,
        amount: new Decimal(3500),
        status: PaymentStatus.CREATED,
      });

      const res = await service.verifyPayment(
        {
          bookingId: 'booking_test_1',
          razorpayOrderId: mockSplitOrderId,
          razorpayPaymentId: 'pay_mock_split_1',
          razorpaySignature: 'mock_signature',
        },
        'cust_test_1',
      );

      expect(res.success).toBe(true);
      expect(res.status).toBe(PaymentStatus.PAID);
      expect(walletsService.debitWallet).toHaveBeenCalledWith(
        'wallet_cust_1',
        new Decimal(750),
        LedgerEntryType.CHECKOUT_DEBIT,
        'BOOKING',
        'booking_test_1',
        'wallet_checkout_debit_booking_test_1',
        'Split wallet payment for booking booking_test_1',
        expect.objectContaining({
          bookingId: 'booking_test_1',
          isFullWallet: false,
          walletAmount: 750,
          gatewayAmount: 2750,
        }),
        expect.anything(),
      );
    });
  });

  describe('Scenario 3: Full Wallet Payment (gatewayAmount = 0)', () => {
    beforeEach(() => {
      // Set wallet available balance to ₹5,000 (covers total ₹3,500)
      walletsService.getOrCreateWallet.mockResolvedValue({
        ...mockWallet,
        availableBalance: new Decimal(5000),
        promoBalance: new Decimal(1000),
        realBalance: new Decimal(4000),
      });
    });

    it('creates full wallet order with order_wallet_full_ prefix and amount 0', async () => {
      const res = await service.createOrder('booking_test_1', 'cust_test_1', true);

      expect(res.isFullWallet).toBe(true);
      expect(res.amount).toBe(0);
      expect(res.orderId).toBe('order_wallet_full_booking_test_1');
      expect(res.breakdown.walletApplied).toBe(3500);
      expect(res.breakdown.promoApplied).toBe(1000);
      expect(res.breakdown.realApplied).toBe(2500);
      expect(res.breakdown.gatewayAmount).toBe(0);
    });

    it('verifies full wallet payment directly without gateway signature validation', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: 'order_wallet_full_booking_test_1',
        amount: new Decimal(3500),
        status: PaymentStatus.CREATED,
      });

      const res = await service.verifyPayment(
        {
          bookingId: 'booking_test_1',
          razorpayOrderId: 'order_wallet_full_booking_test_1',
          razorpayPaymentId: 'pay_wallet_booking_test_1',
          razorpaySignature: 'wallet_signature',
        },
        'cust_test_1',
      );

      expect(res.success).toBe(true);
      expect(res.status).toBe(PaymentStatus.PAID);
      expect(walletsService.debitWallet).toHaveBeenCalledWith(
        'wallet_cust_1',
        new Decimal(3500),
        LedgerEntryType.CHECKOUT_DEBIT,
        'BOOKING',
        'booking_test_1',
        'wallet_checkout_debit_booking_test_1',
        'Full wallet payment for booking booking_test_1',
        expect.objectContaining({
          isFullWallet: true,
          walletAmount: 3500,
          gatewayAmount: 0,
        }),
        expect.anything(),
      );
    });
  });

  describe('Scenario 4 & 5: Mixed Buckets & Insufficient Balance', () => {
    it('rejects verification if wallet balance drops below required amount before verification', async () => {
      walletsService.getOrCreateWallet.mockResolvedValue({
        ...mockWallet,
        availableBalance: new Decimal(100), // dropped from 750 to 100
      });

      const mockSplitOrderId = 'order_mock_split_75000_abc123';
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: mockSplitOrderId,
        amount: new Decimal(3500),
        status: PaymentStatus.CREATED,
      });

      await expect(
        service.verifyPayment(
          {
            bookingId: 'booking_test_1',
            razorpayOrderId: mockSplitOrderId,
            razorpayPaymentId: 'pay_mock_split_1',
            razorpaySignature: 'mock_signature',
          },
          'cust_test_1',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Scenario 6: Idempotency & Duplicate Verification Protection', () => {
    it('returns idempotent success if verifyPayment is called twice', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: 'order_mock_123',
        razorpayPaymentId: 'pay_mock_123',
        amount: new Decimal(3500),
        status: PaymentStatus.PAID, // Already PAID
      });

      const res = await service.verifyPayment(
        {
          bookingId: 'booking_test_1',
          razorpayOrderId: 'order_mock_123',
          razorpayPaymentId: 'pay_mock_123',
          razorpaySignature: 'mock_signature',
        },
        'cust_test_1',
      );

      expect(res.success).toBe(true);
      expect(res.status).toBe(PaymentStatus.PAID);
      expect(walletsService.debitWallet).not.toHaveBeenCalled();
    });

    it('rejects verification with a conflicting payment ID', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: 'order_mock_123',
        razorpayPaymentId: 'pay_original_123',
        amount: new Decimal(3500),
        status: PaymentStatus.PAID,
      });

      await expect(
        service.verifyPayment(
          {
            bookingId: 'booking_test_1',
            razorpayOrderId: 'order_mock_123',
            razorpayPaymentId: 'pay_different_456',
            razorpaySignature: 'mock_signature',
          },
          'cust_test_1',
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('Scenario 7: Cancellation & Refund Partition (Split & Full)', () => {
    it('refunds 100% split payment correctly: Gateway portion to gateway, Wallet portion to wallet', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayPaymentId: 'pay_gateway_123',
        amount: new Decimal(3500),
        status: PaymentStatus.PAID,
      });

      // Customer paid 750 via Wallet, 2750 via Gateway
      prisma.walletLedgerEntry.findMany.mockResolvedValue([
        {
          id: 'ledger_debit_1',
          amount: new Decimal(750),
          type: LedgerEntryType.CHECKOUT_DEBIT,
        },
      ]);

      const res = await service.refund('booking_test_1', 350000, 'Customer cancelled', 'FULL_REFUND_FREE_CANCELLATION');

      expect(res.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(res.refundAmount.toNumber()).toBe(3500);

      // Wallet credited with ₹750
      expect(walletsService.creditWallet).toHaveBeenCalledWith(
        'wallet_cust_1',
        new Decimal(750),
        LedgerEntryType.BOOKING_REFUND,
        WalletBucketType.REFUND_CREDIT,
        'BOOKING',
        'booking_test_1',
        'refund_wallet_booking_test_1_pay_rec_1',
        expect.stringContaining('Refund for cancelled booking'),
        undefined,
        expect.objectContaining({
          gatewayRefund: 2750,
          walletRefund: 750,
        }),
      );
    });

    it('refunds partial cancellation (50% fee): absorbs from wallet, gateway gets remainder', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayPaymentId: 'pay_gateway_123',
        amount: new Decimal(3500),
        status: PaymentStatus.PAID,
      });

      // Customer paid 750 via Wallet, 2750 via Gateway
      prisma.walletLedgerEntry.findMany.mockResolvedValue([
        {
          id: 'ledger_debit_1',
          amount: new Decimal(750),
          type: LedgerEntryType.CHECKOUT_DEBIT,
        },
      ]);

      // 50% refund = ₹1,750 (175000 paise)
      const res = await service.refund('booking_test_1', 175000, 'Late cancellation', 'LATE_CANCELLATION');

      expect(res.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(res.refundAmount.toNumber()).toBe(1750);
      // Since 1750 <= 2750 (gateway paid), entire ₹1,750 goes to gateway source, 0 to wallet
      expect(walletsService.creditWallet).not.toHaveBeenCalled();
    });

    it('refunds full wallet booking 100% to wallet', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_test_1',
        razorpayOrderId: 'order_wallet_full_booking_test_1',
        razorpayPaymentId: 'pay_wallet_booking_test_1',
        amount: new Decimal(3500),
        status: PaymentStatus.PAID,
      });

      // 100% paid from Wallet
      prisma.walletLedgerEntry.findMany.mockResolvedValue([
        {
          id: 'ledger_debit_1',
          amount: new Decimal(3500),
          type: LedgerEntryType.CHECKOUT_DEBIT,
        },
      ]);

      const res = await service.refund('booking_test_1', 350000, 'Host rejected', 'VENDOR_CANCELLED');

      expect(res.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(res.refundAmount.toNumber()).toBe(3500);
      // Entire ₹3,500 credited to wallet
      expect(walletsService.creditWallet).toHaveBeenCalledWith(
        'wallet_cust_1',
        new Decimal(3500),
        LedgerEntryType.BOOKING_REFUND,
        WalletBucketType.REFUND_CREDIT,
        'BOOKING',
        'booking_test_1',
        'refund_wallet_booking_test_1_pay_rec_1',
        expect.stringContaining('Refund for cancelled booking'),
        undefined,
        expect.objectContaining({
          gatewayRefund: 0,
          walletRefund: 3500,
        }),
      );
    });
  });
});
