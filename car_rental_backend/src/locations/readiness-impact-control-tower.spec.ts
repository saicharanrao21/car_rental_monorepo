import { Test, TestingModule } from '@nestjs/testing';
import { ServiceAreasService } from './service-areas.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { AdminIntegrationsService } from '../integrations/admin/admin-integrations.service';
import { ProviderRegistryService } from '../integrations/registry/provider-registry.service';
import { IntegrationConfigService } from '../integrations/config/integration-config.service';
import { ProviderHealthService } from '../integrations/health/provider-health.service';
import { WebhookDispatcherService } from '../integrations/webhooks/webhook-dispatcher.service';
import { SecretVaultService } from '../integrations/security/secret-vault.service';
import { ProviderCatalogService } from '../integrations/catalog/provider-catalog.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { ConfigService } from '@nestjs/config';

describe('Readiness & Impact Previews + Notification Rules Control Tower Suite', () => {
  let serviceAreasService: ServiceAreasService;
  let adminIntegrationsService: AdminIntegrationsService;

  const mockPrisma = {
    supportedCity: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    serviceArea: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    booking: {
      findMany: jest.fn(),
      count: jest.fn(),
    },
    systemConfig: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
  };

  const mockAudit = {
    log: jest.fn().mockResolvedValue({}),
  };

  const mockGeo = {
    calculateHaversineDistanceKm: jest.fn().mockReturnValue(1.5),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ServiceAreasService,
        AdminIntegrationsService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        WebhookDispatcherService,
        SecretVaultService,
        ProviderCatalogService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: GeospatialService, useValue: mockGeo },
        { provide: AuditLogService, useValue: mockAudit },
        { provide: SystemConfigService, useValue: {} },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue(null) } },
      ],
    }).compile();

    serviceAreasService = module.get<ServiceAreasService>(ServiceAreasService);
    adminIntegrationsService = module.get<AdminIntegrationsService>(AdminIntegrationsService);
  });

  describe('Service Area Readiness Checklist', () => {
    it('evaluates readiness checklist and returns isReadyToLaunch = true when all criteria pass', async () => {
      mockPrisma.serviceArea.findUnique.mockResolvedValue({
        id: 'area-gachibowli',
        name: 'Gachibowli',
        status: 'ACTIVE',
        latitude: 17.44,
        longitude: 78.348,
        radiusMeters: 6000,
        city: { id: 'city-hyd', name: 'Hyderabad', status: 'ACTIVE', isActive: true },
        vendorAssignments: [
          {
            isActive: true,
            vendor: { id: 'v1', businessName: 'Apex Wheels', verificationStatus: 'APPROVED', isActive: true },
          },
        ],
        cars: [
          { id: 'c1', make: 'Hyundai', model: 'Creta', registrationNumber: 'TS09EA1234' },
        ],
      });

      const readiness = await serviceAreasService.getServiceAreaReadiness('area-gachibowli');

      expect(readiness.isReadyToLaunch).toBe(true);
      expect(readiness.checklist.length).toBe(4);
      expect(readiness.checklist.every((c) => c.passed)).toBe(true);
      expect(readiness.blockingReasons.length).toBe(0);
      expect(readiness.counts.activeVendorsCount).toBe(1);
      expect(readiness.counts.bookableCarsCount).toBe(1);
    });

    it('flags unreadiness when parent city is inactive or no cars are assigned', async () => {
      mockPrisma.serviceArea.findUnique.mockResolvedValue({
        id: 'area-madhapur',
        name: 'Madhapur',
        status: 'COMING_SOON',
        latitude: 17.448,
        longitude: 78.39,
        radiusMeters: 5000,
        city: { id: 'city-hyd', name: 'Hyderabad', status: 'INACTIVE', isActive: false },
        vendorAssignments: [],
        cars: [],
      });

      const readiness = await serviceAreasService.getServiceAreaReadiness('area-madhapur');

      expect(readiness.isReadyToLaunch).toBe(false);
      expect(readiness.blockingReasons.length).toBeGreaterThanOrEqual(2);
      expect(readiness.checklist.find((c) => c.criterion === 'PARENT_CITY_ACTIVE')?.passed).toBe(false);
      expect(readiness.checklist.find((c) => c.criterion === 'AVAILABLE_FLEET_INVENTORY')?.passed).toBe(false);
    });
  });

  describe('Service Area Impact Assessment', () => {
    it('evaluates downstream impact on vendors, cars, upcoming bookings and active trips', async () => {
      mockPrisma.serviceArea.findUnique.mockResolvedValue({
        id: 'area-gachibowli',
        name: 'Gachibowli',
        status: 'ACTIVE',
        city: { name: 'Hyderabad' },
        vendorAssignments: [
          {
            isActive: true,
            isPrimary: true,
            vendor: { id: 'v1', businessName: 'Apex Wheels', ownerName: 'John', phone: '+919999999999' },
          },
        ],
        cars: [
          { id: 'c1', make: 'Hyundai', model: 'Creta', registrationNumber: 'TS09EA1234', operationalStatus: 'OPERATIONAL' },
        ],
      });

      mockPrisma.booking.findMany.mockResolvedValue([
        {
          id: 'bk-01',
          startDate: new Date('2026-11-01'),
          endDate: new Date('2026-11-04'),
          status: 'CONFIRMED',
          totalFare: 5400,
          customer: { id: 'u1', name: 'Alice', phone: '+919876543210' },
        },
      ]);
      mockPrisma.booking.count.mockResolvedValue(1); // 1 active rental

      const impact = await serviceAreasService.getServiceAreaImpact('area-gachibowli');

      expect(impact.affectedVendorsCount).toBe(1);
      expect(impact.affectedVehiclesCount).toBe(1);
      expect(impact.upcomingBookingsCount).toBe(1);
      expect(impact.activeRentalsCount).toBe(1);
      expect(impact.safeToDeactivate).toBe(false); // active rentals prevent immediate unsafe teardown
      expect(impact.recommendations.length).toBeGreaterThan(0);
    });
  });

  describe('Event & Notification Rules Engine', () => {
    it('returns default canonical rules when no database overrides exist', async () => {
      mockPrisma.systemConfig.findUnique.mockResolvedValue(null);

      const rules = await adminIntegrationsService.getNotificationRules();

      expect(rules.length).toBeGreaterThanOrEqual(10);
      const bookingConfirmed = rules.find((r) => r.eventType === 'BOOKING_CONFIRMED');
      expect(bookingConfirmed).toBeDefined();
      expect(bookingConfirmed.channels).toContain('WHATSAPP');
      expect(bookingConfirmed.channels).toContain('EMAIL');
      expect(bookingConfirmed.priority).toBe('HIGH');
    });

    it('toggles notification rule and persists to SystemConfig', async () => {
      mockPrisma.systemConfig.findUnique.mockResolvedValue(null);
      mockPrisma.systemConfig.upsert.mockResolvedValue({});

      const toggled = await adminIntegrationsService.toggleNotificationRule('rule-booking-confirmed', false);

      expect(toggled.isEnabled).toBe(false);
      expect(mockPrisma.systemConfig.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { key: 'communications.notification_rules' },
        }),
      );
    });

    it('simulates notification rule dispatch and evaluates quiet hours suppression', async () => {
      mockPrisma.systemConfig.findUnique.mockResolvedValue(null);

      const sim = await adminIntegrationsService.simulateNotificationRule('BOOKING_CONFIRMED');

      expect(sim.matched).toBe(true);
      expect(sim.configuredChannels).toEqual(expect.arrayContaining(['IN_APP', 'PUSH', 'EMAIL', 'WHATSAPP']));
      expect(sim.priority).toBe('HIGH');
    });
  });
});
