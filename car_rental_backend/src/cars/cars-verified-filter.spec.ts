import { Test, TestingModule } from '@nestjs/testing';
import { CarsService } from './cars.service';
import { BookingsService } from '../bookings/bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from '../bookings/cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import { HandoverOtpService } from '../bookings/handover-otp.service';
import { VerificationStatus, TripType, Prisma } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('Phase 4E: Verified Vendor Fleet Filtering', () => {
  let carsService: CarsService;
  let bookingsService: BookingsService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      car: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
      },
      booking: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        }),
      },
      vendor: {
        findUnique: jest.fn().mockResolvedValue({ userId: 'v-1' }),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CarsService,
        BookingsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: BookingLockService,
          useValue: {
            acquireLock: jest.fn().mockResolvedValue('token-1'),
            releaseLock: jest.fn(),
          },
        },
        {
          provide: CommissionResolverService,
          useValue: { resolveCommissionPercent: jest.fn().mockResolvedValue(10) },
        },
        {
          provide: FareCalculatorService,
          useValue: {
            calculateFare: jest.fn().mockReturnValue({
              baseFare: new Prisma.Decimal(4000),
              platformFee: new Prisma.Decimal(400),
              gst: new Prisma.Decimal(72),
              total: new Prisma.Decimal(4472),
              netToVendor: new Prisma.Decimal(3600),
            }),
          },
        },
        { provide: PaymentsService, useValue: {} },
        { provide: NotificationsService, useValue: { notifyUser: jest.fn().mockResolvedValue({}) } },
        { provide: CancellationPolicyService, useValue: {} },
        { provide: AuditLogService, useValue: {} },
        { provide: HandoverOtpService, useValue: {} },
      ],
    }).compile();

    carsService = module.get<CarsService>(CarsService);
    bookingsService = module.get<BookingsService>(BookingsService);
  });

  it('1. should enforce verificationStatus === VERIFIED in public searchCars when isAdmin is false', async () => {
    await carsService.searchCars({}, false);

    expect(prisma.car.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          isAvailable: true,
          vendor: expect.objectContaining({
            verificationStatus: VerificationStatus.VERIFIED,
          }),
        }),
      }),
    );
  });

  it('2. should not restrict verificationStatus in admin searchCars when isAdmin is true', async () => {
    await carsService.searchCars({}, true);

    expect(prisma.car.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.not.objectContaining({
          isAvailable: true,
        }),
      }),
    );
  });

  it('3. should reject createBooking for a car owned by an unverified or pending vendor', async () => {
    prisma.car.findUnique.mockResolvedValue({
      id: 'car-unverified-1',
      isAvailable: true,
      availableTripTypes: [TripType.SELF_DRIVE],
      blockedDates: [],
      pricePerDay: new Prisma.Decimal(2000),
      pricePerHour: new Prisma.Decimal(200),
      pricePerKm: new Prisma.Decimal(15),
      vendorId: 'vendor-pending',
      vendor: {
        id: 'vendor-pending',
        city: 'Bengaluru',
        verificationStatus: VerificationStatus.PENDING, // Unverified!
      },
    });

    await expect(
      bookingsService.createBooking('cust-1', {
        carId: 'car-unverified-1',
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Koramangala',
        startDate: new Date(Date.now() + 86400000).toISOString(),
        endDate: new Date(Date.now() + 172800000).toISOString(),
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('4. should reject createBooking for a car owned by a suspended/rejected vendor', async () => {
    prisma.car.findUnique.mockResolvedValue({
      id: 'car-suspended-1',
      isAvailable: true,
      availableTripTypes: [TripType.SELF_DRIVE],
      blockedDates: [],
      pricePerDay: new Prisma.Decimal(2000),
      pricePerHour: new Prisma.Decimal(200),
      pricePerKm: new Prisma.Decimal(15),
      vendorId: 'vendor-suspended',
      vendor: {
        id: 'vendor-suspended',
        city: 'Bengaluru',
        verificationStatus: VerificationStatus.SUSPENDED,
      },
    });

    await expect(
      bookingsService.createBooking('cust-1', {
        carId: 'car-suspended-1',
        tripType: TripType.SELF_DRIVE,
        pickupLocation: 'Indiranagar',
        startDate: new Date(Date.now() + 86400000).toISOString(),
        endDate: new Date(Date.now() + 172800000).toISOString(),
      }),
    ).rejects.toThrow(BadRequestException);
  });

  describe('Direct Car Lookup (findOne) Verified Vendor Policy', () => {
    const sampleCar = {
      id: 'car-direct-1',
      make: 'Maruti',
      model: 'Swift',
      vendorId: 'vendor-1',
      vendor: {
        id: 'vendor-1',
        userId: 'vendor-user-1',
        businessName: 'Swift Fleet',
        verificationStatus: VerificationStatus.VERIFIED,
      },
    };

    it('5. should allow public customer to view car belonging to a VERIFIED vendor', async () => {
      prisma.car.findUnique.mockResolvedValue(sampleCar);

      const result = await carsService.findOne('car-direct-1', undefined);
      expect(result.id).toBe('car-direct-1');
    });

    it('6. should hide car (throw NotFoundException) from public customer if vendor is PENDING or SUSPENDED', async () => {
      prisma.car.findUnique.mockResolvedValue({
        ...sampleCar,
        vendor: {
          ...sampleCar.vendor,
          verificationStatus: VerificationStatus.PENDING,
        },
      });

      await expect(
        carsService.findOne('car-direct-1', undefined),
      ).rejects.toThrow('Car not found');
    });

    it('7. should allow vendor owner to view their own car even if vendor is PENDING', async () => {
      prisma.car.findUnique.mockResolvedValue({
        ...sampleCar,
        vendor: {
          ...sampleCar.vendor,
          userId: 'vendor-user-1',
          verificationStatus: VerificationStatus.PENDING,
        },
      });

      const result = await carsService.findOne('car-direct-1', {
        userId: 'vendor-user-1',
        role: 'VENDOR' as any,
      });
      expect(result.id).toBe('car-direct-1');
    });

    it('8. should allow ADMIN or SUPPORT_AGENT to view car belonging to unverified vendor', async () => {
      prisma.car.findUnique.mockResolvedValue({
        ...sampleCar,
        vendor: {
          ...sampleCar.vendor,
          verificationStatus: VerificationStatus.PENDING,
        },
      });

      const resultAdmin = await carsService.findOne('car-direct-1', {
        userId: 'admin-1',
        role: 'ADMIN' as any,
      });
      expect(resultAdmin.id).toBe('car-direct-1');

      const resultSupport = await carsService.findOne('car-direct-1', {
        userId: 'support-1',
        role: 'SUPPORT_AGENT' as any,
      });
      expect(resultSupport.id).toBe('car-direct-1');
    });
  });
});
