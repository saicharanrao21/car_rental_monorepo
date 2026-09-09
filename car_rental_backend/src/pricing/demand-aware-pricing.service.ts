import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CompetitivePricingService } from './competitive-pricing.service';
import { CarCategory, PricingRuleScope, BookingStatus } from '@prisma/client';

export interface DynamicPricingEvaluationContext {
  vendorId?: string;
  branchId?: string;
  vehicleClass: CarCategory;
  city?: string;
  startDate: Date;
  endDate: Date;
  baseDailyRate: number;
}

export interface DynamicPricingEvaluationResult {
  effectiveDailyRate: number;
  multiplier: number;
  baseDailyRate: number;
  policyBounds: {
    minDailyPrice: number;
    maxDailyPrice: number;
    maxSurgeMultiplier: number;
    minDiscountMultiplier: number;
  };
  factors: {
    utilizationRate: number;
    utilizationMultiplier: number;
    leadTimeDays: number;
    leadTimeMultiplier: number;
    bookingVelocityMultiplier: number;
    competitorIndexMultiplier: number;
  };
  explanation: string;
  isClamped: boolean;
  clampReason?: string;
}

export interface IPricingStrategyModel {
  readonly modelId: string;
  readonly modelVersion: string;
  evaluatePrice(ctx: DynamicPricingEvaluationContext): Promise<DynamicPricingEvaluationResult>;
}

