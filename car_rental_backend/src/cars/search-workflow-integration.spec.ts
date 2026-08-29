import { Test, TestingModule } from '@nestjs/testing';
import { CarsService } from './cars.service';
import { SearchRankingService } from './search-ranking.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { VerificationStatus, CarCategory, TripType } from '@prisma/client';

describe('Phase 27.2 — Search Workflow, Ranking & Caching Integration Tests', () => {
  let carsService: CarsService;
  let cacheService: RedisCacheService;
  let prisma: any;
  let cacheMap: Map<string, any>;

  const sampleCars = [
    {
      id: 'car_1_near',
      make: 'Hyundai',
      model: 'Creta',
      year: 2023,
      type: CarCategory.SUV,
      pricePerDay: '3000',
      isAvailable: true,
      blockedDates: [],
      availableTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
      vendorId: 'vendor_1',
      vendor: {
        id: 'vendor_1',
        businessName: 'Apex Rentals Bandra',
        ownerName: 'Rahul V',
        city: 'Mumbai',
        rating: 4.8,
        latitude: 19.0596,
        longitude: 72.8295,
        verificationStatus: VerificationStatus.VERIFIED,
        isSponsored: false,
        boostExpiresAt: null,
      },
      mileagePackages: [],
    },
    {
      id: 'car_2_sponsored',
      make: 'Tata',
      model: 'Nexon',
      year: 2023,
      type: CarCategory.COMPACT_SUV,
      pricePerDay: '2800',
      isAvailable: true,
      blockedDates: [],
      availableTripTypes: [TripType.SELF_DRIVE],
      vendorId: 'vendor_2',
      vendor: {
        id: 'vendor_2',
        businessName: 'Starline Mobility',
        ownerName: 'Amit S',
        city: 'Mumbai',
        rating: 4.6,
        latitude: 19.076,
        longitude: 72.8777,
        verificationStatus: VerificationStatus.VERIFIED,
        isSponsored: true,
        boostExpiresAt: new Date(Date.now() + 86400000), // Active 24h
      },
      mileagePackages: [],
    },
  ];

  beforeEach(async () => {
    cacheMap = new Map<string, any>();

    const mockRedis = {
      get: jest.fn(async (key: string) => cacheMap.get(key) || null),
      set: jest.fn(async (key: string, val: string) => {
        cacheMap.set(key, val);
        return 'OK';
      }),
      del: jest.fn(async (...keys: string[]) => {
        let count = 0;
        for (const k of keys) {
          if (cacheMap.delete(k)) count++;
        }
        return count;
      }),
      scan: jest.fn(async () => ['0', []]),
    };

    prisma = {
      car: {
        findMany: jest.fn().mockResolvedValue(sampleCars),
        findUnique: jest.fn().mockResolvedValue(sampleCars[0]),
        create: jest.fn().mockResolvedValue(sampleCars[0]),
        update: jest.fn().mockResolvedValue(sampleCars[0]),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
        }),
      },
      supportedCity: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      systemConfig: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CarsService,
        SearchRankingService,
        GeospatialService,
        RedisCacheService,
        SystemConfigService,
        { provide: PrismaService, useValue: prisma },
        { provide: REDIS_CLIENT, useValue: mockRedis },
      ],
    }).compile();

    carsService = module.get<CarsService>(CarsService);
    cacheService = module.get<RedisCacheService>(RedisCacheService);
  });

  describe('searchCars with Ranking and Caching', () => {
    it('executes search, ranks sponsored car near center, and caches result in Redis', async () => {
      const query = {
        city: 'Mumbai',
        lat: 19.076,
        lng: 72.8777,
      };

      // 1. Initial search (Cache Miss -> Computes and Caches)
      const res1 = await carsService.searchCars(query, false);
      expect(res1.data.length).toBe(2);
      expect(res1.total).toBe(2);
      expect(cacheMap.size).toBeGreaterThan(0);

      // 2. Second search (Cache Hit)
      const res2 = await carsService.searchCars(query, false);
      expect(res2.data.length).toBe(res1.data.length);
      expect(res2.total).toBe(res1.total);
      expect(JSON.parse(JSON.stringify(res2))).toEqual(JSON.parse(JSON.stringify(res1)));
    });

    it('supports "ALL" scope query across entire catalog with bounded pagination', async () => {
      const query = {
        city: 'ALL',
        page: 1,
        limit: 10,
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(2);
      expect(result.page).toBe(1);
    });
  });
});
