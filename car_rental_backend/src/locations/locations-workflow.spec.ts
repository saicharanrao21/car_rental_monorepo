import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { VerificationStatus } from '@prisma/client';

describe('Phase 27.2 — Location & Current Location Workflow Integration Tests', () => {
  let service: LocationsService;
  let prisma: any;
  let mockRedis: any;

  const mockCities = [
    {
      id: 'city_mumbai',
      name: 'Mumbai',
      state: 'Maharashtra',
      latitude: 19.076,
      longitude: 72.8777,
      isActive: true,
    },
    {
      id: 'city_pune',
      name: 'Pune',
      state: 'Maharashtra',
      latitude: 18.5204,
      longitude: 73.8567,
      isActive: true,
    },
    {
      id: 'city_hyderabad',
      name: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.385,
      longitude: 78.4867,
      isActive: true,
    },
  ];

  const mockVendors = [
    {
      id: 'v_bandra',
      businessName: 'Bandra Zoom Rentals',
      locality: 'Bandra West',
      city: 'Mumbai',
      latitude: 19.0596,
      longitude: 72.8295,
      verificationStatus: VerificationStatus.VERIFIED,
    },
    {
      id: 'v_andheri',
      businessName: 'Andheri Speed Hub',
      locality: 'Andheri East',
      city: 'Mumbai',
      latitude: 19.1136,
      longitude: 72.8697,
      verificationStatus: VerificationStatus.VERIFIED,
    },
  ];

  beforeEach(async () => {
    prisma = {
      supportedCity: {
        findMany: jest.fn().mockResolvedValue(mockCities),
      },
      vendor: {
        findMany: jest.fn().mockResolvedValue(mockVendors),
      },
    };

    mockRedis = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue('OK'),
      del: jest.fn().mockResolvedValue(1),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LocationsService,
        GeospatialService,
        RedisCacheService,
        { provide: PrismaService, useValue: prisma },
        { provide: REDIS_CLIENT, useValue: mockRedis },
      ],
    }).compile();

    service = module.get<LocationsService>(LocationsService);
  });

  describe('resolveCurrentLocation', () => {
    it('accurately resolves client coordinates in Mumbai to nearest city and nearby hubs', async () => {
      // Coordinate near Bandra, Mumbai
      const userLat = 19.06;
      const userLng = 72.83;

      const result = await service.resolveCurrentLocation(userLat, userLng);

      expect(result.detectedCoordinates).toEqual({ latitude: userLat, longitude: userLng });
      expect(result.nearestCity.name).toBe('Mumbai');
      expect(result.nearestCity.distanceKm).toBeLessThan(15);
      expect(result.nearestCity.isWithinOperationalRange).toBe(true);
      expect(result.suggestedPickupLocations.length).toBeGreaterThan(0);
      expect(result.suggestedPickupLocations[0].name).toBe('Bandra Zoom Rentals');
    });

    it('identifies coordinates far from any supported city as outside operational range', async () => {
      // Coordinates in Nagpur (~700km from Mumbai/Pune/Hyderabad)
      const nagpurLat = 21.1458;
      const nagpurLng = 79.0882;

      const result = await service.resolveCurrentLocation(nagpurLat, nagpurLng);

      expect(result.nearestCity.distanceKm).toBeGreaterThan(100);
      expect(result.nearestCity.isWithinOperationalRange).toBe(false);
    });

    it('rejects invalid coordinate inputs', async () => {
      await expect(service.resolveCurrentLocation(95, 72.8777)).rejects.toThrow(
        'Invalid coordinates',
      );
      await expect(service.resolveCurrentLocation(19.076, 200)).rejects.toThrow(
        'Invalid coordinates',
      );
    });
  });
});
