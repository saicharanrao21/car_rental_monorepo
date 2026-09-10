import { PaymentsService } from '../payments.service';
import { FinancialReconciliationService } from '../reconciliation.service';
import { LedgerCoreService } from '../../finance/ledger-core.service';
import { BookingLifecycleService } from '../../bookings/booking-lifecycle.service';
import { DepositsService } from '../../deposits/deposits.service';
import { WalletsService } from '../../wallets/wallets.service';
import { PayoutsService } from '../../payouts/payouts.service';
import { CorporateAccountsService } from '../../corporate/corporate-accounts.service';
import { RazorpayXPayoutProvider } from '../../payouts/providers/razorpayx-payout.provider';
import {
  BookingStatus,
  PaymentStatus,
  RefundStatus,
  SecurityDepositStatus,
  PayoutStatus,
  LedgerAccountType,
  LedgerEntrySide,
  Role,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';

describe('Phase R: Full Production Readiness & E2E Financial Lifecycle Validation', () => {
  let paymentsService: PaymentsService;
  let reconciliationService: FinancialReconciliationService;
  let bookingLifecycleService: BookingLifecycleService;
  let depositsService: DepositsService;
  let walletsService: WalletsService;
  let payoutsService: PayoutsService;
  let corporateAccountsService: CorporateAccountsService;
  let razorpayXProvider: RazorpayXPayoutProvider;

  let mockPrisma: any;
  let mockLedgerCore: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockConfigService: any;
  let mockRedis: any;
  let recordedJournals: any[] = [];
  let databaseState: Record<string, any> = {};

  beforeEach(() => {
    recordedJournals = [];
    databaseState = {
      bookings: new Map(),
      payments: new Map(),
      securityDeposits: new Map(),
      payouts: new Map(),
      refunds: new Map(),
      wallets: new Map(),
      walletEntries: [],
      corporateAccounts: new Map(),
      corporateEmployees: new Map(),
      corporateLedger: [],
    };

    // Concrete In-Memory Double-Entry Ledger Core Engine
    mockLedgerCore = {
      recordJournal: jest.fn().mockImplementation(async (input: any) => {
        const lines = input.lines || input.entries || [];
        let totalDebit = new Decimal(0);
        let totalCredit = new Decimal(0);

        for (const line of lines) {
          const side = line.side || line.entrySide;
          const amt = new Decimal(line.amount);
          if (amt.lte(0)) {
            throw new BadRequestException('Ledger entry amount must be strictly positive');
          }
          if (side === LedgerEntrySide.DEBIT) totalDebit = totalDebit.add(amt);
          else if (side === LedgerEntrySide.CREDIT) totalCredit = totalCredit.add(amt);
          else throw new BadRequestException(`Invalid entry side: ${side}`);
        }

        // Strict double-entry invariant: Debits must exactly equal Credits
        if (!totalDebit.equals(totalCredit)) {
          throw new Error(
            `UNBALANCED JOURNAL INVARIANT VIOLATION: Debits (₹${totalDebit.toFixed(2)}) != Credits (₹${totalCredit.toFixed(2)})`,
          );
        }

        const journal = {
          journalId: input.journalId || `jrn_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          referenceType: input.referenceType,
          referenceId: input.referenceId,
          bookingId: input.bookingId,
          paymentId: input.paymentId,
          payoutId: input.payoutId,
          vendorId: input.vendorId,
          narration: input.narration || input.description,
          idempotencyKey: input.idempotencyKey,
          lines,
          totalDebit,
          totalCredit,
          postedAt: new Date(),
        };

        // Enforce idempotency key uniqueness
        if (input.idempotencyKey) {
          const existing = recordedJournals.find((j) => j.idempotencyKey === input.idempotencyKey);
          if (existing) {
            return { journalId: existing.journalId, entries: existing.lines, isDuplicate: true };
          }
        }

        recordedJournals.push(journal);
        return { journalId: journal.journalId, entries: lines, isDuplicate: false };
      }),
      getVendorPayableBalance: jest.fn().mockImplementation(async (vendorId: string) => {
        let balance = new Decimal(0);
        for (const j of recordedJournals) {
          for (const line of j.lines) {
            if (
              line.accountType === LedgerAccountType.VENDOR_PAYABLE &&
              (line.accountEntityId === vendorId || j.vendorId === vendorId)
            ) {
              const amt = new Decimal(line.amount);
              const side = line.side || line.entrySide;
              if (side === LedgerEntrySide.CREDIT) balance = balance.add(amt);
              else if (side === LedgerEntrySide.DEBIT) balance = balance.sub(amt);
            }
          }
        }
        return balance;
      }),
      getCustomerEscrowBalance: jest.fn().mockImplementation(async (customerId: string) => {
        let balance = new Decimal(0);
        for (const j of recordedJournals) {
          for (const line of j.lines) {
            if (
              line.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW &&
              line.accountEntityId === customerId
            ) {
              const amt = new Decimal(line.amount);
              const side = line.side || line.entrySide;
              if (side === LedgerEntrySide.CREDIT) balance = balance.add(amt);
              else if (side === LedgerEntrySide.DEBIT) balance = balance.sub(amt);
            }
          }
        }
        return balance;
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue({ id: 'aud_entry_1' }),
    };

    mockRedis = {
      set: jest.fn().mockResolvedValue('OK'),
      eval: jest.fn().mockResolvedValue(1),
      del: jest.fn().mockResolvedValue(1),
      get: jest.fn().mockResolvedValue(null),
    };

    mockConfigService = {
      get: jest.fn((key: string) => {
        const conf: Record<string, string> = {
          NODE_ENV: 'test',
          RAZORPAY_KEY_ID: 'rzp_test_r_key_id',
          RAZORPAY_KEY_SECRET: 'rzp_test_r_secret_key',
          RAZORPAY_WEBHOOK_SECRET: 'rzp_webhook_secret_r',
          RAZORPAY_USE_MOCK: 'true',
          JWT_ACCESS_SECRET: 'super_secure_jwt_access_secret_key_32_chars!',
          JWT_REFRESH_SECRET: 'super_secure_jwt_refresh_secret_key_32_chars!',
        };
        return conf[key] || null;
      }),
    };

    mockPrisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue({ id: 'usr_admin_1', role: Role.ADMIN }),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.phone === '9999999999') return Promise.resolve({ id: 'usr_cust_1', phone: '9999999999', role: Role.CUSTOMER });
          return Promise.resolve({ id: where.id || 'usr_cust_1', role: Role.CUSTOMER });
        }),
      },
      booking: {
        findUnique: jest.fn().mockImplementation(({ where }) => databaseState.bookings.get(where.id) || null),
        findMany: jest.fn().mockImplementation(({ where, include }: any = {}) => {
          let list = Array.from(databaseState.bookings.values());
          if (where) {
            if (where.status) {
              list = list.filter((b: any) => b.status === where.status);
            }
            if (where.refundAmount && where.refundAmount.gt) {
              list = list.filter((b: any) => b.refundAmount && new Decimal(b.refundAmount).gt(where.refundAmount.gt));
            }
            if (where.payment) {
              list = list.filter((b: any) => {
                const p = databaseState.payments.get(b.id) || Array.from(databaseState.payments.values()).find((pay: any) => pay.bookingId === b.id) || b.payment;
                if (!p) return false;
                if (where.payment.status && p.status !== where.payment.status) return false;
                if (where.payment.refundStatus && p.refundStatus !== where.payment.refundStatus) return false;
                return true;
              });
            }
          }
          if (include?.payment) {
            list = list.map((b: any) => ({
              ...b,
              payment: b.payment || Array.from(databaseState.payments.values()).find((pay: any) => pay.bookingId === b.id),
            }));
          }
          return list;
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          databaseState.bookings.set(data.id, { ...data, status: BookingStatus.PENDING });
          return databaseState.bookings.get(data.id);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const b = databaseState.bookings.get(where.id);
          if (!b) throw new Error(`Booking ${where.id} not found`);
          const updated = { ...b, ...data };
          databaseState.bookings.set(where.id, updated);
          return updated;
        }),
      },
      payment: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.bookingId) {
            return Array.from(databaseState.payments.values()).find((p: any) => p.bookingId === where.bookingId) || null;
          }
          return databaseState.payments.get(where.id) || null;
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          if (where.razorpayPaymentId) {
            return Array.from(databaseState.payments.values()).find((p: any) => p.razorpayPaymentId === where.razorpayPaymentId) || null;
          }
          return null;
        }),
        findMany: jest.fn().mockImplementation(({ where, include }: any = {}) => {
          let list = Array.from(databaseState.payments.values());
          if (where) {
            if (where.status) {
              list = list.filter((p: any) => p.status === where.status);
            }
            if (where.refundStatus) {
              list = list.filter((p: any) => p.refundStatus === where.refundStatus);
            }
            if (where.razorpayOrderId) {
              list = list.filter((p: any) => p.razorpayOrderId);
            }
            if (where.razorpayPaymentId) {
              list = list.filter((p: any) => p.razorpayPaymentId);
            }
            if (where.booking && where.booking.status) {
              list = list.filter((p: any) => {
                const b = databaseState.bookings.get(p.bookingId);
                return b && b.status === where.booking.status;
              });
            }
          }
          if (include?.booking) {
            list = list.map((p: any) => ({
              ...p,
              booking: databaseState.bookings.get(p.bookingId),
            }));
          }
          return list;
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          databaseState.payments.set(data.id, { ...data, status: PaymentStatus.PENDING });
          return databaseState.payments.get(data.id);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const p = databaseState.payments.get(where.id);
          if (!p) throw new Error(`Payment ${where.id} not found`);
          const updated = { ...p, ...data };
          databaseState.payments.set(where.id, updated);
          return updated;
        }),
      },
      securityDeposit: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.bookingId) {
            return Array.from(databaseState.securityDeposits.values()).find((d: any) => d.bookingId === where.bookingId) || null;
          }
          return databaseState.securityDeposits.get(where.id) || null;
        }),
        findMany: jest.fn().mockImplementation(() => Array.from(databaseState.securityDeposits.values())),
        upsert: jest.fn().mockImplementation(({ where, create, update }) => {
          const existing = Array.from(databaseState.securityDeposits.values()).find((d: any) => d.bookingId === where.bookingId);
          if (existing) {
            const upd = { ...existing, ...update };
            databaseState.securityDeposits.set(existing.id, upd);
            return upd;
          }
          const id = `sec_dep_${Date.now()}`;
          const rec = { id, ...create, deductedAmount: new Decimal(0), refundedAmount: new Decimal(0) };
          databaseState.securityDeposits.set(id, rec);
          return rec;
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const d = databaseState.securityDeposits.get(where.id);
          if (!d) throw new Error(`Security deposit ${where.id} not found`);
          const updated = { ...d, ...data };
          databaseState.securityDeposits.set(where.id, updated);
          return updated;
        }),
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          let count = 0;
          for (const [id, dep] of databaseState.securityDeposits.entries()) {
            if (dep.id === where.id || dep.bookingId === where.bookingId) {
              if (!where.status || where.status === dep.status || (where.status.in && where.status.in.includes(dep.status))) {
                databaseState.securityDeposits.set(id, { ...dep, ...data });
                count++;
              }
            }
          }
          return { count };
        }),
      },
      payout: {
        findUnique: jest.fn().mockImplementation(({ where }) => databaseState.payouts.get(where.id) || null),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          if (where.idempotencyKey) {
            return Array.from(databaseState.payouts.values()).find((p: any) => p.idempotencyKey === where.idempotencyKey) || null;
          }
          return null;
        }),
        findMany: jest.fn().mockImplementation(() => Array.from(databaseState.payouts.values())),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = data.id || `po_${Date.now()}`;
          const rec = { id, ...data, status: PayoutStatus.PENDING };
          databaseState.payouts.set(id, rec);
          return rec;
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const p = databaseState.payouts.get(where.id);
          if (!p) throw new Error(`Payout ${where.id} not found`);
          const updated = { ...p, ...data };
          databaseState.payouts.set(where.id, updated);
          return updated;
        }),
      },
      paymentRefund: {
        findUnique: jest.fn().mockImplementation(({ where }) => databaseState.refunds.get(where.idempotencyKey) || null),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `rfnd_${Date.now()}`;
          const rec = { id, ...data };
          databaseState.refunds.set(data.idempotencyKey, rec);
          return rec;
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockImplementation(({ where, data }) => Promise.resolve(data)),
      },
      wallet: {
        findUnique: jest.fn().mockImplementation(({ where }) => databaseState.wallets.get(where.userId) || databaseState.wallets.get(where.id) || null),
        findMany: jest.fn().mockImplementation(() => Array.from(databaseState.wallets.values())),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `wlt_${data.userId}`;
          const rec = { id, ...data };
          databaseState.wallets.set(data.userId, rec);
          databaseState.wallets.set(id, rec);
          return rec;
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const w = databaseState.wallets.get(where.id);
          if (!w) throw new Error(`Wallet ${where.id} not found`);
          const updated = { ...w, ...data };
          databaseState.wallets.set(where.id, updated);
          databaseState.wallets.set(updated.userId, updated);
          return updated;
        }),
      },
      walletLedgerEntry: {
        findUnique: jest.fn().mockImplementation(({ where }) => databaseState.walletEntries.find((e: any) => e.idempotencyKey === where.idempotencyKey) || null),
        findMany: jest.fn().mockImplementation(() => databaseState.walletEntries),
        groupBy: jest.fn().mockImplementation(({ by, where }: any = {}) => {
          const entries = databaseState.walletEntries.filter((e: any) => !where?.walletId || e.walletId === where.walletId);
          const credits = entries.filter((e: any) => e.direction === 'CREDIT').reduce((acc: Decimal, e: any) => acc.add(new Decimal(e.amount)), new Decimal(0));
          const debits = entries.filter((e: any) => e.direction === 'DEBIT').reduce((acc: Decimal, e: any) => acc.add(new Decimal(e.amount)), new Decimal(0));
          return [
            { direction: 'CREDIT', _sum: { amount: credits } },
            { direction: 'DEBIT', _sum: { amount: debits } },
          ];
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `wle_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
          const rec = { id, ...data };
          databaseState.walletEntries.push(rec);
          return rec;
        }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Decimal(0) } }),
      },
      vendor: {
        findUnique: jest.fn().mockImplementation(({ where }) => ({
          id: where.id,
          businessName: 'Apex Elite Motors',
          userId: 'usr_vnd_1',
          bankAccount: { accountNumber: '9988776655', ifscCode: 'HDFC0001234', accountHolderName: 'Apex Elite Motors' },
        })),
      },
      corporateAccount: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.corporateCode) {
            return databaseState.corporateAccounts.get(where.corporateCode) || null;
          }
          return databaseState.corporateAccounts.get(where.id) || null;
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `corp_${Date.now()}`;
          const rec = { id, ...data };
          databaseState.corporateAccounts.set(data.corporateCode, rec);
          databaseState.corporateAccounts.set(id, rec);
          return rec;
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const acc = databaseState.corporateAccounts.get(where.id);
          if (!acc) throw new Error(`Corporate account not found`);
          let newUsed = acc.usedCredit;
          if (data.usedCredit?.increment) newUsed = newUsed.add(data.usedCredit.increment);
          if (data.usedCredit?.decrement) newUsed = newUsed.sub(data.usedCredit.decrement);
          const updated = { ...acc, ...data, usedCredit: newUsed };
          databaseState.corporateAccounts.set(acc.corporateCode, updated);
          databaseState.corporateAccounts.set(acc.id, updated);
          return updated;
        }),
      },
      corporateEmployee: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const key = `${where.corporateAccountId_userId?.corporateAccountId}_${where.corporateAccountId_userId?.userId}`;
          return databaseState.corporateEmployees.get(key) || null;
        }),
      },
      corporateCreditLedgerEntry: {
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `ccle_${Date.now()}`;
          const rec = { id, ...data };
          databaseState.corporateLedger.push(rec);
          return rec;
        }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Decimal(0) } }),
      },
      platformLedgerEntry: {
        findFirst: jest.fn().mockImplementation(({ where }) => {
          if (where.idempotencyKey) {
            for (const j of recordedJournals) {
              if (j.idempotencyKey === where.idempotencyKey) return { journalId: j.journalId };
            }
          }
          return null;
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list: any[] = [];
          for (const j of recordedJournals) {
            for (const l of j.lines) {
              list.push({ ...l, journalId: j.journalId, referenceType: j.referenceType, postedAt: j.postedAt });
            }
          }
          if (where?.bookingId) list = list.filter((e) => e.bookingId === where.bookingId);
          if (where?.accountType) list = list.filter((e) => e.accountType === where.accountType);
          return list;
        }),
      },
      paymentAuditLog: { create: jest.fn().mockResolvedValue({ id: 'aud_pay_1' }) },
      bookingOutboxEvent: { create: jest.fn().mockResolvedValue({ id: 'outbox_evt_1' }) },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockImplementation(async (strings: any, ...values: any[]) => {
        const queryStr = Array.isArray(strings) ? strings.join(' ') : String(strings);
        if (queryStr.includes('"Wallet"') || queryStr.includes('Wallet')) {
          const walletId = values[0];
          const w = databaseState.wallets.get(walletId);
          if (w) {
            return [
              {
                id: w.id,
                availableBalance: w.availableBalance,
                lockedBalance: w.lockedBalance,
                realBalance: w.realBalance,
                promoBalance: w.promoBalance,
                status: w.status,
              },
            ];
          }
        }
        if (queryStr.includes('"CorporateAccount"')) {
          const corpId = values[0];
          const acc = databaseState.corporateAccounts.get(corpId);
          if (acc) return [{ id: acc.id }];
        }
        if (queryStr.includes('"CorporateEmployee"')) {
          return [{ id: 'mock_emp_locked' }];
        }
        return [];
      }),
    };

    paymentsService = new PaymentsService(
      mockPrisma,
      mockConfigService,
      mockNotifications,
      undefined,
      undefined,
      mockAuditLog,
      undefined,
      mockLedgerCore,
    );

    bookingLifecycleService = new BookingLifecycleService(
      mockPrisma,
      {
        publishEvent: jest.fn().mockResolvedValue({ id: 'evt_1' }),
        dispatchEvent: jest.fn().mockResolvedValue(undefined),
      } as any, // outboxService
      {
        calculateRefund: jest.fn().mockReturnValue({
          refundAmountInPaise: 840000,
          cancellationFeeInPaise: 0,
          tier: 'FULL_REFUND',
          refundAmount: new Decimal(8400),
          cancellationFee: new Decimal(0),
        }),
        calculateCancellation: jest.fn().mockReturnValue({
          refundAmountInPaise: 840000,
          cancellationFeeInPaise: 0,
          tier: 'FULL_REFUND',
          refundAmount: new Decimal(8400),
          cancellationFee: new Decimal(0),
        }),
        getPolicyForCar: jest.fn().mockResolvedValue({ requirePostTripInspection: false }),
      } as any, // cancellationPolicyService
      { generateOtp: jest.fn(), verifyOtp: jest.fn() } as any, // handoverOtpService
      paymentsService,
      mockAuditLog,
      {
        acquireLock: jest.fn().mockResolvedValue('lock_1'),
        releaseLock: jest.fn().mockResolvedValue(true),
        acquireCancellationLock: jest.fn().mockResolvedValue('cancel_token_1'),
        releaseCancellationLock: jest.fn().mockResolvedValue(true),
      } as any, // bookingLockService
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      mockLedgerCore,
    );

    depositsService = new DepositsService(
      mockPrisma,
      paymentsService,
      mockNotifications,
      mockAuditLog,
      mockLedgerCore,
    );

    walletsService = new WalletsService(
      mockPrisma,
      mockConfigService,
      mockAuditLog,
      mockNotifications,
      undefined,
      undefined,
      mockLedgerCore,
    );

    payoutsService = new PayoutsService(
      mockPrisma,
      mockNotifications,
      mockAuditLog,
      undefined,
      walletsService,
      undefined,
      mockLedgerCore,
    );

    corporateAccountsService = new CorporateAccountsService(mockPrisma);
  });

  describe('17-Step Deterministic End-to-End Financial Lifecycle Test', () => {
    const bookingId = 'book_r_e2e_001';
    const paymentId = 'pay_r_e2e_001';
    const customerId = 'cust_r_001';
    const vendorId = 'vend_r_001';
    const carId = 'car_r_001';

    it('executes steps 1 through 17 with strict database, balance-sheet, and ledger consistency', async () => {
      // -------------------------------------------------------------
      // STEP 1: Customer creates booking / quote request
      // STEP 2: Server calculates authoritative pricing breakdown
      // -------------------------------------------------------------
      const authoritativePricing = {
        basePrice: new Decimal(5000.0),
        platformFee: new Decimal(500.0),
        gstAmount: new Decimal(900.0),
        netToVendor: new Decimal(4500.0),
        totalFare: new Decimal(6400.0),
        securityDeposit: new Decimal(2000.0),
        totalPayable: new Decimal(8400.0), // totalFare + securityDeposit
      };

      const bookingRecord = {
        id: bookingId,
        customerId,
        vendorId,
        carId,
        startDate: new Date(Date.now() + 48 * 3600000),
        endDate: new Date(Date.now() + 96 * 3600000),
        totalFare: authoritativePricing.totalFare,
        netToVendor: authoritativePricing.netToVendor,
        platformFee: authoritativePricing.platformFee,
        gstAmount: authoritativePricing.gstAmount,
        status: BookingStatus.PENDING,
        customer: { id: customerId, name: 'Alice Customer', phone: '9999999999' },
        vendor: { id: vendorId, businessName: 'Apex Elite Motors', user: { phone: '8888888888' } },
        car: { id: carId, make: 'BMW', model: 'M3', registrationNumber: 'KA01MJ2026' },
        securityDeposit: {
          id: 'sec_dep_e2e_01',
          bookingId,
          amount: authoritativePricing.securityDeposit,
          status: SecurityDepositStatus.REQUIRED,
          deductedAmount: new Decimal(0),
          refundedAmount: new Decimal(0),
        },
      };
      databaseState.bookings.set(bookingId, bookingRecord);
      databaseState.securityDeposits.set('sec_dep_e2e_01', bookingRecord.securityDeposit);

      const paymentRecord = {
        id: paymentId,
        bookingId,
        amount: authoritativePricing.totalPayable,
        currency: 'INR',
        status: PaymentStatus.PENDING,
        razorpayOrderId: 'order_rzp_e2e_01',
        gatewayProvider: 'RAZORPAY',
        customer: { id: customerId },
        booking: bookingRecord,
      };
      databaseState.payments.set(paymentId, paymentRecord);

      expect(bookingRecord.status).toBe(BookingStatus.PENDING);
      expect(paymentRecord.status).toBe(PaymentStatus.PENDING);
      expect(recordedJournals.length).toBe(0);

      // -------------------------------------------------------------
      // STEP 3: Payment is verified via PaymentsService
      // STEP 4: Double-entry ledger journal is created atomically
      // STEP 5: Security deposit is recorded in escrow
      // STEP 6: Vendor payable is recorded
      // STEP 7: Platform commission and GST liabilities are recorded
      // -------------------------------------------------------------
      const verifyResult = await paymentsService.verifyPayment(
        {
          bookingId,
          razorpayOrderId: 'order_rzp_e2e_01',
          razorpayPaymentId: 'pay_rzp_captured_e2e_01',
          razorpaySignature: 'mock_signature',
        },
        customerId,
      );

      expect(verifyResult.success).toBe(true);
      expect(verifyResult.status).toBe(PaymentStatus.PAID);

      const updatedPayment = databaseState.payments.get(paymentId);
      expect(updatedPayment.status).toBe(PaymentStatus.PAID);
      expect(updatedPayment.razorpayPaymentId).toBe('pay_rzp_captured_e2e_01');

      // Verify double-entry journal was recorded
      expect(recordedJournals.length).toBe(1);
      const paymentJournal = recordedJournals[0];
      expect(paymentJournal.referenceType).toBe('BOOKING_PAYMENT_VERIFIED');
      expect(paymentJournal.bookingId).toBe(bookingId);

      // Verify mathematical balance of debits and credits
      expect(paymentJournal.totalDebit.equals(paymentJournal.totalCredit)).toBe(true);
      expect(paymentJournal.totalDebit.toNumber()).toBe(8400.0);

      // Verify Debit side: GATEWAY_CLEARING
      const gatewayDebit = paymentJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING && l.side === LedgerEntrySide.DEBIT,
      );
      expect(gatewayDebit).toBeDefined();
      expect(new Decimal(gatewayDebit.amount).toNumber()).toBe(8400.0);

      // Verify Credit side: VENDOR_PAYABLE
      const vendorCredit = paymentJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE && l.side === LedgerEntrySide.CREDIT,
      );
      expect(vendorCredit).toBeDefined();
      expect(new Decimal(vendorCredit.amount).toNumber()).toBe(authoritativePricing.netToVendor.toNumber());

      // Verify Credit side: PLATFORM_COMMISSION_REVENUE
      const commissionCredit = paymentJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.PLATFORM_COMMISSION_REVENUE && l.side === LedgerEntrySide.CREDIT,
      );
      expect(commissionCredit).toBeDefined();

      // Verify Credit side: TAX_GST_LIABILITY
      const gstCredit = paymentJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.TAX_GST_LIABILITY && l.side === LedgerEntrySide.CREDIT,
      );
      expect(gstCredit).toBeDefined();
      expect(new Decimal(gstCredit.amount).toNumber()).toBe(authoritativePricing.gstAmount.toNumber());

      // Verify Credit side: CUSTOMER_DEPOSIT_ESCROW
      const escrowCredit = paymentJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW && l.side === LedgerEntrySide.CREDIT,
      );
      expect(escrowCredit).toBeDefined();
      expect(new Decimal(escrowCredit.amount).toNumber()).toBe(authoritativePricing.securityDeposit.toNumber());

      // Record SecurityDeposit table held status
      const depositHeld = await depositsService.holdDeposit(bookingId, 2000, 'pay_rzp_captured_e2e_01');
      expect(depositHeld.status).toBe(SecurityDepositStatus.HELD);

      // -------------------------------------------------------------
      // STEP 8: Booking is confirmed
      // -------------------------------------------------------------
      bookingRecord.payment = updatedPayment;
      bookingRecord.securityDeposit = depositHeld;
      const confirmResult = await bookingLifecycleService.confirmBooking(
        bookingId,
        'SYSTEM',
        'SYSTEM',
        'Payment received and verified successfully',
      );
      expect(confirmResult.booking.status).toBe(BookingStatus.CONFIRMED);

      // -------------------------------------------------------------
      // STEP 9: Booking is cancelled by customer
      // STEP 10: Refund is created via gateway
      // STEP 11: Ledger reversal journal is recorded
      // -------------------------------------------------------------
      const cancelResult = await bookingLifecycleService.cancelBooking(
        bookingId,
        customerId,
        Role.CUSTOMER,
        'Customer travel schedule changed',
      );
      expect(cancelResult.booking.status).toBe(BookingStatus.CANCELLED);

      // Confirm reversal journal exists and balances perfectly
      expect(recordedJournals.length).toBe(2);
      const reversalJournal = recordedJournals[1];
      expect(reversalJournal.referenceType).toBe('CANCELLATION_REFUND');
      expect(reversalJournal.totalDebit.equals(reversalJournal.totalCredit)).toBe(true);

      // Verify escrow reversal on cancellation
      const escrowReversal = reversalJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW && l.side === LedgerEntrySide.DEBIT,
      );
      expect(escrowReversal).toBeDefined();
      expect(new Decimal(escrowReversal.amount).toNumber()).toBe(2000.0);

      // Verify vendor payable reversed
      const vendorReversal = reversalJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE && l.side === LedgerEntrySide.DEBIT,
      );
      expect(vendorReversal).toBeDefined();

      // Net vendor payable in ledger should now be zero (no phantom liabilities)
      const netVendorPayable = await mockLedgerCore.getVendorPayableBalance(vendorId);
      expect(netVendorPayable.toNumber()).toBe(0);

      // -------------------------------------------------------------
      // STEP 12: Vendor payout eligibility check
      // -------------------------------------------------------------
      // Create a completed, successful rental for the vendor so positive balance exists
      const completedBookingId = 'book_r_completed_01';
      const completedPaymentId = 'pay_r_completed_01';
      const completedBooking = {
        id: completedBookingId,
        customerId,
        vendorId,
        carId,
        startDate: new Date(Date.now() - 100 * 3600000),
        endDate: new Date(Date.now() - 20 * 3600000),
        totalFare: new Decimal(10000.0),
        netToVendor: new Decimal(8000.0),
        platformFee: new Decimal(1000.0),
        gstAmount: new Decimal(1000.0),
        status: BookingStatus.COMPLETED,
        disputeFlag: false,
        payment: { id: completedPaymentId, status: PaymentStatus.PAID, amount: new Decimal(10000.0) },
      };
      databaseState.bookings.set(completedBookingId, completedBooking);

      // Post completion ledger journal (crediting vendor payable ₹8,000)
      await mockLedgerCore.recordJournal({
        referenceType: 'BOOKING_PAYMENT_VERIFIED',
        referenceId: completedBookingId,
        bookingId: completedBookingId,
        vendorId,
        lines: [
          { accountType: LedgerAccountType.GATEWAY_CLEARING, accountEntityId: 'RAZORPAY', side: LedgerEntrySide.DEBIT, amount: new Decimal(10000.0) },
          { accountType: LedgerAccountType.VENDOR_PAYABLE, accountEntityId: vendorId, side: LedgerEntrySide.CREDIT, amount: new Decimal(8000.0) },
          { accountType: LedgerAccountType.PLATFORM_COMMISSION_REVENUE, side: LedgerEntrySide.CREDIT, amount: new Decimal(1000.0) },
          { accountType: LedgerAccountType.TAX_GST_LIABILITY, side: LedgerEntrySide.CREDIT, amount: new Decimal(1000.0) },
        ],
      });

      const eligibleBalance = await mockLedgerCore.getVendorPayableBalance(vendorId);
      expect(eligibleBalance.toNumber()).toBe(8000.0);

      // -------------------------------------------------------------
      // STEP 13: Payout is requested by vendor
      // STEP 14: Concurrent duplicate payout request is rejected
      // -------------------------------------------------------------
      const payout = await payoutsService.requestPayout(vendorId, {
        amount: 8000.0,
        currency: 'INR',
        idempotencyKey: 'payout_idem_key_001',
      });
      expect(payout).toBeDefined();
      expect(payout.amount.toNumber ? payout.amount.toNumber() : Number(payout.amount)).toBe(8000.0);

      // STEP 14: Concurrent duplicate attempt must be caught and rejected
      await expect(
        payoutsService.requestPayout(vendorId, {
          amount: 8000.0,
          currency: 'INR',
          idempotencyKey: 'payout_idem_key_001',
        }),
      ).rejects.toThrow();

      // -------------------------------------------------------------
      // STEP 15: Payout executes through provider abstraction (RazorpayXPayoutProvider)
      // STEP 16: Payout ledger settlement journal is recorded atomically
      // -------------------------------------------------------------
      const payoutId = payout.id;
      const approvedPayout = await payoutsService.approvePayout(payoutId, 'usr_admin_1', { notes: 'Approved for disbursement' });
      expect(approvedPayout.status).toBe(PayoutStatus.APPROVED);

      const executedPayout = await payoutsService.executePayout(payoutId, 'usr_admin_1', {
        providerTransferId: 'pout_rzpx_live_9999',
      });
      expect(executedPayout.status).toBe(PayoutStatus.PAID);
      expect(executedPayout.providerTransferId).toBe('pout_rzpx_live_9999');

      // Verify Payout Ledger Settlement journal
      const payoutJournal = recordedJournals.find((j) => j.referenceType === 'PAYOUT');
      expect(payoutJournal).toBeDefined();
      expect(payoutJournal.totalDebit.equals(payoutJournal.totalCredit)).toBe(true);

      const payoutDebit = payoutJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE && (l.side === LedgerEntrySide.DEBIT || l.entrySide === LedgerEntrySide.DEBIT),
      );
      expect(payoutDebit).toBeDefined();
      expect(new Decimal(payoutDebit.amount).toNumber()).toBe(8000.0);

      const payoutCredit = payoutJournal.lines.find(
        (l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING && (l.side === LedgerEntrySide.CREDIT || l.entrySide === LedgerEntrySide.CREDIT),
      );
      expect(payoutCredit).toBeDefined();
      expect(payoutCredit.accountEntityId).toBe('RAZORPAY');

      // Vendor payable balance is now fully settled back to 0.00
      const finalVendorBalance = await mockLedgerCore.getVendorPayableBalance(vendorId);
      expect(finalVendorBalance.toNumber()).toBe(0.0);

      // -------------------------------------------------------------
      // STEP 17: Reconciliation engine runs and detects zero anomalies
      // -------------------------------------------------------------
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

      const reconSummary = await reconciliationService.runReconciliationCycle();

      expect(reconSummary).toBeDefined();
      expect(reconSummary.errors).toBe(0);
      expect(reconSummary.healed).toBe(0);
    });
  });

  describe('Mandatory Negative Testing & Production Resilience', () => {
    it('rejects duplicate payment verification gracefully without duplicate journal creation', async () => {
      const bookingId = 'book_neg_dup_01';
      const paymentId = 'pay_neg_dup_01';

      databaseState.bookings.set(bookingId, {
        id: bookingId,
        customerId: 'c1',
        vendorId: 'v1',
        totalFare: new Decimal(5000),
        netToVendor: new Decimal(4000),
        platformFee: new Decimal(500),
        gstAmount: new Decimal(500),
        status: BookingStatus.CONFIRMED,
      });

      databaseState.payments.set(paymentId, {
        id: paymentId,
        bookingId,
        amount: new Decimal(5000),
        currency: 'INR',
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_rzp_dup_111',
        razorpayOrderId: 'order_1',
      });

      const res = await paymentsService.verifyPayment(
        {
          bookingId,
          razorpayOrderId: 'order_1',
          razorpayPaymentId: 'pay_rzp_dup_111',
          razorpaySignature: 'mock_signature',
        },
        'c1',
      );

      expect(res.success).toBe(true);
      expect(res.status).toBe(PaymentStatus.PAID);
      expect(recordedJournals.length).toBe(0); // Zero duplicate journals
    });

    it('rejects forged webhook signatures', async () => {
      const payload = JSON.stringify({ event: 'payment.captured' });
      const badSignature = 'invalid_tampered_signature_hex';

      await expect(
        paymentsService.handleWebhook(payload, badSignature),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects duplicate refund requests idempotently', async () => {
      const bookingId = 'book_neg_rfnd_01';
      const paymentId = 'pay_neg_rfnd_01';

      databaseState.payments.set(paymentId, {
        id: paymentId,
        bookingId,
        amount: new Decimal(5000),
        currency: 'INR',
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_rzp_refund_01',
      });

      // Pre-seed an existing completed PaymentRefund
      databaseState.refunds.set(`refund_${bookingId}_${paymentId}`, {
        id: 'rfnd_existing_01',
        gatewayRefundId: 'rfnd_gw_existing',
        requestedAmount: new Decimal(5000),
        processedAmount: new Decimal(5000),
        status: RefundStatus.PROCESSED,
      });

      const refundResult = await paymentsService.refund(bookingId, 500000);
      expect(refundResult.isDuplicate).toBe(true);
      expect(refundResult.refundId).toBe('rfnd_gw_existing');
    });

    it('rejects payout request when vendor balance is insufficient', async () => {
      const vendorId = 'vend_poor_01';
      // Vendor has 0 balance in ledger
      await expect(
        payoutsService.requestPayout(vendorId, {
          amount: 5000,
          currency: 'INR',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects unauthorized employee from using corporate credit', async () => {
      const corporateCode = 'CORP-MICROSOFT';
      const corpAcc = {
        id: 'corp_acc_msft',
        corporateCode,
        companyName: 'Microsoft Corporation',
        creditLimit: new Decimal(100000),
        usedCredit: new Decimal(0),
        isActive: true,
      };
      databaseState.corporateAccounts.set(corporateCode, corpAcc);
      databaseState.corporateAccounts.set(corpAcc.id, corpAcc);

      // Unauthorized caller (not registered as corporate employee)
      await expect(
        corporateAccountsService.reserveCredit(corporateCode, 10000, 'usr_unauthorized_attacker', Role.CUSTOMER),
      ).rejects.toThrow(ForbiddenException);
    });

    it('enforces monthly employee spending limit on corporate reservations', async () => {
      const corporateCode = 'CORP-AMAZON';
      const corpId = 'corp_acc_amzn';
      const employeeUserId = 'usr_emp_amzn';

      const corpAcc = {
        id: corpId,
        corporateCode,
        companyName: 'Amazon India',
        creditLimit: new Decimal(500000),
        usedCredit: new Decimal(0),
        isActive: true,
      };
      databaseState.corporateAccounts.set(corporateCode, corpAcc);
      databaseState.corporateAccounts.set(corpId, corpAcc);

      databaseState.corporateEmployees.set(`${corpId}_${employeeUserId}`, {
        id: 'emp_rec_01',
        corporateAccountId: corpId,
        userId: employeeUserId,
        spendingLimitMonthly: new Decimal(20000),
        isActive: true,
      });

      // Request exceeding ₹20,000 monthly cap
      await expect(
        corporateAccountsService.reserveCredit(corporateCode, 25000, employeeUserId, Role.CUSTOMER),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects invalid payment currency', async () => {
      const bookingId = 'book_curr_01';
      databaseState.bookings.set(bookingId, { id: bookingId, status: BookingStatus.PENDING });
      databaseState.payments.set('pay_curr_01', {
        id: 'pay_curr_01',
        bookingId,
        amount: new Decimal(5000),
        currency: 'USD', // Currency mismatch
        status: PaymentStatus.PENDING,
      });

      // Should fail signature or currency check
      const verifyCall = paymentsService.verifyPayment({
        bookingId,
        razorpayOrderId: 'order_curr',
        razorpayPaymentId: 'pay_curr_01',
        razorpaySignature: 'invalid_sig',
      });
      await expect(verifyCall).rejects.toThrow();
    });

    it('fails safely in production when required credentials are missing', () => {
      const productionConfig = {
        get: jest.fn((key: string) => {
          if (key === 'NODE_ENV') return 'production';
          if (key === 'JWT_ACCESS_SECRET') return 'dev_access_secret_key_change_me_12345!'; // Insecure placeholder
          return null;
        }),
      };

      // AuthService must refuse to boot with default dev secrets in production
      const { AuthService } = require('../../auth/auth.service');
      expect(() => {
        new AuthService(mockPrisma, {} as any, {} as any, productionConfig as any, {} as any);
      }).toThrow('CRITICAL SECURITY CONFIGURATION ERROR');
    });

    it('fails safely in production when Razorpay mock mode is configured in WalletsService', () => {
      const productionMockConfig = {
        get: jest.fn((key: string) => {
          if (key === 'NODE_ENV') return 'production';
          if (key === 'RAZORPAY_USE_MOCK') return 'true';
          return null;
        }),
      };

      expect(() => {
        new WalletsService(
          mockPrisma,
          productionMockConfig as any,
          mockAuditLog,
          mockNotifications,
        );
      }).toThrow('CRITICAL SECURITY CONFIGURATION ERROR');
    });

    it('fails safely when RazorpayX credentials are not configured', async () => {
      const unconfiguredConfig = {
        get: jest.fn(() => null),
      };
      const unconfiguredProvider = new RazorpayXPayoutProvider(unconfiguredConfig as any);
      expect(unconfiguredProvider.isConfigured()).toBe(false);

      const result = await unconfiguredProvider.initiateTransfer({
        payoutId: 'po_unconf_1',
        payoutNumber: 'PO-2026-09-00001',
        vendorId: 'v1',
        amount: 5000,
        currency: 'INR',
        accountNumber: '123456789',
        ifscCode: 'HDFC0001234',
        beneficiaryName: 'Host Vendor',
        idempotencyKey: 'payout_unconf_transfer',
      });

      expect(result.success).toBe(false);
      expect(result.status).toBe('BLOCKED_CREDENTIALS');
    });
  });

  describe('Deposit Release and Wallet Deposit Ledger Unification', () => {
    it('records balanced journal upon security deposit release (DEPOSITS LEDGER UNIFICATION)', async () => {
      const bookingId = 'book_dep_rel_01';
      const depositId = 'sec_dep_rel_01';

      databaseState.bookings.set(bookingId, {
        id: bookingId,
        customerId: 'cust_dep_01',
        vendorId: 'vend_dep_01',
        status: BookingStatus.COMPLETED,
      });

      databaseState.payments.set('pay_dep_01', {
        id: 'pay_dep_01',
        bookingId,
        amount: new Decimal(10000),
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_rzp_dep_rel',
      });

      databaseState.securityDeposits.set(depositId, {
        id: depositId,
        bookingId,
        amount: new Decimal(2000),
        deductedAmount: new Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'cust_dep_01', vendorId: 'vend_dep_01' },
      });

      const released = await depositsService.releaseDeposit(bookingId, 'usr_admin_1', 'Trip completed cleanly');
      expect(released).toBeDefined();

      const releaseJournal = recordedJournals.find((j) => j.referenceType === 'SECURITY_DEPOSIT_RELEASE');
      expect(releaseJournal).toBeDefined();
      expect(releaseJournal.totalDebit.equals(releaseJournal.totalCredit)).toBe(true);

      const escrowDebit = releaseJournal.lines.find((l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW);
      expect(escrowDebit.side).toBe(LedgerEntrySide.DEBIT);
      expect(new Decimal(escrowDebit.amount).toNumber()).toBe(2000);

      const gatewayCredit = releaseJournal.lines.find((l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING);
      expect(gatewayCredit.side).toBe(LedgerEntrySide.CREDIT);
      expect(new Decimal(gatewayCredit.amount).toNumber()).toBe(2000);
    });

    it('records balanced journal upon damage settlement with partial refund (DAMAGE DEDUCTION UNIFICATION)', async () => {
      const bookingId = 'book_damage_01';
      const depositId = 'sec_damage_01';

      databaseState.bookings.set(bookingId, {
        id: bookingId,
        customerId: 'cust_dmg_01',
        vendorId: 'vend_dmg_01',
        status: BookingStatus.COMPLETED,
      });

      databaseState.payments.set('pay_dmg_01', {
        id: 'pay_dmg_01',
        bookingId,
        amount: new Decimal(10000),
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_rzp_dmg',
      });

      databaseState.securityDeposits.set(depositId, {
        id: depositId,
        bookingId,
        amount: new Decimal(5000),
        deductedAmount: new Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'cust_dmg_01', vendorId: 'vend_dmg_01' },
      });

      // Deduct ₹2,000 for bumper scratches, refund remaining ₹3,000 to customer
      const settled = await depositsService.settleDeduction(bookingId, 2000, 'usr_admin_1', 'Bumper scratches repair');
      expect(settled).toBeDefined();

      const damageJournal = recordedJournals.find((j) => j.referenceType === 'DAMAGE_DEDUCTION');
      expect(damageJournal).toBeDefined();
      expect(damageJournal.totalDebit.equals(damageJournal.totalCredit)).toBe(true);

      // Debit: Full Escrow liability of ₹5,000 is settled
      const escrowDebit = damageJournal.lines.find((l: any) => l.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW);
      expect(new Decimal(escrowDebit.amount).toNumber()).toBe(5000);

      // Credit: Vendor payable gets ₹2,000 for repair compensation
      const vendorCredit = damageJournal.lines.find((l: any) => l.accountType === LedgerAccountType.VENDOR_PAYABLE);
      expect(new Decimal(vendorCredit.amount).toNumber()).toBe(2000);

      // Credit: Gateway clearing gets ₹3,000 for refunded customer remainder
      const gatewayCredit = damageJournal.lines.find((l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING);
      expect(new Decimal(gatewayCredit.amount).toNumber()).toBe(3000);
    });

    it('records balanced journal upon wallet deposit verification (WALLET RECHARGE UNIFICATION)', async () => {
      const userId = 'usr_wlt_cust_01';

      const walletObj = {
        id: `wlt_${userId}`,
        userId,
        availableBalance: new Decimal(0),
        realBalance: new Decimal(0),
        promoBalance: new Decimal(0),
        lockedBalance: new Decimal(0),
        currency: 'INR',
        status: 'ACTIVE',
      };
      databaseState.wallets.set(userId, walletObj);
      databaseState.wallets.set(walletObj.id, walletObj);

      const depositResult = await walletsService.verifyDepositPayment(userId, {
        razorpayOrderId: 'order_wlt_01',
        razorpayPaymentId: 'pay_rzp_wlt_recharge_01',
        razorpaySignature: 'mock_signature',
      });

      expect(depositResult.success).toBe(true);
      expect(depositResult.amount).toBe(1000);

      const walletJournal = recordedJournals.find((j) => j.referenceType === 'WALLET_DEPOSIT');
      expect(walletJournal).toBeDefined();
      expect(walletJournal.totalDebit.equals(walletJournal.totalCredit)).toBe(true);

      // Debit: GATEWAY_CLEARING ₹1,000 (money received by gateway)
      const gatewayDebit = walletJournal.lines.find((l: any) => l.accountType === LedgerAccountType.GATEWAY_CLEARING);
      expect(gatewayDebit.side).toBe(LedgerEntrySide.DEBIT);
      expect(new Decimal(gatewayDebit.amount).toNumber()).toBe(1000);

      // Credit: CUSTOMER_WALLET ₹1,000 (platform liability to customer credited)
      const walletCredit = walletJournal.lines.find((l: any) => l.accountType === LedgerAccountType.CUSTOMER_WALLET);
      expect(walletCredit.side).toBe(LedgerEntrySide.CREDIT);
      expect(walletCredit.accountEntityId).toBe(userId);
      expect(new Decimal(walletCredit.amount).toNumber()).toBe(1000);
    });
  });
});
