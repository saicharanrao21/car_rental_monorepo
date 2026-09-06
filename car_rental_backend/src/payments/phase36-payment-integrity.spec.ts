import { PaymentsService } from './payments.service';
import { FinancialReconciliationService } from './reconciliation.service';
import {
  PaymentStatus,
  BookingStatus,
  RefundStatus,
  Role,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import {
  BadRequestException,
  ForbiddenException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';

describe('Phase 36: Payment & Financial Transaction Integrity Engine', () => {
  let paymentsService: PaymentsService;
  let reconciliationService: FinancialReconciliationService;
  let mockPrisma: any;
  let mockConfig: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockInvoices: any;
  let mockWallets: any;
  let mockRedis: any;

  const testWebhookSecret = 'test_phase36_webhook_secret_hmac_sha256';

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
        findFirst: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      paymentRefund: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      paymentAuditLog: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockResolvedValue({ id: 'audit_log_1' }),
      },
      webhookEvent: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      vendor: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
      },
      coupon: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      couponUsage: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
        create: jest.fn(),
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
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_phase36';
        if (key === 'RAZORPAY_KEY_SECRET') return 'rzp_secret_phase36';
        if (key === 'RAZORPAY_WEBHOOK_SECRET') return testWebhookSecret;
        if (key === 'RECONCILIATION_ENABLED') return 'true';
        if (key === 'RECONCILIATION_LOOKBACK_MINUTES') return 30;
        if (key === 'STALE_PAYMENT_ORDER_HOURS') return 24;
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
      generateInvoiceForBooking: jest.fn().mockResolvedValue({ id: 'inv_1' }),
    };

    mockWallets = {
      getOrCreateWallet: jest.fn().mockResolvedValue({
        id: 'wallet_1',
        status: 'ACTIVE',
        availableBalance: new Decimal(0),
        promoBalance: new Decimal(0),
      }),
      debitWallet: jest.fn().mockResolvedValue(true),
      creditWallet: jest.fn().mockResolvedValue(true),
    };

    mockRedis = {
      set: jest.fn().mockResolvedValue('OK'),
      get: jest.fn().mockResolvedValue(null),
      eval: jest.fn().mockResolvedValue(1),
    };

    paymentsService = new PaymentsService(
      mockPrisma,
      mockConfig,
      mockNotifications,
      mockInvoices,
      mockWallets,
      mockAuditLog,
    );

    reconciliationService = new FinancialReconciliationService(
      mockPrisma,
      mockConfig,
      mockNotifications,
      mockAuditLog,
      mockRedis,
      undefined,
      mockInvoices,
    );
  });

  // =========================================================================
  // GROUP A: PAYMENT ORDER INTEGRITY
  // =========================================================================
  describe('Group A: Payment Order Integrity', () => {
    it('A1: should create valid payment order with integer paise and append audit log', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_valid_1',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(4000.5),
        securityDeposit: { amount: new Decimal(1500) },
      });
      mockPrisma.payment.findUnique.mockResolvedValue(null);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'pay_rec_1',
        bookingId: 'booking_valid_1',
        status: PaymentStatus.CREATED,
      });

      const mockCreate = jest.fn().mockResolvedValue({
        id: 'order_rzp_valid_1',
        amount: 550050,
        currency: 'INR',
      });
      (paymentsService as any).razorpay = { orders: { create: mockCreate } };

      const res = await paymentsService.createOrder(
        'booking_valid_1',
        'cust_alice',
        false,
      );

      expect(res.orderId).toBe('order_rzp_valid_1');
      expect(res.amount).toBe(550050); // Exact integer paise: (4000.5 + 1500) * 100
      expect(mockPrisma.payment.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: 'booking_valid_1',
          razorpayOrderId: 'order_rzp_valid_1',
          status: PaymentStatus.CREATED,
        }),
      });
      expect(mockPrisma.paymentAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: 'booking_valid_1',
          eventType: 'PAYMENT_ORDER_CREATED',
          toStatus: PaymentStatus.CREATED,
        }),
      });
    });

    it('A2: should reject order creation for invalid or non-existent booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(null);

      await expect(
        paymentsService.createOrder('booking_nonexistent', 'cust_alice', false),
      ).rejects.toThrow(NotFoundException);
    });

    it('A3: should reject unauthorized customer trying to pay for another user booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_secret',
        customerId: 'cust_bob',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(3000),
      });

      await expect(
        paymentsService.createOrder('booking_secret', 'cust_mallory', false),
      ).rejects.toThrow(ForbiddenException);
    });

    it('A4: should reject order creation for non-pending booking status', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_confirmed',
        customerId: 'cust_alice',
        status: BookingStatus.CONFIRMED,
        totalFare: new Decimal(3000),
      });

      await expect(
        paymentsService.createOrder('booking_confirmed', 'cust_alice', false),
      ).rejects.toThrow(BadRequestException);
    });

    it('A5: should reject order creation if booking payable drifts from accepted quote (Phase 35 integrity)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_quote_drift',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(6000),
        quoteId: 'quote_original_1',
        quote: {
          id: 'quote_original_1',
          totalPayable: new Decimal(4500), // Mismatch!
        },
      });

      await expect(
        paymentsService.createOrder('booking_quote_drift', 'cust_alice', false),
      ).rejects.toThrow(ConflictException);
    });

    it('A6: should update existing payment row and record audit log on retry without deleting record', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_retry_1',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000),
      });
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_existing_1',
        bookingId: 'booking_retry_1',
        razorpayOrderId: 'order_old_123',
        status: PaymentStatus.FAILED,
      });
      mockPrisma.payment.update.mockResolvedValue({
        id: 'pay_existing_1',
        status: PaymentStatus.CREATED,
      });

      const mockCreate = jest.fn().mockResolvedValue({
        id: 'order_rzp_renewed_2',
        amount: 500000,
        currency: 'INR',
      });
      (paymentsService as any).razorpay = { orders: { create: mockCreate } };

      const res = await paymentsService.createOrder(
        'booking_retry_1',
        'cust_alice',
        false,
      );

      expect(res.orderId).toBe('order_rzp_renewed_2');
      expect(mockPrisma.payment.delete).not.toHaveBeenCalled(); // Preserves financial record!
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'pay_existing_1' },
        data: expect.objectContaining({
          razorpayOrderId: 'order_rzp_renewed_2',
          status: PaymentStatus.CREATED,
        }),
      });
      expect(mockPrisma.paymentAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: 'PAYMENT_ORDER_RENEWED',
          fromStatus: PaymentStatus.FAILED,
          toStatus: PaymentStatus.CREATED,
        }),
      });
    });

    it('A7: should reject payment creation if booking is already PAID', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_already_paid',
        customerId: 'cust_alice',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000),
      });
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_paid_1',
        status: PaymentStatus.PAID,
      });

      await expect(
        paymentsService.createOrder('booking_already_paid', 'cust_alice', false),
      ).rejects.toThrow(ConflictException);
    });
  });

  // =========================================================================
  // GROUP B: WEBHOOK SECURITY & IDEMPOTENCY
  // =========================================================================
  describe('Group B: Webhook Security & Idempotency', () => {
    it('B1: should reject webhook request with invalid HMAC signature', async () => {
      const rawBody = JSON.stringify({
        event: 'payment.captured',
        id: 'evt_sig_invalid',
      });

      await expect(
        paymentsService.handleWebhook(rawBody, 'invalid_signature_hex'),
      ).rejects.toThrow(BadRequestException);
    });

    it('B2: should process payment.captured webhook with valid signature and audit log', async () => {
      const payload = {
        event: 'payment.captured',
        id: 'evt_valid_cap_1',
        payload: {
          payment: {
            entity: {
              id: 'pay_rzp_cap_99',
              order_id: 'order_rzp_cap_99',
              amount: 500000,
              currency: 'INR',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'pay_internal_99',
        bookingId: 'booking_cap_99',
        amount: new Decimal(5000),
        status: PaymentStatus.CREATED,
      });
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_cap_99',
        customerId: 'cust_alice',
      });

      const res = await paymentsService.handleWebhook(rawBody, signature, {
        'x-razorpay-event-id': 'evt_valid_cap_1',
      });

      expect(res.received).toBe(true);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'pay_internal_99' },
        data: expect.objectContaining({
          status: PaymentStatus.PAID,
          razorpayPaymentId: 'pay_rzp_cap_99',
        }),
      });
      expect(mockPrisma.paymentAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: 'WEBHOOK_PAYMENT_CAPTURED',
          toStatus: PaymentStatus.PAID,
          source: 'WEBHOOK',
        }),
      });
    });

    it('B3: should handle duplicate webhook delivery idempotently without duplicate capture', async () => {
      const payload = {
        event: 'payment.captured',
        id: 'evt_dup_101',
        payload: {
          payment: {
            entity: {
              id: 'pay_rzp_dup_101',
              order_id: 'order_rzp_dup_101',
              amount: 500000,
              currency: 'INR',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      // Simulate WebhookEvent duplicate key collision
      mockPrisma.webhookEvent.create.mockRejectedValue({
        code: 'P2002',
        message: 'Unique constraint failed on eventId',
      });

      const res = await paymentsService.handleWebhook(rawBody, signature);

      expect(res.received).toBe(true);
      expect(res.duplicate).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });

    it('B4: should safely ignore webhook when payment is already PAID', async () => {
      const payload = {
        event: 'payment.captured',
        id: 'evt_already_paid_1',
        payload: {
          payment: {
            entity: {
              id: 'pay_rzp_rep_1',
              order_id: 'order_rep_1',
              amount: 500000,
              currency: 'INR',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'pay_rep_1',
        bookingId: 'booking_rep_1',
        amount: new Decimal(5000),
        status: PaymentStatus.PAID,
      });

      const res = await paymentsService.handleWebhook(rawBody, signature);

      expect(res.received).toBe(true);
      expect(res.alreadyProcessed).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });

    it('B5: should reject webhook if gateway amount does not match authoritative booking amount', async () => {
      const payload = {
        event: 'payment.captured',
        id: 'evt_amount_fraud',
        payload: {
          payment: {
            entity: {
              id: 'pay_fraud_1',
              order_id: 'order_fraud_1',
              amount: 10000, // 100 INR instead of 5000 INR
              currency: 'INR',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'pay_tamper_1',
        bookingId: 'booking_tamper_1',
        amount: new Decimal(5000),
        status: PaymentStatus.CREATED,
      });

      const res = await paymentsService.handleWebhook(rawBody, signature);

      expect(res.received).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });

    it('B6: should reject webhook if currency is not INR', async () => {
      const payload = {
        event: 'payment.captured',
        id: 'evt_usd_currency',
        payload: {
          payment: {
            entity: {
              id: 'pay_usd_1',
              order_id: 'order_usd_1',
              amount: 500000,
              currency: 'USD',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'pay_usd_internal',
        amount: new Decimal(5000),
        status: PaymentStatus.CREATED,
      });

      const res = await paymentsService.handleWebhook(rawBody, signature);

      expect(res.received).toBe(true);
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });

    it('B7: should not downgrade PAID payment if payment.failed webhook arrives out of order', async () => {
      const payload = {
        event: 'payment.failed',
        id: 'evt_ooo_failed',
        payload: {
          payment: {
            entity: {
              id: 'pay_ooo_1',
              order_id: 'order_ooo_1',
            },
          },
        },
      };
      const rawBody = JSON.stringify(payload);
      const signature = signPayload(rawBody);

      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'pay_ooo_1',
        status: PaymentStatus.PAID, // Already confirmed paid!
      });

      await paymentsService.handleWebhook(rawBody, signature);

      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });
  });

  // =========================================================================
  // GROUP C: CANONICAL PAYMENT STATE MACHINE
  // =========================================================================
  describe('Group C: Canonical Payment State Machine', () => {
    it('C1: should allow valid forward transitions', () => {
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.CREATED, PaymentStatus.PAID),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.CREATED, PaymentStatus.AUTHORIZED),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.AUTHORIZED, PaymentStatus.PAID),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.PAID, PaymentStatus.PARTIALLY_REFUNDED),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.PAID, PaymentStatus.REFUNDED),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.FAILED, PaymentStatus.CREATED),
      ).not.toThrow();
    });

    it('C2: should reject invalid backward or illegal state transitions', () => {
      // Cannot transition PAID to FAILED
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.PAID, PaymentStatus.FAILED),
      ).toThrow(ConflictException);

      // Cannot transition REFUNDED back to PAID
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.REFUNDED, PaymentStatus.PAID),
      ).toThrow(ConflictException);

      // Cannot transition CREATED directly to REFUNDED
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.CREATED, PaymentStatus.REFUNDED),
      ).toThrow(ConflictException);

      // Cannot transition PAID back to CREATED
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.PAID, PaymentStatus.CREATED),
      ).toThrow(ConflictException);
    });

    it('C3: should treat duplicate identical state transitions as idempotent no-ops', () => {
      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.PAID, PaymentStatus.PAID),
      ).not.toThrow();

      expect(() =>
        paymentsService.assertValidTransition(PaymentStatus.CREATED, PaymentStatus.CREATED),
      ).not.toThrow();
    });
  });

  // =========================================================================
  // GROUP D: REFUND INTEGRITY
  // =========================================================================
  describe('Group D: Refund Integrity', () => {
    it('D1: should execute valid full gateway refund and append audit log', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_refund_1',
        bookingId: 'booking_ref_1',
        amount: new Decimal(5000),
        status: PaymentStatus.PAID,
        refundStatus: RefundStatus.NONE,
        razorpayPaymentId: 'pay_rzp_rf_1',
      });

      const mockRefundFn = jest.fn().mockResolvedValue({
        id: 'rfnd_rzp_full_1',
        status: 'processed',
      });
      (paymentsService as any).razorpay = {
        payments: { refund: mockRefundFn },
      };

      const res = await paymentsService.refund(
        'booking_ref_1',
        500000,
        'Customer cancelled within free tier',
      );

      expect(res.refundId).toBe('rfnd_rzp_full_1');
      expect(res.refundAmount.toNumber()).toBe(5000);
      expect(res.refundStatus).toBe(RefundStatus.PROCESSED);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'pay_refund_1' },
        data: expect.objectContaining({
          status: PaymentStatus.REFUNDED,
          refundStatus: RefundStatus.PROCESSED,
        }),
      });
      expect(mockPrisma.paymentAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: 'REFUND_PROCESSED',
          toStatus: PaymentStatus.REFUNDED,
        }),
      });
    });

    it('D2: should reject over-refund attempt exceeding captured payment amount', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_refund_2',
        bookingId: 'booking_ref_2',
        amount: new Decimal(3000),
        status: PaymentStatus.PAID,
      });

      await expect(
        paymentsService.refund('booking_ref_2', 400000), // 4000 INR > 3000 INR
      ).rejects.toThrow(BadRequestException);
    });

    it('D3: should handle duplicate refund call idempotently via PaymentRefund table', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_refund_3',
        bookingId: 'booking_ref_3',
        amount: new Decimal(5000),
        status: PaymentStatus.PAID,
      });
      mockPrisma.paymentRefund.findUnique.mockResolvedValue({
        id: 'pr_existing_1',
        gatewayRefundId: 'rfnd_existing_1',
        requestedAmount: new Decimal(5000),
        status: RefundStatus.PROCESSED,
      });

      const res = await paymentsService.refund(
        'booking_ref_3',
        500000,
        'Duplicate cancel',
        undefined,
        'idemp_duplicate_refund_key',
      );

      expect(res.isDuplicate).toBe(true);
      expect(res.refundId).toBe('rfnd_existing_1');
    });

    it('D4: should reject refund against unpaid payment record', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({
        id: 'pay_refund_4',
        bookingId: 'booking_ref_4',
        amount: new Decimal(5000),
        status: PaymentStatus.CREATED, // Unpaid!
      });

      const res = await paymentsService.refund('booking_ref_4', 500000);
      expect(res.refundId).toBeNull();
    });
  });

  // =========================================================================
  // GROUP E: RECONCILIATION ENGINE
  // =========================================================================
  describe('Group E: Financial Reconciliation Engine', () => {
    it('E1: should auto-heal unconfirmed paid booking where gateway captured payment exists', async () => {
      const report = {
        candidatesFound: 0,
        processed: 0,
        healed: 0,
        skipped: 0,
        errors: 0,
      };

      mockPrisma.payment.findMany.mockResolvedValue([
        {
          id: 'pay_recon_1',
          bookingId: 'booking_recon_1',
          amount: new Decimal(5000),
          razorpayOrderId: 'order_recon_1',
          booking: {
            id: 'booking_recon_1',
            customerId: 'cust_recon',
            totalFare: new Decimal(5000),
            securityDeposit: null,
            status: BookingStatus.PENDING,
          },
        },
      ]);

      const mockFetchPayments = jest.fn().mockResolvedValue({
        items: [
          {
            id: 'pay_rzp_recon_1',
            order_id: 'order_recon_1',
            status: 'captured',
            amount: 500000,
            currency: 'INR',
          },
        ],
      });
      (reconciliationService as any).razorpay = {
        orders: { fetchPayments: mockFetchPayments },
      };

      await reconciliationService.reconcileUnconfirmedPaidBookings(report);

      expect(report.healed).toBe(1);
      expect(mockPrisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'pay_recon_1' },
        data: expect.objectContaining({
          status: PaymentStatus.PAID,
          razorpayPaymentId: 'pay_rzp_recon_1',
        }),
      });
    });

    it('E2: should flag amount mismatch between gateway and internal booking without blind mutation', async () => {
      const report = {
        candidatesFound: 0,
        processed: 0,
        healed: 0,
        skipped: 0,
        errors: 0,
      };

      mockPrisma.payment.findMany.mockResolvedValue([
        {
          id: 'pay_recon_mismatch',
          bookingId: 'booking_recon_mismatch',
          amount: new Decimal(5000),
          razorpayOrderId: 'order_mismatch_1',
          booking: {
            id: 'booking_recon_mismatch',
            customerId: 'cust_recon',
            totalFare: new Decimal(5000),
            securityDeposit: null,
            status: BookingStatus.PENDING,
          },
        },
      ]);

      // Gateway reports payment of 3000 INR instead of 5000 INR
      const mockFetchPayments = jest.fn().mockResolvedValue({
        items: [
          {
            id: 'pay_rzp_mismatch',
            order_id: 'order_mismatch_1',
            status: 'captured',
            amount: 300000,
            currency: 'INR',
          },
        ],
      });
      (reconciliationService as any).razorpay = {
        orders: { fetchPayments: mockFetchPayments },
      };

      await reconciliationService.reconcileUnconfirmedPaidBookings(report);

      expect(report.healed).toBe(0);
      expect(report.errors).toBe(1); // Flagged for manual review!
      expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    });
  });

  // =========================================================================
  // GROUP F: SECURITY & TENANT ISOLATION
  // =========================================================================
  describe('Group F: Security & Multi-Tenant Isolation', () => {
    it('F1: should permit vendor to inspect payment summary for their own vehicle without exposing customer secrets', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_vendor_1',
        vendorId: 'vendor_user_1',
        totalFare: new Decimal(10000),
        netToVendor: new Decimal(8500),
        platformFee: new Decimal(1500),
        securityDeposit: { amount: new Decimal(3000) },
        car: { id: 'car_1', vendorId: 'vendor_user_1' },
        payment: {
          id: 'pay_vendor_1',
          status: PaymentStatus.PAID,
          refundStatus: RefundStatus.NONE,
          currency: 'INR',
          amount: new Decimal(13000),
        },
      });

      const res = await paymentsService.getVendorPaymentByBookingId(
        'booking_vendor_1',
        { userId: 'vendor_user_1', role: Role.VENDOR },
      );

      expect(res.bookingId).toBe('booking_vendor_1');
      expect(res.isPaid).toBe(true);
      expect(res.netVendorEarnings).toBe(8500);
      expect(res.platformCommission).toBe(1500);
      // Secrets stripped:
      expect((res as any).razorpayPaymentId).toBeUndefined();
      expect((res as any).razorpayOrderId).toBeUndefined();
      expect((res as any).gatewaySignature).toBeUndefined();
    });

    it('F2: should reject vendor trying to inspect payment for another vendor booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking_other_vendor',
        vendorId: 'vendor_mallory',
        car: { id: 'car_2', vendorId: 'vendor_mallory' },
      });

      await expect(
        paymentsService.getVendorPaymentByBookingId('booking_other_vendor', {
          userId: 'vendor_innocent',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('F3: should allow admin to retrieve payment audit log history', async () => {
      mockPrisma.payment.findUnique.mockResolvedValue({ id: 'pay_audit_target' });
      mockPrisma.paymentAuditLog.findMany.mockResolvedValue([
        {
          id: 'log_1',
          eventType: 'PAYMENT_ORDER_CREATED',
          toStatus: PaymentStatus.CREATED,
          amount: new Decimal(5000),
        },
        {
          id: 'log_2',
          eventType: 'PAYMENT_VERIFIED',
          toStatus: PaymentStatus.PAID,
          amount: new Decimal(5000),
        },
      ]);

      const logs = await paymentsService.getPaymentAuditLogs('booking_audit_1', {
        userId: 'admin_user_1',
        role: Role.ADMIN,
      });

      expect(logs.length).toBe(2);
      expect(logs[0].eventType).toBe('PAYMENT_ORDER_CREATED');
    });

    it('F4: should reject customer attempting to view payment audit logs', async () => {
      await expect(
        paymentsService.getPaymentAuditLogs('booking_audit_1', {
          userId: 'cust_alice',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
