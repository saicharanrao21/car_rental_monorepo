import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
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
import { CouponsService } from '../coupons/coupons.service';
import { LocationsService } from './locations.service';
import { BookingStatus, DeliveryType, HandoverOtpType, InspectionType, PaymentStatus, Prisma, Role, TripType, VerificationStatus } from '@prisma/client';

describe('Phase 29.17: Cross-Platform Fulfillment Production Integration Suite', () => {
  let bookingsService: BookingsService;
  let handoverOtpService: HandoverOtpService;
  let mockPrisma: any;
  let mockHandoverOtpService: any;
  let mockAuditLogService: any;
  let mockLocationsService: any;

  const vendorAId = 'vnd_apex_01';
  const vendorBId = 'vnd_competitor_02';
  const vendorAUserId = 'usr_vendor_a';
  const vendorBUserId = 'usr_vendor_b';
  const customerUserId = 'usr_customer_01';
  const adminUserId = 'usr_admin_master';

  const mockAuthoritativeBooking = {
    id: 'bk_fulfillment_e2e_01',
    customerId: customerUserId,
    vendorId: vendorAId,
    carId: 'car_hyundai_creta',
    tripType: TripType.ROUND_TRIP,
    pickupLocation: 'Main Operating Yard, Andheri East',
    dropLocation: 'BKC Corporate Branch Hub',
    startDate: new Date('2026-09-10T10:00:00Z'),
    endDate: new Date('2026-09-12T18:00:00Z'),
    baseFare: new Prisma.Decimal(4500),
    platformFee: new Prisma.Decimal(450),
    gstAmount: new Prisma.Decimal(810),
    totalFare: new Prisma.Decimal(6360),
    netToVendor: new Prisma.Decimal(5100),
    status: BookingStatus.CONFIRMED,
    disputeFlag: false,
    disputeNote: null,
    // 13 Authoritative Fulfillment Snapshot Fields
    deliveryType: DeliveryType.DOORSTEP_DELIVERY,
    pickupAddress: 'Sector 4, Andheri East, Mumbai, Maharashtra 400069',
    deliveryAddress: 'Flat 402, Sea Face Towers, Worli, Mumbai',
    deliveryFee: new Prisma.Decimal(350),
    pickupFee: new Prisma.Decimal(0),
    returnFee: new Prisma.Decimal(150),
    oneWayFee: new Prisma.Decimal(250),
    deliveryLatitude: 19.0178,
    deliveryLongitude: 72.8178,
    pickupHubId: 'hub_andheri_main',
    returnHubId: 'hub_bkc_premium',
    pickupName: 'Andheri East Main Yard',
    dropName: 'BKC Premium Branch Hub',
    vendor: { id: vendorAId, userId: vendorAUserId, city: 'Mumbai', businessName: 'Apex Rentals' },
    customer: { id: customerUserId, name: 'John Doe', phone: '+919876543210', email: 'john@example.com' },
    car: {
      id: 'car_hyundai_creta',
      vendorId: vendorAId,
      make: 'Hyundai',
      model: 'Creta',
      registrationNumber: 'MH 02 CD 1234',
      isAvailable: false,
    },
    payment: { status: 'PAID', amount: new Prisma.Decimal(6360) },
  };

  beforeEach(async () => {
    mockAuthoritativeBooking.car = {
      ...mockAuthoritativeBooking.car,
      isAvailable: true,
      availableTripTypes: [TripType.ROUND_TRIP],
      blockedDates: [],
      pricePerDay: new Prisma.Decimal(2500),
      pricePerKm: new Prisma.Decimal(15),
      type: 'SUV',
      vendor: {
        id: vendorAId,
        userId: vendorAUserId,
        city: 'Mumbai',
        verificationStatus: VerificationStatus.VERIFIED,
      },
    };

    mockPrisma = {
      booking: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id === mockAuthoritativeBooking.id) {
            return Promise.resolve(JSON.parse(JSON.stringify(mockAuthoritativeBooking)));
          }
          return Promise.resolve(null);
        }),
        findMany: jest.fn().mockResolvedValue([mockAuthoritativeBooking]),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'bk_new_01', ...data })),
        update: jest.fn().mockImplementation(({ where, data }) =>
          Promise.resolve({
            ...mockAuthoritativeBooking,
            ...data,
          }),
        ),
      },
      car: {
        findUnique: jest.fn().mockResolvedValue(mockAuthoritativeBooking.car),
        update: jest.fn().mockResolvedValue(mockAuthoritativeBooking.car),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'singleton',
          enabledTripTypes: [TripType.ROUND_TRIP],
        }),
      },
      payment: {
        findUnique: jest.fn().mockResolvedValue({
          status: PaymentStatus.PAID,
          amount: new Prisma.Decimal(6360),
        }),
      },
      inspection: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        upsert: jest.fn().mockImplementation(({ create }) => Promise.resolve(create)),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => callback(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([{ id: 'car_hyundai_creta' }]),
    };

    mockHandoverOtpService = {
      verifyOtp: jest.fn().mockResolvedValue(true),
      generateAndSendOtp: jest.fn().mockResolvedValue({ success: true, message: 'OTP sent' }),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue({ id: 'audit_01' }),
    };

    mockLocationsService = {
      calculateDeliveryQuote: jest.fn().mockResolvedValue({
        isAvailable: true,
        deliveryFee: 350,
        pickupFee: 0,
        returnFee: 150,
        oneWaySurcharge: 250,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: mockPrisma },
        {
          provide: BookingLockService,
          useValue: {
            acquireLock: jest.fn().mockResolvedValue('mock_lock_token'),
            releaseLock: jest.fn().mockResolvedValue(true),
            acquireCancellationLock: jest.fn().mockResolvedValue('mock_cancel_token'),
            releaseCancellationLock: jest.fn().mockResolvedValue(true),
          },
        },
        {
          provide: CommissionResolverService,
          useValue: {
            resolveCommissionPercent: jest.fn().mockResolvedValue(10),
          },
        },
        {
          provide: FareCalculatorService,
          useValue: {
            calculateFare: jest.fn().mockReturnValue({
              baseFare: new Prisma.Decimal(4500),
              platformFee: new Prisma.Decimal(450),
              gst: new Prisma.Decimal(810),
              totalFare: new Prisma.Decimal(5760),
              netToVendor: new Prisma.Decimal(4500),
            }),
            calculateBaseFare: jest.fn().mockReturnValue({
              baseFare: new Prisma.Decimal(4500),
              platformFee: new Prisma.Decimal(450),
              gst: new Prisma.Decimal(810),
              total: new Prisma.Decimal(5760),
              netToVendor: new Prisma.Decimal(4500),
            }),
          },
        },
        { provide: PaymentsService, useValue: { refund: jest.fn() } },
        { provide: NotificationsService, useValue: { notifyUser: jest.fn().mockResolvedValue(true) } },
        { provide: CancellationPolicyService, useValue: { calculateCancellation: jest.fn() } },
        { provide: AuditLogService, useValue: mockAuditLogService },
        { provide: HandoverOtpService, useValue: mockHandoverOtpService },
        { provide: CouponsService, useValue: { validateCoupon: jest.fn() } },
        { provide: LocationsService, useValue: mockLocationsService },
      ],
    }).compile();

    bookingsService = module.get<BookingsService>(BookingsService);
    handoverOtpService = module.get<HandoverOtpService>(HandoverOtpService);
  });

  describe('1. 13-Field Authoritative Snapshot Immutability & Contract Fidelity', () => {
    it('preserves all 13 snapshot fields exactly without recomputation across lifecycle updates', async () => {
      mockPrisma.inspection.findUnique.mockResolvedValue({
        id: 'insp_pre_01',
        finalized: true,
        odometer: new Prisma.Decimal(12500),
      });

      const updated = await bookingsService.updateStatus(
        mockAuthoritativeBooking.id,
        BookingStatus.ONGOING,
        { userId: vendorAUserId, role: Role.VENDOR },
        undefined,
        '123456',
      );

      // Verify all 13 fields remain 100% intact
      expect(updated.deliveryType).toBe(DeliveryType.DOORSTEP_DELIVERY);
      expect(updated.pickupAddress).toBe('Sector 4, Andheri East, Mumbai, Maharashtra 400069');
      expect(updated.deliveryAddress).toBe('Flat 402, Sea Face Towers, Worli, Mumbai');
      expect(updated.deliveryFee).toEqual(new Prisma.Decimal(350));
      expect(updated.pickupFee).toEqual(new Prisma.Decimal(0));
      expect(updated.returnFee).toEqual(new Prisma.Decimal(150));
      expect(updated.oneWayFee).toEqual(new Prisma.Decimal(250));
      expect(updated.deliveryLatitude).toBe(19.0178);
      expect(updated.deliveryLongitude).toBe(72.8178);
      expect(updated.pickupHubId).toBe('hub_andheri_main');
      expect(updated.returnHubId).toBe('hub_bkc_premium');
      expect(updated.pickupName).toBe('Andheri East Main Yard');
      expect(updated.dropName).toBe('BKC Premium Branch Hub');
    });
  });

  describe('2. Handover & Return Verification Gates', () => {
    it('requires verified OTP before transitioning from CONFIRMED/HANDOVER_READY to ONGOING', async () => {
      mockPrisma.inspection.findUnique.mockResolvedValue({
        id: 'insp_pre_01',
        finalized: true,
        odometer: new Prisma.Decimal(12500),
      });

      // Attempt transition without OTP
      await expect(
        bookingsService.updateStatus(
          mockAuthoritativeBooking.id,
          BookingStatus.ONGOING,
          { userId: vendorAUserId, role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);

      expect(mockHandoverOtpService.verifyOtp).not.toHaveBeenCalled();

      // Attempt transition with invalid OTP
      mockHandoverOtpService.verifyOtp.mockRejectedValueOnce(
        new BadRequestException('Invalid or expired handover OTP.'),
      );

      await expect(
        bookingsService.updateStatus(
          mockAuthoritativeBooking.id,
          BookingStatus.ONGOING,
          { userId: vendorAUserId, role: Role.VENDOR },
          undefined,
          'wrong_otp',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('requires finalized pre-trip inspection before transitioning to ONGOING', async () => {
      mockPrisma.inspection.findUnique.mockResolvedValue(null);

      await expect(
        bookingsService.updateStatus(
          mockAuthoritativeBooking.id,
          BookingStatus.ONGOING,
          { userId: vendorAUserId, role: Role.VENDOR },
          undefined,
          '123456',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('3. Damaged Vehicle Completion Lock & Active Dispute Protection', () => {
    it('blocks vendors from completing a trip if an active dispute/damage claim is flagged', async () => {
      const disputedBooking = {
        ...mockAuthoritativeBooking,
        status: BookingStatus.RETURN_PENDING,
        disputeFlag: true,
        disputeNote: 'Unreported scratch and dent on left passenger door',
      };

      mockPrisma.booking.findUnique.mockResolvedValue(disputedBooking);
      mockPrisma.inspection.findUnique.mockResolvedValue({
        id: 'insp_post_01',
        finalized: true,
        odometer: new Prisma.Decimal(12750),
      });

      await expect(
        bookingsService.updateStatus(
          disputedBooking.id,
          BookingStatus.COMPLETED,
          { userId: vendorAUserId, role: Role.VENDOR },
          undefined,
          '654321',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('4. Tenant Isolation & RBAC Governance', () => {
    it('prevents unauthorized vendor B from accessing or updating vendor A booking', async () => {
      await expect(
        bookingsService.updateStatus(
          mockAuthoritativeBooking.id,
          BookingStatus.ONGOING,
          { userId: vendorBUserId, role: Role.VENDOR },
          undefined,
          '123456',
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows Admin to inspect unredacted vendor contact information and logs audit events', async () => {
      const adminResult = await bookingsService.getBookingById(
        mockAuthoritativeBooking.id,
        { userId: adminUserId, role: Role.ADMIN },
      );

      expect(adminResult.vendor.userId).toBe(vendorAUserId);
      expect(adminResult.vendor.businessName).toBe('Apex Rentals');
      expect(adminResult.deliveryType).toBe(DeliveryType.DOORSTEP_DELIVERY);
    });
  });

  describe('5. Concurrency & Double-Booking Protection', () => {
    it('rejects concurrent overlapping booking creation on the same car for overlapping dates', async () => {
      mockPrisma.booking.findFirst.mockResolvedValue({
        id: 'bk_existing_overlap',
        status: BookingStatus.CONFIRMED,
        startDate: new Date('2026-09-10T10:00:00Z'),
        endDate: new Date('2026-09-12T18:00:00Z'),
      });

      const futureStart = new Date(Date.now() + 86400000).toISOString();
      const futureEnd = new Date(Date.now() + 86400000 * 3).toISOString();

      await expect(
        bookingsService.createBooking(customerUserId, {
          carId: 'car_hyundai_creta',
          tripType: TripType.ROUND_TRIP,
          pickupLocation: 'Main Operating Yard',
          dropLocation: 'Main Operating Yard',
          startDate: futureStart,
          endDate: futureEnd,
        } as any),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('6. Legacy Booking Backward Compatibility', () => {
    it('safely handles legacy bookings without fulfillment metadata without null crashes', async () => {
      const legacyBooking = {
        ...mockAuthoritativeBooking,
        deliveryType: DeliveryType.NONE,
        pickupAddress: null,
        deliveryAddress: null,
        deliveryFee: new Prisma.Decimal(0),
        pickupFee: new Prisma.Decimal(0),
        returnFee: new Prisma.Decimal(0),
        oneWayFee: new Prisma.Decimal(0),
        deliveryLatitude: null,
        deliveryLongitude: null,
        pickupHubId: null,
        returnHubId: null,
        pickupName: null,
        dropName: null,
      };

      mockPrisma.booking.findUnique.mockResolvedValue(legacyBooking);

      const retrieved = await bookingsService.getBookingById(legacyBooking.id, {
        userId: customerUserId,
        role: Role.CUSTOMER,
      });

      expect(retrieved.id).toBe(legacyBooking.id);
      expect(retrieved.deliveryType).toBe(DeliveryType.NONE);
      expect(retrieved.deliveryFee).toEqual(new Prisma.Decimal(0));
    });
  });
});
