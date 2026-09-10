import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerCoreService } from '../ledger-core.service';
import { UnbalancedJournalException } from '../exceptions/unbalanced-journal.exception';
import { LedgerAccountType, LedgerEntrySide } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase P: Enterprise Double-Entry General Ledger (LedgerCore)', () => {
  let ledgerService: LedgerCoreService;
  let mockPrisma: any;
  let ledgerStore: any[] = [];

  beforeEach(async () => {
    ledgerStore = [];

    mockPrisma = {
      platformLedgerEntry: {
        findFirst: jest.fn().mockImplementation(async ({ where }) => {
          if (where.idempotencyKey) {
            return ledgerStore.find((e) => e.idempotencyKey === where.idempotencyKey) || null;
          }
          return null;
        }),
        findMany: jest.fn().mockImplementation(async ({ where }) => {
          let results = [...ledgerStore];
          if (where?.journalId) {
            results = results.filter((e) => e.journalId === where.journalId);
          }
          if (where?.accountType) {
            results = results.filter((e) => e.accountType === where.accountType);
          }
          if (where?.entrySide) {
            results = results.filter((e) => e.entrySide === where.entrySide);
          }
          if (where?.vendorId) {
            results = results.filter((e) => e.vendorId === where.vendorId);
          }
          return results;
        }),
        create: jest.fn().mockImplementation(async ({ data }) => {
          const entry = {
            id: `entry_${Date.now()}_${Math.random()}`,
            postedAt: new Date(),
            createdAt: new Date(),
            ...data,
          };
          ledgerStore.push(entry);
          return entry;
        }),
        aggregate: jest.fn().mockImplementation(async ({ where }) => {
          let matched = [...ledgerStore];
          if (where?.accountType) {
            matched = matched.filter((e) => e.accountType === where.accountType);
          }
          if (where?.entrySide) {
            matched = matched.filter((e) => e.entrySide === where.entrySide);
          }
          if (where?.vendorId) {
            matched = matched.filter((e) => e.vendorId === where.vendorId);
          }
          const sum = matched.reduce((acc, curr) => acc.add(new Decimal(curr.amount)), new Decimal(0));
          return { _sum: { amount: sum } };
        }),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        if (typeof callback === 'function') {
          return callback(mockPrisma);
        }
        return Promise.all(callback);
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LedgerCoreService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    ledgerService = module.get<LedgerCoreService>(LedgerCoreService);
  });

  describe('Mathematical Invariant Enforcement: SUM(Debits) === SUM(Credits)', () => {
    it('should accept and persist a perfectly balanced journal entry', async () => {
      const journalInput = {
        referenceType: 'CHECKOUT',
        referenceId: 'order_123',
        narration: 'Customer rental payment clearing and vendor allocation',
        idempotencyKey: 'idemp_chk_123',
        lines: [
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.DEBIT,
            amount: 5000,
            narration: 'Receive payment into gateway clearing',
          },
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            accountEntityId: 'vendor_abc',
            side: LedgerEntrySide.CREDIT,
            amount: 4000,
            narration: 'Vendor net payable earnings',
          },
          {
            accountType: LedgerAccountType.PLATFORM_COMMISSION_REVENUE,
            side: LedgerEntrySide.CREDIT,
            amount: 500,
            narration: 'Platform commission fee',
          },
          {
            accountType: LedgerAccountType.TAX_GST_LIABILITY,
            side: LedgerEntrySide.CREDIT,
            amount: 500,
            narration: 'GST tax collected',
          },
        ],
      };

      const result = await ledgerService.recordJournal(journalInput);

      expect(result.journalId).toBeDefined();
      expect(result.entries).toHaveLength(4);
      expect(ledgerStore).toHaveLength(4);
      expect(result.isDuplicate).toBeFalsy();
    });

    it('should strictly reject an unbalanced journal where debits exceed credits', async () => {
      const unbalancedInput = {
        referenceType: 'CHECKOUT',
        referenceId: 'order_unbalanced',
        narration: 'Unbalanced debits exceed credits',
        lines: [
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.DEBIT,
            amount: 5000,
            narration: 'Debit 5000',
          },
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            side: LedgerEntrySide.CREDIT,
            amount: 4000,
            narration: 'Credit 4000 only',
          },
        ],
      };

      await expect(ledgerService.recordJournal(unbalancedInput)).rejects.toThrow(
        UnbalancedJournalException,
      );
      expect(ledgerStore).toHaveLength(0);
    });

    it('should strictly reject an unbalanced journal where credits exceed debits', async () => {
      const unbalancedInput = {
        referenceType: 'ADJUSTMENT',
        referenceId: 'adj_123',
        narration: 'Credits exceed debits',
        lines: [
          {
            accountType: LedgerAccountType.CUSTOMER_WALLET,
            side: LedgerEntrySide.DEBIT,
            amount: 100,
            narration: 'Debit 100',
          },
          {
            accountType: LedgerAccountType.PLATFORM_COMMISSION_REVENUE,
            side: LedgerEntrySide.CREDIT,
            amount: 200,
            narration: 'Credit 200',
          },
        ],
      };

      await expect(ledgerService.recordJournal(unbalancedInput)).rejects.toThrow(
        UnbalancedJournalException,
      );
    });

    it('should reject journal with non-positive line amounts', async () => {
      const invalidInput = {
        referenceType: 'CHECKOUT',
        referenceId: 'order_zero',
        narration: 'Zero amount entry',
        lines: [
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.DEBIT,
            amount: 0,
            narration: 'Debit 0',
          },
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            side: LedgerEntrySide.CREDIT,
            amount: 0,
            narration: 'Credit 0',
          },
        ],
      };

      await expect(ledgerService.recordJournal(invalidInput)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('Idempotency and Immutability Safeguards', () => {
    it('should return existing journal without creating duplicate entries on retry', async () => {
      const journalInput = {
        referenceType: 'CHECKOUT',
        referenceId: 'order_idempotent_test',
        narration: 'Idempotent test journal',
        idempotencyKey: 'idemp_key_unique_999',
        lines: [
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.DEBIT,
            amount: 2000,
            narration: 'Debit 2000',
          },
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            side: LedgerEntrySide.CREDIT,
            amount: 2000,
            narration: 'Credit 2000',
          },
        ],
      };

      const firstCall = await ledgerService.recordJournal(journalInput);
      expect(firstCall.entries).toHaveLength(2);
      expect(ledgerStore).toHaveLength(2);

      const secondCall = await ledgerService.recordJournal(journalInput);
      expect(secondCall.isDuplicate).toBe(true);
      expect(secondCall.journalId).toBe(firstCall.journalId);
      expect(ledgerStore).toHaveLength(2); // No new records added
    });
  });

  describe('Account Balance & Financial Aggregation Calculations', () => {
    beforeEach(async () => {
      // Seed two balanced journals
      await ledgerService.recordJournal({
        referenceType: 'BOOKING_1',
        referenceId: 'b_1',
        narration: 'Booking 1 financial split',
        vendorId: 'vendor_1',
        lines: [
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.DEBIT,
            amount: 10000,
            narration: 'Clearing debit',
          },
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            accountEntityId: 'vendor_1',
            side: LedgerEntrySide.CREDIT,
            amount: 8000,
            narration: 'Vendor 1 payable',
          },
          {
            accountType: LedgerAccountType.PLATFORM_COMMISSION_REVENUE,
            side: LedgerEntrySide.CREDIT,
            amount: 1500,
            narration: 'Commission revenue',
          },
          {
            accountType: LedgerAccountType.TAX_GST_LIABILITY,
            side: LedgerEntrySide.CREDIT,
            amount: 500,
            narration: 'GST liability',
          },
        ],
      });

      await ledgerService.recordJournal({
        referenceType: 'PAYOUT_1',
        referenceId: 'po_1',
        narration: 'Vendor payout execution',
        vendorId: 'vendor_1',
        lines: [
          {
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            accountEntityId: 'vendor_1',
            side: LedgerEntrySide.DEBIT,
            amount: 3000,
            narration: 'Vendor 1 payout debit',
          },
          {
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            side: LedgerEntrySide.CREDIT,
            amount: 3000,
            narration: 'Bank cash out credit',
          },
        ],
      });
    });

    it('should correctly calculate vendor net payable balance (Credits - Debits)', async () => {
      const vendorBalance = await ledgerService.getVendorPayableBalance('vendor_1');
      // 8000 credit - 3000 debit = 5000 net payable
      expect(vendorBalance.toNumber()).toBe(5000);
    });

    it('should correctly calculate cumulative platform commission revenue', async () => {
      const revenue = await ledgerService.getPlatformCommissionRevenue();
      expect(revenue.toNumber()).toBe(1500);
    });

    it('should correctly calculate tax GST liability', async () => {
      const taxLiability = await ledgerService.getTaxLiabilityBalance();
      expect(taxLiability.toNumber()).toBe(500);
    });

    it('should verify total ledger integrity where all posted journals are zero-sum', async () => {
      const audit = await ledgerService.verifyLedgerIntegrity();
      expect(audit.isAudited).toBe(true);
      expect(audit.unbalancedJournals).toHaveLength(0);
      expect(audit.totalJournals).toBe(2);
      expect(audit.balancedJournals).toBe(2);
    });
  });
});
