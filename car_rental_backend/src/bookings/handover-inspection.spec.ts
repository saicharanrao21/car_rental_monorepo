import { Test, TestingModule } from '@nestjs/testing';
import { InspectionsService } from './inspections.service';
import { HandoverOtpService } from './handover-otp.service';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { UploadsService } from '../uploads/uploads.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { PaymentsService } from '../payments/payments.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  BookingStatus,
  InspectionType,
  HandoverOtpType,
  PaymentStatus,
  Role,
  Prisma,
} from '@prisma/client';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('Phase 4E: Vehicle Handover & Inspection Integrity', () => {
  let inspectionsService: InspectionsService;
  let handoverOtpService: HandoverOtpService;
  let bookingsService: BookingsService;
  let prisma: any;
  let uploadsService: any;
  let notificationsService: any;
  let auditLogService: any;

  const mockBooking = {
    id: 'booking-e-1',
    customerId: 'cust-1',
    vendorId: 'vendor-1',
    status: BookingStatus.CONFIRMED,
    startDate: new Date('2026-09-01T10:00:00Z'),
    endDate: new Date('2026-09-05T10:00:00Z'),
    totalFare: new Prisma.Decimal(5000),
    vendor: {
      id: 'vendor-1',
      userId: 'vendor-user-1',
    },
    customer: {
      id: 'cust-1',
      phone: '9876543210',
    },
    car: {
      make: 'Hyundai',
      model: 'Creta',
      registrationNumber: 'KA-01-AB-1234',
    },
  };

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn().mockResolvedValue(mockBooking),
        update: jest.fn().mockImplementation(({ data }) => ({
          ...mockBooking,
          ...data,
        })),
      },
      payment: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'pay-1',
          bookingId: 'booking-e-1',
          status: PaymentStatus.PAID,
        }),
      },
      inspection: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        upsert: jest.fn(),
      },
      handoverOtp: {
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn().mockResolvedValue({ attemptCount: 1 }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        deleteMany: jest.fn(),
      },
    };

    uploadsService = {
      getPresignedDownloadUrl: jest
        .fn()
        .mockImplementation((key) => Promise.resolve(`https://signed.r2/${key}`)),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue({}),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue({ id: 'audit-1' }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InspectionsService,
        HandoverOtpService,
        BookingsService,
        { provide: PrismaService, useValue: prisma },
        { provide: UploadsService, useValue: uploadsService },
        { provide: NotificationsService, useValue: notificationsService },
        {
          provide: BookingLockService,
          useValue: {
            acquireLock: jest.fn(),
            releaseLock: jest.fn(),
            acquireCancellationLock: jest.fn(),
            releaseCancellationLock: jest.fn(),
          },
        },
        { provide: CommissionResolverService, useValue: {} },
        { provide: FareCalculatorService, useValue: {} },
        { provide: PaymentsService, useValue: { refund: jest.fn() } },
        { provide: CancellationPolicyService, useValue: {} },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    inspectionsService = module.get<InspectionsService>(InspectionsService);
    handoverOtpService = module.get<HandoverOtpService>(HandoverOtpService);
    bookingsService = module.get<BookingsService>(BookingsService);
  });

  describe('Vehicle Inspection Lifecycle & Validations', () => {
    it('1. should create pre-trip inspection with odometer, fuel %, damage photos', async () => {
      prisma.inspection.findUnique.mockResolvedValue(null);
      prisma.inspection.upsert.mockResolvedValue({
        id: 'insp-1',
        bookingId: 'booking-e-1',
        type: InspectionType.PRE_TRIP,
        odometer: new Prisma.Decimal(12500),
        fuelPercent: 90,
        conditionNotes: 'Clean, no scratches',
        damagePhotos: ['inspection-photo/vendor-1/front.jpg'],
        finalized: true,
      });

      const result = await inspectionsService.upsertInspection(
        'booking-e-1',
        {
          type: InspectionType.PRE_TRIP,
          odometer: 12500,
          fuelPercent: 90,
          conditionNotes: 'Clean, no scratches',
          damagePhotos: ['inspection-photo/vendor-1/front.jpg'],
          finalize: true,
        },
        { userId: 'vendor-user-1', role: Role.VENDOR },
      );

      expect(result.finalized).toBe(true);
      expect(prisma.inspection.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            bookingId_type: {
              bookingId: 'booking-e-1',
              type: InspectionType.PRE_TRIP,
            },
          },
        }),
      );
    });

    it('2. should reject negative odometer reading or unauthorized actor', async () => {
      await expect(
        inspectionsService.upsertInspection(
          'booking-e-1',
          {
            type: InspectionType.PRE_TRIP,
            odometer: -50,
            fuelPercent: 50,
          },
          { userId: 'unauthorized-user', role: Role.CUSTOMER },
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('3. should reject modification of an already finalized inspection (immutability)', async () => {
      prisma.inspection.findUnique.mockResolvedValue({
        id: 'insp-1',
        bookingId: 'booking-e-1',
        type: InspectionType.PRE_TRIP,
        finalized: true,
      });

      await expect(
        inspectionsService.upsertInspection(
          'booking-e-1',
          {
            type: InspectionType.PRE_TRIP,
            odometer: 13000,
            fuelPercent: 80,
          },
          { userId: 'vendor-user-1', role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('4. should reject post-trip inspection if return odometer < pre-trip odometer', async () => {
      // Booking is ONGOING
      prisma.booking.findUnique.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.ONGOING,
      });

      // Pre-trip had odometer 15000
      prisma.inspection.findUnique.mockResolvedValueOnce({
        id: 'insp-pre',
        bookingId: 'booking-e-1',
        type: InspectionType.PRE_TRIP,
        odometer: new Prisma.Decimal(15000),
        finalized: true,
      });

      // Attempt return with 14900 (lower)
      await expect(
        inspectionsService.upsertInspection(
          'booking-e-1',
          {
            type: InspectionType.POST_TRIP,
            odometer: 14900,
            fuelPercent: 50,
          },
          { userId: 'vendor-user-1', role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Handover OTP Lifecycle & Security', () => {
    it('5. should generate 6-digit OTP, store bcrypt hash with 15-min expiry and notify customer', async () => {
      const result = await handoverOtpService.generateAndSendOtp(
        'booking-e-1',
        HandoverOtpType.PICKUP,
        { userId: 'vendor-user-1', role: Role.VENDOR },
      );

      expect(result.success).toBe(true);
      expect(prisma.handoverOtp.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            bookingId: 'booking-e-1',
            otpType: HandoverOtpType.PICKUP,
            recipientId: 'cust-1',
            attemptCount: 0,
            verified: false,
          }),
        }),
      );
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'cust-1',
        expect.stringContaining('Vehicle Pickup OTP'),
        expect.any(String),
      );
    });

    it('6. should verify valid OTP, invalidate it, and reject incorrect OTP', async () => {
      const rawOtp = '456789';
      const otpHash = bcrypt.hashSync(rawOtp, 10);

      prisma.handoverOtp.findFirst.mockResolvedValue({
        id: 'hotp-1',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.PICKUP,
        otpHash,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        attemptCount: 0,
        verified: false,
      });

      // Verify correct OTP
      const isVerified = await handoverOtpService.verifyOtp(
        'booking-e-1',
        HandoverOtpType.PICKUP,
        '456789',
      );
      expect(isVerified).toBe(true);
      expect(prisma.handoverOtp.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'hotp-1', verified: false },
          data: expect.objectContaining({ verified: true }),
        }),
      );

      // Verify wrong OTP triggers atomic increment
      await expect(
        handoverOtpService.verifyOtp(
          'booking-e-1',
          HandoverOtpType.PICKUP,
          '111111',
        ),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.handoverOtp.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'hotp-1' },
          data: { attemptCount: { increment: 1 } },
        }),
      );
    });

    it('6b. should reject concurrent replay of the same valid OTP if already verified', async () => {
      const rawOtp = '456789';
      const otpHash = bcrypt.hashSync(rawOtp, 10);

      prisma.handoverOtp.findFirst.mockResolvedValue({
        id: 'hotp-1',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.PICKUP,
        otpHash,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        attemptCount: 0,
        verified: false,
      });

      // Simulate race condition where another concurrent worker already marked it verified (count: 0)
      prisma.handoverOtp.updateMany.mockResolvedValueOnce({ count: 0 });

      await expect(
        handoverOtpService.verifyOtp(
          'booking-e-1',
          HandoverOtpType.PICKUP,
          '456789',
        ),
      ).rejects.toThrow('Handover OTP has already been verified or invalidated.');
    });

    it('7. should lock OTP and reject verification after 5 failed attempts or expiration', async () => {
      // Locked OTP (5 attempts)
      prisma.handoverOtp.findFirst.mockResolvedValueOnce({
        id: 'hotp-locked',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.PICKUP,
        otpHash: 'hash',
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        attemptCount: 5,
        verified: false,
      });

      await expect(
        handoverOtpService.verifyOtp(
          'booking-e-1',
          HandoverOtpType.PICKUP,
          '123456',
        ),
      ).rejects.toThrow(BadRequestException);

      // Expired OTP
      prisma.handoverOtp.findFirst.mockResolvedValueOnce({
        id: 'hotp-expired',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.PICKUP,
        otpHash: 'hash',
        expiresAt: new Date(Date.now() - 1000),
        attemptCount: 0,
        verified: false,
      });

      await expect(
        handoverOtpService.verifyOtp(
          'booking-e-1',
          HandoverOtpType.PICKUP,
          '123456',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('State Machine Gating: ONGOING & COMPLETED', () => {
    it('8. should reject CONFIRMED -> ONGOING transition without finalized pre-trip inspection', async () => {
      prisma.inspection.findUnique.mockResolvedValue(null); // No pre-trip inspection

      await expect(
        bookingsService.updateStatus(
          'booking-e-1',
          BookingStatus.ONGOING,
          { userId: 'vendor-user-1', role: Role.VENDOR },
          undefined,
          '123456',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('9. should reject CONFIRMED -> ONGOING transition without valid handover OTP', async () => {
      prisma.inspection.findUnique.mockResolvedValue({
        id: 'insp-pre',
        type: InspectionType.PRE_TRIP,
        finalized: true,
      });

      // No OTP provided
      await expect(
        bookingsService.updateStatus(
          'booking-e-1',
          BookingStatus.ONGOING,
          { userId: 'vendor-user-1', role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('10. should allow CONFIRMED -> ONGOING with finalized pre-trip inspection and valid handover OTP', async () => {
      prisma.inspection.findUnique.mockResolvedValue({
        id: 'insp-pre',
        type: InspectionType.PRE_TRIP,
        finalized: true,
      });

      const rawOtp = '123456';
      prisma.handoverOtp.findFirst.mockResolvedValue({
        id: 'hotp-1',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.PICKUP,
        otpHash: bcrypt.hashSync(rawOtp, 10),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        attemptCount: 0,
        verified: false,
      });

      const result = await bookingsService.updateStatus(
        'booking-e-1',
        BookingStatus.ONGOING,
        { userId: 'vendor-user-1', role: Role.VENDOR },
        undefined,
        '123456',
      );

      expect(result.status).toBe(BookingStatus.ONGOING);
      expect(prisma.booking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'booking-e-1' },
          data: expect.objectContaining({ status: BookingStatus.ONGOING }),
        }),
      );
    });

    it('11. should reject ONGOING -> COMPLETED transition without finalized post-trip inspection', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.ONGOING,
      });
      prisma.inspection.findUnique.mockResolvedValue(null); // No post-trip inspection

      await expect(
        bookingsService.updateStatus(
          'booking-e-1',
          BookingStatus.COMPLETED,
          { userId: 'vendor-user-1', role: Role.VENDOR },
          undefined,
          '654321',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('12. should allow ONGOING -> COMPLETED with finalized post-trip inspection and valid return OTP', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.ONGOING,
      });

      prisma.inspection.findUnique.mockResolvedValue({
        id: 'insp-post',
        type: InspectionType.POST_TRIP,
        finalized: true,
      });

      const rawOtp = '654321';
      prisma.handoverOtp.findFirst.mockResolvedValue({
        id: 'hotp-ret-1',
        bookingId: 'booking-e-1',
        otpType: HandoverOtpType.RETURN,
        otpHash: bcrypt.hashSync(rawOtp, 10),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        attemptCount: 0,
        verified: false,
      });

      const result = await bookingsService.updateStatus(
        'booking-e-1',
        BookingStatus.COMPLETED,
        { userId: 'vendor-user-1', role: Role.VENDOR },
        undefined,
        '654321',
      );

      expect(result.status).toBe(BookingStatus.COMPLETED);
    });
  });
});
