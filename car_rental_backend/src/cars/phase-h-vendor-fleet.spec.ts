import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';
import { VehicleLifecycleService } from './vehicle-lifecycle.service';
import { VendorFleetService } from './vendor-fleet.service';
import { CarsService } from './cars.service';
import { VehicleAvailabilityService } from './vehicle-availability.service';
import {
  Role,
  VerificationStatus,
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  VendorDepositStatus,
  DocumentStatus,
  DocumentType,
  CarCategory,
  FuelType,
  BookingStatus,
  VehicleBlockType,
  Prisma,
} from '@prisma/client';

describe('Phase H — Vendor Fleet Operations, Availability & Operational Readiness Engine', () => {
  let eligibilityService: VehicleOperationsEligibilityService;
  let lifecycleService: VehicleLifecycleService;
  let fleetService: VendorFleetService;
  let carsService: CarsService;
  let availabilityService: VehicleAvailabilityService;

  let mockPrisma: any;
  let mockCache: any;
  let mockConfig: any;
  let mockLock: any;

  // In-memory mock tables
  let vendors: Map<string, any>;
  let cars: Map<string, any>;
  let serviceAreas: Map<string, any>;
  let vendorServiceAreas: Map<string, any>;
  let deposits: Map<string, any>;
  let documents: Map<string, any>;
  let vehicleBlocks: Map<string, any>;
  let bookings: Map<string, any>;
  let auditLogs: any[];
  let platformSettings: any;

  let currentPlatformConfig: any;

  beforeEach(async () => {
    vendors = new Map();
    cars = new Map();
    serviceAreas = new Map();
    vendorServiceAreas = new Map();
    deposits = new Map();
    documents = new Map();
    vehicleBlocks = new Map();
    bookings = new Map();
    auditLogs = [];

    currentPlatformConfig = {
      fleetActivationEnabled: true,
      requireVendorVerified: true,
      requireVendorSecurityDeposit: true,
      requireServiceAreaAssignment: true,
      requireVehicleVerification: true,
      maxMaintenanceDays: 30,
      autoDeactivateOnMissingCoverage: true,
      mandatoryVehicleDocuments: ['RC_BOOK', 'INSURANCE'],
      availabilityBufferMinutes: 30,
    };

    platformSettings = {
      id: 'singleton',
      platformName: 'DriveGo',
      enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
    };

    mockCache = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(true),
      delete: jest.fn().mockResolvedValue(true),
      invalidatePattern: jest.fn().mockResolvedValue(1),
    };

    mockLock = {
      acquireLock: jest.fn().mockResolvedValue('token-123'),
      releaseLock: jest.fn().mockResolvedValue(true),
    };

    mockConfig = {
      getFleetOperationsConfig: jest.fn().mockImplementation(async () => currentPlatformConfig),
      getSearchRankingConfig: jest.fn().mockResolvedValue(null),
    };

    mockPrisma = {
      $transaction: jest.fn().mockImplementation(async (cb) => {
        if (typeof cb === 'function') {
          return await cb(mockPrisma);
        }
        return cb;
      }),
      platformSettings: {
        findUnique: jest.fn().mockImplementation(() => Promise.resolve(platformSettings)),
        create: jest.fn().mockImplementation(({ data }) => {
          platformSettings = data;
          return Promise.resolve(data);
        }),
      },
      vendor: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.userId) {
            for (const v of vendors.values()) {
              if (v.userId === where.userId) return Promise.resolve(v);
            }
            return Promise.resolve(null);
          }
          return Promise.resolve(vendors.get(where.id) || null);
        }),
        findMany: jest.fn().mockImplementation(() => Promise.resolve(Array.from(vendors.values()))),
      },
      car: {
        create: jest.fn().mockImplementation(({ data }) => {
          const id = data.id || `car-${Date.now()}-${Math.random()}`;
          const newCar = {
            id,
            ...data,
            photos: data.photos || [],
            availableTripTypes: data.availableTripTypes || ['SELF_DRIVE'],
            createdAt: new Date(),
            updatedAt: new Date(),
            vendor: vendors.get(data.vendorId),
            serviceArea: data.serviceAreaId ? serviceAreas.get(data.serviceAreaId) : null,
            documents: [],
          };
          cars.set(id, newCar);
          return Promise.resolve(newCar);
        }),
        findUnique: jest.fn().mockImplementation(({ where, include }) => {
          const car = cars.get(where.id);
          if (!car) return Promise.resolve(null);
          const enriched = { ...car };
          if (include?.vendor) {
            const v = vendors.get(car.vendorId);
            enriched.vendor = v
              ? {
                  ...v,
                  vendorSecurityDeposit: deposits.get(car.vendorId) || null,
                }
              : null;
          }
          if (include?.serviceArea) {
            enriched.serviceArea = car.serviceAreaId ? serviceAreas.get(car.serviceAreaId) : null;
          }
          if (include?.documents) {
            enriched.documents = Array.from(documents.values()).filter((d) => d.carId === car.id);
          }
          return Promise.resolve(enriched);
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const car of cars.values()) {
            if (where.registrationNumber && car.registrationNumber === where.registrationNumber) {
              if (where.id?.not && car.id === where.id.not) continue;
              return Promise.resolve(car);
            }
          }
          return Promise.resolve(null);
        }),
        findMany: jest.fn().mockImplementation((args: any) => {
          let list = Array.from(cars.values()).map((c) => ({
            ...c,
            vendor: c.vendor || vendors.get(c.vendorId) || {
              id: c.vendorId,
              latitude: 18.922,
              longitude: 72.834,
              verificationStatus: VerificationStatus.VERIFIED,
            },
            serviceArea: c.serviceArea || (c.serviceAreaId ? serviceAreas.get(c.serviceAreaId) : null),
          }));
          if (args?.where) {
            if (args.where.isAvailable !== undefined) {
              list = list.filter((c) => c.isAvailable === args.where.isAvailable);
            }
            if (args.where.operationalStatus) {
              list = list.filter((c) => c.operationalStatus === args.where.operationalStatus);
            }
            if (args.where.verificationStatus) {
              list = list.filter((c) => c.verificationStatus === args.where.verificationStatus);
            }
            if (args.where.vendorId) {
              list = list.filter((c) => c.vendorId === args.where.vendorId);
            }
            if (args.where.serviceAreaId) {
              list = list.filter((c) => c.serviceAreaId === args.where.serviceAreaId);
            }
            if (args.where.vendor?.verificationStatus) {
              list = list.filter((c) => {
                const v = vendors.get(c.vendorId);
                return v && v.verificationStatus === args.where.vendor.verificationStatus;
              });
            }
          }
          return Promise.resolve(list);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const existing = cars.get(where.id);
          if (!existing) return Promise.resolve(null);
          const updated = { ...existing, ...data, updatedAt: new Date() };
          cars.set(where.id, updated);
          return Promise.resolve(updated);
        }),
        count: jest.fn().mockImplementation(({ where }: any = {}) => {
          let list = Array.from(cars.values());
          if (where?.operationalStatus) {
            list = list.filter((c) => c.operationalStatus === where.operationalStatus);
          }
          if (where?.verificationStatus) {
            list = list.filter((c) => c.verificationStatus === where.verificationStatus);
          }
          return Promise.resolve(list.length);
        }),
      },
      serviceArea: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(serviceAreas.get(where.id) || null);
        }),
        findMany: jest.fn().mockImplementation(() => Promise.resolve(Array.from(serviceAreas.values()))),
      },
      vendorServiceArea: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const key = `${where.vendorId_serviceAreaId.vendorId}_${where.vendorId_serviceAreaId.serviceAreaId}`;
          return Promise.resolve(vendorServiceAreas.get(key) || null);
        }),
      },
      vendorSecurityDeposit: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(deposits.get(where.vendorId) || null);
        }),
      },
      vehicleBlock: {
        create: jest.fn().mockImplementation(({ data }) => {
          const id = `block-${Date.now()}-${Math.random()}`;
          const b = { id, ...data };
          vehicleBlocks.set(id, b);
          return Promise.resolve(b);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list = Array.from(vehicleBlocks.values());
          if (where?.carId) list = list.filter((b) => b.carId === where.carId);
          return Promise.resolve(list);
        }),
        deleteMany: jest.fn().mockImplementation(({ where }) => {
          let count = 0;
          for (const [k, v] of vehicleBlocks.entries()) {
            if (where.carId && v.carId === where.carId && where.blockType && v.blockType === where.blockType) {
              vehicleBlocks.delete(k);
              count++;
            }
          }
          return Promise.resolve({ count });
        }),
      },
      vehicleHold: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      locationException: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      booking: {
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list = Array.from(bookings.values());
          if (where?.carId) list = list.filter((b) => b.carId === where.carId);
          if (where?.status?.in) list = list.filter((b) => where.status.in.includes(b.status));
          return Promise.resolve(list);
        }),
      },
      vehicleAuditLog: {
        create: jest.fn().mockImplementation(({ data }) => {
          const entry = { id: `log-${Date.now()}-${Math.random()}`, ...data, createdAt: new Date() };
          auditLogs.push(entry);
          return Promise.resolve(entry);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list = [...auditLogs];
          if (where?.carId) list = list.filter((l) => l.carId === where.carId);
          return Promise.resolve(list);
        }),
      },
      supportedCity: {
        findFirst: jest.fn().mockResolvedValue({ id: 'city-1', name: 'Mumbai', isActive: true }),
        findMany: jest.fn().mockResolvedValue([{ id: 'city-1', name: 'Mumbai', isActive: true }]),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehicleOperationsEligibilityService,
        VehicleLifecycleService,
        VendorFleetService,
        CarsService,
        VehicleAvailabilityService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
        { provide: SystemConfigService, useValue: mockConfig },
        { provide: BookingLockService, useValue: mockLock },
      ],
    }).compile();

    eligibilityService = module.get<VehicleOperationsEligibilityService>(
      VehicleOperationsEligibilityService,
    );
    lifecycleService = module.get<VehicleLifecycleService>(VehicleLifecycleService);
    fleetService = module.get<VendorFleetService>(VendorFleetService);
    carsService = module.get<CarsService>(CarsService);
    availabilityService = module.get<VehicleAvailabilityService>(VehicleAvailabilityService);
  });

  // Helper setup for seed data
  function seedVerifiedVendor(vendorId = 'vendor-1', userId = 'user-v1') {
    const v = {
      id: vendorId,
      userId,
      businessName: 'Apex Mobility',
      ownerName: 'Vikram Apex',
      city: 'Mumbai',
      verificationStatus: VerificationStatus.VERIFIED,
      isSponsored: false,
      latitude: 18.922,
      longitude: 72.834,
    };
    vendors.set(vendorId, v);

    // Paid deposit
    deposits.set(vendorId, {
      id: `dep-${vendorId}`,
      vendorId,
      status: VendorDepositStatus.PAID,
      requiredAmount: new Prisma.Decimal(25000),
      paidAmount: new Prisma.Decimal(25000),
      remainingAmount: new Prisma.Decimal(0),
    });

    // Active Service Area
    serviceAreas.set('sa-mumbai-south', {
      id: 'sa-mumbai-south',
      name: 'Mumbai South',
      status: 'ACTIVE',
      latitude: 18.922,
      longitude: 72.834,
      radiusMeters: 10000,
    });

    vendorServiceAreas.set(`${vendorId}_sa-mumbai-south`, {
      id: `vsa-1`,
      vendorId,
      serviceAreaId: 'sa-mumbai-south',
      isActive: true,
    });

    return v;
  }

  function seedVehicle(carId = 'car-1', vendorId = 'vendor-1', overrides: any = {}) {
    const v = vendors.get(vendorId) || {
      id: vendorId,
      latitude: 18.922,
      longitude: 72.834,
      verificationStatus: VerificationStatus.VERIFIED,
    };
    const c = {
      id: carId,
      vendorId,
      vendor: v,
      make: 'Hyundai',
      model: 'Creta',
      year: 2024,
      type: CarCategory.SUV,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'MH01AB1234',
      photos: ['https://s3.amazonaws.com/drivego/creta-front.jpg'],
      pricePerKm: new Prisma.Decimal(15),
      pricePerDay: new Prisma.Decimal(3000),
      pricePerHour: new Prisma.Decimal(200),
      isAvailable: false,
      operationalStatus: VehicleOperationalStatus.DRAFT,
      verificationStatus: VehicleVerificationStatus.PENDING,
      serviceAreaId: 'sa-mumbai-south',
      availableTripTypes: ['SELF_DRIVE'],
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
    cars.set(carId, c);

    // Seed valid vehicle documents
    documents.set(`doc-rc-${carId}`, {
      id: `doc-rc-${carId}`,
      carId,
      vendorId,
      type: DocumentType.RC_BOOK,
      status: DocumentStatus.VERIFIED,
      fileUrl: 'https://docs.drivego.in/rc.pdf',
    });
    documents.set(`doc-ins-${carId}`, {
      id: `doc-ins-${carId}`,
      carId,
      vendorId,
      type: DocumentType.INSURANCE,
      status: DocumentStatus.VERIFIED,
      fileUrl: 'https://docs.drivego.in/ins.pdf',
    });

    return c;
  }

  // =========================================================================
  // 30 COMPREHENSIVE SCENARIOS REQUIRED BY PROMPT
  // =========================================================================

  describe('Fleet Operations & Operational Readiness Verification Suite', () => {
    // 1. Vehicle creation
    it('Scenario 1: Vehicle creation sets DRAFT status, unverified, unbookable (isAvailable=false)', async () => {
      seedVerifiedVendor();
      const car = await fleetService.createVehicle('user-v1', {
        make: 'Maruti',
        model: 'Swift',
        year: 2023,
        type: CarCategory.HATCHBACK,
        fuelType: FuelType.PETROL,
        seating: 5,
        isAC: true,
        registrationNumber: 'MH02XY9999',
        photos: ['https://drivego.in/swift.jpg'],
        pricePerKm: 12,
        pricePerDay: 1800,
        pricePerHour: 120,
        serviceAreaId: 'sa-mumbai-south',
      });

      expect(car.operationalStatus).toBe(VehicleOperationalStatus.DRAFT);
      expect(car.verificationStatus).toBe(VehicleVerificationStatus.PENDING);
      expect(car.isAvailable).toBe(false);
      expect(auditLogs.some((l) => l.action === 'CREATE_VEHICLE' && l.carId === car.id)).toBe(true);
    });

    // 2. Vehicle update
    it('Scenario 2: Vehicle update updates metadata, records audit log, and invalidates caches', async () => {
      seedVerifiedVendor();
      seedVehicle('car-update-1');

      const updated = await fleetService.updateVehicle(
        'car-update-1',
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        { pricePerDay: 3500 },
      );

      expect(Number(updated.pricePerDay)).toBe(3500);
      expect(auditLogs.some((l) => l.action === 'UPDATE_VEHICLE')).toBe(true);
      expect(mockCache.delete).toHaveBeenCalled();
    });

    // 3. Duplicate vehicle constraints
    it('Scenario 3: Duplicate vehicle registration number throws ConflictException', async () => {
      seedVerifiedVendor();
      seedVehicle('car-exist-1', 'vendor-1', { registrationNumber: 'MH01DUPLICATE' });

      await expect(
        fleetService.createVehicle('user-v1', {
          make: 'Toyota',
          model: 'Innova',
          year: 2024,
          type: CarCategory.SUV,
          fuelType: FuelType.DIESEL,
          seating: 7,
          isAC: true,
          registrationNumber: 'MH01DUPLICATE',
          photos: ['https://drivego.in/innova.jpg'],
          pricePerKm: 20,
          pricePerDay: 4500,
          pricePerHour: 300,
        }),
      ).rejects.toThrow(ConflictException);
    });

    // 4. Vendor ownership protection
    it('Scenario 4: Vendor cannot modify another vendor vehicle (ForbiddenException)', async () => {
      seedVerifiedVendor('vendor-1', 'user-v1');
      seedVerifiedVendor('vendor-2', 'user-v2');
      seedVehicle('car-v2', 'vendor-2');

      await expect(
        fleetService.updateVehicle(
          'car-v2',
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
          { pricePerDay: 9999 },
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    // 5. Vehicle verification
    it('Scenario 5: Admin vehicle verification sets VERIFIED and auto-activates if eligible', async () => {
      seedVerifiedVendor();
      seedVehicle('car-v-1');

      const result = await fleetService.adminVerifyVehicle('car-v-1', 'admin-super', {
        autoActivate: true,
        notes: 'Documents verified and vehicle physical inspection passed',
      });

      expect(result.vehicle.verificationStatus).toBe(VehicleVerificationStatus.VERIFIED);
      expect(result.vehicle.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(result.vehicle.isAvailable).toBe(true);
      expect(auditLogs.some((l) => l.action === 'ADMIN_VERIFY_VEHICLE')).toBe(true);
    });

    // 6. Verification rejection
    it('Scenario 6: Admin vehicle rejection sets REJECTED, records reason, and demotes to DRAFT', async () => {
      seedVerifiedVendor();
      seedVehicle('car-rej-1', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.PENDING_VERIFICATION,
      });

      const rejected = await fleetService.adminRejectVehicle('car-rej-1', 'admin-super', {
        reason: 'RC Book blurred and insurance policy expired',
      });

      expect(rejected.verificationStatus).toBe(VehicleVerificationStatus.REJECTED);
      expect(rejected.operationalStatus).toBe(VehicleOperationalStatus.DRAFT);
      expect(rejected.rejectionReason).toBe('RC Book blurred and insurance policy expired');
      expect(auditLogs.some((l) => l.action === 'ADMIN_REJECT_VEHICLE')).toBe(true);
    });

    // 7. Activation eligibility
    it('Scenario 7: Eligible vehicle returns eligible: true with 0 blockers', async () => {
      seedVerifiedVendor();
      seedVehicle('car-elig-1', 'vendor-1', {
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const res = await eligibilityService.evaluateEligibility('car-elig-1');
      expect(res.eligible).toBe(true);
      expect(res.blockers).toHaveLength(0);
    });

    // 8. Missing onboarding requirement / vendor not verified
    it('Scenario 8: Unverified vendor blocks vehicle activation (VENDOR_NOT_VERIFIED)', async () => {
      seedVerifiedVendor();
      vendors.get('vendor-1').verificationStatus = VerificationStatus.PENDING;
      seedVehicle('car-unv-vendor', 'vendor-1', {
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const res = await eligibilityService.evaluateEligibility('car-unv-vendor');
      expect(res.eligible).toBe(false);
      expect(res.blockers.some((b) => b.code === 'VENDOR_NOT_VERIFIED')).toBe(true);
    });

    // 9. Missing vehicle requirement (documents)
    it('Scenario 9: Missing mandatory vehicle document blocks activation (MISSING_DOCUMENT_INSURANCE)', async () => {
      seedVerifiedVendor();
      seedVehicle('car-missing-doc');
      documents.delete('doc-ins-car-missing-doc'); // Remove insurance

      const res = await eligibilityService.evaluateEligibility('car-missing-doc');
      expect(res.eligible).toBe(false);
      expect(res.blockers.some((b) => b.code === 'MISSING_DOCUMENT_INSURANCE')).toBe(true);
    });

    // 10. Vendor verification blocker prevents vehicle activation
    it('Scenario 10: Attempting transition to ACTIVE when vendor is unverified throws BadRequestException', async () => {
      seedVerifiedVendor();
      vendors.get('vendor-1').verificationStatus = VerificationStatus.SUSPENDED;
      seedVehicle('car-blocked-active', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.INACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      await expect(
        lifecycleService.transitionStatus(
          'car-blocked-active',
          VehicleOperationalStatus.ACTIVE,
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    // 11. Vendor security deposit blocker
    it('Scenario 11: Unpaid vendor security deposit blocks vehicle activation', async () => {
      seedVerifiedVendor();
      deposits.get('vendor-1').status = VendorDepositStatus.REQUIRED;
      seedVehicle('car-deposit-block');

      const res = await eligibilityService.evaluateEligibility('car-deposit-block');
      expect(res.eligible).toBe(false);
      expect(res.blockers.some((b) => b.code === 'VENDOR_DEPOSIT_UNPAID')).toBe(true);
    });

    // 12. Unauthorized service area
    it('Scenario 12: Unauthorized service area blocks vehicle activation', async () => {
      seedVerifiedVendor();
      serviceAreas.set('sa-pune-east', {
        id: 'sa-pune-east',
        name: 'Pune East',
        status: 'ACTIVE',
      });
      // Vendor has NO coverage in sa-pune-east
      seedVehicle('car-unauth-sa', 'vendor-1', {
        serviceAreaId: 'sa-pune-east',
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const res = await eligibilityService.evaluateEligibility('car-unauth-sa');
      expect(res.eligible).toBe(false);
      expect(res.blockers.some((b) => b.code === 'SERVICE_AREA_NOT_AUTHORIZED')).toBe(true);
    });

    // 13. Authorized service area
    it('Scenario 13: Authorized active service area satisfies coverage requirement', async () => {
      seedVerifiedVendor();
      seedVehicle('car-auth-sa', 'vendor-1', {
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const res = await eligibilityService.evaluateEligibility('car-auth-sa');
      expect(res.blockers.some((b) => b.code.startsWith('SERVICE_AREA'))).toBe(false);
    });

    // 14. Valid lifecycle transition
    it('Scenario 14: Valid lifecycle transitions flow properly (DRAFT -> PENDING_VERIFICATION -> ACTIVE -> INACTIVE -> ACTIVE)', async () => {
      seedVerifiedVendor();
      seedVehicle('car-flow-1');

      // 1. Submit for verification
      const submitted = await fleetService.submitForVerification('car-flow-1', {
        id: 'user-v1',
        role: Role.VENDOR,
        vendorId: 'vendor-1',
      });
      expect(submitted.operationalStatus).toBe(VehicleOperationalStatus.PENDING_VERIFICATION);

      // 2. Admin verify + activate
      cars.get('car-flow-1').verificationStatus = VehicleVerificationStatus.VERIFIED;
      const active = await lifecycleService.transitionStatus(
        'car-flow-1',
        VehicleOperationalStatus.ACTIVE,
        { id: 'admin-1', role: Role.ADMIN },
      );
      expect(active.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(active.isAvailable).toBe(true);

      // 3. Deactivate to INACTIVE
      const inactive = await lifecycleService.transitionStatus(
        'car-flow-1',
        VehicleOperationalStatus.INACTIVE,
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
      );
      expect(inactive.operationalStatus).toBe(VehicleOperationalStatus.INACTIVE);
      expect(inactive.isAvailable).toBe(false);

      // 4. Reactivate to ACTIVE
      const reactivated = await lifecycleService.transitionStatus(
        'car-flow-1',
        VehicleOperationalStatus.ACTIVE,
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
      );
      expect(reactivated.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(reactivated.isAvailable).toBe(true);
    });

    // 15. Invalid lifecycle transition
    it('Scenario 15: Invalid lifecycle transition directly from DRAFT to MAINTENANCE is rejected', async () => {
      seedVerifiedVendor();
      seedVehicle('car-invalid-trans', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.DRAFT,
      });

      await expect(
        lifecycleService.transitionStatus(
          'car-invalid-trans',
          VehicleOperationalStatus.MAINTENANCE,
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    // 16. Maintenance start
    it('Scenario 16: Maintenance start sets MAINTENANCE, disables availability, and creates VehicleBlock', async () => {
      seedVerifiedVendor();
      seedVehicle('car-maint-1', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        isAvailable: true,
      });

      const res = await fleetService.startMaintenance(
        'car-maint-1',
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        {
          reason: 'Brake pad replacement and oil service',
          expectedReturnDate: new Date(Date.now() + 86400000 * 3).toISOString(),
        },
      );

      expect(res.operationalStatus).toBe(VehicleOperationalStatus.MAINTENANCE);
      expect(res.isAvailable).toBe(false);
      expect(res.maintenanceReason).toBe('Brake pad replacement and oil service');
      expect(
        Array.from(vehicleBlocks.values()).some(
          (b) => b.carId === 'car-maint-1' && b.blockType === VehicleBlockType.MAINTENANCE,
        ),
      ).toBe(true);
    });

    // 17. Maintenance completion
    it('Scenario 17: Maintenance completion clears blocks and restores vehicle to ACTIVE if eligible', async () => {
      seedVerifiedVendor();
      seedVehicle('car-maint-comp', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      await fleetService.startMaintenance(
        'car-maint-comp',
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        { reason: 'Tire rotation' },
      );

      const compResult = await fleetService.completeMaintenance(
        'car-maint-comp',
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        { notes: 'Service completed, certified road-worthy' },
      );

      expect(compResult.vehicle.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(compResult.vehicle.isAvailable).toBe(true);
      expect(compResult.vehicle.maintenanceReason).toBeNull();
      expect(
        Array.from(vehicleBlocks.values()).filter(
          (b) => b.carId === 'car-maint-comp' && b.blockType === VehicleBlockType.MAINTENANCE,
        ),
      ).toHaveLength(0);
    });

    // 18. Maintenance blocking discovery
    it('Scenario 18: Vehicle under MAINTENANCE is excluded from public search', async () => {
      seedVerifiedVendor();
      seedVehicle('car-disc-maint', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.MAINTENANCE,
        isAvailable: false,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const results = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(results.data.some((c) => c.id === 'car-disc-maint')).toBe(false);
    });

    // 19. Suspension blocking discovery
    it('Scenario 19: Vehicle under SUSPENDED is excluded from public search', async () => {
      seedVerifiedVendor();
      seedVehicle('car-disc-susp', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.SUSPENDED,
        isAvailable: false,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const results = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(results.data.some((c) => c.id === 'car-disc-susp')).toBe(false);
    });

    // 20. Retirement blocking discovery
    it('Scenario 20: Vehicle under RETIRED is excluded from public search', async () => {
      seedVerifiedVendor();
      seedVehicle('car-disc-ret', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.RETIRED,
        isAvailable: false,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      const results = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(results.data.some((c) => c.id === 'car-disc-ret')).toBe(false);
    });

    // 21. Search filtering
    it('Scenario 21: Public search returns strictly ACTIVE and VERIFIED vehicles', async () => {
      seedVerifiedVendor();
      seedVehicle('car-active-ok', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
        isAvailable: true,
      });
      seedVehicle('car-draft-hidden', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.DRAFT,
        verificationStatus: VehicleVerificationStatus.PENDING,
        isAvailable: false,
      });

      const results = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(results.data.some((c) => c.id === 'car-active-ok')).toBe(true);
      expect(results.data.some((c) => c.id === 'car-draft-hidden')).toBe(false);
    });

    // 22. Service-area filtering
    it('Scenario 22: Search filtering by serviceAreaId isolates fleet to specified coverage boundary', async () => {
      seedVerifiedVendor();
      seedVehicle('car-sa-1', 'vendor-1', {
        serviceAreaId: 'sa-mumbai-south',
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
        isAvailable: true,
      });

      const results = await carsService.searchCars({ serviceAreaId: 'sa-mumbai-south' }, false);
      expect(results.data.some((c) => c.id === 'car-sa-1')).toBe(true);
    });

    // 23. Availability filtering
    it('Scenario 23: checkAvailability returns available: false when vehicle is in MAINTENANCE', async () => {
      seedVerifiedVendor();
      seedVehicle('car-avail-check', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.MAINTENANCE,
        isAvailable: false,
      });

      const avail = await availabilityService.checkAvailability(
        'car-avail-check',
        new Date(Date.now() + 86400000),
        new Date(Date.now() + 86400000 * 2),
      );

      expect(avail.available).toBe(false);
      expect(avail.reason).toContain('maintenance');
    });

    // 24. Double-booking / concurrency protection on maintenance
    it('Scenario 24: Maintenance start rejected if conflicting active bookings exist unless overridden', async () => {
      seedVerifiedVendor();
      seedVehicle('car-book-conflict', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        isAvailable: true,
      });

      const now = new Date();
      const returnDate = new Date(now.getTime() + 86400000 * 5);

      bookings.set('booking-active-1', {
        id: 'booking-active-1',
        carId: 'car-book-conflict',
        status: BookingStatus.CONFIRMED,
        startDate: new Date(now.getTime() + 86400000),
        endDate: new Date(now.getTime() + 86400000 * 3),
      });

      await expect(
        fleetService.startMaintenance(
          'car-book-conflict',
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
          { reason: 'Major engine overhaul', expectedReturnDate: returnDate.toISOString() },
        ),
      ).rejects.toThrow(ConflictException);

      // With overrideConflictingBookings = true
      const overridden = await fleetService.startMaintenance(
        'car-book-conflict',
        { id: 'admin-1', role: Role.ADMIN },
        {
          reason: 'Emergency recall override',
          expectedReturnDate: returnDate.toISOString(),
          overrideConflictingBookings: true,
        },
      );
      expect(overridden.operationalStatus).toBe(VehicleOperationalStatus.MAINTENANCE);
    });

    // 25. Admin permission enforcement
    it('Scenario 25: Only platform administrators can lift vehicle suspension or retire a vehicle', async () => {
      seedVerifiedVendor();
      seedVehicle('car-susp-admin', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.SUSPENDED,
      });

      // Vendor cannot lift suspension
      await expect(
        lifecycleService.transitionStatus(
          'car-susp-admin',
          VehicleOperationalStatus.ACTIVE,
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        ),
      ).rejects.toThrow(ForbiddenException);

      // Admin can lift suspension
      cars.get('car-susp-admin').verificationStatus = VehicleVerificationStatus.VERIFIED;
      const lifted = await lifecycleService.transitionStatus(
        'car-susp-admin',
        VehicleOperationalStatus.INACTIVE,
        { id: 'admin-1', role: Role.ADMIN },
        { reason: 'Administrative review resolved suspension' },
      );
      expect(lifted.operationalStatus).toBe(VehicleOperationalStatus.INACTIVE);
    });

    // 26. Vendor ownership authorization on maintenance
    it('Scenario 26: Vendor cannot put another vendor vehicle into maintenance', async () => {
      seedVerifiedVendor('vendor-1', 'user-v1');
      seedVerifiedVendor('vendor-2', 'user-v2');
      seedVehicle('car-vendor-2', 'vendor-2');

      await expect(
        fleetService.startMaintenance(
          'car-vendor-2',
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
          { reason: 'Unauthorized maintenance' },
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    // 27. Audit logging
    it('Scenario 27: Every operational transition records actor, timestamps, from/to status, and reason', async () => {
      seedVerifiedVendor();
      seedVehicle('car-audit-trace', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
        isAvailable: true,
      });

      await lifecycleService.transitionStatus(
        'car-audit-trace',
        VehicleOperationalStatus.INACTIVE,
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        { reason: 'Seasonal holiday pause' },
      );

      const logs = await fleetService.getVehicleAuditLogs('car-audit-trace');
      expect(logs.length).toBeGreaterThan(0);
      const last = logs[0];
      expect(last.action).toBe('TRANSITION_INACTIVE');
      expect(last.fromStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(last.toStatus).toBe(VehicleOperationalStatus.INACTIVE);
      expect(last.reason).toBe('Seasonal holiday pause');
      expect(last.actorRole).toBe(Role.VENDOR);
    });

    // 28. Redis invalidation
    it('Scenario 28: Vehicle lifecycle transition invalidates Redis cache keys for eligibility and fleet', async () => {
      seedVerifiedVendor();
      seedVehicle('car-redis-inv', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      await lifecycleService.transitionStatus(
        'car-redis-inv',
        VehicleOperationalStatus.INACTIVE,
        { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
      );

      expect(mockCache.delete).toHaveBeenCalledWith(expect.stringContaining('cache:car:detail:'));
      expect(mockCache.delete).toHaveBeenCalledWith(expect.stringContaining('cache:vendor:fleet:'));
      expect(mockCache.delete).toHaveBeenCalledWith(expect.stringContaining('cache:fleet:kpis'));
    });

    // 29. Configuration kill-switch / rule enforcement
    it('Scenario 29: Dynamic kill-switch (fleetActivationEnabled: false) blocks vehicle activations', async () => {
      seedVerifiedVendor();
      seedVehicle('car-killswitch', 'vendor-1', {
        operationalStatus: VehicleOperationalStatus.INACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      });

      currentPlatformConfig.fleetActivationEnabled = false;

      const evalResult = await eligibilityService.evaluateEligibility('car-killswitch');
      expect(evalResult.eligible).toBe(false);
      expect(
        evalResult.blockers.some((b) => b.code === 'PLATFORM_FLEET_ACTIVATION_DISABLED'),
      ).toBe(true);

      await expect(
        lifecycleService.transitionStatus(
          'car-killswitch',
          VehicleOperationalStatus.ACTIVE,
          { id: 'user-v1', role: Role.VENDOR, vendorId: 'vendor-1' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    // 30. End-to-end vehicle activation -> discovery eligibility
    it('Scenario 30: End-to-end vehicle lifecycle from DRAFT creation to admin verification, activation, and public customer search visibility', async () => {
      seedVerifiedVendor('vendor-e2e', 'user-e2e');

      // Step A: Vendor creates vehicle (DRAFT, unverified, unavailable)
      const created = await fleetService.createVehicle('user-e2e', {
        make: 'Mahindra',
        model: 'Thar',
        year: 2024,
        type: CarCategory.SUV,
        fuelType: FuelType.DIESEL,
        seating: 4,
        isAC: true,
        registrationNumber: 'MH04THAR99',
        photos: ['https://drivego.in/thar.jpg'],
        pricePerKm: 18,
        pricePerDay: 4000,
        pricePerHour: 250,
        serviceAreaId: 'sa-mumbai-south',
      });
      expect(created.operationalStatus).toBe(VehicleOperationalStatus.DRAFT);
      expect(created.isAvailable).toBe(false);

      // Public search should NOT find the vehicle
      let search = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(search.data.some((c) => c.id === created.id)).toBe(false);

      // Step B: Attach mandatory documents and submit for verification
      documents.set(`doc-rc-${created.id}`, {
        id: `doc-rc-${created.id}`,
        carId: created.id,
        vendorId: 'vendor-e2e',
        type: DocumentType.RC_BOOK,
        status: DocumentStatus.VERIFIED,
        fileUrl: 'https://docs.drivego.in/rc.pdf',
      });
      documents.set(`doc-ins-${created.id}`, {
        id: `doc-ins-${created.id}`,
        carId: created.id,
        vendorId: 'vendor-e2e',
        type: DocumentType.INSURANCE,
        status: DocumentStatus.VERIFIED,
        fileUrl: 'https://docs.drivego.in/ins.pdf',
      });

      const submitted = await fleetService.submitForVerification(created.id, {
        id: 'user-e2e',
        role: Role.VENDOR,
        vendorId: 'vendor-e2e',
      });
      expect(submitted.operationalStatus).toBe(VehicleOperationalStatus.PENDING_VERIFICATION);

      // Step C: Admin reviews and approves verification with autoActivate
      const verified = await fleetService.adminVerifyVehicle(created.id, 'admin-1', {
        autoActivate: true,
        notes: 'Thar passes all compliance inspection benchmarks',
      });
      expect(verified.vehicle.verificationStatus).toBe(VehicleVerificationStatus.VERIFIED);
      expect(verified.vehicle.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(verified.vehicle.isAvailable).toBe(true);

      // Step D: Public search immediately discovers the verified and active vehicle
      search = await carsService.searchCars({ city: 'Mumbai' }, false);
      expect(search.data.some((c) => c.id === created.id)).toBe(true);

      // Step E: Fleet KPIs accurately reflect the active vehicle
      const kpis = await fleetService.getFleetKPIs();
      expect(kpis.active).toBeGreaterThanOrEqual(1);
      expect(kpis.verifiedCount).toBeGreaterThanOrEqual(1);
    });
  });
});
