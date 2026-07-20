import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, TripType, Prisma } from '@prisma/client';

@Injectable()
export class CommissionResolverService {
  constructor(private readonly prisma: PrismaService) {}

  async resolveCommissionPercent(
    city: string,
    carCategory: CarCategory,
    tripType: TripType,
  ): Promise<Prisma.Decimal> {
    // Fetch all rules that could potentially match (either exact or null/wildcard)
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
            OR: [
              { carCategory: null },
              { carCategory },
            ],
          },
          {
            OR: [
              { tripType: null },
              { tripType },
            ],
          },
        ],
      },
    });

    if (rules.length === 0) {
      return new Prisma.Decimal(10.0); // Default to 10%
    }

    // Score rules based on specificity:
    // city match: weight 4
    // carCategory match: weight 2
    // tripType match: weight 1
    const scoredRules = rules.map(rule => {
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
