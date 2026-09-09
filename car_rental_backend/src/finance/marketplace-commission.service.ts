import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CarCategory,
  PricingRuleScope,
  SalesChannel,
} from '@prisma/client';

export interface CommissionCalculationContext {
  vendorId: string;
  branchId?: string;
  vehicleClass: CarCategory;
  channel?: SalesChannel;
  grossAmount: number; // base fare + fees before discount
  discountAmount?: number;
  subsidyAmount?: number;
  convenienceFee?: number;
}

export interface MultilateralCommissionBreakdown {
  grossAmount: number;
  discountAmount: number;
  taxableAmount: number;
  gstAmount: number;
  totalCustomerPayable: number;
  platformFee: number;
  vendorNetPayable: number;
  branchShare: number;
  gatewayFeeRecovery: number;
  promotionalSubsidy: number;
  appliedRuleScope: PricingRuleScope;
  channel: SalesChannel;
  effectivePercentages: {
    platformPct: number;
    vendorPct: number;
    branchPct: number;
    gstPct: number;
  };
  isBalanced: boolean;
}

@Injectable()
export class MarketplaceCommissionService {
  private readonly logger = new Logger(MarketplaceCommissionService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Calculates multilateral commercial splits across Platform, Vendor, Branch, and Payment Gateway
   */
  async calculateCommission(ctx: CommissionCalculationContext): Promise<MultilateralCommissionBreakdown> {
    const channel = ctx.channel || SalesChannel.CUSTOMER_APP;
    const rule = await this.resolveCommissionRule(ctx, channel);

    const platformPct = rule ? Number(rule.platformPct) : 15.00;
    const vendorPct = rule ? Number(rule.vendorPct) : 80.00;
    const branchPct = rule ? Number(rule.branchPct) : 5.00;
    const fixedFee = rule ? Number(rule.fixedPlatformFee) : 0;
    const gatewayFeePct = rule ? Number(rule.gatewayFeeRecovery) : 2.00;
    const gstPct = rule ? Number(rule.taxGstPct) : 18.00;

    const gross = ctx.grossAmount;
    const discount = ctx.discountAmount || 0;
    const taxable = Math.max(0, gross - discount);

    // GST on customer total
    const gstAmount = Math.round(((taxable * gstPct) / 100) * 100) / 100;
    const totalCustomerPayable = Math.round((taxable + gstAmount) * 100) / 100;

    // Platform, Vendor, Branch splits of the taxable rental revenue
    const platformFee = Math.round(((taxable * platformPct) / 100 + fixedFee) * 100) / 100;
    const branchShare = Math.round(((taxable * branchPct) / 100) * 100) / 100;
    const vendorNetPayable = Math.round((taxable - platformFee - branchShare) * 100) / 100;

    // Gateway processing fee recovery
    const gatewayFeeRecovery = Math.round(((totalCustomerPayable * gatewayFeePct) / 100) * 100) / 100;

    const subsidy = ctx.subsidyAmount || 0;

    // Verify mathematical integrity
    const sumSplits = Math.round((platformFee + branchShare + vendorNetPayable) * 100) / 100;
    const isBalanced = Math.abs(sumSplits - taxable) < 0.05;

    return {
      grossAmount: gross,
      discountAmount: discount,
      taxableAmount: taxable,
      gstAmount,
      totalCustomerPayable,
      platformFee,
      vendorNetPayable,
      branchShare,
      gatewayFeeRecovery,
      promotionalSubsidy: subsidy,
      appliedRuleScope: rule ? rule.scope : PricingRuleScope.PLATFORM,
      channel,
      effectivePercentages: {
        platformPct,
        vendorPct,
        branchPct,
        gstPct,
      },
      isBalanced,
    };
  }

  // Private hierarchical rule lookup
  private async resolveCommissionRule(ctx: CommissionCalculationContext, channel: SalesChannel) {
    if (ctx.branchId) {
      const branchRule = await this.prisma.marketplaceCommissionRule.findFirst({
        where: {
          branchId: ctx.branchId,
          vehicleClass: ctx.vehicleClass,
          channel,
          isActive: true,
        },
      });
      if (branchRule) return branchRule;
    }

    if (ctx.vendorId) {
      const vendorRule = await this.prisma.marketplaceCommissionRule.findFirst({
        where: {
          vendorId: ctx.vendorId,
          vehicleClass: ctx.vehicleClass,
          channel,
          isActive: true,
        },
      });
      if (vendorRule) return vendorRule;
    }

    return this.prisma.marketplaceCommissionRule.findFirst({
      where: {
        scope: PricingRuleScope.PLATFORM,
        channel,
        isActive: true,
      },
    });
  }
}
