import { CorporateAccountsService } from '../corporate-accounts.service';
import { Prisma, Role } from '@prisma/client';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('Phase Q: Corporate Credit Pessimistic Locking & Concurrency Protection (HIGH-Q-01)', () => {
  let service: CorporateAccountsService;
  let mockPrisma: any;

  beforeEach(() => {
    mockPrisma = {
      corporateAccount: {
        findUnique: jest.fn(),
        update: jest.fn().mockImplementation((args) => {
          return Promise.resolve({
            id: 'corp_acc_01',
            companyName: 'Acme Corp',
            corporateCode: 'ACME',
            creditLimit: new Prisma.Decimal(100000),
            usedCredit: args.data.usedCredit.increment
              ? new Prisma.Decimal(80000).add(args.data.usedCredit.increment)
              : new Prisma.Decimal(80000).sub(args.data.usedCredit.decrement || 0),
          });
        }),
      },
      corporateEmployee: {
        findUnique: jest.fn(),
      },
      corporateCreditLedgerEntry: {
        create: jest.fn().mockResolvedValue({ id: 'cc_entry_01' }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(0) } }),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([{ id: 'corp_acc_01' }]),
    };

    service = new CorporateAccountsService(mockPrisma);
  });

  it('acquires pessimistic row lock (SELECT ... FOR UPDATE) and succeeds when sufficient credit is available', async () => {
    const mockAccount = {
      id: 'corp_acc_01',
      companyName: 'Acme Corp',
      corporateCode: 'ACME',
      isActive: true,
      creditLimit: new Prisma.Decimal(100000),
      usedCredit: new Prisma.Decimal(80000), // Available: 20,000
    };

    mockPrisma.corporateAccount.findUnique.mockResolvedValue(mockAccount);

    const result = await service.reserveCredit(
      'ACME',
      15000, // 15,000 <= 20,000 -> Should succeed
      'emp_usr_01',
      'booking_q_01',
      Role.ADMIN,
    );

    // Verify row lock was acquired
    expect(mockPrisma.$queryRaw).toHaveBeenCalled();

    // Verify account updated
    expect(mockPrisma.corporateAccount.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'corp_acc_01' },
        data: { usedCredit: { increment: new Prisma.Decimal(15000) } },
      }),
    );

    // Verify ledger entry created
    expect(mockPrisma.corporateCreditLedgerEntry.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          corporateAccountId: 'corp_acc_01',
          type: 'CREDIT_RESERVATION',
          amount: new Prisma.Decimal(15000),
        }),
      }),
    );

    expect(result).toBeDefined();
  });

  it('rejects concurrent reservation under lock when credit limit would be exceeded', async () => {
    const mockAccount = {
      id: 'corp_acc_01',
      companyName: 'Acme Corp',
      corporateCode: 'ACME',
      isActive: true,
      creditLimit: new Prisma.Decimal(100000),
      usedCredit: new Prisma.Decimal(95000), // Available: 5,000
    };

    mockPrisma.corporateAccount.findUnique.mockResolvedValue(mockAccount);

    // Requesting 10,000 when only 5,000 available must be rejected
    await expect(
      service.reserveCredit(
        'ACME',
        10000,
        'emp_usr_01',
        'booking_q_02',
        Role.ADMIN,
      ),
    ).rejects.toThrow(BadRequestException);

    // Update must NOT have been called
    expect(mockPrisma.corporateAccount.update).not.toHaveBeenCalled();
    expect(mockPrisma.corporateCreditLedgerEntry.create).not.toHaveBeenCalled();
  });

  it('enforces employee monthly spending limit under row lock', async () => {
    const mockAccount = {
      id: 'corp_acc_01',
      companyName: 'Acme Corp',
      corporateCode: 'ACME',
      isActive: true,
      creditLimit: new Prisma.Decimal(500000),
      usedCredit: new Prisma.Decimal(50000), // Company has plenty
    };

    const mockEmployee = {
      id: 'emp_01',
      corporateAccountId: 'corp_acc_01',
      userId: 'usr_emp_01',
      isActive: true,
      spendingLimitMonthly: new Prisma.Decimal(25000), // Employee capped at 25k
    };

    mockPrisma.corporateAccount.findUnique.mockResolvedValue(mockAccount);
    mockPrisma.corporateEmployee.findUnique.mockResolvedValue(mockEmployee);
    mockPrisma.corporateCreditLedgerEntry.aggregate.mockResolvedValue({
      _sum: { amount: new Prisma.Decimal(20000) }, // Already spent 20k this month
    });

    // Requesting 10,000 -> 20,000 + 10,000 = 30,000 > 25,000 cap -> Rejected
    await expect(
      service.reserveCredit(
        'ACME',
        10000,
        'usr_emp_01',
        Role.CUSTOMER,
        'booking_q_03',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  it('acquires row lock when releasing credit', async () => {
    const mockAccount = {
      id: 'corp_acc_01',
      companyName: 'Acme Corp',
      corporateCode: 'ACME',
      creditLimit: new Prisma.Decimal(100000),
      usedCredit: new Prisma.Decimal(50000),
    };

    mockPrisma.corporateAccount.findUnique.mockResolvedValue(mockAccount);

    await service.releaseCredit('ACME', 10000, 'admin_01', 'booking_q_cancel');

    expect(mockPrisma.$queryRaw).toHaveBeenCalled();
    expect(mockPrisma.corporateAccount.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'corp_acc_01' },
        data: { usedCredit: { decrement: new Prisma.Decimal(10000) } },
      }),
    );
  });
});
