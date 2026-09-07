import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { SystemConfigService } from './system-config.service';
import { SystemConfigController } from './system-config.controller';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { PricingService } from '../pricing/pricing.service';
import { CancellationPolicyService, DEFAULT_CANCELLATION_MATRIX } from '../bookings/cancellation-policy.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import {
  CarCategory,
  Prisma,
  QuoteLineItemType,
  QuoteStatus,
  Role,
  TripType,
} from '@prisma/client';

describe('Phase B — Platform Configuration Engine Foundation Tests', () => {
  let systemConfigService: SystemConfigService;
  let systemConfigController: SystemConfigController;
  let pricingService: PricingService;
  let cancellationPolicyService: CancellationPolicyService;
  let commissionResolverService: CommissionResolverService;
  let depositRulesService: DepositRulesService;

  let dbStore: Map<string, any>;
  let cacheStore: Map<string, any>;
  let mockPrisma: any;
  let mockCache: any;

  const mockCar = {
    id: 'car-test-b1',
    vendorId: 'vendor-1',
    make: 'Hyundai',
    model: 'Creta',
    registrationNumber: 'KA-05-CD-5678',
    type: CarCategory.SEDAN,
    pricePerDay: new Prisma.Decimal(2000),
    pricePerHour: new Prisma.Decimal(100),
    pricePerKm: new Prisma.Decimal(10),
    weeklyDiscountPercent: 10,
    monthlyDiscountPercent: 20,
    isAvailable: true,
    availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    vendor: {
      id: 'vendor-1',
      userId: 'vendor-user-1',
      city: 'Bangalore',
      verificationStatus: 'VERIFIED',
    },
    mileagePackages: [],
  };

  beforeEach(async () => {
    dbStore = new Map<string, any>();
    cacheStore = new Map<string, any>();

    mockCache = {
      get: jest.fn(async (key: string) => cacheStore.get(key) || null),
      set: jest.fn(async (key: string, val: any) => {
        cacheStore.set(key, val);
        return true;
      }),
      delete: jest.fn(async (key: string) => {
        cacheStore.delete(key);
        return true;
      }),
    };

    mockPrisma = {
      systemConfig: {
        findUnique: jest.fn(async ({ where }: { where: { key: string } }) => {
          const val = dbStore.get(where.key);
          if (val === undefined) return null;
          return { key: where.key, value: val };
        }),
        upsert: jest.fn(
          async ({
            where,
            create,
            update,
          }: {
            where: { key: string };
            create: any;
            update: any;
          }) => {
            const val = update.value ?? create.value;
            dbStore.set(where.key, val);
            return { key: where.key, value: val };
          },
        ),
      },
      car: {
        findUnique: jest.fn().mockResolvedValue(mockCar),
      },
      bookingQuote: {
        create: jest.fn().mockImplementation((args) => ({
          id: 'quote-test-b1',
          ...args.data,
          lineItems: args.data.lineItems?.create || [],
          car: mockCar,
          createdAt: new Date(),
        })),
        findUnique: jest.fn(),
        update: jest.fn().mockImplementation((args) => ({
          id: args.where.id,
          ...args.data,
        })),
      },
      commissionConfig: {
        findMany: jest.fn().mockResolvedValue([]), // No custom rules to force fallback
      },
      depositRule: {
        findFirst: jest.fn().mockResolvedValue(null), // No custom rules to force fallback
      },
      booking: {
        findUnique: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
      },
      $transaction: jest.fn((cb) => cb(mockPrisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SystemConfigController],
      providers: [
        SystemConfigService,
        CancellationPolicyService,
        CommissionResolverService,
        DepositRulesService,
        FareCalculatorService,
        PricingService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
      ],
    }).compile();

    systemConfigService = module.get<SystemConfigService>(SystemConfigService);
    systemConfigController = module.get<SystemConfigController>(SystemConfigController);
    pricingService = module.get<PricingService>(PricingService);
    cancellationPolicyService = module.get<CancellationPolicyService>(CancellationPolicyService);
    commissionResolverService = module.get<CommissionResolverService>(CommissionResolverService);
    depositRulesService = module.get<DepositRulesService>(DepositRulesService);
  });

  describe('1. GST Configuration Engine', () => {
    it('1. GST uses configured value from SystemConfig', async () => {
      // Configure GST to 12% in DB
      dbStore.set('pricing.tax', { gstRate: 12 });

      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      const quote = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Platform fee = 10% of 2000 = ₹200
      // Configured GST = 12% of 200 = ₹24
      const gstItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.GST);
      expect(gstItem).toBeDefined();
      expect(gstItem?.name).toContain('12%');
      expect(gstItem?.amount).toBe(24.0);
      expect(quote.taxTotal).toBe(24.0);
    });

    it('2. GST falls back to 18% when missing/invalid', async () => {
      // Set invalid GST in DB
      dbStore.set('pricing.tax', { gstRate: -5 });

      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      const quote = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Platform fee = 10% of 2000 = ₹200
      // Fallback GST = 18% of 200 = ₹36
      const gstItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.GST);
      expect(gstItem).toBeDefined();
      expect(gstItem?.name).toContain('18%');
      expect(gstItem?.amount).toBe(36.0);
      expect(quote.taxTotal).toBe(36.0);
    });
  });

  describe('2. Quote Validity Configuration Engine', () => {
    it('3. Quote validity uses configured value from SystemConfig', async () => {
      // Configure quote validity to 45 minutes
      dbStore.set('pricing.quote', { validityMinutes: 45 });

      const before = Date.now();
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      const quote = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      const expiryTime = new Date(quote.expiresAt).getTime();
      const diffMinutes = (expiryTime - before) / (60 * 1000);
      expect(diffMinutes).toBeGreaterThanOrEqual(44.9);
      expect(diffMinutes).toBeLessThanOrEqual(45.1);
    });
  });

  describe('3. Duration Discounts Configuration Engine', () => {
    it('4. Duration discount tiers use configuration', async () => {
      // Configure custom duration discount tiers: 5+ days = 15%, 14+ days = 25%
      dbStore.set('pricing.duration_discounts', [
        { minDays: 5, discountPercent: 15 },
        { minDays: 14, discountPercent: 25 },
      ]);

      const start = new Date(Date.now() + 86400000);

      // Test 5-day rental -> matches 15% tier
      const end5 = new Date(start.getTime() + 5 * 86400000);
      const quote5 = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end5.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Subtotal = 2000 * 5 = ₹10,000
      // 15% discount = ₹1,500
      expect(quote5.subtotal).toBe(10000);
      expect(quote5.discountTotal).toBe(1500);
      const discountItem5 = quote5.lineItems.find((li) => li.type === QuoteLineItemType.DURATION_DISCOUNT);
      expect(discountItem5?.name).toContain('15%');
      expect(discountItem5?.amount).toBe(-1500);

      // Test 14-day rental -> matches 25% tier
      const end14 = new Date(start.getTime() + 14 * 86400000);
      const quote14 = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end14.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Subtotal = 2000 * 14 = ₹28,000
      // 25% discount = ₹7,000
      expect(quote14.subtotal).toBe(28000);
      expect(quote14.discountTotal).toBe(7000);
      const discountItem14 = quote14.lineItems.find((li) => li.type === QuoteLineItemType.DURATION_DISCOUNT);
      expect(discountItem14?.name).toContain('25%');
      expect(discountItem14?.amount).toBe(-7000);
    });
  });

  describe('4. Cancellation Matrix Configuration Engine', () => {
    it('5. Cancellation matrix uses configuration', async () => {
      // Configure custom matrix: > 48h = 0%, 12-48h = 30%, 0-12h = 60%, after start = 100%
      dbStore.set('booking.cancellation_matrix', {
        tiers: [
          {
            minHoursBeforePickup: 48,
            feePercent: 0,
            tier: 'CUSTOM_EARLY_FREE',
            description: 'Free cancellation (> 48 hours)',
          },
          {
            minHoursBeforePickup: 12,
            feePercent: 30,
            tier: 'CUSTOM_TIER_30',
            description: 'Cancellation 12-48 hours before (30% fee)',
          },
          {
            minHoursBeforePickup: 0,
            feePercent: 60,
            tier: 'CUSTOM_TIER_60',
            description: 'Cancellation within 12 hours (60% fee)',
          },
        ],
        afterStartFeePercent: 100,
        afterStartTier: 'NO_REFUND_AFTER_START',
      });

      const startDate = new Date('2026-10-10T12:00:00.000Z');
      // 20 hours remaining: between 12 and 48 hours -> should match CUSTOM_TIER_30 with 30% fee
      const cancellationTime = new Date('2026-10-09T16:00:00.000Z');

      const result = await cancellationPolicyService.calculateCancellationWithConfig({
        startDate,
        cancellationTime,
        amountPaid: new Prisma.Decimal(10000),
        actorRole: Role.CUSTOMER,
      });

      expect(result.tier).toBe('CUSTOM_TIER_30');
      expect(result.cancellationFeePercent).toBe(30);
      expect(result.cancellationFee.toNumber()).toBe(3000);
      expect(result.refundAmount.toNumber()).toBe(7000);
    });
  });

  describe('5. Platform Commission Configuration Engine', () => {
    it('6. Commission uses configured value from SystemConfig', async () => {
      // Configure default commission to 15%
      dbStore.set('pricing.commission', { defaultPercent: 15 });

      const resolved = await commissionResolverService.resolveCommissionPercent(
        'UnknownCity',
        CarCategory.SEDAN,
        TripType.SELF_DRIVE,
      );

      expect(resolved.toNumber()).toBe(15.0);
    });
  });

  describe('6. Deposit Defaults Configuration Engine', () => {
    it('7. Deposit defaults use configured values from SystemConfig', async () => {
      // Configure custom default deposits
      dbStore.set('deposits.defaults', {
        HATCHBACK: 4500,
        SEDAN: 6500,
        SUV: 8500,
        LUXURY: 15000,
      });

      const deposit = await depositRulesService.getDepositAmount(CarCategory.SEDAN);
      expect(deposit).toBe(6500);

      const hatchDeposit = await depositRulesService.getDepositAmount(CarCategory.HATCHBACK);
      expect(hatchDeposit).toBe(4500);
    });
  });

  describe('7. Resilience & Fallback Guarantees', () => {
    it('8. Invalid configuration safely falls back without crashing', async () => {
      // Populate invalid / corrupted configs
      dbStore.set('pricing.tax', { gstRate: 'invalid' });
      dbStore.set('pricing.quote', { validityMinutes: -100 });
      dbStore.set('pricing.duration_discounts', 'invalid-tier-data');
      dbStore.set('pricing.commission', { defaultPercent: 'not-a-number' });
      dbStore.set('deposits.defaults', null);

      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      // Quote generation must still succeed with safe fallbacks
      const quote = await pricingService.generateQuote({
        carId: mockCar.id,
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      expect(quote).toBeDefined();
      expect(quote.taxTotal).toBe(36.0); // 18% fallback
      expect(quote.status).toBe('ACTIVE');

      // Commission fallback
      const comm = await commissionResolverService.resolveCommissionPercent(
        'UnknownCity',
        CarCategory.SEDAN,
        TripType.SELF_DRIVE,
      );
      expect(comm.toNumber()).toBe(10.0); // 10% fallback

      // Deposit fallback
      const deposit = await depositRulesService.getDepositAmount(CarCategory.SEDAN);
      expect(deposit).toBe(4000); // SEDAN fallback
    });

    it('9. Existing historical booking snapshots remain unaffected by runtime config updates', async () => {
      // Historical booking with its own policy snapshot captured at time of acceptance
      const historicalMatrix = {
        tiers: [
          {
            minHoursBeforePickup: 24,
            feePercent: 10,
            tier: 'HISTORICAL_TIER_10',
            description: 'Grandfathered policy 10% fee',
          },
        ],
        afterStartFeePercent: 100,
      };

      // Current system config is updated to a strict 50% fee
      dbStore.set('booking.cancellation_matrix', {
        tiers: [
          {
            minHoursBeforePickup: 24,
            feePercent: 50,
            tier: 'NEW_STRICT_50',
            description: 'New policy 50% fee',
          },
        ],
        afterStartFeePercent: 100,
      });

      const startDate = new Date('2026-10-10T12:00:00.000Z');
      const cancellationTime = new Date('2026-10-09T10:00:00.000Z'); // 26h before

      // Historical booking passes its own snapshot
      const result = await cancellationPolicyService.calculateCancellationWithConfig({
        startDate,
        cancellationTime,
        amountPaid: new Prisma.Decimal(5000),
        actorRole: Role.CUSTOMER,
        cancellationMatrix: historicalMatrix,
      });

      // Must honor the historical snapshot (10%), NOT the updated global rule (50%)
      expect(result.tier).toBe('HISTORICAL_TIER_10');
      expect(result.cancellationFeePercent).toBe(10);
      expect(result.cancellationFee.toNumber()).toBe(500);
      expect(result.refundAmount.toNumber()).toBe(4500);
    });
  });

  describe('8. 3-Tier Cache, DB & Invalidation Integrity', () => {
    it('10. Existing SystemConfig Redis/PostgreSQL fallback behavior remains intact for Phase B keys', async () => {
      // 1. Neither in cache nor DB -> returns default fallback
      const defaultTax = await systemConfigService.getTaxConfig();
      expect(defaultTax.gstRate).toBe(18);

      // 2. Put in DB -> next read retrieves from DB and populates cache
      dbStore.set('pricing.tax', { gstRate: 28 });
      const dbTax = await systemConfigService.getTaxConfig();
      expect(dbTax.gstRate).toBe(28);
      expect(mockCache.set).toHaveBeenCalled();

      // 3. Cache read
      cacheStore.set('cache:config:pricing.tax', { gstRate: 5 });
      const cachedTax = await systemConfigService.getTaxConfig();
      expect(cachedTax.gstRate).toBe(5);
    });

    it('11. Cache invalidation causes updated configuration to be used without server restart', async () => {
      // Seed cache with 18%
      cacheStore.set('cache:config:pricing.tax', { gstRate: 18 });
      expect((await systemConfigService.getTaxConfig()).gstRate).toBe(18);

      // Update config via service
      await systemConfigService.setConfig('pricing.tax', { gstRate: 12 }, 'admin-uuid');

      // Cache delete must be called
      expect(mockCache.delete).toHaveBeenCalledWith('cache:config:pricing.tax');

      // Subsequent read fetches updated DB value (12%)
      const updatedTax = await systemConfigService.getTaxConfig();
      expect(updatedTax.gstRate).toBe(12);
    });

    it('12. SystemConfigController enforces validation on Phase B config update', async () => {
      // Invalid tax rate (> 100)
      await expect(
        systemConfigController.updateConfig('pricing.tax', { gstRate: 150 }, { user: { id: 'admin-1' } }),
      ).rejects.toThrow(BadRequestException);

      // Invalid quote validity (0 minutes)
      await expect(
        systemConfigController.updateConfig('pricing.quote', { validityMinutes: 0 }, { user: { id: 'admin-1' } }),
      ).rejects.toThrow(BadRequestException);

      // Invalid duration discount tier (missing minDays)
      await expect(
        systemConfigController.updateConfig('pricing.duration_discounts', [{ discountPercent: 20 }], { user: { id: 'admin-1' } }),
      ).rejects.toThrow(BadRequestException);

      // Invalid commission percentage (> 100)
      await expect(
        systemConfigController.updateConfig('pricing.commission', { defaultPercent: 120 }, { user: { id: 'admin-1' } }),
      ).rejects.toThrow(BadRequestException);

      // Valid update
      const updateRes = await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 12 },
        { user: { id: 'admin-1' } },
      );
      expect(updateRes).toBeDefined();
    });
  });
});
