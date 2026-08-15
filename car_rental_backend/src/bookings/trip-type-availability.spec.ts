import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CarsService } from '../cars/cars.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import { HandoverOtpService } from './handover-otp.service';
import { TripType, VerificationStatus, CarCategory, FuelType } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Trip-Type Platform Availability & Security Gate Tests', () => {
  let bookingsService: BookingsService;
  let carsService: CarsService;
  let prisma: any;

  const mockSettings = {
    id: 'singleton',
    platformName: 'DriveGo',
    enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
  };

  const mockVerifiedVendor = {
    id: 'vendor_verified_1',
    userId: 'user_vendor_1',
    verificationStatus: VerificationStatus.VERIFIED,
    businessName: 'Apex Rentals',
    city: 'Mumbai',
  };

  const mockCar = {
    id: 'car_multi_trip_1',
    vendorId: 'vendor_verified_1',
    make: 'Maruti Suzuki',
    model: 'Swift',
    year: 2022,
    type: CarCategory.HATCHBACK,
    fuelType: FuelType.PETROL,
    seating: 5,
    isAC: true,
    registrationNumber: 'MH02AB1234',
    photos: ['https://example.com/swift.jpg'],
    pricePerKm: new Decimal(12),
    pricePerDay: new Decimal(2000),
    pricePerHour: new Decimal(150),
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'LOCAL', 'OUTSTATION'],
    blockedDates: [],
    vendor: mockVerifiedVendor,
  };

  beforeEach(async () => {
    prisma = {
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue(mockSettings),
        create: jest.fn().mockResolvedValue(mockSettings),
      },
      car: {
        findUnique: jest.fn().mockResolvedValue(mockCar),
        findMany: jest.fn().mockResolvedValue([mockCar]),
        create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'new_car_1', ...args.data })),
        update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
      },
      vendor: {
        findUnique: jest.fn().mockResolvedValue(mockVerifiedVendor),
      },
      booking: {
        create: jest.fn().mockImplementation((args) =>
          Promise.resolve({
            id: 'book_new_1',
            status: 'PENDING',
            ...args.data,
          }),
        ),
      },
      $transaction: jest.fn().mockImplementation(async (cb) => {
        return cb({
          $queryRaw: jest.fn().mockResolvedValue([]),
          booking: {
            findFirst: jest.fn().mockResolvedValue(null),
            create: jest.fn().mockResolvedValue({
              id: 'book_new_1',
              status: 'PENDING',
              tripType: TripType.SELF_DRIVE,
              totalFare: new Decimal(2500),
              car: mockCar,
              customer: { id: 'user_cust_1', name: 'Rahul' },
            }),
          },
          securityDeposit: {
            create: jest.fn().mockResolvedValue({ id: 'dep_1' }),
          },
        });
      }),
    };

    const mockLockService = {
      acquireLock: jest.fn().mockResolvedValue('mock-token'),
      releaseLock: jest.fn().mockResolvedValue(undefined),
    };

    const mockFareCalc = {
      calculateFare: jest.fn().mockReturnValue({
        baseFare: new Decimal(2000),
        platformFee: new Decimal(200),
        gstAmount: new Decimal(36),
        totalFare: new Decimal(2236),
        netToVendor: new Decimal(2000),
      }),
      calculateSecurityDeposit: jest.fn().mockReturnValue(new Decimal(0)),
    };

    const mockCommissionResolver = {
      resolveCommissionPercent: jest.fn().mockResolvedValue(new Decimal(10)),
    };

    const mockPaymentsService = {};
    const mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };
    const mockCancellationPolicy = {};
    const mockAuditLog = {
      log: jest.fn().mockResolvedValue(undefined),
    };
    const mockHandoverOtp = {};

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        CarsService,
        { provide: PrismaService, useValue: prisma },
        { provide: BookingLockService, useValue: mockLockService },
        { provide: FareCalculatorService, useValue: mockFareCalc },
        { provide: CommissionResolverService, useValue: mockCommissionResolver },
        { provide: PaymentsService, useValue: mockPaymentsService },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: CancellationPolicyService, useValue: mockCancellationPolicy },
        { provide: AuditLogService, useValue: mockAuditLog },
        { provide: HandoverOtpService, useValue: mockHandoverOtp },
      ],
    }).compile();

    bookingsService = module.get<BookingsService>(BookingsService);
    carsService = module.get<CarsService>(CarsService);
  });

  describe('Scenario A & B: Enabled Trip Types (SELF_DRIVE & OUTSTATION)', () => {
    it('Scenario A: SELF_DRIVE booking succeeds', async () => {
      const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
      const dayAfter = new Date(Date.now() + 48 * 3600 * 1000);

      const result = await bookingsService.createBooking('user_cust_1', {
        carId: 'car_multi_trip_1',
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Mumbai Airport T2',
        startDate: tomorrow.toISOString(),
        endDate: dayAfter.toISOString(),
        estimatedDistanceKm: 100,
      });

      expect(result).toBeDefined();
      expect(result.id).toBe('book_new_1');
    });

    it('Scenario B: OUTSTATION booking succeeds', async () => {
      const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
      const dayAfter = new Date(Date.now() + 72 * 3600 * 1000);

      const result = await bookingsService.createBooking('user_cust_1', {
        carId: 'car_multi_trip_1',
        tripType: TripType.OUTSTATION,
        pickupLocation: 'Mumbai',
        dropLocation: 'Pune',
        startDate: tomorrow.toISOString(),
        endDate: dayAfter.toISOString(),
        estimatedDistanceKm: 300,
      });

      expect(result).toBeDefined();
      expect(result.id).toBe('book_new_1');
    });
  });

  describe('Scenario C & D: Disabled Trip Types (LOCAL & AIRPORT_TRANSFER)', () => {
    it('Scenario C: LOCAL booking is rejected when globally disabled', async () => {
      const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
      const dayAfter = new Date(Date.now() + 48 * 3600 * 1000);

      await expect(
        bookingsService.createBooking('user_cust_1', {
          carId: 'car_multi_trip_1',
          tripType: TripType.LOCAL,
          pickupLocation: 'Bandra',
          startDate: tomorrow.toISOString(),
          endDate: dayAfter.toISOString(),
          estimatedDistanceKm: 50,
        }),
      ).rejects.toThrow(new BadRequestException('This trip type is not currently available'));
    });

    it('Scenario D: AIRPORT_TRANSFER booking is rejected when globally disabled', async () => {
      const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
      const dayAfter = new Date(Date.now() + 48 * 3600 * 1000);

      await expect(
        bookingsService.createBooking('user_cust_1', {
          carId: 'car_multi_trip_1',
          tripType: TripType.AIRPORT_TRANSFER,
          pickupLocation: 'Mumbai Airport',
          dropLocation: 'Hotel Taj',
          startDate: tomorrow.toISOString(),
          endDate: dayAfter.toISOString(),
          estimatedDistanceKm: 25,
        }),
      ).rejects.toThrow(new BadRequestException('This trip type is not currently available'));
    });
  });

  describe('Scenario E & F: Vendor Bypass Prevention', () => {
    it('Scenario E: Vendor cannot bypass global availability by adding LOCAL in availableTripTypes during car creation', async () => {
      await expect(
        carsService.createCar('user_vendor_1', {
          make: 'Hyundai',
          model: 'i20',
          year: 2023,
          type: CarCategory.HATCHBACK,
          fuelType: FuelType.PETROL,
          seating: 5,
          isAC: true,
          registrationNumber: 'MH02XY9999',
          photos: [],
          pricePerKm: 15,
          pricePerDay: 2200,
          pricePerHour: 180,
          availableTripTypes: ['SELF_DRIVE', 'LOCAL'],
        }),
      ).rejects.toThrow(
        new BadRequestException('Trip type(s) LOCAL are not currently enabled on the platform.'),
      );
    });

    it('Scenario F: Vendor cannot bypass global availability by adding AIRPORT_TRANSFER during car update', async () => {
      await expect(
        carsService.updateCar('car_multi_trip_1', 'user_vendor_1', {
          availableTripTypes: ['SELF_DRIVE', 'AIRPORT_TRANSFER'],
        }),
      ).rejects.toThrow(
        new BadRequestException('Trip type(s) AIRPORT_TRANSFER are not currently enabled on the platform.'),
      );
    });
  });

  describe('Scenario G: Public Vehicle Search Behavior', () => {
    it('Scenario G: Public vehicle search for disabled trip type (LOCAL) returns empty list', async () => {
      const result = await carsService.searchCars(
        {
          tripType: 'LOCAL' as any,
          page: 1,
          limit: 10,
        },
        false,
      );

      expect(result.data).toEqual([]);
      expect(result.total).toBe(0);
      expect(prisma.car.findMany).not.toHaveBeenCalled();
    });

    it('Public vehicle search for enabled trip type (SELF_DRIVE) queries and returns available cars', async () => {
      const result = await carsService.searchCars(
        {
          tripType: 'SELF_DRIVE' as any,
          page: 1,
          limit: 10,
        },
        false,
      );

      expect(result.data.length).toBeGreaterThan(0);
      expect(prisma.car.findMany).toHaveBeenCalled();
    });
  });
});
