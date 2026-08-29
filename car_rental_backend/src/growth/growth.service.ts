import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { CreatePromotionalCampaignDto } from './dto/create-promotional-campaign.dto';
import { UpdatePromotionalCampaignDto } from './dto/update-promotional-campaign.dto';
import { CreateSponsoredCampaignDto } from './dto/create-sponsored-campaign.dto';
import { CreateFeaturedListingDto } from './dto/create-featured-listing.dto';
import { RecordAttributionDto } from './dto/record-attribution.dto';
import { Prisma } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

@Injectable()
export class GrowthService {
  private readonly logger = new Logger(GrowthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    private readonly auditLogService: AuditLogService,
    private readonly systemConfigService: SystemConfigService,
  ) {}

  // ── 1. Promotional Campaigns ──────────────────────────────────────────────

  async createPromotionalCampaign(
    adminUserId: string,
    dto: CreatePromotionalCampaignDto,
  ) {
    const cleanCode = dto.code.trim().toUpperCase();

    const existing = await this.prisma.promotionalCampaign.findUnique({
      where: { code: cleanCode },
    });
    if (existing) {
      throw new BadRequestException(
        `Campaign with code ${cleanCode} already exists.`,
      );
    }

    const campaign = await this.prisma.promotionalCampaign.create({
      data: {
        code: cleanCode,
        name: dto.name,
        type: dto.type || 'GENERAL',
        city: dto.city,
        carCategory: dto.carCategory,
        discountType: dto.discountType,
        discountValue: new Decimal(dto.discountValue),
        maxDiscountAmount: dto.maxDiscountAmount
          ? new Decimal(dto.maxDiscountAmount)
          : null,
        minBookingAmount: dto.minBookingAmount
          ? new Decimal(dto.minBookingAmount)
          : null,
        budget: dto.budget ? new Decimal(dto.budget) : null,
        maxRedemptions: dto.maxRedemptions,
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        endDate: dto.endDate ? new Date(dto.endDate) : null,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'PROMOTIONAL_CAMPAIGN_CREATED',
      'PromotionalCampaign',
      campaign.id,
      { code: campaign.code, name: campaign.name },
    );

    return campaign;
  }

  async updatePromotionalCampaign(
    adminUserId: string,
    id: string,
    dto: UpdatePromotionalCampaignDto,
  ) {
    const existing = await this.prisma.promotionalCampaign.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException(`Campaign not found: ${id}`);
    }

    const updated = await this.prisma.promotionalCampaign.update({
      where: { id },
      data: {
        name: dto.name,
        type: dto.type,
        city: dto.city,
        carCategory: dto.carCategory,
        discountType: dto.discountType,
        discountValue:
          dto.discountValue !== undefined
            ? new Decimal(dto.discountValue)
            : undefined,
        maxDiscountAmount:
          dto.maxDiscountAmount !== undefined
            ? new Decimal(dto.maxDiscountAmount)
            : undefined,
        minBookingAmount:
          dto.minBookingAmount !== undefined
            ? new Decimal(dto.minBookingAmount)
            : undefined,
        budget: dto.budget !== undefined ? new Decimal(dto.budget) : undefined,
        maxRedemptions: dto.maxRedemptions,
        startDate: dto.startDate ? new Date(dto.startDate) : undefined,
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
        isActive: dto.isActive,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'PROMOTIONAL_CAMPAIGN_UPDATED',
      'PromotionalCampaign',
      id,
      { changes: dto },
    );

    return updated;
  }

  async getPromotionalCampaigns(page = 1, limit = 20, activeOnly = false) {
    const skip = (page - 1) * limit;
    const where = activeOnly ? { isActive: true } : {};

    const [campaigns, total] = await Promise.all([
      this.prisma.promotionalCampaign.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.promotionalCampaign.count({ where }),
    ]);

    return {
      campaigns,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ── 2. Sponsored Campaigns Foundation (No Fake Billing) ───────────────────

  async createSponsoredCampaign(
    userId: string,
    dto: CreateSponsoredCampaignDto,
    isAdmin = false,
  ) {
    // 1. Resolve vendor & verify vehicle ownership
    const car = await this.prisma.car.findUnique({
      where: { id: dto.carId },
      include: { vendor: true },
    });

    if (!car) {
      throw new NotFoundException(`Vehicle not found: ${dto.carId}`);
    }

    if (!isAdmin && car.vendor.userId !== userId) {
      throw new ForbiddenException(
        'You can only create sponsored campaigns for your own vehicles.',
      );
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (end <= start) {
      throw new BadRequestException('End date must be after start date.');
    }

    const growthConfig = await this.systemConfigService.getGrowthCampaignConfig();
    const maxBoost = growthConfig.sponsoredMaxBoostMultiplier || 2.0;
    const requestedMultiplier = dto.boostMultiplier || 1.25;
    const safeMultiplier = Math.min(Math.max(1.0, requestedMultiplier), maxBoost);

    const campaign = await this.prisma.sponsoredCampaign.create({
      data: {
        vendorId: car.vendorId,
        carId: car.id,
        city: dto.city,
        startDate: start,
        endDate: end,
        boostMultiplier: safeMultiplier,
        status: 'ACTIVE',
      },
    });

    // Invalidate search caches
    await this.cacheService.invalidatePattern('cache:search:cars:*');

    return campaign;
  }

  async getVendorSponsoredCampaigns(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    return this.prisma.sponsoredCampaign.findMany({
      where: { vendorId: vendor.id },
      include: {
        car: {
          select: {
            id: true,
            make: true,
            model: true,
            registrationNumber: true,
            isAvailable: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── 3. Featured Listings Foundation ───────────────────────────────────────

  async createFeaturedListing(
    adminUserId: string,
    dto: CreateFeaturedListingDto,
  ) {
    const car = await this.prisma.car.findUnique({
      where: { id: dto.carId },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle not found: ${dto.carId}`);
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (end <= start) {
      throw new BadRequestException('End date must be after start date.');
    }

    const listing = await this.prisma.featuredListing.create({
      data: {
        carId: car.id,
        city: dto.city,
        priority: dto.priority || 1,
        startDate: start,
        endDate: end,
        isActive: true,
      },
    });

    await this.cacheService.invalidatePattern('cache:search:cars:*');

    await this.auditLogService.log(
      adminUserId,
      'FEATURED_LISTING_CREATED',
      'FeaturedListing',
      listing.id,
      { carId: car.id, city: dto.city },
    );

    return listing;
  }

  async getFeaturedListings(city?: string) {
    const now = new Date();
    return this.prisma.featuredListing.findMany({
      where: {
        isActive: true,
        startDate: { lte: now },
        endDate: { gte: now },
        ...(city ? { city: { equals: city, mode: 'insensitive' } } : {}),
      },
      include: {
        car: {
          include: {
            vendor: {
              select: {
                id: true,
                businessName: true,
                rating: true,
                city: true,
              },
            },
          },
        },
      },
      orderBy: { priority: 'desc' },
    });
  }

  // ── 4. Attribution Tracking ───────────────────────────────────────────────

  async recordAttribution(dto: RecordAttributionDto) {
    const existing = await this.prisma.bookingAttribution.findUnique({
      where: { bookingId: dto.bookingId },
    });

    if (existing) {
      return existing;
    }

    const attribution = await this.prisma.bookingAttribution.create({
      data: {
        bookingId: dto.bookingId,
        source: dto.source || 'ORGANIC',
        campaignId: dto.campaignId,
        sponsoredCampaignId: dto.sponsoredCampaignId,
        referralAttributionId: dto.referralAttributionId,
        couponId: dto.couponId,
        metadata: dto.metadata || Prisma.JsonNull,
      },
    });

    // If linked to a sponsored campaign, increment bookings count atomically
    if (dto.sponsoredCampaignId) {
      await this.prisma.sponsoredCampaign.update({
        where: { id: dto.sponsoredCampaignId },
        data: { bookingsCount: { increment: 1 } },
      }).catch((err) => this.logger.warn(`Failed incrementing sponsored bookingsCount: ${err.message}`));
    }

    return attribution;
  }

  /**
   * Atomic aggregation hook for high-scale engagement events (clicks, impressions).
   */
  async recordEngagementEvent(
    type: 'IMPRESSION' | 'CLICK',
    sponsoredCampaignId?: string,
  ) {
    if (!sponsoredCampaignId) return;

    try {
      if (type === 'IMPRESSION') {
        await this.prisma.sponsoredCampaign.update({
          where: { id: sponsoredCampaignId },
          data: { impressionsCount: { increment: 1 } },
        });
      } else if (type === 'CLICK') {
        await this.prisma.sponsoredCampaign.update({
          where: { id: sponsoredCampaignId },
          data: { clicksCount: { increment: 1 } },
        });
      }
    } catch (err: any) {
      this.logger.warn(`Failed recording ${type} event: ${err?.message}`);
    }
  }
}
