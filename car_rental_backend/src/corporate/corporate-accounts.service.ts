import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import {
  CreateCorporateAccountDto,
  UpdateCorporateAccountDto,
  ValidateCorporateCreditDto,
} from './dto/corporate-account.dto';

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
   * 2. GET ACCOUNT BY ID OR CODE:
   */
  async getAccountById(id: string) {
    const account = await this.prisma.corporateAccount.findUnique({
      where: { id },
      include: { preferredVendor: true },
    });
    if (!account) {
      throw new NotFoundException(`Corporate account #${id} not found.`);
    }
    return account;
  }

  async getAccountByCode(corporateCode: string) {
    const account = await this.prisma.corporateAccount.findUnique({
      where: { corporateCode: corporateCode.toUpperCase() },
      include: { preferredVendor: true },
    });
    if (!account) {
      throw new NotFoundException(`Corporate account with code ${corporateCode} not found.`);
    }
    return account;
  }

  /**
   * 3. LIST CORPORATE ACCOUNTS:
   */
  async listAccounts(params?: { isActive?: boolean; query?: string }) {
    return this.prisma.corporateAccount.findMany({
      where: {
        ...(params?.isActive !== undefined ? { isActive: params.isActive } : {}),
        ...(params?.query
          ? {
              OR: [
                { companyName: { contains: params.query, mode: 'insensitive' } },
                { corporateCode: { contains: params.query, mode: 'insensitive' } },
                { contactEmail: { contains: params.query, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: { companyName: 'asc' },
    });
  }

  /**
   * 4. UPDATE CORPORATE ACCOUNT:
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
   * 5. VALIDATE CREDIT LIMIT:
   * Verifies that the corporate account is active and has sufficient uncommitted credit.
   */
  async validateCredit(dto: ValidateCorporateCreditDto) {
    const account = await this.getAccountByCode(dto.corporateCode);

    if (!account.isActive) {
      throw new BadRequestException(`Corporate account ${dto.corporateCode} is inactive.`);
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
      reason: eligible
        ? 'Credit line approved for reservation.'
        : `Credit limit exceeded. Available: ₹${availableCredit.toNumber()}, Required: ₹${dto.estimatedAmount}`,
    };
  }

  /**
   * 6. RECORD CORPORATE BOOKING USAGE:
   * Increments used credit when a corporate billing reservation is created.
   */
  async recordUsage(corporateCode: string, amount: number) {
    const account = await this.getAccountByCode(corporateCode);
    const updated = await this.prisma.corporateAccount.update({
      where: { id: account.id },
      data: {
        usedCredit: { increment: new Prisma.Decimal(amount) },
      },
    });
    this.logger.log(
      `[CORPORATE] Debited ₹${amount} against credit line of ${account.companyName} (${account.corporateCode}). New used: ₹${updated.usedCredit}`,
    );
    return updated;
  }
}
