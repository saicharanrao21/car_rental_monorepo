import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  VendorLocationTypeEnum,
  VendorLocationStatusEnum,
  LocationExceptionTypeEnum,
} from './dto/vendor-location-operations.dto';
import { ForbiddenException, NotFoundException } from '@nestjs/common';

describe('Phase 29.17: Location Exceptions & Fleet Assignment Engine', () => {
  let locationsService: LocationsService;
  let mockPrisma: any;
  let mockGeoService: any;
  let mockCacheService: any;
  let mockAuditLogService: any;

  const vendorId = 'vnd_mumbai_apex';
  const vendorUserId = 'usr_vendor_99';
  const otherUserId = 'usr_other_vendor';

  const hostYardHub = {
    id: 'hub_mumbai_central',
    vendorId,
    name: 'Andheri East Main Yard',
    address: 'Plot 42, Andheri-Kurla Road, Mumbai',
    city: 'Mumbai',
    latitude: 19.1136,
    longitude: 72.8697,
    serviceRadiusKm: 25.0,
    isActive: true,
    operatingHours: JSON.stringify({
      type: 'VENDOR_YARD',
      status: 'ACTIVE',
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: true,
      pickupFee: 0,
      returnFee: 0,
      openingTime: '08:00',
      closingTime: '22:00',
      assignedCarIds: ['car_1'],
    }),
    cars: [{ id: 'car_1' }],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockExceptions: any[] = [];

  beforeEach(async () => {
    mockExceptions.length = 0;

    mockPrisma = {
      vendor: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.userId === vendorUserId || where.id === vendorId) {
            return Promise.resolve({
              id: vendorId,
              userId: vendorUserId,
              businessName: 'Apex Rentals',
              city: 'Mumbai',
              latitude: 19.1136,
              longitude: 72.8697,
              deliveryEnabled: true,
              deliveryMaxKm: 25,
              deliveryFlatFee: 350,
              deliveryRatePerKm: 25,
              deliveryPricingModel: 'FIXED',
              pickupHubs: [hostYardHub],
            });
          }
          if (where.userId === otherUserId || where.id === 'vnd_other') {
            return Promise.resolve({ id: 'vnd_other', userId: otherUserId, businessName: 'Other Rentals', pickupHubs: [] });
          }
          return Promise.resolve(null);
        }),
      },
      pickupHub: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id === hostYardHub.id) return Promise.resolve(hostYardHub);
          return Promise.resolve(null);
        }),
        findMany: jest.fn().mockResolvedValue([hostYardHub]),
        update: jest.fn().mockImplementation(({ where, data }) => {
          return Promise.resolve({
            ...hostYardHub,
            ...data,
            cars: (data.assignedCarIds || []).map((id: string) => ({ id })),
          });
        }),
      },
      car: {
        updateMany: jest.fn().mockResolvedValue({ count: 2 }),
      },
      vendorDeliveryPolicy: {
        findUnique: jest.fn().mockResolvedValue({
          vendorId,
          deliveryEnabled: true,
          maxDeliveryRadiusKm: 25,
          pricingModel: 'FIXED',
          baseDeliveryFee: 350,
          perKmDeliveryFee: 25,
          freeDeliveryWithinKm: 5,
        }),
      },
      locationException: {
        create: jest.fn().mockImplementation(({ data }) => {
          const item = {
            id: `exc_${Date.now()}`,
            locationId: data.locationId,
            date: data.date,
            exceptionType: data.exceptionType,
            isClosed: data.isClosed,
            customOpeningTime: data.customOpeningTime,
            customClosingTime: data.customClosingTime,
            reason: data.reason,
            createdAt: new Date(),
          };
          mockExceptions.push(item);
          return Promise.resolve(item);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(mockExceptions.filter((e) => e.locationId === where.locationId));
        }),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const found = mockExceptions.find((e) => e.id === where.id);
          if (!found) return Promise.resolve(null);
          return Promise.resolve({ ...found, location: hostYardHub });
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(
            mockExceptions.find((e) => {
              const matchesLoc = e.locationId === where.locationId;
              const matchesClosed = where.isClosed !== undefined ? e.isClosed === where.isClosed : true;
              let matchesDate = true;
              if (where.date && where.date.gte && where.date.lte) {
                matchesDate = e.date >= where.date.gte && e.date <= where.date.lte;
              }
              return matchesLoc && matchesClosed && matchesDate;
            }) || null,
          );
        }),
        delete: jest.fn().mockImplementation(({ where }) => {
          const idx = mockExceptions.findIndex((e) => e.id === where.id);
          if (idx !== -1) mockExceptions.splice(idx, 1);
          return Promise.resolve({});
        }),
      },
    };

    mockGeoService = {
      calculateDistanceKm: jest.fn().mockReturnValue(8.5),
    };

    mockCacheService = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(true),
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

  describe('1. Location Exceptions Management (CRUD & Security)', () => {
    it('allows a vendor to schedule a holiday exception with closure', async () => {
      const created = await locationsService.createLocationException(
        vendorUserId,
        hostYardHub.id,
        {
          date: '2026-11-12',
          exceptionType: LocationExceptionTypeEnum.HOLIDAY,
          isClosed: true,
          reason: 'Diwali Festival Grand Holiday',
        },
      );

      expect(created).toBeDefined();
      expect(created.isClosed).toBe(true);
      expect(created.reason).toBe('Diwali Festival Grand Holiday');
      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        vendorUserId,
        'LOCATION_EXCEPTION_CREATED',
        'LocationException',
        created.id,
        expect.objectContaining({ reason: 'Diwali Festival Grand Holiday' }),
      );
    });

    it('rejects exception creation by an unauthorized vendor (Tenant Isolation)', async () => {
      await expect(
        locationsService.createLocationException(otherUserId, hostYardHub.id, {
          date: '2026-11-12',
          reason: 'Unauthorized attempt',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('retrieves all scheduled exceptions for a vendor location in chronological order', async () => {
      await locationsService.createLocationException(vendorUserId, hostYardHub.id, {
        date: '2026-11-12',
        reason: 'Diwali Holiday',
      });
      await locationsService.createLocationException(vendorUserId, hostYardHub.id, {
        date: '2026-12-25',
        reason: 'Christmas Holiday',
      });

      const list = await locationsService.getLocationExceptions(hostYardHub.id);
      expect(list.length).toBe(2);
      expect(list[0].reason).toBe('Diwali Holiday');
      expect(list[1].reason).toBe('Christmas Holiday');
    });

    it('allows deleting an exception by the owning vendor and prevents deletion by strangers', async () => {
      const exc = await locationsService.createLocationException(vendorUserId, hostYardHub.id, {
        date: '2026-09-15',
        reason: 'Yard Paving',
      });

      // Stranger attempt
      await expect(
        locationsService.deleteLocationException(otherUserId, exc.id),
      ).rejects.toThrow(ForbiddenException);

      // Owner delete
      const result = await locationsService.deleteLocationException(vendorUserId, exc.id);
      expect(result.message).toContain('deleted successfully');
      expect(mockExceptions.length).toBe(0);
    });
  });

  describe('2. Vehicle Fleet Location Assignment', () => {
    it('assigns specific fleet vehicles to a vendor branch/yard', async () => {
      const updated = await locationsService.updateVendorLocation(
        vendorUserId,
        hostYardHub.id,
        {
          assignedCarIds: ['car_creta_01', 'car_harrier_02', 'car_thar_03'],
        },
      );

      expect(updated).toBeDefined();
      expect(mockPrisma.car.updateMany).toHaveBeenCalledWith({
        where: { pickupHubId: hostYardHub.id, vendorId },
        data: { pickupHubId: null },
      });
      expect(mockPrisma.car.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['car_creta_01', 'car_harrier_02', 'car_thar_03'] }, vendorId },
        data: { pickupHubId: hostYardHub.id },
      });
      expect(mockCacheService.invalidatePattern).toHaveBeenCalledWith('cache:hubs:*');
    });
  });

  describe('3. Pre-booking Eligibility & Quote Validation with Exceptions', () => {
    it('rejects fulfillment quote when pickup date falls on a closed exception date', async () => {
      // Add a holiday exception on 2026-11-12
      mockExceptions.push({
        id: 'exc_diwali',
        locationId: hostYardHub.id,
        date: new Date('2026-11-12T12:00:00.000Z'),
        isClosed: true,
        reason: 'Diwali Closure',
      });

      const quote = await locationsService.calculateDeliveryQuote({
        vendorId,
        pickupLocationId: hostYardHub.id,
        customerLatitude: 19.1200,
        customerLongitude: 72.8700,
        pickupDate: '2026-11-12T10:00:00.000Z',
      });

      expect(quote.isAvailable).toBe(false);
      expect(quote.reason).toContain('closed on this date');
    });

    it('approves fulfillment quote when location has no closures on requested dates', async () => {
      const quote = await locationsService.calculateDeliveryQuote({
        vendorId,
        pickupLocationId: hostYardHub.id,
        customerLatitude: 19.1200,
        customerLongitude: 72.8700,
        pickupDate: '2026-11-15T10:00:00.000Z',
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.distanceKm).toBe(8.5);
    });
  });
});
