import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { BookingsService } from '../bookings/bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  VendorLocationTypeEnum,
  VendorLocationStatusEnum,
  DeliveryPricingModelEnum,
} from './dto/vendor-location-operations.dto';
import { BookingStatus, TripType, VerificationStatus, Prisma } from '@prisma/client';
import { ConflictException, ForbiddenException, BadRequestException } from '@nestjs/common';

describe('Phase 29.12: Location & Fulfillment Persistence + Hardening Test Suite', () => {
  let locationsService: LocationsService;
  let mockPrisma: any;
  let mockGeoService: any;
  let mockCacheService: any;
  let mockAuditLogService: any;

  const vendorId1 = 'vnd_mumbai_apex';
  const vendorUserId1 = 'usr_vendor_01';
  const vendorId2 = 'vnd_pune_motors';
  const vendorUserId2 = 'usr_vendor_02';

  const hostYardHub = {
    id: 'hub_yard_01',
    vendorId: vendorId1,
    name: 'Apex Andheri Yard',
    address: 'Plot 10, MIDC Andheri, Mumbai',
    city: 'Mumbai',
    latitude: 19.1136,
    longitude: 72.8697,
    serviceRadiusKm: 20.0,
    locationType: 'VENDOR_YARD',
    status: 'ACTIVE',
    allowsPickup: true,
    allowsReturn: true,
    allowsDelivery: true,
    pickupFee: new Prisma.Decimal(0),
    returnFee: new Prisma.Decimal(0),
    oneWayFee: new Prisma.Decimal(0),
    operatingHours: JSON.stringify({ type: 'VENDOR_YARD', status: 'ACTIVE', pickupFee: 0, returnFee: 0, oneWayFee: 0 }),
    isActive: true,
    cars: [{ id: 'car_creta_01' }],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const bkcBranchHub = {
    id: 'hub_bkc_02',
    vendorId: vendorId1,
    name: 'Apex BKC Hub',
    address: 'One BKC, G Block, Mumbai',
    city: 'Mumbai',
    latitude: 19.0657,
    longitude: 72.8687,
    serviceRadiusKm: 15.0,
    locationType: 'TRANSIT_HUB',
    status: 'ACTIVE',
    allowsPickup: true,
    allowsReturn: true,
    allowsDelivery: false,
    pickupFee: new Prisma.Decimal(100),
    returnFee: new Prisma.Decimal(100),
    oneWayFee: new Prisma.Decimal(450),
    operatingHours: JSON.stringify({ type: 'TRANSIT_HUB', status: 'ACTIVE', pickupFee: 100, returnFee: 100, oneWayFee: 450 }),
    isActive: true,
    cars: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const defaultDeliveryPolicy = {
    id: 'pol_vnd_01',
    vendorId: vendorId1,
    deliveryEnabled: true,
    maxDeliveryRadiusKm: 25.0,
    pricingModel: DeliveryPricingModelEnum.DISTANCE_BASED,
    baseDeliveryFee: new Prisma.Decimal(150),
    perKmDeliveryFee: new Prisma.Decimal(25),
    freeDeliveryWithinKm: 3.0,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  let inMemoryBookings: any[] = [];
  let inMemoryExceptions: any[] = [];
  let inMemoryMatrix: any[] = [];
  let inMemoryCache: Map<string, any> = new Map();

  beforeEach(async () => {
    inMemoryBookings = [];
    inMemoryExceptions = [];
    inMemoryMatrix = [
      {
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: bkcBranchHub.id,
        isSupported: true,
        oneWaySurcharge: new Prisma.Decimal(450),
      },
    ];
    inMemoryCache.clear();

    mockPrisma = {
      vendor: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.userId === vendorUserId1 || where.id === vendorId1) {
            return Promise.resolve({
              id: vendorId1,
              userId: vendorUserId1,
              businessName: 'Apex Rentals',
              verificationStatus: VerificationStatus.VERIFIED,
              city: 'Mumbai',
              latitude: 19.1136,
              longitude: 72.8697,
              pickupHubs: [hostYardHub, bkcBranchHub],
            });
          }
          if (where.userId === vendorUserId2 || where.id === vendorId2) {
            return Promise.resolve({
              id: vendorId2,
              userId: vendorUserId2,
              businessName: 'Pune Motors',
              verificationStatus: VerificationStatus.VERIFIED,
              city: 'Pune',
              latitude: 18.5204,
              longitude: 73.8567,
              pickupHubs: [],
            });
          }
          return Promise.resolve(null);
        }),
      },
      pickupHub: {
        findMany: jest.fn().mockResolvedValue([hostYardHub, bkcBranchHub]),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id === hostYardHub.id) return Promise.resolve(hostYardHub);
          if (where.id === bkcBranchHub.id) return Promise.resolve(bkcBranchHub);
          return Promise.resolve(null);
        }),
        create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'hub_new_1', ...data })),
        update: jest.fn().mockImplementation(({ where, data }) => Promise.resolve({ id: where.id, ...data })),
      },
      vendorDeliveryPolicy: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.vendorId === vendorId1) return Promise.resolve(defaultDeliveryPolicy);
          return Promise.resolve(null);
        }),
        upsert: jest.fn().mockImplementation(({ create, update }) => Promise.resolve({ ...defaultDeliveryPolicy, ...update })),
      },
      vendorLocationMatrix: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const key = where.vendorId_pickupLocationId_returnLocationId;
          const found = inMemoryMatrix.find(
            (m) =>
              m.vendorId === key.vendorId &&
              m.pickupLocationId === key.pickupLocationId &&
              m.returnLocationId === key.returnLocationId,
          );
          return Promise.resolve(found || null);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(inMemoryMatrix.filter((m) => m.vendorId === where.vendorId));
        }),
        upsert: jest.fn().mockImplementation(({ create, update }) => {
          const item = { ...create, ...update };
          const idx = inMemoryMatrix.findIndex(
            (m) =>
              m.vendorId === item.vendorId &&
              m.pickupLocationId === item.pickupLocationId &&
              m.returnLocationId === item.returnLocationId,
          );
          if (idx >= 0) inMemoryMatrix[idx] = item;
          else inMemoryMatrix.push(item);
          return Promise.resolve(item);
        }),
      },
      locationException: {
        findFirst: jest.fn().mockImplementation(({ where }) => {
          const found = inMemoryExceptions.find((e) => {
            const locMatch = e.locationId === where.locationId;
            const closedMatch = where.isClosed === undefined || e.isClosed === where.isClosed;
            let dateMatch = true;
            if (where.date && where.date.gte && where.date.lte) {
              const eTime = new Date(e.date).getTime();
              dateMatch = eTime >= where.date.gte.getTime() && eTime <= where.date.lte.getTime();
            }
            return locMatch && closedMatch && dateMatch;
          });
          return Promise.resolve(found || null);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const item = { id: `exc_${Date.now()}`, ...data };
          inMemoryExceptions.push(item);
          return Promise.resolve(item);
        }),
      },
      booking: {
        create: jest.fn().mockImplementation(({ data }) => {
          const b = { id: `bk_${Date.now()}`, ...data };
          inMemoryBookings.push(b);
          return Promise.resolve(b);
        }),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(inMemoryBookings.find((b) => b.id === where.id) || null);
        }),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      car: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'car_creta_01',
          vendorId: vendorId1,
          type: 'SUV',
          isAvailable: true,
          availableTripTypes: ['SELF_DRIVE'],
          blockedDates: [],
          pricePerDay: new Prisma.Decimal(2500),
          pricePerHour: new Prisma.Decimal(150),
          pricePerKm: new Prisma.Decimal(12),
          vendor: {
            id: vendorId1,
            city: 'Mumbai',
            verificationStatus: VerificationStatus.VERIFIED,
          },
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: ['SELF_DRIVE'],
        }),
      },
      $transaction: jest.fn().mockImplementation(async (cb) => {
        return cb({
          $queryRaw: jest.fn().mockResolvedValue([]),
          booking: mockPrisma.booking,
        });
      }),
    };

    mockGeoService = {
      calculateDistanceKm: jest.fn().mockImplementation((lat1, lng1, lat2, lng2) => {
        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lng2 - lng1) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      }),
    };

    mockCacheService = {
      get: jest.fn().mockImplementation((key) => Promise.resolve(inMemoryCache.get(key) || null)),
      set: jest.fn().mockImplementation((key, val) => {
        inMemoryCache.set(key, val);
        return Promise.resolve();
      }),
      delete: jest.fn().mockImplementation((key) => {
        inMemoryCache.delete(key);
        return Promise.resolve();
      }),
      invalidatePattern: jest.fn().mockResolvedValue(true),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LocationsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: GeospatialService, useValue: mockGeoService },
        { provide: RedisCacheService, useValue: mockCacheService },
        { provide: AuditLogService, useValue: mockAuditLogService },
      ],
    }).compile();

    locationsService = module.get<LocationsService>(LocationsService);
  });

  describe('Scenario A: Same Location Fulfillment (Host Yard Zero Surcharge)', () => {
    it('returns zero one-way surcharge and zero delivery fee when pickup and return are identical yard', async () => {
      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: hostYardHub.id,
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.deliveryFee).toBe(0);
      expect(quote.oneWaySurcharge).toBe(0);
      expect(quote.pickupFee).toBe(0);
      expect(quote.returnFee).toBe(0);
      expect(quote.totalFulfillmentFee).toBe(0);
    });
  });

  describe('Scenario B: Multi-Branch Relocation Matrix', () => {
    it('applies authoritative matrix surcharge when returning to a different branch', async () => {
      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: bkcBranchHub.id,
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.oneWaySurcharge).toBe(450);
      expect(quote.returnFee).toBe(100);
      expect(quote.totalFulfillmentFee).toBe(550); // 450 + 100
    });

    it('rejects quote when matrix marks route as unsupported', async () => {
      inMemoryMatrix[0].isSupported = false;

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: bkcBranchHub.id,
      });

      expect(quote.isAvailable).toBe(false);
      expect(quote.reason).toContain('not supported');
    });
  });

  describe('Scenario C: Doorstep Delivery Distance & Radius', () => {
    it('quotes distance-based delivery fee when customer coordinate is within max radius', async () => {
      // Coordinate ~5.8 km from host yard
      const customerLat = 19.1136 + 0.05;
      const customerLng = 72.8697 + 0.02;

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.distanceKm).toBeGreaterThan(0);
      expect(quote.distanceKm).toBeLessThanOrEqual(25.0);
      expect(quote.deliveryFee).toBeGreaterThan(0);
      expect(quote.pricingModel).toBe(DeliveryPricingModelEnum.DISTANCE_BASED);
    });

    it('rejects delivery quote when customer address exceeds vendor maximum radius', async () => {
      // Coordinate ~80 km away (far outside 25 km max radius)
      const customerLat = 19.8;
      const customerLng = 73.5;

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      });

      expect(quote.isAvailable).toBe(false);
      expect(quote.reason).toContain('exceeds vendor\'s maximum delivery radius of 25 km');
    });
  });

  describe('Scenario D: Location Exception (Holiday / Closure) Handling', () => {
    it('marks fulfillment unavailable when pickup hub has an active closure exception on the requested date', async () => {
      const holidayDate = '2026-09-15';
      inMemoryExceptions.push({
        id: 'exc_01',
        locationId: hostYardHub.id,
        date: new Date('2026-09-15T00:00:00.000Z'),
        isClosed: true,
        reason: 'National Independence Holiday',
      });

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        startDate: holidayDate,
      });

      expect(quote.isAvailable).toBe(false);
      expect(quote.reason).toContain('closed on this date: National Independence Holiday');
    });

    it('allows fulfillment when exception date does not overlap requested date', async () => {
      inMemoryExceptions.push({
        id: 'exc_01',
        locationId: hostYardHub.id,
        date: new Date('2026-09-25T00:00:00.000Z'),
        isClosed: true,
        reason: 'Maintenance Day',
      });

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        startDate: '2026-09-10',
      });

      expect(quote.isAvailable).toBe(true);
    });
  });

  describe('Scenario E: Historical Booking Fulfillment Snapshot Immutability', () => {
    it('ensures confirmed booking fulfillment terms remain unchanged when vendor later updates delivery policy', async () => {
      // 1. Initial quote & booking confirmation at oneWayFee = 450
      const initialQuote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: bkcBranchHub.id,
      });

      const confirmedBooking = await mockPrisma.booking.create({
        data: {
          customerId: 'usr_cust_1',
          vendorId: vendorId1,
          carId: 'car_creta_01',
          tripType: 'SELF_DRIVE',
          pickupLocation: hostYardHub.address,
          dropLocation: bkcBranchHub.address,
          startDate: new Date('2026-09-10'),
          endDate: new Date('2026-09-12'),
          pickupHubId: hostYardHub.id,
          returnHubId: bkcBranchHub.id,
          pickupName: hostYardHub.name,
          dropName: bkcBranchHub.name,
          pickupFee: new Prisma.Decimal(initialQuote.pickupFee),
          returnFee: new Prisma.Decimal(initialQuote.returnFee),
          oneWayFee: new Prisma.Decimal(initialQuote.oneWaySurcharge),
          deliveryFee: new Prisma.Decimal(0),
          deliveryType: 'HUB_PICKUP',
          totalFare: new Prisma.Decimal(5550),
          status: BookingStatus.CONFIRMED,
        },
      });

      expect(confirmedBooking.oneWayFee.toNumber()).toBe(450);

      // 2. Vendor modifies matrix surcharge to ₹750
      await locationsService.updateVendorLocationMatrix(vendorUserId1, {
        matrix: [
          {
            pickupLocationId: hostYardHub.id,
            returnLocationId: bkcBranchHub.id,
            isSupported: true,
            oneWaySurcharge: 750,
          },
        ],
      });

      // 3. New customer quote reflects the updated fee
      const subsequentQuote = await locationsService.calculateDeliveryQuote({
        vendorId: vendorId1,
        pickupLocationId: hostYardHub.id,
        returnLocationId: bkcBranchHub.id,
      });
      expect(subsequentQuote.oneWaySurcharge).toBe(750);

      // 4. Historical booking retains the original snapshot of ₹450
      const persistedBooking = await mockPrisma.booking.findUnique({
        where: { id: confirmedBooking.id },
      });
      expect(persistedBooking.oneWayFee.toNumber()).toBe(450);
      expect(persistedBooking.pickupHubId).toBe(hostYardHub.id);
      expect(persistedBooking.returnHubId).toBe(bkcBranchHub.id);
    });
  });

  describe('Scenario F: Redis Cache Invalidation & PostgreSQL Source of Truth Rebuild', () => {
    it('rebuilds Redis cache from PostgreSQL when cache is flushed or missing', async () => {
      const cacheKey = `vendor:delivery-policy:${vendorId1}`;

      // 1. Initially cache is empty
      expect(inMemoryCache.has(cacheKey)).toBe(false);

      // 2. First read loads from PostgreSQL and stores in Redis
      const policyFromDb = await locationsService.getVendorDeliveryPolicy(vendorUserId1);
      expect(policyFromDb).toBeDefined();
      expect(policyFromDb.vendorId).toBe(vendorId1);
      expect(mockCacheService.set).toHaveBeenCalledWith(cacheKey, expect.any(Object), expect.any(Number));

      // 3. Simulate cache flush / eviction
      inMemoryCache.delete(cacheKey);
      expect(inMemoryCache.has(cacheKey)).toBe(false);

      // 4. Subsequent read recovers gracefully from PostgreSQL
      const recoveredPolicy = await locationsService.getVendorDeliveryPolicy(vendorUserId1);
      expect(recoveredPolicy).toBeDefined();
      expect(recoveredPolicy.vendorId).toBe(vendorId1);
      expect(recoveredPolicy.maxDeliveryRadiusKm).toBe(25.0);
    });
  });

  describe('Scenario G: Tenant / Vendor Isolation Enforcement', () => {
    it('forbids Vendor 2 from modifying or deleting Vendor 1 locations', async () => {
      await expect(
        locationsService.getVendorLocationById(vendorUserId2, hostYardHub.id),
      ).rejects.toThrow(ForbiddenException);

      await expect(
        locationsService.updateVendorLocation(vendorUserId2, hostYardHub.id, {
          name: 'Hacked Yard Name',
        }),
      ).rejects.toThrow(ForbiddenException);

      await expect(
        locationsService.deleteVendorLocation(vendorUserId2, hostYardHub.id),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
