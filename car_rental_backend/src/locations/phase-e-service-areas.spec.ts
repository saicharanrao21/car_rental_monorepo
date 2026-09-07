import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { ServiceAreasService } from './service-areas.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { SystemConfigValidator } from '../config-engine/system-config-validator';
import { ServiceAreaStatus, VerificationStatus } from '@prisma/client';

describe('Phase E: Service Areas & Vendor Coverage Engine', () => {
  let service: ServiceAreasService;
  let prismaMock: any;
  let geoService: GeospatialService;
  let cacheMock: any;
  let auditMock: any;
  let configMock: any;

  beforeEach(async () => {
    prismaMock = {
      supportedCity: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      serviceArea: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
      },
      vendorServiceArea: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        delete: jest.fn(),
        count: jest.fn(),
      },
    };

    geoService = new GeospatialService();

    cacheMock = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(true),
      delete: jest.fn().mockResolvedValue(true),
      invalidatePattern: jest.fn().mockResolvedValue(1),
    };

    auditMock = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    configMock = {
      getConfig: jest.fn().mockResolvedValue({
        defaultRadiusMeters: 5000,
        maxServiceRadiusMeters: 50000,
        minServiceRadiusMeters: 500,
        comingSoonCatchmentRadiusKm: 50,
        maxNearestAreasToSuggest: 5,
        strictVendorCoverageEnforcement: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ServiceAreasService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: GeospatialService, useValue: geoService },
        { provide: RedisCacheService, useValue: cacheMock },
        { provide: AuditLogService, useValue: auditMock },
        { provide: SystemConfigService, useValue: configMock },
      ],
    }).compile();

    service = module.get<ServiceAreasService>(ServiceAreasService);
  });

  describe('1. City Management', () => {
    it('should create a city with uppercase normalized name, default country and active status', async () => {
      prismaMock.supportedCity.findFirst.mockResolvedValue(null);
      prismaMock.supportedCity.create.mockImplementation(({ data }: any) => ({
        id: 'city-hyd-1',
        ...data,
      }));

      const result = await service.createCity(
        {
          name: '  Hyderabad  ',
          state: 'Telangana',
          latitude: 17.385,
          longitude: 78.4867,
        },
        'admin-user-1',
      );

      expect(result.name).toBe('Hyderabad');
      expect(result.normalizedName).toBe('HYDERABAD');
      expect(result.country).toBe('India');
      expect(result.status).toBe(ServiceAreaStatus.ACTIVE);
      expect(result.isActive).toBe(true);
      expect(auditMock.log).toHaveBeenCalledWith(
        'admin-user-1',
        'CITY_CREATED',
        'SupportedCity',
        'city-hyd-1',
        expect.any(Object),
      );
      expect(cacheMock.delete).toHaveBeenCalled();
    });

    it('should reject duplicate city creation with ConflictException', async () => {
      prismaMock.supportedCity.findFirst.mockResolvedValue({ id: 'existing-1', name: 'Hyderabad' });

      await expect(
        service.createCity(
          { name: 'hyderabad', state: 'Telangana', latitude: 17.38, longitude: 78.48 },
          'admin-user-1',
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('should update city status and synchronize isActive boolean', async () => {
      prismaMock.supportedCity.findUnique.mockResolvedValue({
        id: 'city-hyd-1',
        name: 'Hyderabad',
        status: ServiceAreaStatus.ACTIVE,
        isActive: true,
      });
      prismaMock.supportedCity.update.mockResolvedValue({
        id: 'city-hyd-1',
        name: 'Hyderabad',
        status: ServiceAreaStatus.INACTIVE,
        isActive: false,
      });

      const updated = await service.setCityStatus(
        'city-hyd-1',
        ServiceAreaStatus.INACTIVE,
        'admin-user-1',
        'Temporarily shutting down operations',
      );

      expect(updated.status).toBe(ServiceAreaStatus.INACTIVE);
      expect(updated.isActive).toBe(false);
      expect(auditMock.log).toHaveBeenCalledWith(
        'admin-user-1',
        'CITY_STATUS_CHANGED',
        'SupportedCity',
        'city-hyd-1',
        expect.objectContaining({
          previousStatus: ServiceAreaStatus.ACTIVE,
          newStatus: ServiceAreaStatus.INACTIVE,
          reason: 'Temporarily shutting down operations',
        }),
      );
    });
  });

  describe('2. Service Area Management', () => {
    it('should create service area when valid and inside platform radius bounds', async () => {
      prismaMock.supportedCity.findUnique.mockResolvedValue({
        id: 'city-hyd-1',
        name: 'Hyderabad',
        status: ServiceAreaStatus.ACTIVE,
      });
      prismaMock.serviceArea.findUnique.mockResolvedValue(null);
      prismaMock.serviceArea.create.mockImplementation(({ data }: any) => ({
        id: 'area-madhapur-1',
        ...data,
        city: { name: 'Hyderabad' },
      }));

      const result = await service.createServiceArea(
        {
          cityId: 'city-hyd-1',
          name: 'Madhapur',
          latitude: 17.4483,
          longitude: 78.3915,
          radiusMeters: 6000,
          priority: 10,
        },
        'admin-user-1',
      );

      expect(result.name).toBe('Madhapur');
      expect(result.normalizedName).toBe('MADHAPUR');
      expect(result.radiusMeters).toBe(6000);
      expect(auditMock.log).toHaveBeenCalledWith(
        'admin-user-1',
        'SERVICE_AREA_CREATED',
        'ServiceArea',
        'area-madhapur-1',
        expect.any(Object),
      );
    });

    it('should reject service area creation exceeding max configured radius', async () => {
      prismaMock.supportedCity.findUnique.mockResolvedValue({
        id: 'city-hyd-1',
        name: 'Hyderabad',
        status: ServiceAreaStatus.ACTIVE,
      });
      prismaMock.serviceArea.findUnique.mockResolvedValue(null);

      await expect(
        service.createServiceArea(
          {
            cityId: 'city-hyd-1',
            name: 'Statewide',
            latitude: 17.44,
            longitude: 78.39,
            radiusMeters: 100000, // exceeds max 50000m
          },
          'admin-user-1',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should prevent activating service area if parent city is INACTIVE', async () => {
      prismaMock.serviceArea.findUnique.mockResolvedValue({
        id: 'area-1',
        name: 'Madhapur',
        status: ServiceAreaStatus.INACTIVE,
        city: { id: 'city-1', name: 'Hyderabad', status: ServiceAreaStatus.INACTIVE },
      });

      await expect(
        service.setServiceAreaStatus('area-1', ServiceAreaStatus.ACTIVE, 'admin-1'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('3. Vendor Coverage Management', () => {
    it('should assign vendor to service area and handle primary area uniqueness', async () => {
      prismaMock.vendor.findUnique.mockResolvedValue({
        id: 'vendor-1',
        businessName: 'Royal Cars Hyderabad',
      });
      prismaMock.serviceArea.findUnique.mockResolvedValue({
        id: 'area-1',
        name: 'Madhapur',
        city: { name: 'Hyderabad' },
      });
      prismaMock.vendorServiceArea.findUnique.mockResolvedValue(null);
      prismaMock.vendorServiceArea.create.mockImplementation(({ data }: any) => ({
        id: 'vsa-1',
        ...data,
      }));

      const assignment = await service.assignVendorToServiceArea(
        {
          vendorId: 'vendor-1',
          serviceAreaId: 'area-1',
          isPrimary: true,
        },
        'admin-user-1',
      );

      expect(prismaMock.vendorServiceArea.updateMany).toHaveBeenCalledWith({
        where: { vendorId: 'vendor-1', isPrimary: true },
        data: { isPrimary: false },
      });
      expect(assignment.isPrimary).toBe(true);
      expect(auditMock.log).toHaveBeenCalledWith(
        'admin-user-1',
        'VENDOR_SERVICE_AREA_ASSIGNED',
        'VendorServiceArea',
        'vsa-1',
        expect.any(Object),
      );
    });

    it('should reject duplicate active vendor assignment with ConflictException', async () => {
      prismaMock.vendor.findUnique.mockResolvedValue({ id: 'vendor-1', businessName: 'Royal Cars' });
      prismaMock.serviceArea.findUnique.mockResolvedValue({ id: 'area-1', name: 'Madhapur', city: { name: 'Hyd' } });
      prismaMock.vendorServiceArea.findUnique.mockResolvedValue({
        id: 'vsa-1',
        isActive: true,
      });

      await expect(
        service.assignVendorToServiceArea(
          { vendorId: 'vendor-1', serviceAreaId: 'area-1' },
          'admin-user-1',
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('should remove vendor assignment and record audit log with reason', async () => {
      prismaMock.vendorServiceArea.findUnique.mockResolvedValue({
        id: 'vsa-1',
        vendor: { businessName: 'Royal Cars' },
        serviceArea: { name: 'Madhapur' },
      });
      prismaMock.vendorServiceArea.delete.mockResolvedValue({ id: 'vsa-1' });

      const res = await service.removeVendorFromServiceArea(
        'vendor-1',
        'area-1',
        'admin-1',
        'Vendor relocated hub',
      );

      expect(res.success).toBe(true);
      expect(prismaMock.vendorServiceArea.delete).toHaveBeenCalledWith({ where: { id: 'vsa-1' } });
      expect(auditMock.log).toHaveBeenCalledWith(
        'admin-1',
        'VENDOR_SERVICE_AREA_REMOVED',
        'VendorServiceArea',
        'vsa-1',
        expect.objectContaining({ reason: 'Vendor relocated hub' }),
      );
    });
  });

  describe('4. Server-Authoritative Location Resolution & Serviceability', () => {
    const mockActiveAreaMadhapur = {
      id: 'area-madhapur',
      name: 'Madhapur',
      status: ServiceAreaStatus.ACTIVE,
      latitude: 17.4483,
      longitude: 78.3915,
      radiusMeters: 5000,
      priority: 10,
      city: {
        id: 'city-hyd',
        name: 'Hyderabad',
        state: 'Telangana',
        country: 'India',
        latitude: 17.385,
        longitude: 78.4867,
        timezone: 'Asia/Kolkata',
      },
    };

    const mockComingSoonAreaGachibowli = {
      id: 'area-gachibowli',
      name: 'Gachibowli Financial District',
      status: ServiceAreaStatus.COMING_SOON,
      latitude: 17.4200,
      longitude: 78.3400,
      radiusMeters: 4000,
      priority: 5,
      city: {
        id: 'city-hyd',
        name: 'Hyderabad',
        state: 'Telangana',
        country: 'India',
        latitude: 17.385,
        longitude: 78.4867,
        timezone: 'Asia/Kolkata',
      },
    };

    it('should resolve SERVICEABLE when coordinate is inside active service area', async () => {
      prismaMock.serviceArea.findMany.mockResolvedValue([mockActiveAreaMadhapur]);
      prismaMock.vendorServiceArea.count.mockResolvedValue(8);

      // Coordinate near Inorbit Mall Madhapur (~1.2 km from center, inside 5000m radius)
      const res = await service.resolveServiceability({
        latitude: 17.436,
        longitude: 78.388,
      });

      expect(res.state).toBe('SERVICEABLE');
      expect(res.resolvedServiceArea?.name).toBe('Madhapur');
      expect(res.resolvedCity?.name).toBe('Hyderabad');
      expect(res.availableVendorsCount).toBe(8);
      expect(cacheMock.set).toHaveBeenCalled();
    });

    it('should resolve COMING_SOON with informative message and nearest active area when inside coming soon area', async () => {
      prismaMock.serviceArea.findMany.mockResolvedValue([
        mockActiveAreaMadhapur,
        mockComingSoonAreaGachibowli,
      ]);

      // Coordinate right in Gachibowli (within 4000m radius of Gachibowli)
      const res = await service.resolveServiceability({
        latitude: 17.421,
        longitude: 78.341,
      });

      expect(res.state).toBe('COMING_SOON');
      expect(res.resolvedServiceArea?.name).toBe('Gachibowli Financial District');
      expect(res.message).toContain('DriveGo is coming soon');
      expect(res.nearestActiveAreas.length).toBeGreaterThan(0);
      expect(res.nearestActiveAreas[0].name).toBe('Madhapur');
    });

    it('should resolve NO_MATCH with sorted nearest active suggestions when outside any service area', async () => {
      prismaMock.serviceArea.findMany.mockResolvedValue([
        mockActiveAreaMadhapur,
        mockComingSoonAreaGachibowli,
      ]);

      // Coordinate in Warangal (~140 km away)
      const res = await service.resolveServiceability({
        latitude: 17.9689,
        longitude: 79.5941,
      });

      expect(res.state).toBe('NO_MATCH');
      expect(res.message).toContain('not currently available at your exact location');
      expect(res.nearestActiveAreas.length).toBeGreaterThan(0);
      expect(res.nearestActiveAreas[0].distanceKm).toBeGreaterThan(100);
    });

    it('should reject invalid coordinates with BadRequestException', async () => {
      await expect(
        service.resolveServiceability({ latitude: 195.0, longitude: 78.0 }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('5. SystemConfigEngine location.rules validator', () => {
    it('should validate and accept valid location.rules payload', () => {
      const payload = {
        defaultRadiusMeters: 5000,
        maxServiceRadiusMeters: 40000,
        minServiceRadiusMeters: 500,
        comingSoonCatchmentRadiusKm: 60,
        maxNearestAreasToSuggest: 5,
        strictVendorCoverageEnforcement: true,
      };

      const validated = SystemConfigValidator.validate('location.rules', payload);
      expect(validated.defaultRadiusMeters).toBe(5000);
      expect(validated.maxServiceRadiusMeters).toBe(40000);
    });

    it('should throw BadRequestException on negative defaultRadiusMeters', () => {
      expect(() =>
        SystemConfigValidator.validate('location.rules', { defaultRadiusMeters: -100 }),
      ).toThrow(BadRequestException);
    });
  });
});
