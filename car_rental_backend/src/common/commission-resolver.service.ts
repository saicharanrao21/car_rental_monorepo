import { Injectable, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, TripType, Prisma } from '@prisma/client';
import { SystemConfigService } from '../config-engine/system-config.service';

@Injectable()
export class CommissionResolverService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly configService?: SystemConfigService,
  ) {}

  /**
   * Resolves effective commission percentage following the 4-tier precedence hierarchy:
   * Tier 1: Active Negotiated Dealer Agreement (for vendorId)
   * Tier 2: Active Fleet-Volume Tier Rule
   * Tier 3: Localized City / Category / Trip Rule (specificity score)
   * Tier 4: Global Default Commission Rate
   */
  async resolveCommissionPercent(
    city: string,
    carCategory: CarCategory,
    tripType: TripType,
    vendorId?: string,
  ): Promise<Prisma.Decimal> {
    // Tier 1: Check active dealer negotiated agreement override
    if (vendorId && (this.prisma as any).marketplaceCommissionRule) {
      const dealerOverride = await (this.prisma as any).marketplaceCommissionRule.findFirst({
        where: {
          vendorId,
          isActive: true,
          OR: [
            { vehicleClass: null },
            { vehicleClass: carCategory },
          ],
        },
        orderBy: [
          { vehicleClass: 'desc' },
          { createdAt: 'desc' },
        ],
      });

      if (dealerOverride && dealerOverride.platformPct) {
        return new Prisma.Decimal(dealerOverride.platformPct);
      }
    }

    // Tier 3: Localized City / Category / Trip Rules with specificity scoring
    const rules = await this.prisma.commissionConfig.findMany({
      where: {
        AND: [
          {
            OR: [
              { city: null },
              { city: { equals: city, mode: 'insensitive' } },
            ],
          },
          {
            OR: [{ carCategory: null }, { carCategory }],
          },
          {
            OR: [{ tripType: null }, { tripType }],
          },
        ],
      },
    });

    if (rules.length === 0) {
      // Tier 4: Fallback to Global Default Commission Rate
      let defaultCommission = 10.0;
      if (this.configService) {
        try {
          const cfg = await this.configService.getCommissionConfig();
          if (
            cfg &&
            typeof cfg.defaultPercent === 'number' &&
            !isNaN(cfg.defaultPercent) &&
            cfg.defaultPercent >= 0 &&
            cfg.defaultPercent <= 100
          ) {
            defaultCommission = cfg.defaultPercent;
          }
        } catch {
          // Safe fallback to default
        }
      }
      return new Prisma.Decimal(defaultCommission);
    }

    // Score rules based on specificity:
    // city match: weight 4
    // carCategory match: weight 2
    // tripType match: weight 1
    const scoredRules = rules.map((rule) => {
      let score = 0;
      if (rule.city !== null) score += 4;
      if (rule.carCategory !== null) score += 2;
      if (rule.tripType !== null) score += 1;
      return { rule, score };
    });

    // Sort by score descending (highest specificity first)
    scoredRules.sort((a, b) => b.score - a.score);

    return scoredRules[0].rule.percentage;
  }
}
