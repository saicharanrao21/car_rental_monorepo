import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Optional,
  Inject,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import { QUEUE_NAMES, JOB_TYPES } from '../queues/queue.constants';
import { TrackAnalyticsEventDto } from './dto/track-event.dto';
import { AnalyticsQueryDto } from './dto/analytics-query.dto';
import { BookingStatus, PaymentStatus, Prisma, Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
    @Optional() private readonly queueProducer?: QueueProducerService,
  ) {}

  private parseDateRange(dto?: AnalyticsQueryDto) {
    const end = dto?.endDate ? new Date(dto.endDate) : new Date();
    end.setHours(23, 59, 59, 999);

    const start = dto?.startDate
      ? new Date(dto.startDate)
      : new Date(Date.now() - 30 * 86400000);
    start.setHours(0, 0, 0, 0);

    return { start, end };
  }

  // ── 1. Event Ingestion & Async Pipeline ────────────────────────────────────

  async trackEvent(dto: TrackAnalyticsEventDto): Promise<{ success: boolean; eventId?: string }> {
    try {
      // 1. Idempotency Check
      if (dto.idempotencyKey) {
        const existing = await this.prisma.analyticsEvent.findUnique({
          where: { idempotencyKey: dto.idempotencyKey },
        });
        if (existing) {
          return { success: true, eventId: existing.id };
        }
      }

      // 2. Enqueue or write directly
      if (this.queueProducer) {
        await this.queueProducer.dispatchAnalyticsEvent(dto);
        return { success: true };
      }

      // Fallback: synchronous DB insert (non-blocking in catch)
      const event = await this.prisma.analyticsEvent.create({
        data: {
          eventType: dto.eventType,
          userId: dto.userId,
          vendorId: dto.vendorId,
          carId: dto.carId,
          bookingId: dto.bookingId,
          city: dto.city,
          sessionId: dto.sessionId,
          platform: dto.platform,
          source: dto.source || 'ORGANIC',
          metadata: dto.metadata || Prisma.JsonNull,
          idempotencyKey: dto.idempotencyKey,
        },
      });

      return { success: true, eventId: event.id };
    } catch (err: any) {
      this.logger.warn(`Analytics trackEvent error (suppressed to preserve business flow): ${err.message}`);
      return { success: false };
    }
  }

  // ── 2. Core Marketplace Overview & KPIs ───────────────────────────────────

  async getMarketplaceOverview(query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);
    const whereClause: any = {
      createdAt: { gte: start, lte: end },
    };

    if (query?.city) {
      whereClause.car = {
        vendor: {
          city: { equals: query.city, mode: 'insensitive' },
        },
      };
    }

    const [bookings, totalSearches, totalViews, activeCars, activeVendors, activeUsers] =
      await Promise.all([
        this.prisma.booking.findMany({
          where: whereClause,
          select: {
            id: true,
            totalFare: true,
            platformFee: true,
            netToVendor: true,
            refundAmount: true,
            status: true,
            createdAt: true,
          },
        }),
        this.prisma.analyticsEvent.count({
          where: {
            eventType: 'SEARCH_PERFORMED',
            createdAt: { gte: start, lte: end },
            city: query?.city ? { equals: query.city, mode: 'insensitive' } : undefined,
          },
        }),
        this.prisma.analyticsEvent.count({
          where: {
            eventType: 'CAR_VIEWED',
            createdAt: { gte: start, lte: end },
            city: query?.city ? { equals: query.city, mode: 'insensitive' } : undefined,
          },
        }),
        this.prisma.car.count({
          where: {
            isAvailable: true,
            vendor: query?.city ? { city: { equals: query.city, mode: 'insensitive' } } : undefined,
          },
        }),
        this.prisma.vendor.count({
          where: query?.city ? { city: { equals: query.city, mode: 'insensitive' } } : undefined,
        }),
        this.prisma.user.count({
          where: { role: Role.CUSTOMER },
        }),
      ]);

    let gmv = new Decimal(0);
    let platformRevenue = new Decimal(0);
    let vendorPayable = new Decimal(0);
    let refundTotal = new Decimal(0);
    let completedTrips = 0;
    let cancelledBookings = 0;

    for (const b of bookings) {
      if (b.status !== BookingStatus.CANCELLED) {
        gmv = gmv.add(b.totalFare);
        platformRevenue = platformRevenue.add(b.platformFee);
        vendorPayable = vendorPayable.add(b.netToVendor);
      }
      if (b.status === BookingStatus.COMPLETED) {
        completedTrips++;
      }
      if (b.status === BookingStatus.CANCELLED) {
        cancelledBookings++;
      }
      if (b.refundAmount) {
        refundTotal = refundTotal.add(b.refundAmount);
      }
    }

    const totalBookings = bookings.length;
    const cancellationRate = totalBookings > 0 ? (cancelledBookings / totalBookings) * 100 : 0;
    const conversionRate = totalSearches > 0 ? (totalBookings / totalSearches) * 100 : 0;
    const avgBookingValue = totalBookings > 0 ? gmv.toNumber() / totalBookings : 0;

    return {
      period: { start, end },
      grossMerchandiseValue: gmv.toNumber(),
      platformRevenue: platformRevenue.toNumber(),
      vendorPayable: vendorPayable.toNumber(),
      refundTotal: refundTotal.toNumber(),
      totalBookings,
      completedTrips,
      cancelledBookings,
      cancellationRate: Number(cancellationRate.toFixed(2)),
      totalSearches,
      totalViews,
      searchToBookingConversionRate: Number(conversionRate.toFixed(2)),
      avgBookingValue: Number(avgBookingValue.toFixed(2)),
      activeFleet: activeCars,
      activeVendors,
      totalCustomers: activeUsers,
    };
  }

  // ── 3. Customer Funnel Analysis ───────────────────────────────────────────

  async getCustomerFunnel(query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);
    const filter: Prisma.AnalyticsEventWhereInput = {
      createdAt: { gte: start, lte: end },
      city: query?.city ? { equals: query.city, mode: 'insensitive' as Prisma.QueryMode } : undefined,
    };

    const [
      appOpens,
      searches,
      carViews,
      bookingsStarted,
      bookingsCreated,
      paymentsSuccess,
      tripsCompleted,
    ] = await Promise.all([
      this.prisma.analyticsEvent.count({ where: { ...filter, eventType: 'APP_OPENED' } }),
      this.prisma.analyticsEvent.count({ where: { ...filter, eventType: 'SEARCH_PERFORMED' } }),
      this.prisma.analyticsEvent.count({ where: { ...filter, eventType: 'CAR_VIEWED' } }),
      this.prisma.analyticsEvent.count({ where: { ...filter, eventType: 'BOOKING_STARTED' } }),
      this.prisma.booking.count({ where: { createdAt: { gte: start, lte: end } } }),
      this.prisma.payment.count({ where: { status: PaymentStatus.PAID, createdAt: { gte: start, lte: end } } }),
      this.prisma.booking.count({ where: { status: BookingStatus.COMPLETED, updatedAt: { gte: start, lte: end } } }),
    ]);

    const baseCount = Math.max(1, appOpens > 0 ? appOpens : searches);

    const funnelStages = [
      { stage: 'App Open', count: appOpens, dropoffRate: 0 },
      {
        stage: 'Search Performed',
        count: searches,
        dropoffRate: appOpens > 0 ? Number((((appOpens - searches) / appOpens) * 100).toFixed(1)) : 0,
      },
      {
        stage: 'Car Details Viewed',
        count: carViews,
        dropoffRate: searches > 0 ? Number((((searches - carViews) / searches) * 100).toFixed(1)) : 0,
      },
      {
        stage: 'Booking Started',
        count: bookingsStarted,
        dropoffRate: carViews > 0 ? Number((((carViews - bookingsStarted) / carViews) * 100).toFixed(1)) : 0,
      },
      {
        stage: 'Booking Created',
        count: bookingsCreated,
        dropoffRate: bookingsStarted > 0 ? Number((((bookingsStarted - bookingsCreated) / bookingsStarted) * 100).toFixed(1)) : 0,
      },
      {
        stage: 'Payment Verified',
        count: paymentsSuccess,
        dropoffRate: bookingsCreated > 0 ? Number((((bookingsCreated - paymentsSuccess) / bookingsCreated) * 100).toFixed(1)) : 0,
      },
      {
        stage: 'Trip Completed',
        count: tripsCompleted,
        dropoffRate: paymentsSuccess > 0 ? Number((((paymentsSuccess - tripsCompleted) / paymentsSuccess) * 100).toFixed(1)) : 0,
      },
    ];

    return {
      period: { start, end },
      funnelStages,
      overallConversionRate: Number(((tripsCompleted / baseCount) * 100).toFixed(2)),
    };
  }

  // ── 4. Search & Discovery Intelligence ────────────────────────────────────

  async getSearchIntelligence(query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);

    const searches = await this.prisma.analyticsEvent.findMany({
      where: {
        eventType: 'SEARCH_PERFORMED',
        createdAt: { gte: start, lte: end },
        city: query?.city ? { equals: query.city, mode: 'insensitive' } : undefined,
      },
      select: {
        city: true,
        metadata: true,
        createdAt: true,
      },
    });

    const totalSearches = searches.length;
    let noResultSearches = 0;
    const citySearchMap = new Map<string, number>();

    for (const s of searches) {
      const city = s.city || 'Unknown';
      citySearchMap.set(city, (citySearchMap.get(city) || 0) + 1);

      if (s.metadata && (s.metadata as any).resultCount === 0) {
        noResultSearches++;
      }
    }

    const cityBreakdown = Array.from(citySearchMap.entries()).map(([city, count]) => ({
      city,
      searches: count,
      sharePercentage: totalSearches > 0 ? Number(((count / totalSearches) * 100).toFixed(1)) : 0,
    }));

    return {
      totalSearches,
      noResultSearches,
      noResultRate: totalSearches > 0 ? Number(((noResultSearches / totalSearches) * 100).toFixed(2)) : 0,
      cityBreakdown: cityBreakdown.sort((a, b) => b.searches - a.searches),
    };
  }

  // ── 5. City & Regional Intelligence ───────────────────────────────────────

  async getCityIntelligence(query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: { gte: start, lte: end },
      },
      include: {
        car: {
          include: { vendor: true },
        },
      },
    });

    const cityMap = new Map<string, { gmv: Decimal; bookings: number; completed: number; cancelled: number }>();

    for (const b of bookings) {
      const city = b.car?.vendor?.city || 'Unknown';
      const entry = cityMap.get(city) || {
        gmv: new Decimal(0),
        bookings: 0,
        completed: 0,
        cancelled: 0,
      };

      entry.bookings++;
      if (b.status !== BookingStatus.CANCELLED) {
        entry.gmv = entry.gmv.add(b.totalFare);
      }
      if (b.status === BookingStatus.COMPLETED) {
        entry.completed++;
      }
      if (b.status === BookingStatus.CANCELLED) {
        entry.cancelled++;
      }
      cityMap.set(city, entry);
    }

    return Array.from(cityMap.entries()).map(([city, data]) => ({
      city,
      gmv: data.gmv.toNumber(),
      totalBookings: data.bookings,
      completedTrips: data.completed,
      cancelledBookings: data.cancelled,
      cancellationRate: data.bookings > 0 ? Number(((data.cancelled / data.bookings) * 100).toFixed(1)) : 0,
    }));
  }

  // ── 6. Vehicle Intelligence ───────────────────────────────────────────────

  async getVehicleIntelligence(query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);

    const cars = await this.prisma.car.findMany({
      where: {
        id: query?.carId,
        vendorId: query?.vendorId,
      },
      include: {
        vendor: { select: { id: true, businessName: true, city: true } },
        bookings: {
          where: { createdAt: { gte: start, lte: end } },
          select: { totalFare: true, netToVendor: true, status: true },
        },
      },
    });

    return cars.map((car) => {
      const totalBookings = car.bookings.length;
      let revenue = new Decimal(0);
      let completed = 0;

      for (const b of car.bookings) {
        if (b.status !== BookingStatus.CANCELLED) {
          revenue = revenue.add(b.netToVendor);
        }
        if (b.status === BookingStatus.COMPLETED) {
          completed++;
        }
      }

      return {
        carId: car.id,
        brand: car.make,
        model: car.model,
        registrationNumber: car.registrationNumber,
        category: car.type,
        city: car.vendor?.city,
        vendorBusinessName: car.vendor?.businessName,
        totalBookings,
        completedTrips: completed,
        netRevenueEarned: revenue.toNumber(),
        isActive: car.isAvailable,
      };
    });
  }

  // ── 7. Vendor Intelligence & Risk ─────────────────────────────────────────

  async getVendorIntelligence(vendorId: string, query?: AnalyticsQueryDto) {
    const { start, end } = this.parseDateRange(query);

    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      include: {
        cars: true,
        bookings: {
          where: { createdAt: { gte: start, lte: end } },
          select: { totalFare: true, netToVendor: true, status: true, platformFee: true },
        },
        payouts: {
          where: { createdAt: { gte: start, lte: end } },
          select: { amount: true, status: true },
        },
      },
    });

    if (!vendor) {
      throw new NotFoundException('Vendor record not found.');
    }

    const totalBookings = vendor.bookings.length;
    let completedTrips = 0;
    let cancelledBookings = 0;
    let grossRevenue = new Decimal(0);
    let netEarned = new Decimal(0);

    for (const b of vendor.bookings) {
      if (b.status !== BookingStatus.CANCELLED) {
        grossRevenue = grossRevenue.add(b.totalFare);
        netEarned = netEarned.add(b.netToVendor);
      }
      if (b.status === BookingStatus.COMPLETED) completedTrips++;
      if (b.status === BookingStatus.CANCELLED) cancelledBookings++;
    }

    const cancellationRate = totalBookings > 0 ? (cancelledBookings / totalBookings) * 100 : 0;
    const acceptanceRate = totalBookings > 0 ? ((totalBookings - cancelledBookings) / totalBookings) * 100 : 100;

    // Deterministic Risk Score (0-100, where higher is safer)
    let riskScore = 100;
    if (cancellationRate > 20) riskScore -= 30;
    if (vendor.cars.filter((c) => c.isAvailable).length === 0) riskScore -= 20;

    return {
      vendorId: vendor.id,
      businessName: vendor.businessName,
      city: vendor.city,
      fleetSize: vendor.cars.length,
      activeFleet: vendor.cars.filter((c) => c.isAvailable).length,
      totalBookings,
      completedTrips,
      cancelledBookings,
      cancellationRate: Number(cancellationRate.toFixed(1)),
      acceptanceRate: Number(acceptanceRate.toFixed(1)),
      grossRevenue: grossRevenue.toNumber(),
      netEarned: netEarned.toNumber(),
      riskScore: Math.max(0, riskScore),
      riskStatus: riskScore >= 75 ? 'HEALTHY' : riskScore >= 50 ? 'MEDIUM_RISK' : 'HIGH_RISK',
    };
  }

  // ── 8. Customer Segmentation ──────────────────────────────────────────────

  async getCustomerSegmentation() {
    const customers = await this.prisma.user.findMany({
      where: { role: Role.CUSTOMER },
      include: {
        bookings: {
          select: { totalFare: true, status: true, createdAt: true },
        },
      },
    });

    const now = Date.now();
    const segmentCounts = {
      NEW: 0,
      ACTIVE: 0,
      REPEAT: 0,
      HIGH_VALUE: 0,
      AT_RISK: 0,
      DORMANT: 0,
    };

    for (const user of customers) {
      const bookingCount = user.bookings.length;
      const completedCount = user.bookings.filter((b) => b.status === BookingStatus.COMPLETED).length;
      const totalSpent = user.bookings.reduce((sum, b) => sum.add(b.totalFare), new Decimal(0)).toNumber();

      const lastBookingDate = user.bookings.length > 0
        ? new Date(Math.max(...user.bookings.map((b) => b.createdAt.getTime()))).getTime()
        : null;
      const daysSinceLastBooking = lastBookingDate ? (now - lastBookingDate) / 86400000 : 999;

      if (bookingCount === 0) {
        segmentCounts.NEW++;
      } else if (totalSpent >= 50000 || completedCount >= 5) {
        segmentCounts.HIGH_VALUE++;
      } else if (daysSinceLastBooking > 60) {
        segmentCounts.DORMANT++;
      } else if (daysSinceLastBooking > 30) {
        segmentCounts.AT_RISK++;
      } else if (completedCount > 1) {
        segmentCounts.REPEAT++;
      } else {
        segmentCounts.ACTIVE++;
      }
    }

    return {
      totalCustomers: customers.length,
      segments: segmentCounts,
    };
  }

  // ── 9. Transparent Marketplace Health Score ───────────────────────────────

  async getMarketplaceHealthScore() {
    const [overview, segmentation] = await Promise.all([
      this.getMarketplaceOverview(),
      this.getCustomerSegmentation(),
    ]);

    // 8 Sub-dimension calculations (max 100 total)
    // 1. Demand Health (15 pts) - Search volume & active users
    const demandScore = Math.min(15, (overview.totalSearches / 100) * 15);

    // 2. Supply Health (15 pts) - Active fleet & vendors
    const supplyScore = Math.min(15, (overview.activeFleet / 50) * 15);

    // 3. Conversion Health (15 pts) - Search to booking conversion
    const conversionScore = Math.min(15, (overview.searchToBookingConversionRate / 5) * 15);

    // 4. Reliability Health (15 pts) - Low cancellation rate
    const reliabilityScore = Math.max(0, 15 - (overview.cancellationRate / 100) * 15);

    // 5. Financial Health (15 pts) - Low refund rate & GMV positivity
    const refundRatio = overview.grossMerchandiseValue > 0
      ? overview.refundTotal / overview.grossMerchandiseValue
      : 0;
    const financialScore = Math.max(0, 15 - refundRatio * 15);

    // 6. Customer Retention (15 pts) - Repeat and High-Value customer ratios
    const totalCustomers = Math.max(1, segmentation.totalCustomers);
    const retentionRatio = (segmentation.segments.REPEAT + segmentation.segments.HIGH_VALUE) / totalCustomers;
    const retentionScore = Math.min(15, retentionRatio * 30);

    // 7. Base Operations (10 pts)
    const baseScore = 10;

    const overallHealthScore = Math.min(
      100,
      Math.round(
        demandScore +
        supplyScore +
        conversionScore +
        reliabilityScore +
        financialScore +
        retentionScore +
        baseScore,
      ),
    );

    return {
      overallHealthScore,
      healthGrade: overallHealthScore >= 80 ? 'EXCELLENT' : overallHealthScore >= 60 ? 'HEALTHY' : 'NEEDS_ATTENTION',
      dimensions: {
        demandScore: Number(demandScore.toFixed(1)),
        supplyScore: Number(supplyScore.toFixed(1)),
        conversionScore: Number(conversionScore.toFixed(1)),
        reliabilityScore: Number(reliabilityScore.toFixed(1)),
        financialScore: Number(financialScore.toFixed(1)),
        retentionScore: Number(retentionScore.toFixed(1)),
      },
    };
  }

  // ── 10. Financial Reconciliation Drift Check ───────────────────────────────

  async getFinancialAnalyticsComparison() {
    const [financePaymentAgg, analyticsGmvAgg, payoutAgg] = await Promise.all([
      this.prisma.payment.aggregate({
        where: { status: PaymentStatus.PAID },
        _sum: { amount: true },
      }),
      this.prisma.booking.aggregate({
        where: { status: { not: BookingStatus.CANCELLED } },
        _sum: { totalFare: true },
      }),
      this.prisma.payout.aggregate({
        where: { status: 'PAID' },
        _sum: { amount: true },
      }),
    ]);

    const transactionalPaidGmv = financePaymentAgg._sum.amount?.toNumber() || 0;
    const analyticsBookingGmv = analyticsGmvAgg._sum.totalFare?.toNumber() || 0;
    const totalPayoutsPaid = payoutAgg._sum.amount?.toNumber() || 0;

    const discrepancy = Math.abs(transactionalPaidGmv - analyticsBookingGmv);

    return {
      transactionalVerifiedRevenue: transactionalPaidGmv,
      analyticsBookingGmv,
      totalPayoutsPaid,
      driftAmount: Number(discrepancy.toFixed(2)),
      isSynchronized: discrepancy < 1.0,
      status: discrepancy < 1.0 ? 'MATCHED' : 'DRIFT_DETECTED',
    };
  }
}
