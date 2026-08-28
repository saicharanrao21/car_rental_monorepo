import { Test, TestingModule } from '@nestjs/testing';
import { CarsService } from './cars.service';
import { BookingsService } from '../bookings/bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { CouponsService } from '../coupons/coupons.service';
import { ReferralsService } from '../referrals/referrals.service';
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { FraudService, RiskAction } from '../fraud/fraud.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from '../bookings/cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import { HandoverOtpService } from '../bookings/handover-otp.service';
import { TripType, Role, CarCategory, FuelType, VerificationStatus } from '@prisma/client';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

describe('Configurable Mileage Packages Test Suite', () => {
  let carsService: CarsService;
  let bookingsService: BookingsService;
  let prisma: any;

  const mockVendorOwner = {
    id: 'vendor_1',
    userId: 'user_vendor_1',
    city: 'Mumbai',
    verificationStatus: VerificationStatus.VERIFIED,
  };
  const mockVendorOther = {
    id: 'vendor_2',
    userId: 'user_vendor_2',
    city: 'Mumbai',
    verificationStatus: VerificationStatus.VERIFIED,
  };

  const mockCar = {
    id: 'car_1',
    vendorId: 'vendor_1',
    make: 'Hyundai',
    model: 'Creta',
    year: 2023,
    type: CarCategory.SUV,
    fuelType: FuelType.PETROL,
    seating: 5,
    isAC: true,
    registrationNumber: 'MH01AB1234',
    photos: [],
    pricePerKm: new Prisma.Decimal(15),
    pricePerDay: new Prisma.Decimal(3000),
    pricePerHour: new Prisma.Decimal(200),
    weeklyDiscountPercent: 10,
    monthlyDiscountPercent: 20,
    isAvailable: true,
    availableTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
    blockedDates: [],
    vendor: mockVendorOwner,
  };

  beforeEach(async () => {
    prisma = {
      car: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
      },
      mileagePackage: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        delete: jest.fn(),
      },
      booking: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        create: jest.fn(),
      },
      $transaction: jest.fn(async (cb) => cb(prisma)),
      $queryRaw: jest.fn(),
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION, TripType.LOCAL],
        }),
      },
      supportedCity: {
        findFirst: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CarsService,
        BookingsService,
        FareCalculatorService,
        {
          provide: CommissionResolverService,
          useValue: {
            resolveCommissionPercent: jest.fn().mockResolvedValue(10),
          },
        },
        {
          provide: CouponsService,
          useValue: {
            validateCoupon: jest.fn(),
          },
        },
        {
          provide: ReferralsService,
          useValue: {
            getRefereeEligibility: jest.fn().mockResolvedValue({ eligible: false }),
          },
        },
        {
          provide: DepositRulesService,
          useValue: {
            getDepositAmount: jest.fn().mockResolvedValue(5000),
          },
        },
        {
          provide: FraudService,
          useValue: {
            evaluateUserRisk: jest.fn().mockResolvedValue({ action: RiskAction.ALLOW, score: 10 }),
          },
        },
        {
          provide: BookingLockService,
          useValue: {
            acquireLock: jest.fn().mockResolvedValue(true),
            releaseLock: jest.fn().mockResolvedValue(true),
          },
        },
        {
          provide: PaymentsService,
          useValue: {},
        },
        {
          provide: NotificationsService,
          useValue: {
            notifyVendorNewBooking: jest.fn(),
          },
        },
        {
          provide: CancellationPolicyService,
          useValue: {},
        },
        {
          provide: AuditLogService,
          useValue: {},
        },
        {
          provide: HandoverOtpService,
          useValue: {},
        },
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    carsService = module.get<CarsService>(CarsService);
    bookingsService = module.get<BookingsService>(BookingsService);
  });

  describe('1. Vendor Mileage Package Management & Validation', () => {
    it('allows vendor to create package for their own car', async () => {
      prisma.vendor.findUnique.mockResolvedValue(mockVendorOwner);
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 'pkg_1', ...data }),
      );

      const result = await carsService.createCarMileagePackage('user_vendor_1', 'car_1', {
        tripType: TripType.SELF_DRIVE,
        name: '100 km/day',
        includedKmPerDay: 100,
        basePricePerDay: 2500,
        extraKmRate: 12,
        isDefault: true,
      });

      expect(result.id).toBe('pkg_1');
      expect(result.includedKmPerDay).toBe(100);
      expect(result.isDefault).toBe(true);
      expect(prisma.mileagePackage.updateMany).toHaveBeenCalledWith({
        where: { carId: 'car_1', tripType: TripType.SELF_DRIVE, isDefault: true },
        data: { isDefault: false },
      });
    });

    it('rejects vendor creating package for another vendor\'s car', async () => {
      prisma.vendor.findUnique.mockResolvedValue(mockVendorOther);
      prisma.car.findUnique.mockResolvedValue(mockCar); // car.vendorId is vendor_1

      await expect(
        carsService.createCarMileagePackage('user_vendor_2', 'car_1', {
          tripType: TripType.SELF_DRIVE,
          name: '100 km/day',
          includedKmPerDay: 100,
          basePricePerDay: 2500,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects negative or zero base price and negative extra km rate', async () => {
      prisma.vendor.findUnique.mockResolvedValue(mockVendorOwner);
      prisma.car.findUnique.mockResolvedValue(mockCar);

      await expect(
        carsService.createCarMileagePackage('user_vendor_1', 'car_1', {
          tripType: TripType.SELF_DRIVE,
          name: 'Invalid Price',
          includedKmPerDay: 100,
          basePricePerDay: 0,
        }),
      ).rejects.toThrow(BadRequestException);

      await expect(
        carsService.createCarMileagePackage('user_vendor_1', 'car_1', {
          tripType: TripType.SELF_DRIVE,
          name: 'Negative Extra Km',
          includedKmPerDay: 100,
          basePricePerDay: 2500,
          extraKmRate: -5,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('supports unlimited package representation with null includedKmPerDay', async () => {
      prisma.vendor.findUnique.mockResolvedValue(mockVendorOwner);
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 'pkg_unlimited', ...data }),
      );

      const result = await carsService.createCarMileagePackage('user_vendor_1', 'car_1', {
        tripType: TripType.SELF_DRIVE,
        name: 'Unlimited',
        isUnlimited: true,
        basePricePerDay: 4000,
        extraKmRate: 0,
      });

      expect(result.includedKmPerDay).toBeNull();
      expect(result.basePricePerDay).toEqual(new Prisma.Decimal(4000));
    });

    it('soft-deactivates package when existing bookings reference it', async () => {
      prisma.vendor.findUnique.mockResolvedValue(mockVendorOwner);
      prisma.mileagePackage.findUnique.mockResolvedValue({
        id: 'pkg_1',
        carId: 'car_1',
        car: mockCar,
      });
      prisma.booking.count.mockResolvedValue(3); // 3 historical bookings

      const res = await carsService.deleteCarMileagePackage('user_vendor_1', 'car_1', 'pkg_1');

      expect(prisma.mileagePackage.update).toHaveBeenCalledWith({
        where: { id: 'pkg_1' },
        data: { isActive: false, isDefault: false },
      });
      expect(res.message).toContain('deactivated');
    });
  });

  describe('2. Booking Authoritative Pricing & Snapshot Persistence', () => {
    const activePackage = {
      id: 'pkg_200km',
      carId: 'car_1',
      tripType: TripType.SELF_DRIVE,
      name: '200 km/day',
      includedKmPerDay: 200,
      basePricePerDay: new Prisma.Decimal(3200),
      extraKmRate: new Prisma.Decimal(10),
      isDefault: true,
      isActive: true,
    };

    const getFutureDates = (durationDays: number) => {
      const now = new Date();
      const start = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const end = new Date(start.getTime() + durationDays * 24 * 60 * 60 * 1000);
      return { startDate: start, endDate: end };
    };

    it('calculates authoritative price from selected package and stores immutable snapshot', async () => {
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.findUnique.mockResolvedValue(activePackage);
      prisma.booking.findFirst.mockResolvedValue(null); // No overlap

      let createdBookingPayload: any = null;
      prisma.booking.create.mockImplementation(({ data, include }) => {
        createdBookingPayload = data;
        return Promise.resolve({ id: 'bk_123', ...data, car: mockCar, customer: { id: 'cust_1' } });
      });

      const { startDate, endDate } = getFutureDates(3); // 3 days

      const booking = await bookingsService.createBooking('cust_1', {
        carId: 'car_1',
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Mumbai Airport',
        dropLocation: 'Mumbai Airport',
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        mileagePackageId: 'pkg_200km',
      });

      expect(booking.id).toBe('bk_123');
      expect(createdBookingPayload.pricingBasis).toBe('PACKAGE_TIER');
      expect(createdBookingPayload.mileagePackageId).toBe('pkg_200km');
      expect(createdBookingPayload.mileagePackageName).toBe('200 km/day');
      expect(createdBookingPayload.includedKmPerDay).toBe(200);
      expect(createdBookingPayload.includedKmTotal).toBe(600); // 200 * 3 days
      expect(createdBookingPayload.packageBasePricePerDay).toEqual(new Prisma.Decimal(3200));
      expect(createdBookingPayload.extraKmRate).toEqual(new Prisma.Decimal(10));
      
      // Base price for 3 days = 3200 * 3 = 9600
      expect(Number(createdBookingPayload.baseFare)).toBe(9600);
    });

    it('rejects booking if package does not belong to the selected car', async () => {
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.findUnique.mockResolvedValue({
        ...activePackage,
        carId: 'car_OTHER',
      });

      const { startDate, endDate } = getFutureDates(1);

      await expect(
        bookingsService.createBooking('cust_1', {
          carId: 'car_1',
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Mumbai',
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          mileagePackageId: 'pkg_200km',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects booking if package is inactive', async () => {
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.findUnique.mockResolvedValue({
        ...activePackage,
        isActive: false,
      });

      const { startDate, endDate } = getFutureDates(1);

      await expect(
        bookingsService.createBooking('cust_1', {
          carId: 'car_1',
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Mumbai',
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          mileagePackageId: 'pkg_200km',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects booking if package tripType does not match booking tripType', async () => {
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.mileagePackage.findUnique.mockResolvedValue({
        ...activePackage,
        tripType: TripType.OUTSTATION,
      });

      const { startDate, endDate } = getFutureDates(1);

      await expect(
        bookingsService.createBooking('cust_1', {
          carId: 'car_1',
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Mumbai',
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          mileagePackageId: 'pkg_200km',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('legacy car without packages still creates booking successfully with LEGACY_DAILY pricing', async () => {
      prisma.car.findUnique.mockResolvedValue(mockCar);
      prisma.booking.findFirst.mockResolvedValue(null);

      let createdBookingPayload: any = null;
      prisma.booking.create.mockImplementation(({ data }) => {
        createdBookingPayload = data;
        return Promise.resolve({ id: 'bk_legacy', ...data, car: mockCar, customer: { id: 'cust_1' } });
      });

      const { startDate, endDate } = getFutureDates(2); // 2 days

      const booking = await bookingsService.createBooking('cust_1', {
        carId: 'car_1',
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Mumbai',
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        distanceKm: 50,
      });

      expect(booking.id).toBe('bk_legacy');
      expect(createdBookingPayload.pricingBasis).toBe('LEGACY_DAILY');
      expect(createdBookingPayload.mileagePackageId).toBeNull();
      // Legacy fare = 3000 * 2 + 50 * 15 = 6000 + 750 = 6750
      expect(Number(createdBookingPayload.baseFare)).toBe(6750);
    });
  });
});
