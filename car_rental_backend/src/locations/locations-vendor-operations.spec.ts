import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import {
  VendorLocationTypeEnum,
  VendorLocationStatusEnum,
  DeliveryPricingModelEnum,
} from './dto/vendor-location-operations.dto';
import { ForbiddenException, NotFoundException } from '@nestjs/common';

describe('LocationsService - Vendor Operations Suite (Phase 29.11)', () => {
  let service: LocationsService;
  let prisma: PrismaService;

  const mockVendor = {
    id: 'vendor_test_1',
    userId: 'user_vendor_1',
    businessName: 'DriveGo Hyderabad Fleet',
    city: 'Hyderabad',
    latitude: 17.4483,
    longitude: 78.3915,
  };

  const mockHubs = [
    {
      id: 'hub_1',
      vendorId: 'vendor_test_1',
      name: 'Hyderabad Main Yard',
      address: 'Plot 42, Madhapur, Hitec City',
      locality: 'Madhapur',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.4483,
      longitude: 78.3915,
      serviceRadiusKm: 25.0,
      contactPhone: '+91 9876543001',
      operatingHours: JSON.stringify({
        type: 'VENDOR_YARD',
        status: 'ACTIVE',
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: true,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 0,
        openingTime: '08:00',
        closingTime: '22:00',
        is24x7: false,
        assignedCarIds: ['car_1', 'car_2'],
      }),
      isActive: true,
      cars: [{ id: 'car_1' }, { id: 'car_2' }],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: 'hub_2',
      vendorId: 'vendor_test_1',
      name: 'RGIA Airport Hub',
      address: 'Arrivals Gate 3, RGIA Shamshabad',
      locality: 'Shamshabad',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.2403,
      longitude: 78.4294,
      serviceRadiusKm: 10.0,
      contactPhone: '+91 9876543002',
      operatingHours: JSON.stringify({
        type: 'AIRPORT',
        status: 'ACTIVE',
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: false,
        pickupFee: 300,
        returnFee: 0,
        oneWayFee: 250,
        openingTime: '00:00',
        closingTime: '23:59',
        is24x7: true,
        assignedCarIds: ['car_3'],
      }),
      isActive: true,
      cars: [{ id: 'car_3' }],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ];

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LocationsService,
        {
          provide: PrismaService,
          useValue: {
            vendor: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.userId === 'user_vendor_1' || where.id === 'vendor_test_1') {
                  return Promise.resolve(mockVendor);
                }
                return Promise.resolve(null);
              }),
            },
            pickupHub: {
              findMany: jest.fn().mockResolvedValue(mockHubs),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                const found = mockHubs.find((h) => h.id === where.id);
                return Promise.resolve(found || null);
              }),
              create: jest.fn().mockImplementation(({ data }) => {
                return Promise.resolve({
                  id: 'hub_new_3',
                  ...data,
                  cars: [],
                  createdAt: new Date(),
                  updatedAt: new Date(),
                });
              }),
              update: jest.fn().mockImplementation(({ where, data }) => {
                const found = mockHubs.find((h) => h.id === where.id) || mockHubs[0];
                return Promise.resolve({
                  ...found,
                  ...data,
                  cars: found.cars,
                  updatedAt: new Date(),
                });
              }),
              delete: jest.fn().mockResolvedValue({ id: 'hub_2' }),
            },
            car: {
              updateMany: jest.fn().mockResolvedValue({ count: 2 }),
            },
            booking: {
              findMany: jest.fn().mockResolvedValue([
                {
                  id: 'b1',
                  pickupLocation: 'Hyderabad Main Yard',
                  dropLocation: 'RGIA Airport Hub',
                  status: 'CONFIRMED',
                  deliveryType: 'NONE',
                },
              ]),
            },
          },
        },
        {
          provide: GeospatialService,
          useValue: {
            calculateDistanceKm: jest.fn((lat1, lon1, lat2, lon2) => 12.5),
          },
        },
        {
          provide: RedisCacheService,
          useValue: {
            get: jest.fn().mockResolvedValue(null),
            set: jest.fn().mockResolvedValue(true),
            delete: jest.fn().mockResolvedValue(true),
            invalidatePattern: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    service = module.get<LocationsService>(LocationsService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  describe('Vendor Location Management', () => {
    it('1. Retrieves all vendor locations with parsed metadata', async () => {
      const locations = await service.getVendorLocations('user_vendor_1');
      expect(locations).toHaveLength(2);
      expect(locations[0].name).toBe('Hyderabad Main Yard');
      expect(locations[0].type).toBe(VendorLocationTypeEnum.VENDOR_YARD);
      expect(locations[0].allowsPickup).toBe(true);
      expect(locations[0].allowsDelivery).toBe(true);
      expect(locations[1].type).toBe(VendorLocationTypeEnum.AIRPORT);
      expect(locations[1].is24x7).toBe(true);
      expect(locations[1].pickupFee).toBe(300);
    });

    it('2. Creates a new vendor location and associates assigned vehicles', async () => {
      const dto = {
        name: 'Secunderabad Branch',
        type: VendorLocationTypeEnum.BRANCH,
        address: 'MG Road, Secunderabad',
        city: 'Hyderabad',
        latitude: 17.4399,
        longitude: 78.4983,
        contactPhone: '+91 9876543003',
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: false,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 150,
        openingTime: '09:00',
        closingTime: '21:00',
        is24x7: false,
        assignedCarIds: ['car_4'],
      };

      const result = await service.createVendorLocation('user_vendor_1', dto);
      expect(result.name).toBe('Secunderabad Branch');
      expect(result.type).toBe(VendorLocationTypeEnum.BRANCH);
      expect(result.oneWayFee).toBe(150);
      expect(prisma.car.updateMany).toHaveBeenCalled();
    });

    it('3. Throws ForbiddenException when non-vendor attempts to access locations', async () => {
      await expect(service.getVendorLocations('unregistered_user')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('4. Updates location operating hours and capability policies', async () => {
      const updated = await service.updateVendorLocation('user_vendor_1', 'hub_1', {
        name: 'Hyderabad Main Yard (Updated)',
        is24x7: true,
        pickupFee: 50,
      });

      expect(updated.name).toBe('Hyderabad Main Yard (Updated)');
      expect(updated.is24x7).toBe(true);
      expect(updated.pickupFee).toBe(50);
    });
  });

  describe('Delivery Policy & Quote Engine', () => {
    it('5. Retrieves default delivery policy when none is persisted', async () => {
      const policy = await service.getVendorDeliveryPolicy('user_vendor_1');
      expect(policy.deliveryEnabled).toBe(true);
      expect(policy.maxDeliveryRadiusKm).toBe(15.0);
      expect(policy.pricingModel).toBe(DeliveryPricingModelEnum.FIXED);
      expect(policy.baseDeliveryFee).toBe(300.0);
    });

    it('6. Calculates server-authoritative delivery quote within radius', async () => {
      const quote = await service.calculateDeliveryQuote({
        vendorId: 'vendor_test_1',
        customerLatitude: 17.4400,
        customerLongitude: 78.3800,
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.distanceKm).toBe(12.5);
      expect(quote.deliveryFee).toBe(300);
      expect(quote.estimatedMinutes).toBeGreaterThan(0);
    });

    it('7. Rejects delivery quote outside maximum delivery radius', async () => {
      jest.spyOn(service as any, 'calculateHaversine').mockReturnValue(45.0);
      const geo = (service as any).geoService;
      geo.calculateDistanceKm.mockReturnValue(45.0);

      const quote = await service.calculateDeliveryQuote({
        vendorId: 'vendor_test_1',
        customerLatitude: 17.8000,
        customerLongitude: 78.9000,
      });

      expect(quote.isAvailable).toBe(false);
      expect(quote.reason).toContain('exceeds vendor\'s maximum delivery radius');
    });
  });

  describe('Pickup / Return Compatibility Matrix & Summary', () => {
    it('8. Generates supported pickup/return matrix with one-way surcharges', async () => {
      const matrix = await service.getVendorLocationMatrix('user_vendor_1');
      expect(matrix).toHaveLength(4); // 2x2 combinations
      const oneWay = matrix.find(
        (m: any) => m.pickupLocationId === 'hub_1' && m.returnLocationId === 'hub_2',
      );
      expect(oneWay).toBeDefined();
      expect(oneWay.isSupported).toBe(true);
      expect(oneWay.oneWaySurcharge).toBe(250);
    });

    it('9. Aggregates operations summary for Command Center', async () => {
      const summary = await service.getVendorLocationOperationsSummary('user_vendor_1');
      expect(summary.locations.length).toBeGreaterThan(0);
      expect(summary.totalTodayPickups).toBeGreaterThan(0);
      expect(summary.totalTodayReturns).toBeGreaterThan(0);
      expect(summary.totalDeliveryRequests).toBeGreaterThan(0);
    });

    it('10. Provides public transport catalog for airports and stations', async () => {
      const catalog = await service.getPublicLocationCatalog('Hyderabad');
      expect(catalog.length).toBeGreaterThan(0);
      expect(catalog.some((c) => c.type === VendorLocationTypeEnum.AIRPORT)).toBe(true);
      expect(catalog.some((c) => c.type === VendorLocationTypeEnum.RAILWAY_STATION)).toBe(true);
    });
  });
});
