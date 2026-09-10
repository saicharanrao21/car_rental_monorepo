import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, Role } from '@prisma/client';
import {
  CreateCorporateAccountDto,
  UpdateCorporateAccountDto,
  ValidateCorporateCreditDto,
  AddCorporateEmployeeDto,
} from './dto/corporate-account.dto';
import * as crypto from 'crypto';

@Injectable()
export class CorporateAccountsService {
  private readonly logger = new Logger(CorporateAccountsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * 1. CREATE CORPORATE ACCOUNT:
   * Sets up a new B2B client profile with credit limits and negotiated discount terms.
   */
  async createAccount(dto: CreateCorporateAccountDto) {
    const existing = await this.prisma.corporateAccount.findUnique({
      where: { corporateCode: dto.corporateCode.toUpperCase() },
    });

    if (existing) {
      throw new ConflictException(
        `Corporate account with code ${dto.corporateCode} already exists.`,
      );
    }

    return this.prisma.corporateAccount.create({
      data: {
        companyName: dto.companyName,
        corporateCode: dto.corporateCode.toUpperCase(),
        contactEmail: dto.contactEmail,
        contactPhone: dto.contactPhone,
        taxIdNumber: dto.taxIdNumber,
        billingAddress: dto.billingAddress,
        creditLimit: new Prisma.Decimal(dto.creditLimit ?? 50000),
        usedCredit: new Prisma.Decimal(0),
        negotiatedDiscountPct: new Prisma.Decimal(dto.negotiatedDiscountPct ?? 10.0),
        paymentTermsDays: dto.paymentTermsDays ?? 30,
        preferredVendorId: dto.preferredVendorId,
        metadata: dto.metadata || {},
      },
    });
  }

  /**
   * 2. GET ACCOUNT BY ID:
   */
  async getAccountById(id: string) {
    const account = await this.prisma.corporateAccount.findUnique({
      where: { id },
      include: {
        preferredVendor: {
          select: { id: true, businessName: true, city: true },
        },
        _count: {
          select: { employees: true, bookings: true },
        },
      },
    });

    if (!account) {
      throw new NotFoundException(`Corporate account with ID ${id} not found.`);
    }

    return account;
  }

  /**
   * 3. GET ACCOUNT BY CODE:
   */
  async getAccountByCode(code: string) {
    const account = await this.prisma.corporateAccount.findUnique({
      where: { corporateCode: code.toUpperCase() },
    });

    if (!account) {
      throw new NotFoundException(`Corporate account with code ${code} not found.`);
    }

    return account;
  }

  /**
   * 4. LIST CORPORATE ACCOUNTS (Filterable & Searchable with Pagination):
   */
  async listAccounts(params: {
    isActive?: boolean;
    query?: string;
    page?: number;
    limit?: number;
  }) {
    const page = params.page ?? 1;
    const limit = params.limit ?? 50;
    const skip = (page - 1) * limit;

    const where: Prisma.CorporateAccountWhereInput = {
      ...(params.isActive !== undefined ? { isActive: params.isActive } : {}),
      ...(params.query
        ? {
            OR: [
              { companyName: { contains: params.query, mode: 'insensitive' } },
              { corporateCode: { contains: params.query, mode: 'insensitive' } },
              { contactEmail: { contains: params.query, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [accounts, total] = await Promise.all([
      this.prisma.corporateAccount.findMany({
        where,
        skip,
        take: limit,
        orderBy: { companyName: 'asc' },
        include: {
          _count: { select: { employees: true, bookings: true } },
        },
      }),
      this.prisma.corporateAccount.count({ where }),
    ]);

    return {
      data: accounts,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 5. UPDATE CORPORATE ACCOUNT:
   */
  async updateAccount(id: string, dto: UpdateCorporateAccountDto) {
    await this.getAccountById(id);

    return this.prisma.corporateAccount.update({
      where: { id },
      data: {
        ...(dto.companyName ? { companyName: dto.companyName } : {}),
        ...(dto.contactEmail ? { contactEmail: dto.contactEmail } : {}),
        ...(dto.contactPhone ? { contactPhone: dto.contactPhone } : {}),
        ...(dto.taxIdNumber !== undefined ? { taxIdNumber: dto.taxIdNumber } : {}),
        ...(dto.billingAddress ? { billingAddress: dto.billingAddress } : {}),
        ...(dto.creditLimit !== undefined ? { creditLimit: new Prisma.Decimal(dto.creditLimit) } : {}),
        ...(dto.negotiatedDiscountPct !== undefined
          ? { negotiatedDiscountPct: new Prisma.Decimal(dto.negotiatedDiscountPct) }
          : {}),
        ...(dto.paymentTermsDays !== undefined ? { paymentTermsDays: dto.paymentTermsDays } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.preferredVendorId !== undefined ? { preferredVendorId: dto.preferredVendorId } : {}),
        ...(dto.metadata !== undefined ? { metadata: dto.metadata } : {}),
      },
    });
  }

  /**
   * 6. VALIDATE CREDIT LIMIT (With Tenant Authorization & Employee Domain Guard):
   */
  async validateCredit(
    dto: ValidateCorporateCreditDto,
    callerUserId?: string,
    callerRole?: Role,
  ) {
    const account = await this.getAccountByCode(dto.corporateCode);

    if (!account.isActive) {
      throw new BadRequestException(`Corporate account ${dto.corporateCode} is inactive.`);
    }

    let employeeRecord: any = null;
    if (callerRole === Role.CUSTOMER) {
      if (!callerUserId) {
        throw new ForbiddenException(
          'Corporate authentication required. Please sign in as an authorized employee.',
        );
      }
      employeeRecord = await this.prisma.corporateEmployee.findUnique({
        where: {
          corporateAccountId_userId: {
            corporateAccountId: account.id,
            userId: callerUserId,
          },
        },
      });

      if (!employeeRecord || !employeeRecord.isActive) {
        throw new ForbiddenException(
          `Unauthorized: User is not an active authorized employee of corporate account ${account.corporateCode} (${account.companyName}).`,
        );
      }
    }

    const availableCredit = account.creditLimit.sub(account.usedCredit);
    const required = new Prisma.Decimal(dto.estimatedAmount);

    const eligible = availableCredit.gte(required);

    return {
      eligible,
      corporateCode: account.corporateCode,
      companyName: account.companyName,
      creditLimit: account.creditLimit.toNumber(),
      usedCredit: account.usedCredit.toNumber(),
      availableCredit: availableCredit.toNumber(),
      negotiatedDiscountPct: account.negotiatedDiscountPct.toNumber(),
      employeeCode: employeeRecord?.employeeCode || null,
      reason: eligible
        ? 'Credit line approved for reservation.'
        : `Credit limit exceeded. Available: ₹${availableCredit.toNumber()}, Required: ₹${dto.estimatedAmount}`,
    };
  }

  /**
   * 7. ATOMIC CREDIT RESERVATION (With Overdraft Prevention & Tenant Employee Guard):
   */
  async reserveCredit(
    corporateCode: string,
    amount: number,
    callerUserId?: string,
    callerRole?: Role,
    bookingId?: string,
    tx?: Prisma.TransactionClient,
  ) {
    if (amount <= 0) {
      throw new BadRequestException('Reservation amount must be strictly positive.');
    }

    const execute = async (prismaTx: Prisma.TransactionClient) => {
      const account = await prismaTx.corporateAccount.findUnique({
        where: { corporateCode: corporateCode.toUpperCase() },
      });

      if (!account) {
        throw new NotFoundException(
          `Corporate account with code ${corporateCode} not found.`,
        );
      }

      if (!account.isActive) {
        throw new BadRequestException(
          `Corporate account ${corporateCode} is inactive.`,
        );
      }

      // Security Check: Customer must be an active corporate employee
      if (callerRole === Role.CUSTOMER) {
        if (!callerUserId) {
          throw new ForbiddenException('Corporate authentication required.');
        }
        const employee = await prismaTx.corporateEmployee.findUnique({
          where: {
            corporateAccountId_userId: {
              corporateAccountId: account.id,
              userId: callerUserId,
            },
          },
        });

        if (!employee || !employee.isActive) {
          throw new ForbiddenException(
            `Unauthorized: Caller is not an active authorized employee of corporate account ${account.corporateCode}.`,
          );
        }

        if (employee.spendingLimitMonthly && employee.spendingLimitMonthly.gt(0)) {
          const startOfMonth = new Date();
          startOfMonth.setDate(1);
          startOfMonth.setHours(0, 0, 0, 0);

          const monthlySpent = await prismaTx.corporateCreditLedgerEntry.aggregate({
            where: {
              corporateAccountId: account.id,
              userId: callerUserId,
              type: 'CREDIT_RESERVATION',
              createdAt: { gte: startOfMonth },
            },
            _sum: { amount: true },
          });

          const currentTotal = monthlySpent._sum.amount || new Prisma.Decimal(0);
          if (currentTotal.add(new Prisma.Decimal(amount)).gt(employee.spendingLimitMonthly)) {
            throw new BadRequestException(
              `Corporate monthly employee spending limit exceeded. Cap: ₹${employee.spendingLimitMonthly.toNumber()}, Used: ₹${currentTotal.toNumber()}`,
            );
          }
        }
      }

      const availableCredit = account.creditLimit.sub(account.usedCredit);
      const required = new Prisma.Decimal(amount);

      if (availableCredit.lt(required)) {
        throw new BadRequestException(
          `Insufficient corporate credit. Available: ₹${availableCredit.toNumber()}, Required: ₹${amount}`,
        );
      }

      const updated = await prismaTx.corporateAccount.update({
        where: { id: account.id },
        data: {
          usedCredit: { increment: required },
        },
      });

      const balanceAfter = updated.creditLimit.sub(updated.usedCredit);

      // Record in CorporateCreditLedgerEntry
      await prismaTx.corporateCreditLedgerEntry.create({
        data: {
          corporateAccountId: account.id,
          userId: callerUserId || 'SYSTEM',
          bookingId: bookingId || null,
          type: 'CREDIT_RESERVATION',
          amount: required,
          balanceAfter,
          referenceKey: `cc_res_${account.id}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
          notes: `Credit reserved for ${bookingId ? `booking ${bookingId}` : 'checkout'} by user ${callerUserId || 'admin'}`,
        },
      });

      this.logger.log(
        `[CORPORATE] Reserved ₹${amount} against credit line of ${account.companyName} (${account.corporateCode}). New used: ₹${updated.usedCredit}`,
      );

      return updated;
    };

    if (tx) {
      return execute(tx);
    }
    return this.prisma.$transaction(execute);
  }

  /**
   * 8. RELEASE CORPORATE CREDIT (On Cancellation or Downward Modification):
   */
  async releaseCredit(
    corporateCode: string,
    amount: number,
    callerUserId?: string,
    bookingId?: string,
    tx?: Prisma.TransactionClient,
  ) {
    if (amount <= 0) {
      throw new BadRequestException('Release amount must be strictly positive.');
    }

    const execute = async (prismaTx: Prisma.TransactionClient) => {
      const account = await prismaTx.corporateAccount.findUnique({
        where: { corporateCode: corporateCode.toUpperCase() },
      });

      if (!account) {
        throw new NotFoundException(
          `Corporate account with code ${corporateCode} not found.`,
        );
      }

      const decrementAmount = Prisma.Decimal.min(
        account.usedCredit,
        new Prisma.Decimal(amount),
      );

      const updated = await prismaTx.corporateAccount.update({
        where: { id: account.id },
        data: {
          usedCredit: { decrement: decrementAmount },
        },
      });

      const balanceAfter = updated.creditLimit.sub(updated.usedCredit);

      await prismaTx.corporateCreditLedgerEntry.create({
        data: {
          corporateAccountId: account.id,
          userId: callerUserId || 'SYSTEM',
          bookingId: bookingId || null,
          type: 'CREDIT_RELEASE',
          amount: decrementAmount,
          balanceAfter,
          referenceKey: `cc_rel_${account.id}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
          notes: `Credit released for ${bookingId ? `booking ${bookingId}` : 'cancellation'}`,
        },
      });

      this.logger.log(
        `[CORPORATE] Released ₹${decrementAmount} to credit line of ${account.companyName} (${account.corporateCode}). New used: ₹${updated.usedCredit}`,
      );

      return updated;
    };

    if (tx) {
      return execute(tx);
    }
    return this.prisma.$transaction(execute);
  }

  /**
   * 9. SETTLE CORPORATE CREDIT (Invoice Settlement):
   */
  async settleCredit(
    corporateCode: string,
    amount: number,
    callerUserId?: string,
    bookingIdOrTx?: string | Prisma.TransactionClient,
    tx?: Prisma.TransactionClient,
  ) {
    if (amount <= 0) {
      throw new BadRequestException('Settlement amount must be strictly positive.');
    }

    let bookingId: string | undefined;
    let actualTx: Prisma.TransactionClient | undefined = tx;
    if (typeof bookingIdOrTx === 'string') {
      bookingId = bookingIdOrTx;
    } else if (bookingIdOrTx && typeof bookingIdOrTx === 'object') {
      actualTx = bookingIdOrTx as Prisma.TransactionClient;
    }

    const execute = async (prismaTx: Prisma.TransactionClient) => {
      const account = await prismaTx.corporateAccount.findUnique({
        where: { corporateCode: corporateCode.toUpperCase() },
      });

      if (!account) {
        throw new NotFoundException(
          `Corporate account with code ${corporateCode} not found.`,
        );
      }

      const decrementAmount = Prisma.Decimal.min(
        account.usedCredit,
        new Prisma.Decimal(amount),
      );

      const updated = await prismaTx.corporateAccount.update({
        where: { id: account.id },
        data: {
          usedCredit: { decrement: decrementAmount },
        },
      });

      const balanceAfter = updated.creditLimit.sub(updated.usedCredit);

      await prismaTx.corporateCreditLedgerEntry.create({
        data: {
          corporateAccountId: account.id,
          userId: callerUserId || 'SYSTEM',
          bookingId: bookingId || null,
          type: 'INVOICE_SETTLEMENT',
          amount: decrementAmount,
          balanceAfter,
          referenceKey: `cc_stl_${account.id}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
          notes: `Corporate invoice payment settled${bookingId ? ` for booking ${bookingId}` : ''}`,
        },
      });

      return updated;
    };

    if (actualTx) {
      return execute(actualTx);
    }
    return this.prisma.$transaction(execute);
  }

  /**
   * 10. EMPLOYEE HIERARCHY MANAGEMENT:
   */
  async addEmployee(corporateAccountId: string, dto: AddCorporateEmployeeDto) {
    await this.getAccountById(corporateAccountId);

    const user = await this.prisma.user.findUnique({
      where: { id: dto.userId },
    });
    if (!user) {
      throw new NotFoundException(`User with ID ${dto.userId} not found.`);
    }

    const existing = await this.prisma.corporateEmployee.findUnique({
      where: {
        corporateAccountId_userId: {
          corporateAccountId,
          userId: dto.userId,
        },
      },
    });

    if (existing) {
      throw new ConflictException('User is already registered as an employee of this corporate account.');
    }

    return this.prisma.corporateEmployee.create({
      data: {
        corporateAccountId,
        userId: dto.userId,
        employeeCode: dto.employeeCode,
        department: dto.department,
        spendingLimitMonthly: dto.spendingLimitMonthly
          ? new Prisma.Decimal(dto.spendingLimitMonthly)
          : null,
      },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true } },
      },
    });
  }

  async listEmployees(corporateAccountId: string) {
    await this.getAccountById(corporateAccountId);
    return this.prisma.corporateEmployee.findMany({
      where: { corporateAccountId },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async updateEmployeeStatus(corporateAccountId: string, employeeId: string, isActive: boolean) {
    const employee = await this.prisma.corporateEmployee.findFirst({
      where: { id: employeeId, corporateAccountId },
    });
    if (!employee) {
      throw new NotFoundException('Corporate employee record not found.');
    }

    return this.prisma.corporateEmployee.update({
      where: { id: employeeId },
      data: { isActive },
    });
  }

  async getCreditLedger(corporateAccountId: string, page = 1, limit = 20) {
    await this.getAccountById(corporateAccountId);
    const skip = (page - 1) * limit;

    const [entries, total] = await Promise.all([
      this.prisma.corporateCreditLedgerEntry.findMany({
        where: { corporateAccountId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.corporateCreditLedgerEntry.count({
        where: { corporateAccountId },
      }),
    ]);

    return {
      data: entries,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 11. RECORD CORPORATE BOOKING USAGE:
   */
  async recordUsage(corporateCode: string, amount: number) {
    return this.reserveCredit(corporateCode, amount);
  }
}
