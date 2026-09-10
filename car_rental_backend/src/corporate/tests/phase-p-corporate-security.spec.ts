import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CorporateAccountsService } from '../corporate-accounts.service';
import { Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase P: Corporate Credit Security, Employee Hierarchy & Audit Ledger', () => {
  let corporateService: CorporateAccountsService;
  let mockPrisma: any;

  let accountsStore: any[] = [];
  let employeesStore: any[] = [];
  let creditLedgerStore: any[] = [];

  beforeEach(async () => {
    accountsStore = [
      {
        id: 'corp_alpha',
        companyName: 'Alpha Corp',
        corporateCode: 'CORP_ALPHA',
        creditLimit: new Decimal(100000),
        usedCredit: new Decimal(20000),
        isActive: true,
      },
      {
        id: 'corp_inactive',
        companyName: 'Inactive Corp',
        corporateCode: 'CORP_INACTIVE',
        creditLimit: new Decimal(50000),
        usedCredit: new Decimal(0),
        isActive: false,
      },
    ];

    employeesStore = [
      {
        id: 'emp_1',
        corporateAccountId: 'corp_alpha',
        userId: 'user_active_employee',
        isActive: true,
        spendingLimitMonthly: new Decimal(50000),
        spentThisMonth: new Decimal(10000),
      },
      {
        id: 'emp_2',
        corporateAccountId: 'corp_alpha',
        userId: 'user_inactive_employee',
        isActive: false,
        spendingLimitMonthly: new Decimal(50000),
        spentThisMonth: new Decimal(0),
      },
      {
        id: 'emp_3',
        corporateAccountId: 'corp_alpha',
        userId: 'user_low_limit_employee',
        isActive: true,
        spendingLimitMonthly: new Decimal(5000),
        spentThisMonth: new Decimal(4000),
      },
    ];

    creditLedgerStore = [];

    mockPrisma = {
      corporateAccount: {
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          if (where.id) return accountsStore.find((a) => a.id === where.id) || null;
          if (where.corporateCode) return accountsStore.find((a) => a.corporateCode === where.corporateCode) || null;
          return null;
        }),
        findMany: jest.fn().mockImplementation(async () => accountsStore),
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          const acc = accountsStore.find((a) => a.id === where.id);
          if (acc) {
            if (data.usedCredit?.increment) {
              acc.usedCredit = acc.usedCredit.add(new Decimal(data.usedCredit.increment));
            } else if (data.usedCredit?.decrement) {
              acc.usedCredit = acc.usedCredit.sub(new Decimal(data.usedCredit.decrement));
            } else if (data.usedCredit !== undefined) {
              acc.usedCredit = new Decimal(data.usedCredit);
            }
          }
          return acc;
        }),
      },
      corporateEmployee: {
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          if (where?.corporateAccountId_userId) {
            const { corporateAccountId, userId } = where.corporateAccountId_userId;
            return employeesStore.find(
              (e) => e.corporateAccountId === corporateAccountId && e.userId === userId,
            ) || null;
          }
          if (where?.id) return employeesStore.find((e) => e.id === where.id) || null;
          return null;
        }),
        findFirst: jest.fn().mockImplementation(async ({ where }) => {
          return employeesStore.find(
            (e) => e.corporateAccountId === where.corporateAccountId && e.userId === where.userId,
          ) || null;
        }),
        findMany: jest.fn().mockImplementation(async ({ where }) => {
          return employeesStore.filter((e) => e.corporateAccountId === where.corporateAccountId);
        }),
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          const emp = employeesStore.find((e) => e.id === where.id);
          if (emp) {
            if (data.spentThisMonth?.increment) {
              emp.spentThisMonth = emp.spentThisMonth.add(new Decimal(data.spentThisMonth.increment));
            } else if (data.spentThisMonth?.decrement) {
              emp.spentThisMonth = emp.spentThisMonth.sub(new Decimal(data.spentThisMonth.decrement));
            }
          }
          return emp;
        }),
      },
      corporateCreditLedgerEntry: {
        create: jest.fn().mockImplementation(async ({ data }) => {
          const entry = { id: `cledger_${Date.now()}`, createdAt: new Date(), ...data };
          creditLedgerStore.push(entry);
          return entry;
        }),
        findMany: jest.fn().mockImplementation(async ({ where }) => {
          return creditLedgerStore.filter((e) => e.corporateAccountId === where.corporateAccountId);
        }),
        aggregate: jest.fn().mockImplementation(async ({ where }) => {
          const entries = creditLedgerStore.filter((e) => {
            if (where?.corporateAccountId && e.corporateAccountId !== where.corporateAccountId) return false;
            if (where?.userId && e.userId !== where.userId) return false;
            if (where?.type && e.type !== where.type) return false;
            return true;
          });
          let sum = new Decimal(0);
          if (where?.userId === 'user_low_limit_employee') {
            sum = sum.add(new Decimal(4000));
          }
          for (const e of entries) {
            sum = sum.add(new Decimal(e.amount));
          }
          return {
            _sum: {
              amount: sum,
            },
          };
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
        CorporateAccountsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    corporateService = module.get<CorporateAccountsService>(CorporateAccountsService);
  });

  describe('IDOR Protection & Employee Association Enforcement', () => {
    it('should allow an active affiliated employee to validate and reserve corporate credit', async () => {
      const reservation = await corporateService.reserveCredit(
        'CORP_ALPHA',
        15000,
        'user_active_employee',
        Role.CUSTOMER,
        'ref_booking_101',
      );

      expect(reservation.id).toBe('corp_alpha');
      expect(reservation.usedCredit.toNumber()).toBe(35000); // 20000 + 15000
      expect(creditLedgerStore).toHaveLength(1);
      expect(creditLedgerStore[0].type).toBe('CREDIT_RESERVATION');
      expect(creditLedgerStore[0].amount.toNumber()).toBe(15000);
    });

    it('should strictly reject an unauthorized customer attempting to consume corporate credit via code alone (IDOR blocked)', async () => {
      await expect(
        corporateService.reserveCredit(
          'CORP_ALPHA',
          5000,
          'user_unrelated_stranger',
          Role.CUSTOMER,
        ),
      ).rejects.toThrow(ForbiddenException);

      // Verify no credit was deducted
      const account = accountsStore.find((a) => a.id === 'corp_alpha');
      expect(account.usedCredit.toNumber()).toBe(20000);
      expect(creditLedgerStore).toHaveLength(0);
    });

    it('should reject an inactive or de-authorized corporate employee', async () => {
      await expect(
        corporateService.reserveCredit(
          'CORP_ALPHA',
          5000,
          'user_inactive_employee',
          Role.CUSTOMER,
        ),
      ).rejects.toThrow(ForbiddenException);

      expect(creditLedgerStore).toHaveLength(0);
    });

    it('should reject credit reservation for an inactive corporate account', async () => {
      await expect(
        corporateService.reserveCredit(
          'CORP_INACTIVE',
          5000,
          'user_active_employee',
          Role.CUSTOMER,
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Credit Limits and Monthly Spending Caps', () => {
    it('should prevent reservation when corporate credit limit is exceeded', async () => {
      // Available: 100000 - 20000 = 80000
      // Attempting: 85000
      await expect(
        corporateService.reserveCredit(
          'CORP_ALPHA',
          85000,
          'user_active_employee',
          Role.CUSTOMER,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should prevent reservation when employee monthly spending limit is exceeded', async () => {
      // emp_3 has spendingLimitMonthly: 5000, spentThisMonth: 4000
      // Attempting: 1500 (total would be 5500 > 5000)
      await expect(
        corporateService.reserveCredit(
          'CORP_ALPHA',
          1500,
          'user_low_limit_employee',
          Role.CUSTOMER,
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Credit Release & Final Settlement Auditability', () => {
    it('should restore available credit upon cancellation/release and write credit ledger entry', async () => {
      // First reserve
      await corporateService.reserveCredit(
        'CORP_ALPHA',
        10000,
        'user_active_employee',
        Role.CUSTOMER,
        'ref_b_202',
      );
      expect(accountsStore[0].usedCredit.toNumber()).toBe(30000);

      // Now release
      const release = await corporateService.releaseCredit(
        'CORP_ALPHA',
        10000,
        'user_active_employee',
        'ref_b_202',
      );

      expect(release.id).toBe('corp_alpha');
      expect(accountsStore[0].usedCredit.toNumber()).toBe(20000);

      // Check credit ledger audit records
      expect(creditLedgerStore).toHaveLength(2);
      expect(creditLedgerStore[1].type).toBe('CREDIT_RELEASE');
      expect(creditLedgerStore[1].amount.toNumber()).toBe(10000);
      expect(creditLedgerStore[1].balanceAfter.toNumber()).toBe(80000); // 100000 - 20000
    });

    it('should record final settlement in credit ledger upon trip completion', async () => {
      const settlement = await corporateService.settleCredit(
        'CORP_ALPHA',
        10000,
        'user_active_employee',
        'booking_303',
      );

      expect(settlement.id).toBe('corp_alpha');
      expect(creditLedgerStore).toHaveLength(1);
      expect(creditLedgerStore[0].type).toBe('INVOICE_SETTLEMENT');
    });
  });
});
