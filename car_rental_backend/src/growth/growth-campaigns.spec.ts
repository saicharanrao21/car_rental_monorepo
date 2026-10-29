import { GrowthService } from './growth.service';
import { SearchRankingService } from '../cars/search-ranking.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { DiscountType, CarCategory } from '@prisma/client';

describe('GrowthCampaigns (Phase 27.4)', () => {
  let service: GrowthService;
  let rankingService: SearchRankingService;
  let mockPrisma: any;
  let mockCacheService: any;
  let mockAuditLogService: any;
  let mockSystemConfigService: any;

  beforeEach(() => {
    mockPrisma = {
      promotionalCampaign: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      sponsoredCampaign: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
      },
      featuredListing: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
      },
      bookingAttribution: {
        findUnique: jest.fn(),
        create: jest.fn(),
        upsert: jest.fn().mockResolvedValue({ id: 'attr-1' }),
      },
      car: {
        findUnique: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
      },
      $transaction: jest.fn((callback) => callback(mockPrisma)),
      $queryRaw: jest.fn(),
    };

    mockCacheService = {
      invalidatePattern: jest.fn().mockResolvedValue(undefined),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfigService = {
      getGrowthCampaignConfig: jest.fn().mockResolvedValue({
        enablePromotionalCampaigns: true,
        enableSponsoredListings: true,
        enableFeaturedListings: true,
        sponsoredMaxBoostMultiplier: 2.0,
        featuredMaxBoostMultiplier: 1.5,
      }),
    };

    service = new GrowthService(
      mockPrisma,
      mockCacheService,
      mockAuditLogService,
      mockSystemConfigService,
    );

    rankingService = new SearchRankingService(new GeospatialService());
  });

  describe('Promotional Campaigns', () => {
    it('should create a valid promotional campaign and record audit log', async () => {
      mockPrisma.promotionalCampaign.findUnique.mockResolvedValue(null);
      mockPrisma.promotionalCampaign.create.mockImplementation((args: any) => ({
        id: 'camp-1',
        ...args.data,
      }));

      const campaign = await service.createPromotionalCampaign('admin-1', {
        code: 'MONSOON2026',
        name: 'Monsoon Getaway Promo',
        discountType: DiscountType.PERCENTAGE,
        discountValue: 15,
        maxDiscountAmount: 1500,
        minBookingAmount: 3000,
        budget: 500000,
      });

      expect(campaign.code).toBe('MONSOON2026');
      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin-1',
        'PROMOTIONAL_CAMPAIGN_CREATED',
        'PromotionalCampaign',
        'camp-1',
        expect.any(Object),
      );
    });

    it('should reject duplicate campaign codes', async () => {
      mockPrisma.promotionalCampaign.findUnique.mockResolvedValue({ id: 'existing' });

      await expect(
        service.createPromotionalCampaign('admin-1', {
          code: 'MONSOON2026',
          name: 'Duplicate',
          discountValue: 10,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Sponsored Campaigns & Marketplace Fairness', () => {
    it('should reject sponsored campaign creation for vehicles not owned by the vendor', async () => {
      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car-99',
        vendorId: 'vendor-OTHER',
        vendor: { userId: 'user-OTHER' },
      });

      await expect(
        service.createSponsoredCampaign('user-HACKER', {
          carId: 'car-99',
          city: 'Mumbai',
          startDate: new Date().toISOString(),
          endDate: new Date(Date.now() + 86400000).toISOString(),
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should cap sponsored boost multiplier at 2.0x ceiling', async () => {
      const now = new Date();
      const future = new Date(Date.now() + 86400000);

      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car-1',
        vendorId: 'v1',
        vendor: { userId: 'u1' },
      });
      mockPrisma.sponsoredCampaign.create.mockImplementation((args: any) => ({
        id: 'sc-1',
        ...args.data,
      }));

      const created = await service.createSponsoredCampaign('u1', {
        carId: 'car-1',
        city: 'Mumbai',
        startDate: now.toISOString(),
        endDate: future.toISOString(),
        boostMultiplier: 5.0, // Aggressive attempt to bypass ceiling
      });

      expect(created.boostMultiplier).toBe(2.0); // Bounded to max 2.0x
    });

    it('Marketplace Fairness: Unavailable car with active sponsored campaign strictly scores 0.0', () => {
      const now = new Date();
      const cars = [
        {
          id: 'car-unavail-sponsored',
          pricePerDay: 2000,
          isAvailable: false, // Hard gate
          vendor: { id: 'v1', rating: 4.9 },
          sponsoredCampaigns: [
            {
              status: 'ACTIVE',
              startDate: new Date(now.getTime() - 10000),
              endDate: new Date(now.getTime() + 100000),
              boostMultiplier: 2.0,
            },
          ],
        },
        {
          id: 'car-avail-organic',
          pricePerDay: 2500,
          isAvailable: true,
          vendor: { id: 'v2', rating: 4.2 },
        },
      ];

      const scored = rankingService.rankVehicles(cars as any);

      expect(scored.find((s) => s.car.id === 'car-unavail-sponsored')!.scoreBreakdown.finalCompositeScore).toBe(0);
      expect(scored[0].car.id).toBe('car-avail-organic');
    });
  });

  describe('Booking Attribution Tracking', () => {
    it('should record booking attribution and increment sponsored bookingsCount', async () => {
      mockPrisma.bookingAttribution.findUnique.mockResolvedValue(null);
      mockPrisma.bookingAttribution.create.mockImplementation((args: any) => ({
        id: 'attr-1',
        ...args.data,
      }));
      mockPrisma.sponsoredCampaign.update.mockResolvedValue({});

      const attribution = await service.recordAttribution({
        bookingId: 'booking-101',
        source: 'SPONSORED',
        sponsoredCampaignId: 'sc-123',
      });

      expect(attribution.bookingId).toBe('booking-101');
      expect(attribution.source).toBe('SPONSORED');
      expect(mockPrisma.sponsoredCampaign.update).toHaveBeenCalledWith({
        where: { id: 'sc-123' },
        data: { bookingsCount: { increment: 1 } },
      });
    });
  });

  describe('Campaign Validation & Pessimistic Concurrency Redemption (Phase 3 Engine)', () => {
    it('validates percentage campaign and bounds discount by maxDiscountAmount', async () => {
      mockPrisma.promotionalCampaign.findUnique.mockResolvedValue({
        id: 'camp-p1',
        code: 'SAVE20',
        isActive: true,
        discountType: DiscountType.PERCENTAGE,
        discountValue: 20,
        maxDiscountAmount: 500,
        minBookingAmount: 1000,
        budget: 10000,
        spentBudget: 1000,
        maxRedemptions: 100,
        redemptionCount: 10,
        startDate: new Date('2026-01-01'),
        endDate: new Date('2026-12-31'),
      });

      const res = await service.validateCampaign({
        code: 'SAVE20',
        bookingAmount: 4000,
      });

      expect(res.isValid).toBe(true);
      // 20% of 4000 is 800, capped at maxDiscountAmount 500
      expect(res.discountAmount).toBe(500);
      expect(res.netPayable).toBe(3500);
    });

    it('rejects validation when minimum booking amount is not met', async () => {
      mockPrisma.promotionalCampaign.findUnique.mockResolvedValue({
        id: 'camp-p1',
        code: 'MIN2000',
        isActive: true,
        discountType: DiscountType.FLAT,
        discountValue: 200,
        minBookingAmount: 2000,
      });

      await expect(
        service.validateCampaign({
          code: 'MIN2000',
          bookingAmount: 1500,
        }),
      ).rejects.toThrow('Minimum booking amount of ₹2000 required for this promotion.');
    });

    it('redeems campaign with row lock, increments redemptions & spend atomically', async () => {
      mockPrisma.bookingAttribution.findUnique.mockResolvedValue(null);
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'camp-p1',
          code: 'FESTIVE500',
          isActive: true,
          discountType: DiscountType.FLAT,
          discountValue: 500,
          budget: 5000,
          spentBudget: 4000,
          maxRedemptions: 10,
          redemptionCount: 8,
          minBookingAmount: 1000,
        },
      ]);
      mockPrisma.promotionalCampaign.update.mockResolvedValue({ id: 'camp-p1' });

      const redemption = await service.redeemCampaign({
        code: 'FESTIVE500',
        bookingId: 'booking-202',
        bookingAmount: 2500,
        customerId: 'user-101',
      });

      expect(redemption.success).toBe(true);
      expect(redemption.discountAmount).toBe(500);
      expect(mockPrisma.promotionalCampaign.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'camp-p1' },
          data: expect.objectContaining({
            redemptionCount: { increment: 1 },
          }),
        }),
      );
    });

    it('automatically deactivates campaign when redemption exhausts remaining budget', async () => {
      mockPrisma.bookingAttribution.findUnique.mockResolvedValue(null);
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'camp-exhaust',
          code: 'LAST500',
          isActive: true,
          discountType: DiscountType.FLAT,
          discountValue: 500,
          budget: 5000,
          spentBudget: 4500, // + 500 = 5000 (exhausted)
          maxRedemptions: 50,
          redemptionCount: 9,
          minBookingAmount: 1000,
        },
      ]);
      mockPrisma.promotionalCampaign.update.mockResolvedValue({ id: 'camp-exhaust' });

      const redemption = await service.redeemCampaign({
        code: 'LAST500',
        bookingId: 'booking-203',
        bookingAmount: 2000,
        customerId: 'user-102',
      });

      expect(redemption.success).toBe(true);
      expect(mockPrisma.promotionalCampaign.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            isActive: false, // Auto-exhausted
          }),
        }),
      );
    });
  });
});
