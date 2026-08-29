import { CarsService } from './cars.service';
import { SearchRankingService } from './search-ranking.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { CarCategory, FuelType, VerificationStatus } from '@prisma/client';
import { SortByOption } from './dto/cars-query.dto';

describe('SearchGeoDiscovery (Phase 27.3)', () => {
  let service: CarsService;
  let rankingService: SearchRankingService;
  let mockPrisma: any;
  let mockGeoService: any;
  let mockCacheService: any;
  let mockConfigService: any;

  beforeEach(() => {
    mockPrisma = {
      car: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      supportedCity: {
        findFirst: jest.fn(),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        }),
      },
      vendor: {
        findUnique: jest.fn(),
      },
    };

    mockGeoService = new GeospatialService();
    rankingService = new SearchRankingService(mockGeoService);

    mockCacheService = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(undefined),
      delete: jest.fn().mockResolvedValue(undefined),
      invalidatePattern: jest.fn().mockResolvedValue(undefined),
    };

    mockConfigService = {
      getSearchRankingConfig: jest.fn().mockResolvedValue({
        relevanceWeight: 0.35,
        distanceWeight: 0.35,
        ratingWeight: 0.20,
        availabilityWeight: 0.10,
        sponsoredBoostMultiplier: 1.30,
        featuredBoostMultiplier: 1.15,
      }),
    };

    service = new CarsService(
      mockPrisma,
      rankingService,
      mockGeoService,
      mockCacheService,
      mockConfigService,
    );
  });

  describe('Multi-City, Pickup Hub & ALL Search Coverage', () => {
    it('6. should filter inventory by specific city', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car-mumbai-1',
          make: 'Honda',
          model: 'City',
          pricePerDay: 2500,
          isAvailable: true,
          vendor: { id: 'v1', city: 'Mumbai', rating: 4.8, isSponsored: false },
          pickupHub: { id: 'hub-1', name: 'BKC Hub', city: 'Mumbai', latitude: 19.06, longitude: 72.86 },
        },
      ]);

      const result = await service.searchCars({ city: 'Mumbai' } as any, false);

      expect(mockPrisma.car.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            vendor: expect.objectContaining({
              city: { equals: 'Mumbai', mode: 'insensitive' },
            }),
          }),
        }),
      );
      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-mumbai-1');
    });

    it('7. should filter by specific pickupHubId', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car-hub-1',
          make: 'Hyundai',
          model: 'Creta',
          pricePerDay: 3200,
          isAvailable: true,
          vendor: { id: 'v1', city: 'Mumbai', rating: 4.9 },
          pickupHub: { id: 'hub-specific-123', name: 'Airport T2 Hub' },
        },
      ]);

      const result = await service.searchCars(
        { city: 'Mumbai', pickupHubId: 'hub-specific-123' } as any,
        false,
      );

      expect(mockPrisma.car.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            pickupHubId: 'hub-specific-123',
          }),
        }),
      );
      expect(result.data.length).toBe(1);
    });

    it('8 & 9. should execute nationwide ALL search with bounded pagination', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'c-mum',
          make: 'Tata',
          model: 'Nexon',
          pricePerDay: 2200,
          isAvailable: true,
          vendor: { id: 'v1', city: 'Mumbai', rating: 4.5 },
        },
        {
          id: 'c-pun',
          make: 'Maruti',
          model: 'Swift',
          pricePerDay: 1800,
          isAvailable: true,
          vendor: { id: 'v2', city: 'Pune', rating: 4.7 },
        },
      ]);

      const result = await service.searchCars({ city: 'ALL', page: 1, limit: 20 } as any, false);

      expect(result.data.length).toBe(2);
      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
    });

    it('14 & 17. should reject vehicle creation with unowned or inactive pickup hub', async () => {
      mockPrisma.vendor.findUnique.mockResolvedValue({ id: 'vendor-1', userId: 'user-1' });
      mockPrisma.pickupHub = {
        findUnique: jest.fn().mockResolvedValue({
          id: 'hub-alien',
          vendorId: 'vendor-OTHER',
          isActive: true,
        }),
      };

      await expect(
        service.createCar('user-1', {
          make: 'Toyota',
          model: 'Innova',
          year: 2023,
          type: CarCategory.SUV,
          fuelType: FuelType.DIESEL,
          seating: 7,
          isAC: true,
          registrationNumber: 'MH 02 AB 1234',
          pricePerKm: 15,
          pricePerDay: 4000,
          pricePerHour: 200,
          pickupHubId: 'hub-alien',
        }),
      ).rejects.toThrow('Invalid or inactive pickup hub specified.');
    });
  });

  describe('Geo Search, Nearest Radius & Distance Decay', () => {
    it('4 & 5. should calculate proximity from pickup hub and filter by radiusKm', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car-near',
          make: 'Tata',
          model: 'Harrier',
          pricePerDay: 3500,
          isAvailable: true,
          vendor: { id: 'v1', city: 'Mumbai', rating: 4.8 },
          pickupHub: { id: 'h1', latitude: 19.07, longitude: 72.87 }, // ~1.5km away
        },
        {
          id: 'car-far',
          make: 'Mahindra',
          model: 'XUV700',
          pricePerDay: 4200,
          isAvailable: true,
          vendor: { id: 'v2', city: 'Mumbai', rating: 4.9 },
          pickupHub: { id: 'h2', latitude: 19.45, longitude: 72.80 }, // ~45km away
        },
      ]);

      // Search within 10km radius from client (19.06, 72.87)
      const result = await service.searchCars(
        { lat: 19.06, lng: 72.87, radiusKm: 10 } as any,
        false,
      );

      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-near');
      expect(result.data[0].distanceKm).toBeDefined();
    });
  });

  describe('Marketplace Ranking, Availability Gate & Promotional Multipliers', () => {
    it('11. should NEVER rank or boost an unavailable car', () => {
      const cars = [
        {
          id: 'car-unavail',
          pricePerDay: 2000,
          isAvailable: false,
          vendor: { id: 'v1', rating: 5.0, isSponsored: true, boostExpiresAt: new Date(Date.now() + 100000) },
          isFeatured: true,
        },
        {
          id: 'car-avail',
          pricePerDay: 2500,
          isAvailable: true,
          vendor: { id: 'v2', rating: 4.2, isSponsored: false },
        },
      ];

      const scored = rankingService.rankVehicles(cars as any);

      const unavail = scored.find((s) => s.car.id === 'car-unavail');
      const avail = scored.find((s) => s.car.id === 'car-avail');

      expect(unavail!.scoreBreakdown.finalCompositeScore).toBe(0);
      expect(avail!.scoreBreakdown.finalCompositeScore).toBeGreaterThan(0);
      expect(scored[0].car.id).toBe('car-avail');
    });

    it('12 & 13. should boost sponsored & featured vehicles with capped fairness ceilings', () => {
      const futureDate = new Date(Date.now() + 3600000);
      const cars = [
        {
          id: 'car-organic',
          pricePerDay: 2500,
          isAvailable: true,
          vendor: { id: 'v1', rating: 4.5, isSponsored: false },
        },
        {
          id: 'car-sponsored',
          pricePerDay: 2500,
          isAvailable: true,
          vendor: { id: 'v2', rating: 4.5, isSponsored: true, boostExpiresAt: futureDate },
        },
      ];

      const scored = rankingService.rankVehicles(cars as any);

      const sponsored = scored.find((s) => s.car.id === 'car-sponsored')!;
      const organic = scored.find((s) => s.car.id === 'car-organic')!;

      expect(sponsored.scoreBreakdown.sponsoredBoost).toBe(1.25);
      expect(organic.scoreBreakdown.sponsoredBoost).toBe(1.0);
      expect(sponsored.scoreBreakdown.finalCompositeScore).toBeGreaterThan(
        organic.scoreBreakdown.finalCompositeScore,
      );
    });
  });

  describe('Redis Search Cache Key Isolation & Invalidation', () => {
    it('14. should cache public search and isolate keys based on search scope', async () => {
      mockPrisma.car.findMany.mockResolvedValue([]);

      await service.searchCars({ city: 'Mumbai', sortBy: SortByOption.RECOMMENDED } as any, false);

      expect(mockCacheService.set).toHaveBeenCalledTimes(1);
      const firstCallKey = mockCacheService.set.mock.calls[0][0];

      await service.searchCars({ city: 'Hyderabad', sortBy: SortByOption.RECOMMENDED } as any, false);

      const secondCallKey = mockCacheService.set.mock.calls[1][0];
      expect(firstCallKey).not.toEqual(secondCallKey);
    });
  });
});
