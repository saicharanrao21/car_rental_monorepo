import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { BookingLifecycleService } from '../booking-lifecycle.service';
import { BookingOutboxService } from '../booking-outbox.service';
import { CancellationPolicyService } from '../cancellation-policy.service';
import { HandoverOtpService } from '../handover-otp.service';
import { PaymentsService } from '../../payments/payments.service';
import { AuditLogService } from '../../admin/audit-log.service';
import { BookingLockService } from '../../redis/booking-lock.service';
import { LedgerCoreService } from '../../finance/ledger-core.service';
import {
  BookingStatus,
  RefundStatus,
  SecurityDepositStatus,
  LedgerAccountType,
  LedgerEntrySide,
  Role,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase P: Resilient Cancellation / Refund State Machine (GAP-02)', () => {
  let lifecycleService: BookingLifecycleService;
  let mockPrisma: any;
  let mockOutboxService: any;
  let mockCancellationPolicy: any;
  let mockPaymentsService: any;
  let mockAuditLogService: any;
  let mockBookingLockService: any;
  let mockLedgerService: any;

  let refundsStore: any[] = [];
  let bookingsStore: any[] = [];
  let recordedJournals: any[] = [];
  let depositStatus: string = 'HELD';

  const mockBooking = {
    id: 'bk_cancel_101',
    vendorId: 'vendor_fast_wheels',
    customerId: 'cust_charlie',
    carId: 'car_scorpio',
    status: BookingStatus.CONFIRMED,
    totalFare: new Decimal(10000),
    startDate: new Date(Date.now() + 86400000 * 3), // 3 days in future
    endDate: new Date(Date.now() + 86400000 * 6),
    car: { pickupHubId: 'hub_mumbai', operationalStatus: 'ACTIVE' },
    payment: {
      id: 'pay_rec_101',
      gatewayProvider: 'RAZORPAY',
      amount: new Decimal(10000),
    },
    securityDeposit: {
      id: 'dep_rec_101',
      amount: new Decimal(3000),
      status: SecurityDepositStatus.HELD,
    },
  };

  beforeEach(async () => {
    refundsStore = [];
    recordedJournals = [];
    depositStatus = 'HELD';
    bookingsStore = [{ ...mockBooking, status: BookingStatus.CONFIRMED }];

    mockPrisma = {
      booking: {
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          const bk = bookingsStore.find((b) => b.id === where.id);
          if (!bk) return null;
          return {
            ...bk,
            payment: bk.payment,
            securityDeposit: { ...bk.securityDeposit, status: depositStatus },
            vendor: { user: { id: 'usr_vendor' } },
            customer: { id: bk.customerId },
          };
        }),
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          const bk = bookingsStore.find((b) => b.id === where.id);
          if (bk) {
            Object.assign(bk, data);
          }
          return bk;
        }),
      },
      paymentRefund: {
        create: jest.fn().mockImplementation(async ({ data }) => {
          const r = { id: `rf_${Date.now()}`, ...data };
          refundsStore.push(r);
          return r;
        }),
        updateMany: jest.fn().mockImplementation(async ({ where, data }) => {
          let count = 0;
          for (const r of refundsStore) {
            if (r.bookingId === where.bookingId && (where.status === undefined || r.status === where.status)) {
              Object.assign(r, data);
              count++;
            }
          }
          return { count };
        }),
      },
      securityDeposit: {
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          depositStatus = data.status;
          return { id: where.id, status: data.status };
        }),
        updateMany: jest.fn().mockImplementation(async ({ where, data }) => {
          depositStatus = data.status;
          return { count: 1 };
        }),
      },
      bookingOutboxEvent: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'outbox_cancel_1' }),
      },
      vehicleAuditLog: {
        create: jest.fn().mockResolvedValue({}),
      },
      fulfillmentRecord: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      $transaction: jest.fn().mockImplementation(async (cb) => {
        return cb(mockPrisma);
      }),
    };

    mockOutboxService = {
      dispatchEvent: jest.fn().mockResolvedValue(true),
    };

    mockCancellationPolicy = {
      calculateCancellation: jest.fn().mockReturnValue({
        refundAmountInPaise: 1000000, // ₹10,000 (100% refund)
        refundAmount: new Decimal(10000),
        tier: 'FULL_REFUND',
        tierDescription: '100% full refund',
        feeInPaise: 0,
        cancellationFee: new Decimal(0),
        isEligibleForRefund: true,
      }),
      calculateCancellationWithConfig: jest.fn().mockResolvedValue({
        refundAmountInPaise: 1000000,
        refundAmount: new Decimal(10000),
        tier: 'FULL_REFUND',
        tierDescription: '100% full refund',
        feeInPaise: 0,
        cancellationFee: new Decimal(0),
        isEligibleForRefund: true,
      }),
    };

    mockPaymentsService = {
      refund: jest.fn().mockResolvedValue({
        refundId: 'rfnd_rzp_ext_999',
        refundAmount: 10000,
        status: 'PROCESSED',
      }),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue({}),
    };

    mockBookingLockService = {
      acquireCancellationLock: jest.fn().mockResolvedValue('lock_tok_1'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    mockLedgerService = {
      recordJournal: jest.fn().mockImplementation(async (input) => {
        recordedJournals.push(input);
        const lines = input.lines || [];
        return {
          journalId: `jnl_${Date.now()}`,
          entryCount: lines.length,
          totalDebits: lines.reduce((sum: number, e: any) => sum + (e.side === 'DEBIT' ? Number(e.amount) : 0), 0),
          totalCredits: lines.reduce((sum: number, e: any) => sum + (e.side === 'CREDIT' ? Number(e.amount) : 0), 0),
        };
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingLifecycleService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: BookingOutboxService, useValue: mockOutboxService },
        { provide: CancellationPolicyService, useValue: mockCancellationPolicy },
        { provide: HandoverOtpService, useValue: {} },
        { provide: PaymentsService, useValue: mockPaymentsService },
        { provide: AuditLogService, useValue: mockAuditLogService },
        { provide: BookingLockService, useValue: mockBookingLockService },
        { provide: LedgerCoreService, useValue: mockLedgerService },
      ],
    }).compile();

    lifecycleService = module.get<BookingLifecycleService>(BookingLifecycleService);
  });

  describe('Clean Cancellation with Successful Gateway Refund', () => {
    it('should transition booking to CANCELLED, release deposit, persist refund, and write balanced reversal journal', async () => {
      const result = await lifecycleService.cancelBooking(
        'bk_cancel_101',
        'cust_charlie',
        Role.CUSTOMER,
        'Change of travel dates',
      );

      expect(result.success).toBe(true);
      expect(result.booking.status).toBe(BookingStatus.CANCELLED);

      // Verify SecurityDeposit cancelled/released
      expect(depositStatus).toBe(SecurityDepositStatus.CANCELLED);

      // Verify PaymentRefund record transitioned to PROCESSED
      expect(refundsStore).toHaveLength(1);
      expect(refundsStore[0].status).toBe(RefundStatus.PROCESSED);
      expect(refundsStore[0].gatewayRefundId).toBe('rfnd_rzp_ext_999');
      expect(refundsStore[0].requestedAmount.toNumber()).toBe(10000);

      // Verify double-entry ledger reversal
      expect(recordedJournals).toHaveLength(1);
      const journal = recordedJournals[0];
      expect(journal.referenceType).toBe('CANCELLATION_REFUND');

      let debits = 0;
      let credits = 0;
      for (const line of journal.lines) {
        if (line.side === LedgerEntrySide.DEBIT) debits += Number(line.amount);
        if (line.side === LedgerEntrySide.CREDIT) credits += Number(line.amount);
      }
      expect(debits).toBe(10000);
      expect(credits).toBe(10000);
      expect(debits).toBe(credits);

      // VENDOR_PAYABLE debited, GATEWAY_CLEARING credited
      const vendorDebit = journal.lines.find((l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE);
      expect(vendorDebit).toBeDefined();
      expect(vendorDebit.side).toBe(LedgerEntrySide.DEBIT);

      const gatewayCredit = journal.lines.find((l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING);
      expect(gatewayCredit).toBeDefined();
      expect(gatewayCredit.side).toBe(LedgerEntrySide.CREDIT);
    });
  });

  describe('Decoupled Gateway Refund Failure Resilience (GAP-02)', () => {
    it('should NOT abort DB cancellation when payment gateway refund fails, and should mark PaymentRefund as RETRYABLE', async () => {
      // Configure gateway to simulate timeout / network crash
      mockPaymentsService.refund.mockRejectedValueOnce(
        new Error('Razorpay Gateway 504 Gateway Timeout: connection reset by peer'),
      );

      const result = await lifecycleService.cancelBooking(
        'bk_cancel_101',
        'cust_charlie',
        Role.CUSTOMER,
        'Flight cancelled',
      );

      // CRITICAL GUARANTEE: Booking state transition MUST succeed despite gateway failure
      expect(result.success).toBe(true);
      expect(result.booking.status).toBe(BookingStatus.CANCELLED);

      // PaymentRefund record must NOT be lost: marked as RETRYABLE for reconciliation sweep
      expect(refundsStore).toHaveLength(1);
      expect(refundsStore[0].status).toBe(RefundStatus.RETRYABLE);
      expect(refundsStore[0].failureReason).toContain('Razorpay Gateway 504');

      // Security deposit must still be released
      expect(depositStatus).toBe(SecurityDepositStatus.CANCELLED);

      // Double-entry refund journal intent must still be safely recorded
      expect(recordedJournals).toHaveLength(1);
    });
  });
});
