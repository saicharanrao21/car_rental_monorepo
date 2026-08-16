import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, Prisma } from '@prisma/client';

export const DEFAULT_DEPOSIT_AMOUNTS: Record<CarCategory, number> = {
  [CarCategory.HATCHBACK]: 3000,
  [CarCategory.SEDAN]: 4000,
  [CarCategory.SUV]: 5000,
  [CarCategory.LUXURY]: 10000,
  [CarCategory.TEMPO_TRAVELLER]: 8000,
  [CarCategory.MINI_BUS]: 10000,
};

@Injectable()
export class DepositRulesService {
  private readonly logger = new Logger(DepositRulesService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Resolves the authoritative security deposit requirement for a car category and optional city.
   * Priority: City-specific rule > Category global rule > Category default constant.
   */
  async getDepositAmount(
    carCategory: CarCategory,
    city?: string,
  ): Promise<number> {
    try {
      if (city) {
        const cityRule = await this.prisma.depositRule.findFirst({
          where: {
            carCategory,
            city: { equals: city.trim(), mode: 'insensitive' },
            isActive: true,
          },
        });
        if (cityRule) {
          return cityRule.depositAmount.toNumber();
        }
      }

      const globalRule = await this.prisma.depositRule.findFirst({
        where: {
          carCategory,
          city: null,
          isActive: true,
        },
      });

      if (globalRule) {
        return globalRule.depositAmount.toNumber();
      }
    } catch (err: any) {
      this.logger.warn(
        `Failed to fetch dynamic deposit rule: ${err.message}. Falling back to category default.`,
      );
    }

    return DEFAULT_DEPOSIT_AMOUNTS[carCategory] ?? 5000;
  }

  /**
   * Retrieves all configured deposit rules for the Admin Panel.
   */
  async getAllRules() {
    return this.prisma.depositRule.findMany({
      orderBy: [{ city: 'asc' }, { carCategory: 'asc' }],
    });
  }

  /**
   * Upserts a security deposit rule (Admin only).
   */
  async upsertRule(
    carCategory: CarCategory,
    depositAmount: number,
    city?: string,
  ) {
    const normalizedCity = city?.trim() || null;
    const amountDecimal = new Prisma.Decimal(depositAmount);

    const existing = await this.prisma.depositRule.findFirst({
      where: {
        carCategory,
        city: normalizedCity,
      },
    });

    if (existing) {
      return this.prisma.depositRule.update({
        where: { id: existing.id },
        data: {
          depositAmount: amountDecimal,
          isActive: true,
        },
      });
    }

    return this.prisma.depositRule.create({
      data: {
        carCategory,
        city: normalizedCity,
        depositAmount: amountDecimal,
        isActive: true,
      },
    });
  }

  /**
   * Deletes or deactivates a deposit rule (Admin only).
   */
  async deleteRule(id: string) {
    return this.prisma.depositRule.delete({
      where: { id },
    });
  }
}
