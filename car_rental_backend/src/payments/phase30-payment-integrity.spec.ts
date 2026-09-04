import { PaymentsService } from './payments.service';
import { PayoutsService } from '../payouts/payouts.service';
import {
  PaymentStatus,
  BookingStatus,
  RefundStatus,
  Role,
  LedgerDirection,
  PayoutStatus,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import {
  BadRequestException,
  ForbiddenException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';

describe('Phase 30: Production Payment Integrity & Idempotency Layer', () => {
  let paymentsService: PaymentsService;
  let payoutsService: PayoutsService;
  let mockPrisma: any;
  let mockConfig: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockInvoices: any;
  let mockWallets: any;

  const testWebhookSecret = 'test_phase30_webhook_secret_key_abcdef';

  function signPayload(body: string): string {
    return crypto
      .createHmac('sha256', testWebhookSecret)
      .update(body)
      .digest('hex');
  }

  beforeEach(() => {
    mockPrisma = {
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      paymentRefund: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        upsert: jest.fn(),
      },
      webhookEvent: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
      },
      payout: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
      },
      financialAdjustment: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      securityDeposit: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      walletLedgerEntry: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    mockConfig = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'test';
        if (key === 'RAZORPAY_USE_MOCK') return 'false';
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_phase30';
        if (key === 'RAZORPAY_KEY_SECRET') return 'rzp_secret_phase30';
        if (key === 'RAZORPAY_WEBHOOK_SECRET') return testWebhookSecret;
        return null;
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue(true),
    };

    mockInvoices = {
      generateInvoice: jest.fn().mockResolvedValue({ id: 'inv-30' }),
    };

    mockWallets = {
      getOrCreateWallet: jest.fn().mockResolvedValue({
        id: 'wlt-1',
        availableBalance: new Decimal(0),
        status: 'ACTIVE',
      }),
      creditWallet: jest.fn().mockResolvedValue(true),
      debitForBooking: jest.fn().mockResolvedValue(true),
    };

    const mockSystemConfig: any = {
      getPayoutConfig: jest.fn().mockResolvedValue({
        settlementHoldDays: 2,
        minPayoutAmount: 500,
        maxSinglePayoutAmount: 100000,
        dailyVendorPayoutCap: 500000,
      }),
    };

    paymentsService = new PaymentsService(
      mockPrisma,
      mockConfig,
      mockNotifications,
      mockInvoices,
      mockWallets,
      mockAuditLog,
    );

    payoutsService = new PayoutsService(
      mockPrisma,
      mockNotifications,
      mockAuditLog,
      mockSystemConfig,
      undefined,
    );
  });

  describe('1. Server-Authoritative Order Creation & Tenancy Guards', () => {
    it('should reject payment creation when customer tries to pay for another user booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_1',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(4500),
      });

      await expect(
        paymentsService.createOrder('booking_1', 'cust_mallory', false),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reject payment creation for non-pending booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_1',
        customerId: 'cust_alice',
        status: BookingStatus.CONFIRMED,
        totalFare: new Decimal(4500),
      });

      await expect(
        paymentsService.createOrder('booking_1', 'cust_alice', false),
      ).rejects.toThrow(BadRequestException);
    });

    it('should compute exact server-side amount and prevent arbitrary client amounts', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_1',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000.5),
        securityDeposit: { amount: new Decimal(2000.0) },
      });
      mockPrisma.payment.findUnique.mockResolvedValue(null);

      const mockOrdersCreate = jest.fn().mockResolvedValue({
        id: 'order_rzp_phase30_1',
        amount: 700050,
        currency: 'INR',
      });
      (paymentsService as any).razorpay = {
        orders: { create: mockOrdersCreate },
      };

      const result = await paymentsService.createOrder(
        'booking_1',
        'cust_alice',
        false,
      );

      expect(result.amount).toBe(700050); // Exact paise
      expect(result.currency).toBe('INR');
      expect(mockOrdersCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          amount: 700050,
          currency: 'INR',
          receipt: 'booking_1',
        }),
      );
      expect(mockPrisma.payment.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: 'booking_1',
          amount: new Decimal(7000.5),
          status: PaymentStatus.CREATED,
        }),
      });
    });

    it('should reject duplicate payment creation if booking is already PAID', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_paid',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000),
      });
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_existing',
        bookingId: 'booking_paid',
        status: PaymentStatus.PAID,
      });

      await expect(
        paymentsService.createOrder('booking_paid', 'cust_alice', false),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('2. Webhook Ingestion, Signature Verification & Deduplication', () => {
    it('should verify valid webhook signature and process payment.captured', async () => {
      const payload = JSON.stringify({
        event: 'payment.captured',
        event_id: 'evt_rzp_unique_101',
        payload: {
          payment: {
            entity: {
              id: 'pay_rzp_cap_1',
              order_id: 'order_rzp_101',
              amount: 500000,
              currency: 'INR',
            },
          },
        },
      });
      const sig = signPayload(payload);

      mockPrisma.webhookEvent.create.mockResolvedValue({ id: 'we_1' });
      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'payment_1',
        bookingId: 'booking_101',
        amount: new Decimal(5000),
        status: PaymentStatus.CREATED,
      });
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_101',
        customerId: 'cust_1',
      });

      const res = await paymentsService.handleWebhook(payload, sig, {
        'x-razorpay-event-id': 'evt_rzp_unique_101',
      });

      expect(res.received).toBe(true);
      expect(mockPrisma.webhookEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            eventId: 'evt_rzp_unique_101',
            eventType: 'payment.captured',
          }),
        }),
      );
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'payment_1' },
        data: {
          status: PaymentStatus.PAID,
          razorpayPaymentId: 'pay_rzp_cap_1',
        },
      });
    });

    it('should reject webhook with tampered body or invalid signature', async () => {
      const payload = JSON.stringify({ event: 'payment.captured' });
      const badSig = 'bad_forged_signature_000000000000000000000';

      await expect(
        paymentsService.handleWebhook(payload, badSig),
      ).rejects.toThrow(BadRequestException);
    });

    it('should detect duplicate webhook delivery via DB unique constraint and return duplicate response safely', async () => {
      const payload = JSON.stringify({
        event: 'payment.captured',
        event_id: 'evt_duplicate_202',
        payload: {
          payment: {
            entity: {
              id: 'pay_dup_1',
              order_id: 'order_dup_1',
              amount: 500000,
              currency: 'INR',
            },
          },
        },
      });
      const sig = signPayload(payload);

      // Simulate PostgreSQL unique constraint error P2002
      const p2002Error: any = new Error('Unique constraint failed on the fields: (eventId)');
      p2002Error.code = 'P2002';
      mockPrisma.webhookEvent.create.mockRejectedValue(p2002Error);

      const res = await paymentsService.handleWebhook(payload, sig, {
        'x-razorpay-event-id': 'evt_duplicate_202',
      });

      expect(res.received).toBe(true);
      expect(res.duplicate).toBe(true);
      expect(res.alreadyProcessed).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });
  });

  describe('3. Idempotent Refunds & Webhook Reconciliation', () => {
    it('should create refund with idempotency key and persist PaymentRefund record', async () => {
      const mockPayment = {
        id: 'pay_refund_1',
        bookingId: 'booking_rf_1',
        razorpayPaymentId: 'pay_rzp_rf_1',
        amount: new Decimal(6000),
        status: PaymentStatus.PAID,
        refundStatus: RefundStatus.NONE,
      };
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);
      mockPrisma.paymentRefund.findUnique.mockResolvedValue(null); // No previous refund with this key
      mockPrisma.paymentRefund.create.mockResolvedValue({ id: 'pr_1' });

      const mockRefundApi = jest.fn().mockResolvedValue({
        id: 'rfnd_gw_30_1',
        amount: 300000,
        status: 'processed',
      });
      (paymentsService as any).razorpay = {
        payments: { refund: mockRefundApi },
      };

      const result = await paymentsService.refund(
        'booking_rf_1',
        300000, // 3,000 INR partial refund (50%)
        'Customer cancellation within policy',
        'MODERATE',
        'idemp_refund_booking_rf_1_unique',
        'admin_user_1',
      );

      expect(result.refundId).toBe('rfnd_gw_30_1');
      expect(result.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(mockRefundApi).toHaveBeenCalledWith(
        'pay_rzp_rf_1',
        expect.objectContaining({
          amount: 300000,
          receipt: 'idemp_refund_booking_rf_1_unique',
        }),
      );
      expect(mockPrisma.paymentRefund.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: 'booking_rf_1',
          gatewayRefundId: 'rfnd_gw_30_1',
          idempotencyKey: 'idemp_refund_booking_rf_1_unique',
          requestedAmount: new Decimal(3000),
          status: RefundStatus.PROCESSED,
        }),
      });
    });

    it('should intercept duplicate refund submission with same idempotency key and return existing refund without second gateway call', async () => {
      const mockPayment = {
        id: 'pay_refund_1',
        bookingId: 'booking_rf_1',
        amount: new Decimal(6000),
        status: PaymentStatus.PAID,
      };
      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);
      mockPrisma.paymentRefund.findUnique.mockResolvedValue({
        id: 'pr_existing_1',
        gatewayRefundId: 'rfnd_gw_existing',
        requestedAmount: new Decimal(3000),
        processedAmount: new Decimal(3000),
        status: RefundStatus.PROCESSED,
      });

      const mockRefundApi = jest.fn();
      (paymentsService as any).razorpay = {
        payments: { refund: mockRefundApi },
      };

      const result = await paymentsService.refund(
        'booking_rf_1',
        300000,
        'Customer cancellation duplicate click',
        'MODERATE',
        'idemp_refund_booking_rf_1_unique',
      );

      expect(result.isDuplicate).toBe(true);
      expect(result.refundId).toBe('rfnd_gw_existing');
      expect(result.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(mockRefundApi).not.toHaveBeenCalled(); // Gateway never called second time!
    });
  });

  describe('4. Escrow Security & Disputed Vehicle Settlement Locks', () => {
    it('should exclude disputed bookings from eligible vendor payout earnings', async () => {
      const mockVendor = { id: 'vendor_escrow_1' };
      mockPrisma.vendor.findUnique.mockResolvedValue(mockVendor);

      // 2 completed bookings: 1 clean (₹5,000) and 1 disputed (₹4,000)
      mockPrisma.booking.findMany.mockResolvedValue([
        {
          id: 'booking_clean',
          vendorId: 'vendor_escrow_1',
          status: 'COMPLETED',
          netToVendor: new Decimal(5000),
          disputeFlag: false,
          updatedAt: new Date(Date.now() - 5 * 86400000), // Beyond 2-day hold
          damageClaims: [],
        },
        {
          id: 'booking_disputed',
          vendorId: 'vendor_escrow_1',
          status: 'COMPLETED',
          netToVendor: new Decimal(4000),
          disputeFlag: true, // Disputed / Damaged vehicle
          updatedAt: new Date(Date.now() - 5 * 86400000),
          damageClaims: [{ id: 'claim_1', status: 'OPEN' }],
        },
      ]);
      mockPrisma.payout.findMany
        .mockResolvedValueOnce([]) // paid payouts
        .mockResolvedValueOnce([]); // pending payouts

      const summary = await payoutsService.getVendorEarningsSummary('vendor_escrow_1');

      // Total clean earnings = ₹5,000. Disputed earnings (₹4,000) held in escrow
      expect(summary.totalEarnings).toBe(5000);
      expect(summary.availableBalance).toBe(5000);
    });

    it('should reject vendor payout request when requested amount relies on disputed booking funds', async () => {
      mockPrisma.vendor.findUnique.mockResolvedValue({ id: 'vendor_escrow_1' });

      // Clean: ₹2,000, Disputed: ₹8,000
      mockPrisma.booking.findMany.mockResolvedValue([
        {
          id: 'booking_clean',
          vendorId: 'vendor_escrow_1',
          status: 'COMPLETED',
          netToVendor: new Decimal(2000),
          disputeFlag: false,
          updatedAt: new Date(Date.now() - 5 * 86400000),
          damageClaims: [],
        },
        {
          id: 'booking_disputed',
          vendorId: 'vendor_escrow_1',
          status: 'COMPLETED',
          netToVendor: new Decimal(8000),
          disputeFlag: true,
          damageClaims: [{ id: 'claim_2', status: 'UNDER_REVIEW' }],
        },
      ]);
      mockPrisma.payout.findMany
        .mockResolvedValueOnce([]) // today payouts
        .mockResolvedValueOnce([]) // paid
        .mockResolvedValueOnce([]); // pending

      // Vendor attempts to withdraw ₹5,000 (exceeds ₹2,000 clean available balance)
      await expect(
        payoutsService.requestPayout('vendor_escrow_1', { amount: 5000 }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('5. Admin Governance & Manual Refund Overrides', () => {
    it('should allow admin to issue partial refund with audit log compliance', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_admin_1',
        bookingId: 'booking_admin_1',
        amount: new Decimal(10000),
        refundAmount: new Decimal(2000),
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_rzp_admin_1',
      });
      mockPrisma.paymentRefund.findUnique.mockResolvedValue(null);
      mockPrisma.paymentRefund.create.mockResolvedValue({ id: 'pr_admin_1' });

      const mockRefundApi = jest.fn().mockResolvedValue({
        id: 'rfnd_admin_gw',
        amount: 300000,
        status: 'processed',
      });
      (paymentsService as any).razorpay = {
        payments: { refund: mockRefundApi },
      };

      const res = await paymentsService.adminRefund(
        'booking_admin_1',
        {
          amountInPaise: 300000, // ₹3,000
          reason: 'Goodwill compensation approved by lead support agent',
          idempotencyKey: 'admin_audit_idemp_key_1',
        },
        { userId: 'admin_123', role: Role.ADMIN },
      );

      expect(res.success).toBe(true);
      expect(res.refundId).toBe('rfnd_admin_gw');
      expect(mockAuditLog.log).toHaveBeenCalledWith(
        'admin_123',
        'ADMIN_PAYMENT_REFUND',
        'Payment',
        'pay_admin_1',
        expect.objectContaining({
          bookingId: 'booking_admin_1',
          refundAmountPaise: 300000,
        }),
      );
    });

    it('should reject non-admin from executing administrative refund override', async () => {
      await expect(
        paymentsService.adminRefund(
          'booking_admin_1',
          { reason: 'Customer requested manual refund' },
          { userId: 'customer_1', role: Role.CUSTOMER },
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reject admin refund if requested amount exceeds remaining refundable amount', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_admin_2',
        bookingId: 'booking_admin_2',
        amount: new Decimal(5000),
        refundAmount: new Decimal(4000), // Remaining = ₹1,000
        status: PaymentStatus.PAID,
      });

      await expect(
        paymentsService.adminRefund(
          'booking_admin_2',
          {
            amountInPaise: 200000, // ₹2,000 > ₹1,000
            reason: 'Excessive refund attempt',
          },
          { userId: 'admin_123', role: Role.ADMIN },
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
