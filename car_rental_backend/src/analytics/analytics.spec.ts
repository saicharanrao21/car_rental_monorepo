import { AnalyticsService } from './analytics.service';
import { BookingStatus, PaymentStatus, Prisma, Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('AnalyticsService (Phase 27.7)', () => {
  let service: AnalyticsService;
  let mockPrisma: any;
  let mockCache: any;
  let mockSystemConfig: any;
  let mockQueueProducer: any;

  beforeEach(() => {
    mockPrisma = {
      analyticsEvent: {
        findUnique: jest.fn(),
        create: jest.fn(),
        count: jest.fn().mockResolvedValue(100),
        findMany: jest.fn().mockResolvedValue([]),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'b1',
            totalFare: new Decimal(10000),
            platformFee: new Decimal(1500),
            netToVendor: new Decimal(8500),
            refundAmount: null,
            status: BookingStatus.COMPLETED,
            createdAt: new Date(),
          },
          {
            id: 'b2',
            totalFare: new Decimal(5000),
            platformFee: new Decimal(750),
            netToVendor: new Decimal(4250),
            refundAmount: new Decimal(5000),
            status: BookingStatus.CANCELLED,
            createdAt: new Date(),
          },
        ]),
        count: jest.fn().mockResolvedValue(2),
        aggregate: jest.fn().mockResolvedValue({ _sum: { totalFare: new Decimal(15000) } }),
      },
      payment: {
        count: jest.fn().mockResolvedValue(1),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Decimal(15000) } }),
      },
      payout: {
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Decimal(8500) } }),
      },
      car: {
        count: jest.fn().mockResolvedValue(25),
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'car-1',
            make: 'Hyundai',
            model: 'Creta',
            registrationNumber: 'KA01AB1234',
            type: 'SUV',
            isAvailable: true,
            vendor: { id: 'v1', businessName: 'Speedy Rentals', city: 'Bangalore' },
            bookings: [
              { totalFare: new Decimal(10000), netToVendor: new Decimal(8500), status: BookingStatus.COMPLETED },
            ],
          },
        ]),
      },
      vendor: {
        count: jest.fn().mockResolvedValue(10),
        findUnique: jest.fn().mockResolvedValue({
          id: 'v1',
          businessName: 'Speedy Rentals',
          city: 'Bangalore',
          cars: [{ id: 'car-1', isAvailable: true }],
          bookings: [
            { totalFare: new Decimal(10000), netToVendor: new Decimal(8500), platformFee: new Decimal(1500), status: BookingStatus.COMPLETED },
          ],
          payouts: [{ amount: new Decimal(8500), status: 'PAID' }],
        }),
      },
      user: {
        count: jest.fn().mockResolvedValue(250),
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'u1',
            role: Role.CUSTOMER,
            bookings: [
              { totalFare: new Decimal(10000), status: BookingStatus.COMPLETED, createdAt: new Date() },
            ],
          },
          {
            id: 'u2',
            role: Role.CUSTOMER,
            bookings: [],
          },
        ]),
      },
    };

    mockCache = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue('OK'),
    };

    mockSystemConfig = {
      getAnalyticsConfig: jest.fn().mockResolvedValue({
        rawEventRetentionDays: 90,
        enableRealtimeEventTracking: true,
        aggregationIntervalMinutes: 60,
        churnInactivityDays: 45,
        vendorRiskInactivityDays: 30,
        alertPaymentFailureSpikeRate: 0.15,
        alertCancellationSpikeRate: 0.25,
      }),
    };

    mockQueueProducer = {
      dispatchAnalyticsEvent: jest.fn().mockResolvedValue(undefined),
    };

    service = new AnalyticsService(
      mockPrisma,
      mockCache,
      mockSystemConfig,
      mockQueueProducer,
    );
  });

  describe('1. Event Tracking & Idempotency', () => {
    it('should enqueue analytics event asynchronously to BullMQ without blocking', async () => {
      const result = await service.trackEvent({
        eventType: 'SEARCH_PERFORMED',
        city: 'Bangalore',
        idempotencyKey: 'search_evt_unique_123',
      });

      expect(result.success).toBe(true);
      expect(mockQueueProducer.dispatchAnalyticsEvent).toHaveBeenCalledWith(
        expect.objectContaining({ eventType: 'SEARCH_PERFORMED' }),
      );
    });

    it('should deduplicate event if idempotency key already exists in database', async () => {
      mockPrisma.analyticsEvent.findUnique.mockResolvedValue({
        id: 'evt-existing-1',
        eventType: 'CAR_VIEWED',
      });

      const result = await service.trackEvent({
        eventType: 'CAR_VIEWED',
        carId: 'car-123',
        idempotencyKey: 'evt_existing_key',
      });

      expect(result.success).toBe(true);
      expect(result.eventId).toBe('evt-existing-1');
      expect(mockQueueProducer.dispatchAnalyticsEvent).not.toHaveBeenCalled();
    });
  });

  describe('2. Core Marketplace Overview & KPIs', () => {
    it('should calculate GMV, platform revenue, vendor payable, and cancellation rate accurately', async () => {
      const overview = await service.getMarketplaceOverview();

      expect(overview.grossMerchandiseValue).toBe(10000); // 10,000 non-cancelled
      expect(overview.platformRevenue).toBe(1500);
      expect(overview.vendorPayable).toBe(8500);
      expect(overview.refundTotal).toBe(5000);
      expect(overview.totalBookings).toBe(2);
      expect(overview.completedTrips).toBe(1);
      expect(overview.cancelledBookings).toBe(1);
      expect(overview.cancellationRate).toBe(50); // 1/2 * 100
      expect(overview.activeFleet).toBe(25);
      expect(overview.activeVendors).toBe(10);
    });
  });

  describe('3. Customer Funnel Analysis', () => {
    it('should compute progressive conversion and drop-off rates across funnel stages', async () => {
      mockPrisma.analyticsEvent.count
        .mockResolvedValueOnce(500) // APP_OPENED
        .mockResolvedValueOnce(400) // SEARCH_PERFORMED
        .mockResolvedValueOnce(300) // CAR_VIEWED
        .mockResolvedValueOnce(150); // BOOKING_STARTED

      mockPrisma.booking.count
        .mockResolvedValueOnce(100) // Created
        .mockResolvedValueOnce(80); // Completed

      mockPrisma.payment.count.mockResolvedValueOnce(90); // Payments Success

      const funnel = await service.getCustomerFunnel();

      expect(funnel.funnelStages).toHaveLength(7);
      expect(funnel.funnelStages[0].stage).toBe('App Open');
      expect(funnel.funnelStages[0].count).toBe(500);
      expect(funnel.funnelStages[1].stage).toBe('Search Performed');
      expect(funnel.funnelStages[1].count).toBe(400);
      expect(funnel.overallConversionRate).toBe(16); // 80 / 500 * 100
    });
  });

  describe('4. Search Intelligence', () => {
    it('should calculate search volume, no-result rate, and city breakdown', async () => {
      mockPrisma.analyticsEvent.findMany.mockResolvedValue([
        { city: 'Bangalore', metadata: { resultCount: 15 }, createdAt: new Date() },
        { city: 'Bangalore', metadata: { resultCount: 0 }, createdAt: new Date() },
        { city: 'Mumbai', metadata: { resultCount: 8 }, createdAt: new Date() },
      ]);

      const searchIntel = await service.getSearchIntelligence();

      expect(searchIntel.totalSearches).toBe(3);
      expect(searchIntel.noResultSearches).toBe(1);
      expect(searchIntel.noResultRate).toBe(33.33);
      expect(searchIntel.cityBreakdown[0].city).toBe('Bangalore');
      expect(searchIntel.cityBreakdown[0].searches).toBe(2);
    });
  });

  describe('5. Vendor Intelligence & Isolation', () => {
    it('should generate isolated vendor metrics and deterministic risk rating', async () => {
      const vendorIntel = await service.getVendorIntelligence('v1');

      expect(vendorIntel.vendorId).toBe('v1');
      expect(vendorIntel.businessName).toBe('Speedy Rentals');
      expect(vendorIntel.fleetSize).toBe(1);
      expect(vendorIntel.completedTrips).toBe(1);
      expect(vendorIntel.grossRevenue).toBe(10000);
      expect(vendorIntel.riskStatus).toBe('HEALTHY');
      expect(vendorIntel.riskScore).toBe(100);
    });
  });

  describe('6. Customer Segmentation', () => {
    it('should segment customers deterministically into categories', async () => {
      const segmentation = await service.getCustomerSegmentation();

      expect(segmentation.totalCustomers).toBe(2);
      expect(segmentation.segments.NEW).toBe(1); // u2 has 0 bookings
      expect(segmentation.segments.ACTIVE).toBe(1); // u1 has 1 booking
    });
  });

  describe('7. Marketplace Health Score', () => {
    it('should compute an 8-dimensional health score bounded between 0 and 100', async () => {
      const health = await service.getMarketplaceHealthScore();

      expect(health.overallHealthScore).toBeGreaterThan(0);
      expect(health.overallHealthScore).toBeLessThanOrEqual(100);
      expect(health.dimensions).toHaveProperty('demandScore');
      expect(health.dimensions).toHaveProperty('supplyScore');
      expect(health.dimensions).toHaveProperty('conversionScore');
      expect(health.dimensions).toHaveProperty('financialScore');
    });
  });

  describe('8. Financial Reconciliation Drift Check', () => {
    it('should compare transactional verified revenue against analytics GMV and confirm synchronization', async () => {
      const reconciliation = await service.getFinancialAnalyticsComparison();

      expect(reconciliation.transactionalVerifiedRevenue).toBe(15000);
      expect(reconciliation.analyticsBookingGmv).toBe(15000);
      expect(reconciliation.driftAmount).toBe(0);
      expect(reconciliation.isSynchronized).toBe(true);
      expect(reconciliation.status).toBe('MATCHED');
    });
  });
});
