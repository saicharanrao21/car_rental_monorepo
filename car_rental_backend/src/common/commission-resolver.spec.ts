import { CommissionResolverService } from './commission-resolver.service';
import { MarketplaceCommissionService } from '../finance/marketplace-commission.service';
import { CarCategory, TripType, PricingRuleScope, SalesChannel, Prisma } from '@prisma/client';

describe('Commission Resolution & Commercial Splits — Founder Business Model Audit', () => {
  let resolver: CommissionResolverService;
  let marketplaceCommission: MarketplaceCommissionService;
  let prismaMock: any;
  let configServiceMock: any;

  beforeEach(() => {
    prismaMock = {
      marketplaceCommissionRule: {
        findFirst: jest.fn(),
      },
      commissionConfig: {
        findMany: jest.fn(),
      },
    };

    configServiceMock = {
      getCommissionConfig: jest.fn().mockResolvedValue({ defaultPercent: 12.5 }),
    };

    resolver = new CommissionResolverService(prismaMock, configServiceMock);
    marketplaceCommission = new MarketplaceCommissionService(prismaMock);
  });

  describe('CommissionResolverService — 4-Tier Precedence Hierarchy', () => {
    it('Tier 1: should apply active dealer-specific negotiated agreement override when vendorId matches', async () => {
      // Dealer B has negotiated 8.5% commission rate
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue({
        id: 'rule_dealer_b',
        vendorId: 'vendor_b',
        platformPct: new Prisma.Decimal(8.5),
        isActive: true,
      });

      const result = await resolver.resolveCommissionPercent(
        'Hyderabad',
        CarCategory.SEDAN,
        TripType.SELF_DRIVE,
        'vendor_b',
      );

      expect(prismaMock.marketplaceCommissionRule.findFirst).toHaveBeenCalledWith({
        where: {
          vendorId: 'vendor_b',
          isActive: true,
          OR: [{ vehicleClass: null }, { vehicleClass: CarCategory.SEDAN }],
        },
        orderBy: [{ vehicleClass: 'desc' }, { createdAt: 'desc' }],
      });
      expect(result.toNumber()).toBe(8.5);
    });

    it('Tier 3: should fall back to localized city/category/trip specificity scoring if dealer has no negotiated agreement', async () => {
      // Dealer has no override
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue(null);

      // Localized rules in DB
      prismaMock.commissionConfig.findMany.mockResolvedValue([
        {
          id: 'cfg_general_city',
          city: 'Hyderabad',
          carCategory: null,
          tripType: null,
          percentage: new Prisma.Decimal(14.0), // score = 4
        },
        {
          id: 'cfg_city_and_category',
          city: 'Hyderabad',
          carCategory: CarCategory.LUXURY,
          tripType: null,
          percentage: new Prisma.Decimal(18.0), // score = 4 + 2 = 6
        },
      ]);

      const result = await resolver.resolveCommissionPercent(
        'Hyderabad',
        CarCategory.LUXURY,
        TripType.SELF_DRIVE,
        'vendor_generic',
      );

      // Rule with higher specificity (score 6) must win
      expect(result.toNumber()).toBe(18.0);
    });

    it('Tier 4: should fall back to Global SystemConfig rate when no localized rules match', async () => {
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue(null);
      prismaMock.commissionConfig.findMany.mockResolvedValue([]);

      const result = await resolver.resolveCommissionPercent(
        'Warangal',
        CarCategory.HATCHBACK,
        TripType.LOCAL,
        'vendor_c',
      );

      expect(result.toNumber()).toBe(12.5);
    });

    it('Tier 4 fallback: should return 10.0% when system config is unavailable', async () => {
      const resolverNoConfig = new CommissionResolverService(prismaMock);
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue(null);
      prismaMock.commissionConfig.findMany.mockResolvedValue([]);

      const result = await resolverNoConfig.resolveCommissionPercent(
        'Karimnagar',
        CarCategory.SUV,
        TripType.OUTSTATION,
      );

      expect(result.toNumber()).toBe(10.0);
    });
  });

  describe('MarketplaceCommissionService — Commercial Splits & Elimination of Legacy 5% Cut', () => {
    it('FND-CONF-07: Gross Rental Total calculates splits with 0% branch cut by default', async () => {
      // Default platform rule: 15% platform fee, 0% branch cut
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue(null);

      // Base fare 3,000 + Delivery fee 500 = Gross Rental Total 3,500
      const breakdown = await marketplaceCommission.calculateCommission({
        vendorId: 'vendor_123',
        vehicleClass: CarCategory.SEDAN,
        channel: SalesChannel.CUSTOMER_APP,
        grossAmount: 3500,
        discountAmount: 0,
      });

      // PlatformPct: 15.00%, BranchPct: 0.00%, VendorPct: 85.00%
      expect(breakdown.effectivePercentages.platformPct).toBe(15.0);
      expect(breakdown.effectivePercentages.branchPct).toBe(0.0);
      expect(breakdown.effectivePercentages.vendorPct).toBe(85.0);

      // Platform fee: 15% of 3,500 = 525
      expect(breakdown.platformFee).toBe(525);
      // Branch cut must be zero
      expect(breakdown.branchShare).toBe(0);
      // Vendor net payable: 3,500 - 525 = 2,975 (Full 85% without 5% legacy deduction)
      expect(breakdown.vendorNetPayable).toBe(2975);
      expect(breakdown.isBalanced).toBe(true);
    });

    it('Security deposits and convenience fees are not subjected to commission splits', async () => {
      prismaMock.marketplaceCommissionRule.findFirst.mockResolvedValue({
        id: 'rule_platform',
        scope: PricingRuleScope.PLATFORM,
        channel: SalesChannel.CUSTOMER_APP,
        platformPct: new Prisma.Decimal(12.0),
        vendorPct: new Prisma.Decimal(88.0),
        branchPct: new Prisma.Decimal(0.0),
        fixedPlatformFee: new Prisma.Decimal(0),
        gatewayFeeRecovery: new Prisma.Decimal(2.0),
        taxGstPct: new Prisma.Decimal(18.0),
      });

      // Rental fare: 2,000 (excluding 5,000 deposit and 99 platform convenience fee)
      const breakdown = await marketplaceCommission.calculateCommission({
        vendorId: 'vendor_123',
        vehicleClass: CarCategory.HATCHBACK,
        grossAmount: 2000,
      });

      expect(breakdown.platformFee).toBe(240); // 12% of 2,000
      expect(breakdown.vendorNetPayable).toBe(1760); // 88% of 2,000
      expect(breakdown.branchShare).toBe(0);
      expect(breakdown.isBalanced).toBe(true);
    });
  });
});

