import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CarCategory,
  PricingRuleScope,
  RentalPricingRule,
  TripType,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface PricingResolutionContext {
  vendorId: string;
  branchId?: string; // pickupHubId
  returnBranchId?: string; // returnHubId for one-way calculation
  vehicleClass: CarCategory;
  carId?: string;
  startDate: Date;
  endDate: Date;
  tripType: TripType;
  distanceKm?: number;
  couponCode?: string;
  couponDiscountAmount?: number;
  deliveryType?: string;
  deliveryFee?: number;
  pickupFee?: number;
  returnFee?: number;
}

export interface PricingBreakdownItem {
  code: string;
  name: string;
  category: 'BASE' | 'MULTIPLIER' | 'FEE' | 'TAX' | 'DISCOUNT' | 'DEPOSIT';
  rate: number;
  quantity: number;
  amount: number;
  isRefundable: boolean;
  explanation: string;
}

export interface EffectivePricingResolution {
  version: string;
  resolvedScope: PricingRuleScope;
  appliedRuleIds: string[];
  rulesAppliedSummary: Array<{
    ruleId: string;
    scope: PricingRuleScope;
    name: string;
  }>;
  duration: {
    totalHours: number;
    totalDays: number;
    billingBasis: 'HOURLY' | 'DAILY';
    weekendDays: number;
    holidayOrPeakDays: number;
  };
  rates: {
    hourlyRate: number;
    dailyRate: number;
    weekendMultiplier: number;
    peakMultiplier: number;
    holidayMultiplier: number;
    weeklyDiscountPct: number;
    monthlyDiscountPct: number;
    extraKmRate: number;
    lateReturnHourlyFee: number;
  };
  lineItems: PricingBreakdownItem[];
  subtotal: number;
  discountTotal: number;
  feesTotal: number;
  taxTotal: number;
  depositTotal: number;
  totalPayable: number;
  netToVendor: number;
  currency: string;
  effectiveSnapshot: Record<string, any>;
}