@Injectable()
export class DemandAwarePricingService implements IPricingStrategyModel {
  private readonly logger = new Logger(DemandAwarePricingService.name);
  public readonly modelId = 'DETERMINISTIC_DYNAMIC_PRICING_V1';
  public readonly modelVersion = '1.0.0-enterprise';

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly competitivePricing?: CompetitivePricingService,
  ) {}

  /**
   * Evaluates dynamic pricing factor with strict, auditable policy bounds
   */
  async evaluatePrice(ctx: DynamicPricingEvaluationContext): Promise<DynamicPricingEvaluationResult> {
    const baseDailyRate = ctx.baseDailyRate;

    // 1. Resolve active dynamic pricing policy (Branch -> Vendor -> Platform)
    const policy = await this.resolveActivePolicy(ctx);

    const minPrice = policy ? Number(policy.minDailyPrice) : Math.round(baseDailyRate * 0.70);
    const maxPrice = policy ? Number(policy.maxDailyPrice) : Math.round(baseDailyRate * 2.00);
    const maxSurge = policy ? Number(policy.maxSurgeMultiplier) : 1.50;
    const minDiscount = policy ? Number(policy.minDiscountMultiplier) : 0.80;

    // 2. Factor A: Fleet Utilization Rate for vehicle class
    const utilizationRate = await this.calculateUtilization(ctx);
    let utilMultiplier = 1.0;

    const thresholdHigh = policy?.utilizationThresholdHigh ?? 0.85;
    const thresholdLow = policy?.utilizationThresholdLow ?? 0.30;

    if (utilizationRate >= thresholdHigh) {
      // High scarcity surge (e.g. 90% utilization -> +15%)
      const excess = (utilizationRate - thresholdHigh) / (1 - thresholdHigh);
      utilMultiplier = 1.0 + Math.min(0.35, excess * 0.30 + 0.05);
    } else if (utilizationRate <= thresholdLow) {
      // Low demand discount (e.g. 20% utilization -> -10%)
      const deficit = (thresholdLow - utilizationRate) / thresholdLow;
      utilMultiplier = 1.0 - Math.min(0.20, deficit * 0.15 + 0.05);
    }

    // 3. Factor B: Lead Time (Advance Booking Window Curve)
    const now = new Date();
    const leadTimeMs = ctx.startDate.getTime() - now.getTime();
    const leadTimeDays = Math.max(0, Math.round(leadTimeMs / (24 * 60 * 60 * 1000)));

    let leadTimeMultiplier = 1.0;
    if (leadTimeDays <= 1) {
      // Last-minute booking premium (+5%)
      leadTimeMultiplier = 1.05;
    } else if (leadTimeDays >= 14) {
      // Early bird discount (-5%)
      leadTimeMultiplier = 0.95;
    }

    // 4. Factor C: Booking Velocity (recent reservations in last 24h)
    const bookingVelocityMultiplier = await this.calculateVelocityMultiplier(ctx);

    // 5. Factor D: Competitive Market Signal
    let competitorMultiplier = 1.0;
    if (this.competitivePricing && ctx.city) {
      const marketIndex = await this.competitivePricing.getMarketPriceIndex(ctx.city, ctx.vehicleClass);
      if (marketIndex && marketIndex.medianPrice > 0) {
        const ratio = marketIndex.medianPrice / baseDailyRate;
        if (ratio > 1.20) {
          // Market is significantly pricier; slight upward adjustment (+5%)
          competitorMultiplier = 1.05;
        } else if (ratio < 0.80) {
          // Market is cheaper; slight discount (-5%)
          competitorMultiplier = 0.95;
        }
      }
    }

    // Composite raw multiplier
    let rawMultiplier =
      utilMultiplier *
      leadTimeMultiplier *
      bookingVelocityMultiplier *
      competitorMultiplier;

    // Apply strict policy multiplier bounds
    let isClamped = false;
    let clampReason: string | undefined;

    if (rawMultiplier > maxSurge) {
      rawMultiplier = maxSurge;
      isClamped = true;
      clampReason = `Surge multiplier capped at maximum allowable ceiling (${maxSurge}x).`;
    } else if (rawMultiplier < minDiscount) {
      rawMultiplier = minDiscount;
      isClamped = true;
      clampReason = `Discount multiplier floored at minimum allowable limit (${minDiscount}x).`;
    }

    // Calculate raw effective rate
    let effectiveRate = Math.round(baseDailyRate * rawMultiplier * 100) / 100;

    // Apply absolute currency bounds
    if (effectiveRate > maxPrice) {
      effectiveRate = maxPrice;
      rawMultiplier = Math.round((maxPrice / baseDailyRate) * 100) / 100;
      isClamped = true;
      clampReason = `Effective rate capped at policy max price of ₹${maxPrice}/day.`;
    } else if (effectiveRate < minPrice) {
      effectiveRate = minPrice;
      rawMultiplier = Math.round((minPrice / baseDailyRate) * 100) / 100;
      isClamped = true;
      clampReason = `Effective rate floored at policy min price of ₹${minPrice}/day.`;
    }

    const explanation = `Base rate ₹${baseDailyRate}/day adjusted by ${Math.round((rawMultiplier - 1) * 100)}% dynamic factor (Util: ${Math.round(utilizationRate * 100)}%, Lead: ${leadTimeDays}d).`;

    return {
      effectiveDailyRate: effectiveRate,
      multiplier: Math.round(rawMultiplier * 100) / 100,
      baseDailyRate,
      policyBounds: {
        minDailyPrice: minPrice,
        maxDailyPrice: maxPrice,
        maxSurgeMultiplier: maxSurge,
        minDiscountMultiplier: minDiscount,
      },
      factors: {
        utilizationRate: Math.round(utilizationRate * 100) / 100,
        utilizationMultiplier: Math.round(utilMultiplier * 100) / 100,
        leadTimeDays,
        leadTimeMultiplier: Math.round(leadTimeMultiplier * 100) / 100,
        bookingVelocityMultiplier: Math.round(bookingVelocityMultiplier * 100) / 100,
        competitorIndexMultiplier: Math.round(competitorMultiplier * 100) / 100,
      },
      explanation,
      isClamped,
      clampReason,
    };
  }

  // Private: Resolve hierarchical policy
  private async resolveActivePolicy(ctx: DynamicPricingEvaluationContext) {
    if (ctx.branchId) {
      const branchPolicy = await this.prisma.dynamicPricingPolicy.findFirst({
        where: {
          branchId: ctx.branchId,
          vehicleClass: ctx.vehicleClass,
          isActive: true,
        },
      });
      if (branchPolicy) return branchPolicy;
    }

    if (ctx.vendorId) {
      const vendorPolicy = await this.prisma.dynamicPricingPolicy.findFirst({
        where: {
          vendorId: ctx.vendorId,
          vehicleClass: ctx.vehicleClass,
          isActive: true,
        },
      });
      if (vendorPolicy) return vendorPolicy;
    }

    return this.prisma.dynamicPricingPolicy.findFirst({
      where: {
        scope: PricingRuleScope.PLATFORM,
        vehicleClass: ctx.vehicleClass,
        isActive: true,
      },
    });
  }

  // Private: Compute utilization
  private async calculateUtilization(ctx: DynamicPricingEvaluationContext): Promise<number> {
    const whereCars: any = {
      type: ctx.vehicleClass,
      operationalStatus: { in: ['ACTIVE', 'AVAILABLE'] },
    };
    if (ctx.vendorId) whereCars.vendorId = ctx.vendorId;
    if (ctx.branchId) whereCars.pickupHubId = ctx.branchId;

    const totalCars = await this.prisma.car.count({ where: whereCars });
    if (totalCars === 0) return 0.50; // default midpoint

    const overlappingBookings = await this.prisma.booking.count({
      where: {
        status: { in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.HANDOVER_READY] },
        vehicleClass: ctx.vehicleClass,
        ...(ctx.vendorId ? { vendorId: ctx.vendorId } : {}),
        startDate: { lte: ctx.endDate },
        endDate: { gte: ctx.startDate },
      },
    });

    return Math.min(1.0, overlappingBookings / totalCars);
  }

  // Private: Compute booking velocity multiplier
  private async calculateVelocityMultiplier(ctx: DynamicPricingEvaluationContext): Promise<number> {
    const last24h = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentCount = await this.prisma.booking.count({
      where: {
        vehicleClass: ctx.vehicleClass,
        createdAt: { gte: last24h },
      },
    });

    if (recentCount >= 20) return 1.08;
    if (recentCount >= 10) return 1.04;
    return 1.0;
  }
}
