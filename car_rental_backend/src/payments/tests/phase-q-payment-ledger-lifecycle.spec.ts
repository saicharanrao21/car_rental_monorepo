import { PaymentsService } from '../payments.service';
import { FinancialReconciliationService } from '../reconciliation.service';
import { LedgerCoreService } from '../../finance/ledger-core.service';
import { BookingLifecycleService } from '../../bookings/booking-lifecycle.service';
import {
  BookingStatus,
  PaymentStatus,
  RefundStatus,
  LedgerAccountType,
  LedgerEntrySide,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase Q: Payment Ledger Lifecycle & Reconciliation Integrity', () => {
  let paymentsService: PaymentsService;
  let reconciliationService: FinancialReconciliationService;
  let bookingLifecycleService: BookingLifecycleService;
  let mockPrisma: any;
  let mockLedgerCore: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockConfigService: any;
  let mockRedis: any;
  let mockBookingLockService: any;
  let mockCancellationPolicyService: any;
  let mockOutboxService: any;

  beforeEach(() => {
    mockLedgerCore = {
      recordJournal: jest.fn().mockImplementation(async (input: any) => {
        let totalDebit = new Decimal(0);
        let totalCredit = new Decimal(0);
        for (const line of input.lines || input.entries || []) {
          const side = line.side || line.entrySide;
          const amt = new Decimal(line.amount);
          if (side === LedgerEntrySide.DEBIT) totalDebit = totalDebit.add(amt);
          if (side === LedgerEntrySide.CREDIT) totalCredit = totalCredit.add(amt);
        }
        if (!totalDebit.equals(totalCredit)) {
          throw new Error(`Unbalanced journal: debit ${totalDebit} != credit ${totalCredit}`);
        }
        return {
          journalId: `jrn_${Date.now()}`,
          entries: input.lines || input.entries,
        };
      }),
    };

    mockPrisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue({ id: 'usr_admin_1' }),
      },
      payment: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
        create: jest.fn(),
      },
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      },
      securityDeposit: {
        update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      paymentRefund: {
        create: jest.fn().mockResolvedValue({ id: 'rfnd_01' }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      },
      platformLedgerEntry: {
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
      },
      paymentAuditLog: {
        create: jest.fn().mockResolvedValue({ id: 'aud_1' }),
      },
      auditLog: {
        create: jest.fn().mockResolvedValue({ id: 'aud_2' }),
      },
      bookingOutboxEvent: {
        create: jest.fn().mockResolvedValue({ id: 'outbox_1' }),
      },
      couponUsage: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'cu_1' }),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockConfigService = {
      get: jest.fn((key: string) => {
        if (key === 'RAZORPAY_USE_MOCK') return 'true';
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_123';
        if (key === 'RAZORPAY_KEY_SECRET') return 'rzp_secret_123';
        return undefined;
      }),
    };

    mockRedis = {
      set: jest.fn().mockResolvedValue('OK'),
      eval: jest.fn().mockResolvedValue(1),
    };

    mockBookingLockService = {
      acquireCancellationLock: jest.fn().mockResolvedValue('lock_tok_1'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    mockCancellationPolicyService = {
      calculateCancellation: jest.fn().mockReturnValue({
        refundAmountInPaise: 650000,
        cancellationFeeInPaise: 0,
        policyApplied: 'FLEXIBLE',
        tier: 'FULL_REFUND',
      }),
      calculateRefund: jest.fn().mockResolvedValue({
        refundAmountInPaise: 650000,
        cancellationFeeInPaise: 0,
        policyApplied: 'FLEXIBLE',
        tier: 'FULL_REFUND',
      }),
    };

    mockOutboxService = {
      recordEvent: jest.fn().mockResolvedValue({ id: 'evt_1' }),
      dispatchEvent: jest.fn().mockResolvedValue(undefined),
    };

    paymentsService = new PaymentsService(
      mockPrisma,
      mockConfigService,
      mockNotifications,
      undefined, // invoicesService
      undefined, // walletsService
      mockAuditLog, // auditLogService
      undefined, // runtimeService
      mockLedgerCore, // ledgerCore
    );

    reconciliationService = new FinancialReconciliationService(
      mockPrisma,
      mockConfigService,
      mockNotifications,
      mockAuditLog,
      mockRedis,
      undefined,
      undefined,
      undefined,
      mockLedgerCore,
    );

    bookingLifecycleService = new BookingLifecycleService(
      mockPrisma,
      mockOutboxService as any,
      mockCancellationPolicyService as any,
      {} as any,
      paymentsService,
      mockAuditLog,
      mockBookingLockService as any,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      mockLedgerCore,
    );
  });

  describe('Standard Payment Verification Ledger Unification (CRIT-Q-01)', () => {
    it('creates a balanced zero-sum journal in LedgerCore upon successful payment verification', async () => {
      const mockBooking = {
        id: 'book_q_01',
        vendorId: 'vendor_q_01',
        customerId: 'cust_q_01',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000),
        netToVendor: new Decimal(4250),
        platformFee: new Decimal(500),
        gstAmount: new Decimal(250),
        securityDeposit: {
          id: 'sec_01',
          amount: new Decimal(2000),
          status: 'PENDING',
        },
      };

      const mockPayment = {
        id: 'pay_q_01',
        bookingId: 'book_q_01',
        status: PaymentStatus.CREATED,
        amount: new Decimal(7000), // 5000 fare + 2000 deposit
        razorpayOrderId: 'order_q_01',
        gatewayProvider: 'RAZORPAY',
        booking: mockBooking,
      };

      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);

      await paymentsService.verifyPayment(
        {
          bookingId: 'book_q_01',
          razorpayPaymentId: 'pay_rzp_mock_123',
          razorpayOrderId: 'order_q_01',
          razorpaySignature: 'mock_signature',
        },
        'cust_q_01',
      );

      // Verify LedgerCore was invoked
      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);
      const journalCall = mockLedgerCore.recordJournal.mock.calls[0][0];

      expect(journalCall.referenceType).toBe('BOOKING_PAYMENT_VERIFIED');
      expect(journalCall.idempotencyKey).toBe('jrn_pay_verify_book_q_01');

      // Verify double-entry balancing: Debits must equal Credits
      let totalDebit = new Decimal(0);
      let totalCredit = new Decimal(0);
      for (const line of journalCall.lines) {
        if (line.side === LedgerEntrySide.DEBIT) totalDebit = totalDebit.add(line.amount);
        if (line.side === LedgerEntrySide.CREDIT) totalCredit = totalCredit.add(line.amount);
      }

      expect(totalDebit.toNumber()).toBe(7000);
      expect(totalCredit.toNumber()).toBe(7000);

      // Verify accounts credited
      const vendorCredit = journalCall.lines.find(
        (l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE,
      );
      expect(vendorCredit.amount.toNumber()).toBe(4250);

      const escrowCredit = journalCall.lines.find(
        (l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW,
      );
      expect(escrowCredit.amount.toNumber()).toBe(2000);
    });

    it('ensures repeated payment verification is idempotent and does not create duplicate journals', async () => {
      const mockBooking = {
        id: 'book_q_02',
        vendorId: 'vendor_q_02',
        customerId: 'cust_q_02',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(3000),
        netToVendor: new Decimal(2550),
        platformFee: new Decimal(300),
        gstAmount: new Decimal(150),
        securityDeposit: null,
      };

      const mockPayment = {
        id: 'pay_q_02',
        bookingId: 'book_q_02',
        status: PaymentStatus.PAID,
        amount: new Decimal(3000),
        razorpayOrderId: 'order_q_02',
        razorpayPaymentId: 'pay_rzp_existing',
        gatewayProvider: 'RAZORPAY',
        booking: mockBooking,
      };

      mockPrisma.payment.findUnique.mockResolvedValue(mockPayment);
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);

      const result = await paymentsService.verifyPayment(
        {
          bookingId: 'book_q_02',
          razorpayPaymentId: 'pay_rzp_existing',
          razorpayOrderId: 'order_q_02',
          razorpaySignature: 'mock_signature',
        },
        'cust_q_02',
      );

      // Since payment was already PAID, idempotent return without recording another journal
      expect(mockLedgerCore.recordJournal).not.toHaveBeenCalled();
      expect(result).toBeDefined();
    });
  });

  describe('Cancellation Reversal Hardening (CRIT-Q-02)', () => {
    it('creates an economically balanced reversal journal and prevents negative vendor payable', async () => {
      const mockBooking = {
        id: 'book_cancel_01',
        vendorId: 'vendor_q_03',
        customerId: 'cust_q_03',
        status: BookingStatus.CONFIRMED,
        totalFare: new Decimal(5000),
        netToVendor: new Decimal(4000),
        platformFee: new Decimal(700),
        gstAmount: new Decimal(300),
        startDate: new Date(Date.now() + 48 * 3600000), // 48h in future -> 100% refund
        endDate: new Date(Date.now() + 96 * 3600000),
        vendor: { user: { id: 'usr_v_03' } },
        customer: { id: 'cust_q_03' },
        car: { id: 'car_01' },
        securityDeposit: {
          id: 'sec_c_01',
          amount: new Decimal(1500),
          status: 'HELD',
        },
        payment: {
          id: 'pay_c_01',
          status: PaymentStatus.PAID,
          amount: new Decimal(6500), // 5000 fare + 1500 deposit
          gatewayProvider: 'RAZORPAY',
        },
      };

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.payment.findUnique.mockResolvedValue(mockBooking.payment);
      mockPrisma.payment.findFirst.mockResolvedValue(mockBooking.payment);
      mockPrisma.platformLedgerEntry.findFirst.mockResolvedValue({ id: 'ple_existing_1' });

      await bookingLifecycleService.cancelBooking(
        'book_cancel_01',
        'cust_q_03',
        'CUSTOMER',
        'Customer changed travel plans',
      );

      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);
      const reversalCall = mockLedgerCore.recordJournal.mock.calls[0][0];

      expect(reversalCall.referenceType).toBe('CANCELLATION_REFUND');

      let totalDebit = new Decimal(0);
      let totalCredit = new Decimal(0);
      for (const line of reversalCall.lines) {
        if (line.side === LedgerEntrySide.DEBIT) totalDebit = totalDebit.add(line.amount);
        if (line.side === LedgerEntrySide.CREDIT) totalCredit = totalCredit.add(line.amount);
      }

      // Exact zero-sum balance: debits == credits
      expect(totalDebit.toNumber()).toBe(totalCredit.toNumber());

      // Debits must NOT exceed original vendor payable
      const vendorDebit = reversalCall.lines.find(
        (l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE,
      );
      expect(vendorDebit.amount.toNumber()).toBeLessThanOrEqual(4000);

      // Escrow deposit refund debit
      const escrowDebit = reversalCall.lines.find(
        (l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW,
      );
      expect(escrowDebit.amount.toNumber()).toBe(1500);

      // Gateway clearing credited
      const gatewayCredit = reversalCall.lines.find(
        (l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING,
      );
      expect(gatewayCredit.amount.toNumber()).toBe(totalDebit.toNumber());
    });
  });

  describe('Reconciliation Auto-Healing LedgerCore Integration (HIGH-Q-05)', () => {
    it('records balanced LedgerCore journal when auto-healing unconfirmed paid bookings', async () => {
      const candidatePayment = {
        id: 'pay_heal_01',
        bookingId: 'book_heal_01',
        status: PaymentStatus.CREATED,
        amount: new Decimal(4000),
        razorpayOrderId: 'order_heal_01',
        gatewayProvider: 'RAZORPAY',
        booking: {
          id: 'book_heal_01',
          vendorId: 'vendor_h_01',
          customerId: 'cust_h_01',
          status: BookingStatus.PENDING,
          totalFare: new Decimal(4000),
          netToVendor: new Decimal(3400),
          platformFee: new Decimal(400),
          gstAmount: new Decimal(200),
          securityDeposit: null,
        },
      };

      mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

      // Mock Razorpay instance on reconciliationService
      (reconciliationService as any).razorpay = {
        orders: {
          fetchPayments: jest.fn().mockResolvedValue({
            items: [
              {
                id: 'pay_rzp_captured_999',
                order_id: 'order_heal_01',
                status: 'captured',
                currency: 'INR',
                amount: 400000, // 4000 INR in paise
              },
            ],
          }),
        },
      };
      (reconciliationService as any).useMock = false;

      const report = {
        candidatesFound: 0,
        processed: 0,
        healed: 0,
        skipped: 0,
        errors: 0,
      };

      await reconciliationService.reconcileUnconfirmedPaidBookings(report);

      expect(report.healed).toBe(1);
      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);

      const healJournal = mockLedgerCore.recordJournal.mock.calls[0][0];
      expect(healJournal.referenceType).toBe('BOOKING_PAYMENT_VERIFIED');
      expect(healJournal.idempotencyKey).toBe('jrn_pay_verify_book_heal_01');

      let totalDebit = new Decimal(0);
      let totalCredit = new Decimal(0);
      for (const line of healJournal.lines) {
        if (line.side === LedgerEntrySide.DEBIT) totalDebit = totalDebit.add(line.amount);
        if (line.side === LedgerEntrySide.CREDIT) totalCredit = totalCredit.add(line.amount);
      }
      expect(totalDebit.toNumber()).toBe(4000);
      expect(totalCredit.toNumber()).toBe(4000);
    });
  });
});
