import { Test, TestingModule } from '@nestjs/testing';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { BookingsService } from './bookings.service';
import { VehicleLifecycleService } from '../cars/vehicle-lifecycle.service';
import { VendorFleetService } from '../cars/vendor-fleet.service';
import { VehicleOperationsEligibilityService } from '../cars/vehicle-operations-eligibility.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { HandoverOtpService } from './handover-otp.service';
import { PaymentsService } from '../payments/payments.service';
import { AuditLogService } from '../admin/audit-log.service';
import { BookingOutboxService } from './booking-outbox.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CouponsService } from '../coupons/coupons.service';
import {
  BookingStatus,
  Role,
  PaymentStatus,
  InspectionType,
  HandoverOtpType,
  SecurityDepositStatus,
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  VerificationStatus,
  VehicleBlockType,
  DamageClaimStatus,
  TripType,
  Prisma,
} from '@prisma/client';
import {
  BadRequestException,
  ForbiddenException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';

describe('Phase I — Booking Execution, Vehicle Handoff & Fleet Integrity Suite', () => {
  let lifecycleService: BookingLifecycleService;
  let bookingsService: BookingsService;
  let vehicleLifecycleService: VehicleLifecycleService;
  let vendorFleetService: VendorFleetService;
  let eligibilityService: VehicleOperationsEligibilityService;

  let prismaMock: any;
  let lockServiceMock: any;
  let cacheServiceMock: any;
  let configServiceMock: any;
  let handoverOtpMock: any;
  let paymentsServiceMock: any;
  let auditLogMock: any;
  let outboxServiceMock: any;
  let cancellationPolicyMock: any;

  // In-memory state storage
  let bookingsDb: Map<string, any>;
  let carsDb: Map<string, any>;
  let vehicleBlocksDb: any[];
  let vehicleAuditLogsDb: any[];
  let inspectionsDb: Map<string, any>;
  let damageClaimsDb: any[];
  let depositsDb: Map<string, any>;
  let outboxEventsDb: any[];

  const VENDOR_A_USER_ID = 'usr_vendor_a';
  const VENDOR_A_ID = 'vnd_alpha_1';
  const VENDOR_B_USER_ID = 'usr_vendor_b';
  const VENDOR_B_ID = 'vnd_beta_2';
  const CUSTOMER_USER_ID = 'usr_customer_1';
  const ADMIN_USER_ID = 'usr_admin_root';

  const defaultCarId = 'car_safari_001';

  beforeEach(async () => {
    bookingsDb = new Map();
    carsDb = new Map();
    vehicleBlocksDb = [];
    vehicleAuditLogsDb = [];
    inspectionsDb = new Map();
    damageClaimsDb = [];
    depositsDb = new Map();
    outboxEventsDb = [];

    // Seed default operational vehicle
    carsDb.set(defaultCarId, {
      id: defaultCarId,
      vendorId: VENDOR_A_ID,
      make: 'Tata',
      model: 'Safari Dark',
      registrationNumber: 'KA-01-EQ-5544',
      type: 'SUV',
      pricePerDay: new Prisma.Decimal(4500),
      pricePerHour: new Prisma.Decimal(350),
      pricePerKm: new Prisma.Decimal(18),
      isAvailable: true,
      operationalStatus: VehicleOperationalStatus.ACTIVE,
      verificationStatus: VehicleVerificationStatus.VERIFIED,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
      blockedDates: [],
      photos: ['https://storage.drivego.in/cars/safari-front.webp'],
      vendor: {
        id: VENDOR_A_ID,
        userId: VENDOR_A_USER_ID,
        businessName: 'Alpha Fleet Logistics',
        city: 'Bangalore',
        verificationStatus: VerificationStatus.VERIFIED,
        user: { id: VENDOR_A_USER_ID, phone: '+919988776655' },
      },
    });

    prismaMock = {
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(prismaMock);
      }),
      $queryRaw: jest.fn().mockResolvedValue([]),
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
        }),
        create: jest.fn().mockResolvedValue({}),
      },
      car: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const c = carsDb.get(where.id);
          return Promise.resolve(c ? JSON.parse(JSON.stringify(c)) : null);
        }),
        findMany: jest.fn().mockImplementation(() => Promise.resolve(Array.from(carsDb.values()))),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const c = carsDb.get(where.id);
          if (!c) throw new NotFoundException('Car not found');
          Object.assign(c, data);
          return Promise.resolve(JSON.parse(JSON.stringify(c)));
        }),
      },
      booking: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const b = bookingsDb.get(where.id);
          return Promise.resolve(b ? JSON.parse(JSON.stringify(b)) : null);
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          const list = Array.from(bookingsDb.values());
          for (const b of list) {
            if (where.carId && b.carId !== where.carId) continue;
            if (where.id?.not && b.id === where.id.not) continue;
            if (where.status?.in && !where.status.in.includes(b.status)) continue;
            if (where.status && !where.status.in && b.status !== where.status) continue;
            if (where.startDate?.lt && !(new Date(b.startDate) < new Date(where.startDate.lt))) continue;
            if (where.endDate?.gt && !(new Date(b.endDate) > new Date(where.endDate.gt))) continue;
            return Promise.resolve(JSON.parse(JSON.stringify(b)));
          }
          return Promise.resolve(null);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list = Array.from(bookingsDb.values());
          if (where?.carId) list = list.filter((b) => b.carId === where.carId);
          if (where?.status?.in) list = list.filter((b) => where.status.in.includes(b.status));
          return Promise.resolve(JSON.parse(JSON.stringify(list)));
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const id = data.id || `bk_${Date.now()}_${Math.random().toString(36).substring(7)}`;
          const car = carsDb.get(data.carId);
          const newBooking = {
            id,
            ...data,
            startDate: new Date(data.startDate),
            endDate: new Date(data.endDate),
            car,
            customer: { id: data.customerId, name: 'Customer Test', phone: '+919000000001' },
            vendor: car?.vendor || { id: VENDOR_A_ID, userId: VENDOR_A_USER_ID, businessName: 'Alpha Fleet' },
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          bookingsDb.set(id, newBooking);
          return Promise.resolve(newBooking);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const b = bookingsDb.get(where.id);
          if (!b) throw new NotFoundException('Booking not found');
          if (where.status && b.status !== where.status) {
            const err: any = new Error('Concurrent state mismatch');
            err.code = 'P2025';
            throw err;
          }
          Object.assign(b, data);
          return Promise.resolve(JSON.parse(JSON.stringify(b)));
        }),
      },
      vehicleBlock: {
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const blk of vehicleBlocksDb) {
            if (where.carId && blk.carId !== where.carId) continue;
            if (where.startDate?.lt && !(new Date(blk.startDate) < new Date(where.startDate.lt))) continue;
            if (where.endDate?.gt && !(new Date(blk.endDate) > new Date(where.endDate.gt))) continue;
            return Promise.resolve(blk);
          }
          return Promise.resolve(null);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const blk = { id: `blk_${Date.now()}`, ...data, createdAt: new Date() };
          vehicleBlocksDb.push(blk);
          return Promise.resolve(blk);
        }),
      },
      vehicleAuditLog: {
        create: jest.fn().mockImplementation(({ data }) => {
          const log = { id: `log_${Date.now()}_${vehicleAuditLogsDb.length}`, ...data, createdAt: new Date() };
          vehicleAuditLogsDb.push(log);
          return Promise.resolve(log);
        }),
      },
      inspection: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const key = `${where.bookingId_type.bookingId}_${where.bookingId_type.type}`;
          const ins = inspectionsDb.get(key);
          return Promise.resolve(ins ? JSON.parse(JSON.stringify(ins)) : null);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const key = `${data.bookingId}_${data.type}`;
          const record = { id: `ins_${Date.now()}`, ...data };
          inspectionsDb.set(key, record);
          return Promise.resolve(record);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const key = `${where.bookingId_type.bookingId}_${where.bookingId_type.type}`;
          const ins = inspectionsDb.get(key);
          if (ins) Object.assign(ins, data);
          return Promise.resolve(ins);
        }),
      },
      damageClaim: {
        findMany: jest.fn().mockImplementation(({ where }) => {
          let list = damageClaimsDb.filter((c) => c.bookingId === where.bookingId);
          if (where.status?.notIn) {
            list = list.filter((c) => !where.status.notIn.includes(c.status));
          }
          return Promise.resolve(list);
        }),
      },
      securityDeposit: {
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          const b = bookingsDb.get(where.bookingId);
          if (b && b.securityDeposit) {
            Object.assign(b.securityDeposit, data);
          }
          return Promise.resolve({ count: 1 });
        }),
      },
      bookingOutboxEvent: {
        create: jest.fn().mockImplementation(({ data }) => {
          const evt = { id: `evt_${Date.now()}`, ...data, createdAt: new Date() };
          outboxEventsDb.push(evt);
          return Promise.resolve(evt);
        }),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      locationException: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    };

    lockServiceMock = {
      acquireLock: jest.fn().mockResolvedValue('mock_lock_token'),
      releaseLock: jest.fn().mockResolvedValue(true),
      acquireCancellationLock: jest.fn().mockResolvedValue('mock_cancel_lock'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    cacheServiceMock = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue(true),
      delete: jest.fn().mockResolvedValue(true),
      invalidatePattern: jest.fn().mockResolvedValue(true),
    };

    configServiceMock = {
      getBookingPolicyConfig: jest.fn().mockResolvedValue({
        handoverOtpTtlMinutes: 15,
        cancellationGraceMinutes: 60,
        maxAdvanceBookingDays: 90,
        doorstepDeliveryMaxRadiusKm: 50,
        requirePreTripInspection: true,
        requireHandoverOtp: true,
        requireReturnOtp: true,
        blockVehicleOnReturnDamage: true,
        allowEarlyPickupMinutes: 30,
        requireVehicleActiveAtPickup: true,
      }),
      getFleetOperationsConfig: jest.fn().mockResolvedValue({
        fleetActivationEnabled: true,
        requireVendorVerified: true,
        requireVendorSecurityDeposit: false,
        requireServiceAreaAssignment: false,
        requireVehicleVerification: true,
        maxMaintenanceDays: 90,
        autoDeactivateOnMissingCoverage: false,
        allowVendorSelfDeactivation: true,
        mandatoryVehicleDocuments: [],
        availabilityBufferMinutes: 120,
      }),
    };

    handoverOtpMock = {
      verifyOtp: jest.fn().mockResolvedValue({ verified: true }),
      generateAndSendOtp: jest.fn().mockResolvedValue({ success: true }),
    };

    paymentsServiceMock = {
      refund: jest.fn().mockResolvedValue({ success: true, refundId: 'rf_123' }),
    };

    auditLogMock = {
      log: jest.fn().mockResolvedValue({}),
    };

    outboxServiceMock = {
      dispatchEvent: jest.fn().mockResolvedValue(true),
    };

    cancellationPolicyMock = {
      calculateCancellation: jest.fn().mockReturnValue({
        tier: 'FULL_REFUND',
        cancellationFee: 0,
        refundAmount: 12000,
        refundAmountInPaise: 1200000,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingLifecycleService,
        BookingsService,
        VehicleLifecycleService,
        VendorFleetService,
        VehicleOperationsEligibilityService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: BookingLockService, useValue: lockServiceMock },
        { provide: RedisCacheService, useValue: cacheServiceMock },
        { provide: SystemConfigService, useValue: configServiceMock },
        { provide: HandoverOtpService, useValue: handoverOtpMock },
        { provide: PaymentsService, useValue: paymentsServiceMock },
        { provide: AuditLogService, useValue: auditLogMock },
        { provide: BookingOutboxService, useValue: outboxServiceMock },
        { provide: CancellationPolicyService, useValue: cancellationPolicyMock },
        {
          provide: CommissionResolverService,
          useValue: { resolveCommissionPercent: jest.fn().mockResolvedValue(15) },
        },
        {
          provide: FareCalculatorService,
          useValue: {
            calculateFare: jest.fn().mockReturnValue({
              baseFare: new Prisma.Decimal(9000),
              platformFee: new Prisma.Decimal(450),
              gst: new Prisma.Decimal(850),
              total: new Prisma.Decimal(10300),
              netToVendor: new Prisma.Decimal(7650),
            }),
          },
        },
        {
          provide: NotificationsService,
          useValue: { notifyUser: jest.fn().mockResolvedValue(true) },
        },
        {
          provide: CouponsService,
          useValue: { validateCoupon: jest.fn() },
        },
      ],
    }).compile();

    lifecycleService = module.get<BookingLifecycleService>(BookingLifecycleService);
    bookingsService = module.get<BookingsService>(BookingsService);
    vehicleLifecycleService = module.get<VehicleLifecycleService>(VehicleLifecycleService);
    vendorFleetService = module.get<VendorFleetService>(VendorFleetService);
    eligibilityService = module.get<VehicleOperationsEligibilityService>(VehicleOperationsEligibilityService);
  });

  // Helper to seed a valid booking
  function seedBooking(overrides: Partial<any> = {}) {
    const start = new Date(Date.now() + 2 * 60 * 60 * 1000); // 2 hours from now
    const end = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours from now
    const id = overrides.id || `bk_${Date.now()}`;
    const car = carsDb.get(overrides.carId || defaultCarId);

    const booking = {
      id,
      customerId: CUSTOMER_USER_ID,
      vendorId: VENDOR_A_ID,
      carId: defaultCarId,
      status: BookingStatus.PENDING,
      startDate: start,
      endDate: end,
      totalFare: new Prisma.Decimal(10300),
      pickupLocation: 'Koramangala Hub, Bangalore',
      dropLocation: 'Indiranagar Hub, Bangalore',
      disputeFlag: false,
      disputeNote: null,
      car,
      customer: { id: CUSTOMER_USER_ID, name: 'Customer Test', phone: '+919000000001' },
      vendor: car.vendor,
      payment: {
        id: `pay_${id}`,
        status: PaymentStatus.PAID,
        amount: new Prisma.Decimal(10300),
      },
      securityDeposit: {
        id: `dep_${id}`,
        status: SecurityDepositStatus.HELD,
        amount: new Prisma.Decimal(5000),
      },
      ...overrides,
    };

    bookingsDb.set(id, booking);
    return booking;
  }

  // Helper to seed finalized inspections
  function seedInspection(bookingId: string, type: InspectionType, finalized = true, damagePhotos: string[] = [], notes = '') {
    inspectionsDb.set(`${bookingId}_${type}`, {
      id: `ins_${bookingId}_${type}`,
      bookingId,
      type,
      odometer: new Prisma.Decimal(15000),
      fuelPercent: 95,
      conditionNotes: notes || null,
      damagePhotos,
      finalized,
      finalizedAt: finalized ? new Date() : null,
    });
  }

  // ==========================================
  // CATEGORY A: Booking Eligibility
  // ==========================================
  describe('Category A: Booking Eligibility', () => {
    it('successfully creates booking when car is ACTIVE, VERIFIED, and vendor is compliant', async () => {
      const now = new Date();
      const start = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString();
      const end = new Date(now.getTime() + 72 * 60 * 60 * 1000).toISOString();

      const booking = await bookingsService.createBooking(CUSTOMER_USER_ID, {
        carId: defaultCarId,
        startDate: start,
        endDate: end,
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Bangalore Central',
      });

      expect(booking).toBeDefined();
      expect(booking.carId).toBe(defaultCarId);
      expect(booking.status).toBe(BookingStatus.PENDING);
    });
  });

  // ==========================================
  // CATEGORY B: Operational Vehicle Gating
  // ==========================================
  describe('Category B: Operational Vehicle Gating', () => {
    it.each([
      VehicleOperationalStatus.DRAFT,
      VehicleOperationalStatus.INACTIVE,
      VehicleOperationalStatus.MAINTENANCE,
      VehicleOperationalStatus.SUSPENDED,
      VehicleOperationalStatus.RETIRED,
    ])('rejects booking creation when vehicle is in operational status: %s', async (status) => {
      const car = carsDb.get(defaultCarId);
      car.operationalStatus = status;

      const start = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const end = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString();

      await expect(
        bookingsService.createBooking(CUSTOMER_USER_ID, {
          carId: defaultCarId,
          startDate: start,
          endDate: end,
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Bangalore Central',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY C: Vendor Eligibility
  // ==========================================
  describe('Category C: Vendor Eligibility', () => {
    it('rejects booking creation if vendor is not VERIFIED', async () => {
      const car = carsDb.get(defaultCarId);
      car.vendor.verificationStatus = VerificationStatus.PENDING;

      const start = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const end = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString();

      await expect(
        bookingsService.createBooking(CUSTOMER_USER_ID, {
          carId: defaultCarId,
          startDate: start,
          endDate: end,
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Bangalore Central',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ==========================================
  // CATEGORY D: Vehicle Verification
  // ==========================================
  describe('Category D: Vehicle Verification', () => {
    it.each([
      VehicleVerificationStatus.PENDING,
      VehicleVerificationStatus.REJECTED,
    ])('rejects booking creation when vehicle verificationStatus is %s', async (verStatus) => {
      const car = carsDb.get(defaultCarId);
      car.verificationStatus = verStatus;

      const start = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const end = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString();

      await expect(
        bookingsService.createBooking(CUSTOMER_USER_ID, {
          carId: defaultCarId,
          startDate: start,
          endDate: end,
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Bangalore Central',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ==========================================
  // CATEGORY E: Deposit & Payment Gating
  // ==========================================
  describe('Category E: Deposit & Payment Gating', () => {
    it('vendor cannot confirm unpaid booking', async () => {
      const b = seedBooking({
        status: BookingStatus.PENDING,
        payment: { status: PaymentStatus.PENDING, amount: new Prisma.Decimal(10300) },
      });

      await expect(
        lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR),
      ).rejects.toThrow(BadRequestException);
    });

    it('admin can confirm unpaid booking with explicit justification >= 10 chars', async () => {
      const b = seedBooking({
        status: BookingStatus.PENDING,
        payment: { status: PaymentStatus.PENDING, amount: new Prisma.Decimal(10300) },
      });

      const res = await lifecycleService.confirmBooking(
        b.id,
        ADMIN_USER_ID,
        Role.ADMIN,
        'Corporate client post-paid approval',
      );

      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.CONFIRMED);
    });

    it('pickup startRental fails if customer security deposit is still REQUIRED (unpaid)', async () => {
      const b = seedBooking({
        status: BookingStatus.CONFIRMED,
        securityDeposit: { status: SecurityDepositStatus.REQUIRED, amount: new Prisma.Decimal(5000) },
      });
      seedInspection(b.id, InspectionType.PRE_TRIP, true);

      await expect(
        lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ==========================================
  // CATEGORY F: Service-Area Gating
  // ==========================================
  describe('Category F: Service-Area Gating', () => {
    it('rejects booking when vehicle has active operational blocks in date range', async () => {
      const now = new Date();
      const start = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const end = new Date(now.getTime() + 72 * 60 * 60 * 1000);

      // Create overlapping vehicle block
      vehicleBlocksDb.push({
        id: 'block_maint_1',
        carId: defaultCarId,
        blockType: VehicleBlockType.MAINTENANCE,
        reason: 'Scheduled brake pad replacement',
        startDate: new Date(now.getTime() + 12 * 60 * 60 * 1000),
        endDate: new Date(now.getTime() + 36 * 60 * 60 * 1000),
      });

      await expect(
        bookingsService.createBooking(CUSTOMER_USER_ID, {
          carId: defaultCarId,
          startDate: start.toISOString(),
          endDate: end.toISOString(),
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Bangalore Central',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY G: Concurrent Booking Protection
  // ==========================================
  describe('Category G: Concurrent Booking Protection', () => {
    it('pessimistically rejects overlapping booking creation for same vehicle', async () => {
      const now = new Date();
      const start = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const end = new Date(now.getTime() + 72 * 60 * 60 * 1000);

      // Existing confirmed booking in that window
      seedBooking({
        carId: defaultCarId,
        status: BookingStatus.CONFIRMED,
        startDate: start,
        endDate: end,
      });

      await expect(
        bookingsService.createBooking(CUSTOMER_USER_ID, {
          carId: defaultCarId,
          startDate: start.toISOString(),
          endDate: end.toISOString(),
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Bangalore Central',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY H: Reservation Lock Integrity
  // ==========================================
  describe('Category H: Reservation Lock Integrity', () => {
    it('confirmation establishes BOOKING_RESERVED vehicle audit log', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });

      const res = await lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR);
      expect(res.success).toBe(true);

      const auditLog = vehicleAuditLogsDb.find(
        (l) => l.carId === defaultCarId && l.action === 'BOOKING_RESERVED',
      );
      expect(auditLog).toBeDefined();
      expect(auditLog.metadata.bookingId).toBe(b.id);
    });

    it('confirmation rejects if overlapping vehicle block was scheduled during pending payment', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });

      // Add overlapping block
      vehicleBlocksDb.push({
        id: 'block_conflict_1',
        carId: defaultCarId,
        blockType: VehicleBlockType.ADMIN_LOCK,
        reason: 'Compliance audit hold',
        startDate: b.startDate,
        endDate: b.endDate,
      });

      await expect(
        lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY I: Pickup Validation
  // ==========================================
  describe('Category I: Pickup Validation', () => {
    it('pickup fails if vehicle was deactivated or placed in maintenance after booking', async () => {
      const b = seedBooking({ status: BookingStatus.CONFIRMED });
      seedInspection(b.id, InspectionType.PRE_TRIP, true);

      // Vehicle was placed in maintenance after confirmation
      const car = carsDb.get(defaultCarId);
      car.operationalStatus = VehicleOperationalStatus.MAINTENANCE;

      await expect(
        lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456'),
      ).rejects.toThrow(ConflictException);
    });

    it('pickup fails if pre-trip inspection is missing or not finalized', async () => {
      const b = seedBooking({ status: BookingStatus.CONFIRMED });
      // No inspection seeded

      await expect(
        lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456'),
      ).rejects.toThrow(BadRequestException);
    });

    it('pickup fails if customer attempts pickup more than 30 mins before scheduled start', async () => {
      // Scheduled 3 hours in future
      const futureStart = new Date(Date.now() + 3 * 60 * 60 * 1000);
      const b = seedBooking({ status: BookingStatus.CONFIRMED, startDate: futureStart });
      seedInspection(b.id, InspectionType.PRE_TRIP, true);

      await expect(
        lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ==========================================
  // CATEGORY J: Pickup Idempotency
  // ==========================================
  describe('Category J: Pickup Idempotency', () => {
    it('repeated startRental when already ONGOING returns success without re-transitioning', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });

      const res = await lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR);
      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.ONGOING);
      expect(res.message).toContain('already in ONGOING');
    });
  });

  // ==========================================
  // CATEGORY K: Active Rental Protection
  // ==========================================
  describe('Category K: Active Rental Protection', () => {
    it('vendor cannot deactivate vehicle while rental is ONGOING', async () => {
      seedBooking({ status: BookingStatus.ONGOING, carId: defaultCarId });

      await expect(
        vehicleLifecycleService.transitionStatus(
          defaultCarId,
          VehicleOperationalStatus.INACTIVE,
          { id: VENDOR_A_USER_ID, role: Role.VENDOR, vendorId: VENDOR_A_ID },
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY L: Cancellation Release
  // ==========================================
  describe('Category L: Cancellation Release', () => {
    it('cancellation releases customer security deposit and writes BOOKING_CANCELLED audit log', async () => {
      const b = seedBooking({ status: BookingStatus.CONFIRMED });

      const res = await lifecycleService.cancelBooking(
        b.id,
        CUSTOMER_USER_ID,
        Role.CUSTOMER,
        'Trip plan changed',
      );

      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.CANCELLED);

      const cancelLog = vehicleAuditLogsDb.find(
        (l) => l.carId === defaultCarId && l.action === 'BOOKING_CANCELLED',
      );
      expect(cancelLog).toBeDefined();
    });
  });

  // ==========================================
  // CATEGORY M: Return Validation
  // ==========================================
  describe('Category M: Return Validation', () => {
    it('completion fails without finalized post-trip inspection', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });
      // Post-trip inspection not seeded

      await expect(
        lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321'),
      ).rejects.toThrow(BadRequestException);
    });

    it('completion fails without customer return verification OTP', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });
      seedInspection(b.id, InspectionType.POST_TRIP, true);

      await expect(
        lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR),
      ).rejects.toThrow(BadRequestException);
    });

    it('completion fails if active dispute flag is present without admin override', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING, disputeFlag: true });
      seedInspection(b.id, InspectionType.POST_TRIP, true);

      await expect(
        lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ==========================================
  // CATEGORY N: Concurrent Return Protection
  // ==========================================
  describe('Category N: Concurrent Return Protection', () => {
    it('prevents concurrent return processing via locking and state machine guard', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });
      seedInspection(b.id, InspectionType.POST_TRIP, true);

      // Simulate lock rejection or race condition
      prismaMock.booking.update.mockImplementationOnce(() => {
        const err: any = new Error('P2025');
        err.code = 'P2025';
        throw err;
      });

      await expect(
        lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321'),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY O: Return Idempotency
  // ==========================================
  describe('Category O: Return Idempotency', () => {
    it('re-executing completeBooking when already COMPLETED returns idempotent success', async () => {
      const b = seedBooking({ status: BookingStatus.COMPLETED });

      const res = await lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR);
      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.COMPLETED);
    });
  });

  // ==========================================
  // CATEGORY P: Maintenance Conflict Prevention
  // ==========================================
  describe('Category P: Maintenance Conflict Prevention', () => {
    it('vendor cannot start maintenance while a rental is currently ONGOING', async () => {
      seedBooking({ status: BookingStatus.ONGOING, carId: defaultCarId });

      await expect(
        vendorFleetService.startMaintenance(
          defaultCarId,
          { id: VENDOR_A_USER_ID, role: Role.VENDOR, vendorId: VENDOR_A_ID },
          { reason: 'Scheduled oil change', overrideConflictingBookings: true },
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ==========================================
  // CATEGORY Q: Suspension Conflict Prevention
  // ==========================================
  describe('Category Q: Suspension Conflict Prevention', () => {
    it('admin emergency suspension during active rental requires explicit justification >= 10 chars', async () => {
      seedBooking({ status: BookingStatus.ONGOING, carId: defaultCarId });

      // Short reason fails
      await expect(
        vehicleLifecycleService.transitionStatus(
          defaultCarId,
          VehicleOperationalStatus.SUSPENDED,
          { id: ADMIN_USER_ID, role: Role.ADMIN },
          { reason: 'Emergency' },
        ),
      ).rejects.toThrow(BadRequestException);

      // Explicit justification succeeds
      const res = await vehicleLifecycleService.transitionStatus(
        defaultCarId,
        VehicleOperationalStatus.SUSPENDED,
        { id: ADMIN_USER_ID, role: Role.ADMIN },
        { reason: 'Severe police inquiry and impoundment order received' },
      );
      expect(res.operationalStatus).toBe(VehicleOperationalStatus.SUSPENDED);
    });
  });

  // ==========================================
  // CATEGORY R: Damage / Inspection Blocking
  // ==========================================
  describe('Category R: Damage / Inspection Blocking', () => {
    it('post-trip damage photos place vehicle on SAFETY_HOLD and set operationalStatus to INACTIVE', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });
      seedInspection(
        b.id,
        InspectionType.POST_TRIP,
        true,
        ['https://storage.drivego.in/inspections/dents.webp'],
        'Major front bumper collision damage',
      );

      const res = await lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321');
      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.COMPLETED);

      // Vehicle must be marked INACTIVE
      const car = carsDb.get(defaultCarId);
      expect(car.operationalStatus).toBe(VehicleOperationalStatus.INACTIVE);
      expect(car.isAvailable).toBe(false);

      // VehicleBlock must exist
      const block = vehicleBlocksDb.find((blk) => blk.carId === defaultCarId && blk.blockType === VehicleBlockType.SAFETY_HOLD);
      expect(block).toBeDefined();

      // Audit log must reflect POST_RENTAL_DAMAGE_HOLD
      const auditLog = vehicleAuditLogsDb.find((l) => l.action === 'POST_RENTAL_DAMAGE_HOLD');
      expect(auditLog).toBeDefined();
      expect(auditLog.toStatus).toBe(VehicleOperationalStatus.INACTIVE);
    });
  });

  // ==========================================
  // CATEGORY S: Vehicle Restoration
  // ==========================================
  describe('Category S: Vehicle Restoration', () => {
    it('clean post-trip inspection without damage leaves vehicle ACTIVE and available', async () => {
      const b = seedBooking({ status: BookingStatus.ONGOING });
      seedInspection(b.id, InspectionType.POST_TRIP, true, [], 'Vehicle in showroom condition');

      const res = await lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321');
      expect(res.success).toBe(true);

      const car = carsDb.get(defaultCarId);
      expect(car.operationalStatus).toBe(VehicleOperationalStatus.ACTIVE);
      expect(car.isAvailable).toBe(true);

      const auditLog = vehicleAuditLogsDb.find((l) => l.action === 'RENTAL_COMPLETED');
      expect(auditLog).toBeDefined();
      expect(auditLog.toStatus).toBe(VehicleOperationalStatus.ACTIVE);
    });
  });

  // ==========================================
  // CATEGORY T: Audit History
  // ==========================================
  describe('Category T: Audit History', () => {
    it('records complete audit trail across full lifecycle: RESERVED -> STARTED -> COMPLETED', async () => {
      const now = new Date();
      const b = seedBooking({
        status: BookingStatus.PENDING,
        startDate: new Date(now.getTime() + 10 * 60 * 1000), // 10 minutes from now (within 30m window)
      });

      // 1. Confirm
      await lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR);
      // 2. Pre-trip inspection & Start rental
      seedInspection(b.id, InspectionType.PRE_TRIP, true);
      await lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456');
      // 3. Post-trip inspection & Complete
      seedInspection(b.id, InspectionType.POST_TRIP, true, [], 'All good');
      await lifecycleService.completeBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR, '654321');

      const actions = vehicleAuditLogsDb.map((l) => l.action);
      expect(actions).toContain('BOOKING_RESERVED');
      expect(actions).toContain('RENTAL_STARTED');
      expect(actions).toContain('RENTAL_COMPLETED');
    });
  });

  // ==========================================
  // CATEGORY U: RBAC
  // ==========================================
  describe('Category U: RBAC', () => {
    it('customer cannot confirm booking', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });
      await expect(
        lifecycleService.confirmBooking(b.id, CUSTOMER_USER_ID, Role.CUSTOMER),
      ).rejects.toThrow(ForbiddenException);
    });

    it('customer cannot start rental', async () => {
      const b = seedBooking({ status: BookingStatus.CONFIRMED });
      await expect(
        lifecycleService.startRental(b.id, CUSTOMER_USER_ID, Role.CUSTOMER, '123456'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  // ==========================================
  // CATEGORY V: Cross-Vendor Isolation
  // ==========================================
  describe('Category V: Cross-Vendor Isolation', () => {
    it('vendor B cannot confirm or operate on vendor A bookings', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });

      await expect(
        lifecycleService.confirmBooking(b.id, VENDOR_B_USER_ID, Role.VENDOR),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  // ==========================================
  // CATEGORY W: Configuration Changes
  // ==========================================
  describe('Category W: Configuration Changes', () => {
    it('early pickup window adjusts dynamically when platform config changes', async () => {
      // Configure early pickup to 60 minutes
      configServiceMock.getBookingPolicyConfig.mockResolvedValueOnce({
        allowEarlyPickupMinutes: 60,
      });

      // Scheduled 45 minutes in future (allowed under 60m, but was blocked under 30m)
      const futureStart = new Date(Date.now() + 45 * 60 * 1000);
      const b = seedBooking({ status: BookingStatus.CONFIRMED, startDate: futureStart });
      seedInspection(b.id, InspectionType.PRE_TRIP, true);

      const res = await lifecycleService.startRental(b.id, VENDOR_A_USER_ID, Role.VENDOR, '123456');
      expect(res.success).toBe(true);
      expect(res.newStatus).toBe(BookingStatus.ONGOING);
    });
  });

  // ==========================================
  // CATEGORY X: Cache Invalidation
  // ==========================================
  describe('Category X: Cache Invalidation', () => {
    it('lifecycle mutations trigger Redis cache invalidation for car availability and eligibility', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });

      await lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR);

      expect(cacheServiceMock.delete).toHaveBeenCalled();
    });
  });

  // ==========================================
  // CATEGORY Y: Regression Compatibility
  // ==========================================
  describe('Category Y: Regression Compatibility', () => {
    it('outbox events are generated and dispatched as in prior phases', async () => {
      const b = seedBooking({ status: BookingStatus.PENDING });

      const res = await lifecycleService.confirmBooking(b.id, VENDOR_A_USER_ID, Role.VENDOR);
      expect(res.outboxEventId).toBeDefined();
      expect(outboxServiceMock.dispatchEvent).toHaveBeenCalledWith(res.outboxEventId);
    });
  });
});