@Injectable()
export class RentalPricingResolutionService {
  private readonly logger = new Logger(RentalPricingResolutionService.name);
  public static readonly CURRENT_PRICING_ENGINE_VERSION = 'v2.0-enterprise';

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Hierarchically resolves pricing configuration:
   * PLATFORM -> VENDOR -> BRANCH -> VEHICLE_CLASS
   */
  async resolvePricing(ctx: PricingResolutionContext): Promise<EffectivePricingResolution> {
    const start = new Date(ctx.startDate);
    const end = new Date(ctx.endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid start or end date format.');
    }
    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    const durationMs = end.getTime() - start.getTime();
    const totalHours = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60)));
    const totalDays = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60 * 24)));

    // 1. Fetch relevant active pricing rules across all scopes
    const rules = await this.fetchActiveHierarchyRules(ctx);

    // 2. Fetch car defaults if carId provided
    let car: any = null;
    if (ctx.carId) {
      car = await this.prisma.car.findUnique({
        where: { id: ctx.carId },
        include: { vendor: true, pickupHub: true },
      });
    }

    // 3. Fallback defaults
    const defaultDailyRate = car ? Number(car.pricePerDay) : this.getDefaultDailyRateForClass(ctx.vehicleClass);
    const defaultHourlyRate = car ? Number(car.pricePerHour) : Math.round(defaultDailyRate / 8);

    // 4. Resolve effective rates using hierarchical inheritance:
    // Highest priority wins, or override cascade: CLASS > BRANCH > VENDOR > PLATFORM
    let resolvedDailyRate = defaultDailyRate;
    let resolvedHourlyRate = defaultHourlyRate;
    let resolvedWeekendMultiplier = 1.0;
    let resolvedPeakMultiplier = 1.0;
    let resolvedHolidayMultiplier = 1.0;
    let resolvedWeeklyDiscountPct = car?.weeklyDiscountPercent || 0;
    let resolvedMonthlyDiscountPct = car?.monthlyDiscountPercent || 0;
    let resolvedExtraKmRate = car ? Number(car.pricePerKm) : 12.0;
    let resolvedLateReturnHourlyFee = Math.round(resolvedHourlyRate * 1.5);
    let resolvedDeposit = 3000.0;
    let resolvedConvenienceFee = 150.0;
    let resolvedOneWayBaseFee = 500.0;

    const appliedRules: Array<{ ruleId: string; scope: PricingRuleScope; name: string }> = [];
    const appliedRuleIds: string[] = [];

    // Sort rules by priority ascending so higher priority overwrites
    const sortedRules = [...rules].sort((a, b) => {
      const scopeRank: Record<PricingRuleScope, number> = {
        PLATFORM: 1,
        VENDOR: 2,
        BRANCH: 3,
        VEHICLE_CLASS: 4,
      };
      if (scopeRank[a.scope] !== scopeRank[b.scope]) {
        return scopeRank[a.scope] - scopeRank[b.scope];
      }
      return a.priority - b.priority;
    });

    let topScope: PricingRuleScope = PricingRuleScope.PLATFORM;

    for (const r of sortedRules) {
      appliedRules.push({ ruleId: r.id, scope: r.scope, name: r.name });
      appliedRuleIds.push(r.id);
      topScope = r.scope;

      if (r.dailyRate) resolvedDailyRate = Number(r.dailyRate);
      if (r.hourlyRateMultiplier) resolvedHourlyRate = Math.round(resolvedDailyRate * Number(r.hourlyRateMultiplier));
      if (r.weekendMultiplier) resolvedWeekendMultiplier = Number(r.weekendMultiplier);
      if (r.peakSeasonMultiplier) resolvedPeakMultiplier = Number(r.peakSeasonMultiplier);
      if (r.holidayMultiplier) resolvedHolidayMultiplier = Number(r.holidayMultiplier);
      if (r.weeklyDiscountPct !== null && r.weeklyDiscountPct !== undefined) resolvedWeeklyDiscountPct = r.weeklyDiscountPct;
      if (r.monthlyDiscountPct !== null && r.monthlyDiscountPct !== undefined) resolvedMonthlyDiscountPct = r.monthlyDiscountPct;
      if (r.extraKmRate) resolvedExtraKmRate = Number(r.extraKmRate);
      if (r.lateReturnHourlyFee) resolvedLateReturnHourlyFee = Number(r.lateReturnHourlyFee);
      if (r.securityDepositAmount) resolvedDeposit = Number(r.securityDepositAmount);
      if (r.convenienceFee) resolvedConvenienceFee = Number(r.convenienceFee);
      if (r.oneWayBaseFee) resolvedOneWayBaseFee = Number(r.oneWayBaseFee);
    }

    // 5. Calculate Calendar Factors (Weekend days, Holidays/Peak)
    const { weekendDays, peakDays } = this.calculateCalendarFactors(start, end);

    // 6. Determine billing basis: Hourly for short trips (e.g. < 24h on local/airport), Daily otherwise
    const billingBasis: 'HOURLY' | 'DAILY' =
      (ctx.tripType === TripType.LOCAL || ctx.tripType === TripType.AIRPORT_TRANSFER) && totalHours < 24
        ? 'HOURLY'
        : 'DAILY';

    const lineItems: PricingBreakdownItem[] = [];

    // Base fare calculation
    let baseFare = 0;
    if (billingBasis === 'HOURLY') {
      baseFare = Math.round(resolvedHourlyRate * totalHours);
      lineItems.push({
        code: 'BASE_FARE_HOURLY',
        name: `Hourly Rental (${totalHours} hrs)`,
        category: 'BASE',
        rate: resolvedHourlyRate,
        quantity: totalHours,
        amount: baseFare,
        isRefundable: false,
        explanation: `${totalHours} hours @ ₹${resolvedHourlyRate}/hr for ${ctx.vehicleClass}`,
      });
    } else {
      baseFare = Math.round(resolvedDailyRate * totalDays);
      lineItems.push({
        code: 'BASE_FARE_DAILY',
        name: `Daily Rental (${totalDays} days)`,
        category: 'BASE',
        rate: resolvedDailyRate,
        quantity: totalDays,
        amount: baseFare,
        isRefundable: false,
        explanation: `${totalDays} days @ ₹${resolvedDailyRate}/day for ${ctx.vehicleClass}`,
      });
    }

    // Weekend Surcharge if applicable
    let weekendSurcharge = 0;
    if (weekendDays > 0 && resolvedWeekendMultiplier > 1.0) {
      const dailyRatePortion = billingBasis === 'HOURLY' ? resolvedHourlyRate * 8 : resolvedDailyRate;
      weekendSurcharge = Math.round(dailyRatePortion * (resolvedWeekendMultiplier - 1.0) * weekendDays);
      if (weekendSurcharge > 0) {
        lineItems.push({
          code: 'WEEKEND_SURCHARGE',
          name: `Weekend Peak Rate (${weekendDays} weekend day${weekendDays > 1 ? 's' : ''})`,
          category: 'MULTIPLIER',
          rate: Number((resolvedWeekendMultiplier - 1.0).toFixed(2)),
          quantity: weekendDays,
          amount: weekendSurcharge,
          isRefundable: false,
          explanation: `Weekend surcharge of ${Math.round((resolvedWeekendMultiplier - 1.0) * 100)}% on ${weekendDays} weekend day(s)`,
        });
      }
    }

    // Peak / Holiday Surcharge if applicable
    let peakSurcharge = 0;
    const maxMultiplier = Math.max(resolvedPeakMultiplier, resolvedHolidayMultiplier);
    if (peakDays > 0 && maxMultiplier > 1.0) {
      const dailyRatePortion = billingBasis === 'HOURLY' ? resolvedHourlyRate * 8 : resolvedDailyRate;
      peakSurcharge = Math.round(dailyRatePortion * (maxMultiplier - 1.0) * peakDays);
      if (peakSurcharge > 0) {
        lineItems.push({
          code: 'SEASONAL_PEAK_SURCHARGE',
          name: `Peak Season / Holiday Rate (${peakDays} day${peakDays > 1 ? 's' : ''})`,
          category: 'MULTIPLIER',
          rate: Number((maxMultiplier - 1.0).toFixed(2)),
          quantity: peakDays,
          amount: peakSurcharge,
          isRefundable: false,
          explanation: `High demand peak surcharge of ${Math.round((maxMultiplier - 1.0) * 100)}% on ${peakDays} holiday/peak day(s)`,
        });
      }
    }

    // Duration discounts
    let durationDiscount = 0;
    if (totalDays >= 30 && resolvedMonthlyDiscountPct > 0) {
      durationDiscount = Math.round(baseFare * (resolvedMonthlyDiscountPct / 100));
      lineItems.push({
        code: 'MONTHLY_DURATION_DISCOUNT',
        name: `Monthly Rental Discount (${resolvedMonthlyDiscountPct}%)`,
        category: 'DISCOUNT',
        rate: resolvedMonthlyDiscountPct,
        quantity: 1,
        amount: -durationDiscount,
        isRefundable: false,
        explanation: `${resolvedMonthlyDiscountPct}% multi-week rental discount for 30+ days`,
      });
    } else if (totalDays >= 7 && resolvedWeeklyDiscountPct > 0) {
      durationDiscount = Math.round(baseFare * (resolvedWeeklyDiscountPct / 100));
      lineItems.push({
        code: 'WEEKLY_DURATION_DISCOUNT',
        name: `Weekly Rental Discount (${resolvedWeeklyDiscountPct}%)`,
        category: 'DISCOUNT',
        rate: resolvedWeeklyDiscountPct,
        quantity: 1,
        amount: -durationDiscount,
        isRefundable: false,
        explanation: `${resolvedWeeklyDiscountPct}% extended rental discount for 7+ days`,
      });
    }

    // Coupon discount
    let couponDiscount = 0;
    if (ctx.couponDiscountAmount && ctx.couponDiscountAmount > 0) {
      couponDiscount = ctx.couponDiscountAmount;
      lineItems.push({
        code: 'COUPON_PROMOTIONAL_DISCOUNT',
        name: `Promotional Coupon (${ctx.couponCode || 'APPLIED'})`,
        category: 'DISCOUNT',
        rate: couponDiscount,
        quantity: 1,
        amount: -couponDiscount,
        isRefundable: false,
        explanation: `Applied promo code discount ${ctx.couponCode || ''}`,
      });
    }

    // Fees: One-way fee
    let oneWayFee = 0;
    if (ctx.branchId && ctx.returnBranchId && ctx.branchId !== ctx.returnBranchId) {
      oneWayFee = resolvedOneWayBaseFee;
      lineItems.push({
        code: 'ONE_WAY_RELOCATION_FEE',
        name: 'Inter-Branch One-Way Relocation Fee',
        category: 'FEE',
        rate: oneWayFee,
        quantity: 1,
        amount: oneWayFee,
        isRefundable: false,
        explanation: 'Fleet repositioning fee between departure and return branches',
      });
    }

    // Convenience fee
    if (resolvedConvenienceFee > 0) {
      lineItems.push({
        code: 'PLATFORM_CONVENIENCE_FEE',
        name: 'Platform Service & Safety Fee',
        category: 'FEE',
        rate: resolvedConvenienceFee,
        quantity: 1,
        amount: resolvedConvenienceFee,
        isRefundable: false,
        explanation: 'DriveGo 24x7 roadside assist & telematics platform fee',
      });
    }

    // Pickup / Delivery fees
    if (ctx.pickupFee && ctx.pickupFee > 0) {
      lineItems.push({
        code: 'DOORSTEP_DELIVERY_FEE',
        name: 'Doorstep Delivery Fee',
        category: 'FEE',
        rate: ctx.pickupFee,
        quantity: 1,
        amount: ctx.pickupFee,
        isRefundable: false,
        explanation: 'Vehicle delivered directly to customer address',
      });
    }
    if (ctx.returnFee && ctx.returnFee > 0) {
      lineItems.push({
        code: 'DOORSTEP_COLLECTION_FEE',
        name: 'Doorstep Collection Fee',
        category: 'FEE',
        rate: ctx.returnFee,
        quantity: 1,
        amount: ctx.returnFee,
        isRefundable: false,
        explanation: 'Vehicle picked up from customer return address',
      });
    }

    // Subtotal
    const subtotal = Math.max(0, baseFare + weekendSurcharge + peakSurcharge);
    const totalDiscounts = durationDiscount + couponDiscount;
    const totalFees =
      resolvedConvenienceFee +
      oneWayFee +
      (ctx.pickupFee || 0) +
      (ctx.returnFee || 0) +
      (ctx.deliveryFee || 0);

    // GST (Taxes - 18% standard car rental GST in India)
    const taxableAmount = Math.max(0, subtotal - totalDiscounts + totalFees);
    const gstRate = 0.18;
    const taxTotal = Math.round(taxableAmount * gstRate);
    lineItems.push({
      code: 'GST_TAX_18',
      name: 'Goods & Services Tax (GST 18%)',
      category: 'TAX',
      rate: 18.0,
      quantity: 1,
      amount: taxTotal,
      isRefundable: false,
      explanation: 'Statutory 18% GST (CGST 9% + SGST 9%) on commercial passenger vehicle rental',
    });

    // Refundable Security Deposit
    if (resolvedDeposit > 0) {
      lineItems.push({
        code: 'REFUNDABLE_SECURITY_DEPOSIT',
        name: 'Refundable Security Deposit',
        category: 'DEPOSIT',
        rate: resolvedDeposit,
        quantity: 1,
        amount: resolvedDeposit,
        isRefundable: true,
        explanation: 'Refundable security escrow released upon damage-free vehicle return',
      });
    }

    const totalPayable = taxableAmount + taxTotal + resolvedDeposit;
    // Net to vendor (subtotal minus platform commission, approx 85% to vendor + full deposit)
    const netToVendor = Math.round((subtotal - totalDiscounts) * 0.85);

    const effectiveSnapshot = {
      version: RentalPricingResolutionService.CURRENT_PRICING_ENGINE_VERSION,
      resolvedScope: topScope,
      appliedRuleIds,
      duration: { totalHours, totalDays, billingBasis, weekendDays, peakDays },
      rates: {
        dailyRate: resolvedDailyRate,
        hourlyRate: resolvedHourlyRate,
        weekendMultiplier: resolvedWeekendMultiplier,
        peakMultiplier: resolvedPeakMultiplier,
        holidayMultiplier: resolvedHolidayMultiplier,
        weeklyDiscountPct: resolvedWeeklyDiscountPct,
        monthlyDiscountPct: resolvedMonthlyDiscountPct,
        extraKmRate: resolvedExtraKmRate,
        lateReturnHourlyFee: resolvedLateReturnHourlyFee,
        securityDeposit: resolvedDeposit,
      },
      calculatedAt: new Date().toISOString(),
    };

    return {
      version: RentalPricingResolutionService.CURRENT_PRICING_ENGINE_VERSION,
      resolvedScope: topScope,
      appliedRuleIds,
      rulesAppliedSummary: appliedRules,
      duration: {
        totalHours,
        totalDays,
        billingBasis,
        weekendDays,
        holidayOrPeakDays: peakDays,
      },
      rates: {
        hourlyRate: resolvedHourlyRate,
        dailyRate: resolvedDailyRate,
        weekendMultiplier: resolvedWeekendMultiplier,
        peakMultiplier: resolvedPeakMultiplier,
        holidayMultiplier: resolvedHolidayMultiplier,
        weeklyDiscountPct: resolvedWeeklyDiscountPct,
        monthlyDiscountPct: resolvedMonthlyDiscountPct,
        extraKmRate: resolvedExtraKmRate,
        lateReturnHourlyFee: resolvedLateReturnHourlyFee,
      },
      lineItems,
      subtotal,
      discountTotal: totalDiscounts,
      feesTotal: totalFees,
      taxTotal,
      depositTotal: resolvedDeposit,
      totalPayable,
      netToVendor,
      currency: 'INR',
      effectiveSnapshot,
    };
  }

  /**
   * Helper: fetches all active hierarchical rules matching the context.
   */
  private async fetchActiveHierarchyRules(ctx: PricingResolutionContext): Promise<RentalPricingRule[]> {
    const now = new Date();

    const orClauses: Prisma.RentalPricingRuleWhereInput[] = [
      { scope: PricingRuleScope.PLATFORM },
    ];

    if (ctx.vendorId) {
      orClauses.push({ scope: PricingRuleScope.VENDOR, vendorId: ctx.vendorId });
    }
    if (ctx.branchId) {
      orClauses.push({ scope: PricingRuleScope.BRANCH, branchId: ctx.branchId });
    }
    if (ctx.vehicleClass) {
      orClauses.push({ scope: PricingRuleScope.VEHICLE_CLASS, vehicleClass: ctx.vehicleClass });
    }
    if (ctx.carId) {
      orClauses.push({ carId: ctx.carId });
    }

    return this.prisma.rentalPricingRule.findMany({
      where: {
        isActive: true,
        OR: orClauses,
        AND: [
          {
            OR: [
              { effectiveFrom: null },
              { effectiveFrom: { lte: now } },
            ],
          },
          {
            OR: [
              { effectiveTo: null },
              { effectiveTo: { gte: now } },
            ],
          },
        ],
      },
      orderBy: { priority: 'desc' },
    });
  }

  /**
   * Calculates weekend and peak holiday days in the interval.
   */
  private calculateCalendarFactors(start: Date, end: Date): { weekendDays: number; peakDays: number } {
    let weekendDays = 0;
    let peakDays = 0;
    const current = new Date(start);

    // Peak months: Dec, Jan, May, June (holiday seasons)
    const peakMonths = [0, 4, 5, 11];

    while (current < end) {
      const dayOfWeek = current.getDay();
      if (dayOfWeek === 0 || dayOfWeek === 6) {
        weekendDays++;
      }
      if (peakMonths.includes(current.getMonth())) {
        peakDays++;
      }
      current.setDate(current.getDate() + 1);
    }

    return { weekendDays, peakDays };
  }

  /**
   * Default daily rates per vehicle class in INR
   */
  public getDefaultDailyRateForClass(category: CarCategory): number {
    switch (category) {
      case CarCategory.HATCHBACK:
        return 1499;
      case CarCategory.SEDAN:
        return 2299;
      case CarCategory.SUV:
        return 3499;
      case CarCategory.LUXURY:
        return 7999;
      case CarCategory.TEMPO_TRAVELLER:
        return 5499;
      case CarCategory.MINI_BUS:
        return 8999;
      default:
        return 2499;
    }
  }
}
