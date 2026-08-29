import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { LocationsService } from './locations.service';
import { VerificationStatus } from '@prisma/client';

describe('LocationsHubWorkflow (Phase 27.3)', () => {
  let service: LocationsService;
  let mockPrisma: any;
  let mockGeoService: any;
  let mockCacheService: any;
  let mockAuditLogService: any;

  beforeEach(() => {
    mockPrisma = {
      supportedCity: {
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      pickupHub: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
      },
    };

    mockGeoService = {
      calculateDistanceKm: jest.fn((lat1, lng1, lat2, lng2) => {
        const dLat = (lat2 - lat1) * 111.0;
        const dLng = (lng2 - lng1) * 111.0 * Math.cos((lat1 * Math.PI) / 180);
        return Math.sqrt(dLat * dLat + dLng * dLng);
      }),
    };

    mockCacheService = {
      getOrSet: jest.fn(async (key, fn) => fn()),
      set: jest.fn(),
      delete: jest.fn(),
      invalidatePattern: jest.fn(),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    service = new LocationsService(
      mockPrisma,
      mockGeoService,
      mockCacheService,
      mockAuditLogService,
    );
  });

  describe('Server-Authoritative Location & Coordinate Validation', () => {
    it('1 & 2. should reject invalid/out-of-range coordinates', async () => {
      await expect(service.resolveCurrentLocation(95.0, 72.87)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.resolveCurrentLocation(19.07, -195.0)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.resolveCurrentLocation(NaN, 72.87)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('1 & 3. should accurately resolve supported city and check 100km catchment radius', async () => {
      mockPrisma.supportedCity.findMany.mockResolvedValue([
        { id: 'c1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.076, longitude: 72.8777, isActive: true },
        { id: 'c2', name: 'Pune', state: 'Maharashtra', latitude: 18.5204, longitude: 73.8567, isActive: true },
      ]);
      mockPrisma.pickupHub.findMany.mockResolvedValue([
        {
          id: 'h1',
          name: 'Bandra BKC Hub',
          locality: 'BKC',
          city: 'Mumbai',
          latitude: 19.065,
          longitude: 72.868,
          serviceRadiusKm: 20.0,
          operatingHours: '06:00 - 23:00',
          isActive: true,
        },
      ]);
      mockPrisma.vendor.findMany.mockResolvedValue([]);

      // Customer in Bandra (19.06, 72.86)
      const res = await service.resolveCurrentLocation(19.06, 72.86);

      expect(res.nearestCity.name).toBe('Mumbai');
      expect(res.nearestCity.isWithinOperationalRange).toBe(true);
      expect(res.suggestedPickupLocations.length).toBeGreaterThan(0);
      expect(res.suggestedPickupLocations[0].name).toBe('Bandra BKC Hub');
      expect(res.suggestedPickupLocations[0].isWithinServiceRadius).toBe(true);
    });

    it('3. should mark isWithinOperationalRange=false for location far from any supported city', async () => {
      mockPrisma.supportedCity.findMany.mockResolvedValue([
        { id: 'c1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.076, longitude: 72.8777, isActive: true },
      ]);
      mockPrisma.pickupHub.findMany.mockResolvedValue([]);
      mockPrisma.vendor.findMany.mockResolvedValue([]);

      // Point in remote desert (26.0, 71.0) ~900km from Mumbai
      const res = await service.resolveCurrentLocation(26.0, 71.0);

      expect(res.nearestCity.name).toBe('Mumbai');
      expect(res.nearestCity.isWithinOperationalRange).toBe(false);
      expect(res.nearestCity.distanceKm).toBeGreaterThan(100);
    });
  });

  describe('Pickup Hub Vendor Isolation & Lifecycle Management', () => {
    it('4 & 17. should allow vendor to create hub and isolate vendor hub mutations', async () => {
      mockPrisma.vendor.findUnique.mockResolvedValue({ id: 'v1', userId: 'user-v1' });
      mockPrisma.pickupHub.create.mockImplementation((args: any) => ({
        id: 'new-hub-1',
        ...args.data,
      }));

      const created = await service.createPickupHub('user-v1', {
        name: 'Hiranandani Hub',
        address: 'Central Ave, Powai',
        city: 'Mumbai',
        latitude: 19.119,
        longitude: 72.905,
        serviceRadiusKm: 25.0,
      });

      expect(created.id).toBe('new-hub-1');
      expect(created.vendorId).toBe('v1');
      expect(mockCacheService.invalidatePattern).toHaveBeenCalledWith('cache:hubs:*');
    });

    it('17. should forbid Vendor B from updating or deleting Vendor A hub', async () => {
      mockPrisma.pickupHub.findUnique.mockResolvedValue({
        id: 'hub-123',
        vendorId: 'v1',
        vendor: { userId: 'user-vendor-1' },
        cars: [],
      });

      // Vendor 2 attempts mutation
      await expect(
        service.updatePickupHub('user-vendor-2', 'hub-123', { name: 'Hijacked' }, false),
      ).rejects.toThrow(ForbiddenException);

      await expect(
        service.deletePickupHub('user-vendor-2', 'hub-123', false),
      ).rejects.toThrow(ForbiddenException);
    });

    it('5. should deactivate instead of hard delete if active cars are assigned', async () => {
      mockPrisma.pickupHub.findUnique.mockResolvedValue({
        id: 'hub-123',
        vendorId: 'v1',
        vendor: { userId: 'user-vendor-1' },
        cars: [{ id: 'car-1' }, { id: 'car-2' }],
      });
      mockPrisma.pickupHub.update.mockResolvedValue({ id: 'hub-123', isActive: false });

      const res = await service.deletePickupHub('user-vendor-1', 'hub-123', false);

      expect(res.message).toContain('deactivated because active vehicles are assigned');
      expect(mockPrisma.pickupHub.update).toHaveBeenCalledWith({
        where: { id: 'hub-123' },
        data: { isActive: false },
      });
    });
  });

  describe('Admin City & Location Management with RBAC & Audit Logging', () => {
    it('16. should allow admin to create and update supported cities with audit logging', async () => {
      mockPrisma.supportedCity.create.mockResolvedValue({
        id: 'city-new',
        name: 'Ahmedabad',
        state: 'Gujarat',
        latitude: 23.0225,
        longitude: 72.5714,
        isActive: true,
      });

      const city = await service.adminCreateSupportedCity('admin-user-1', {
        name: 'Ahmedabad',
        state: 'Gujarat',
        latitude: 23.0225,
        longitude: 72.5714,
      });

      expect(city.name).toBe('Ahmedabad');
      expect(mockCacheService.delete).toHaveBeenCalledWith('cache:cities:all');
      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin-user-1',
        'CITY_CREATED',
        'SupportedCity',
        'city-new',
        expect.objectContaining({ name: 'Ahmedabad' }),
      );
    });
  });
});
