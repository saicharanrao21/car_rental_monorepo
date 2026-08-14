import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import { BookingStatus, PaymentStatus, Role } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('Phase 4D: Payment-Gated Booking Confirmation Security', () => {
  let service: BookingsService;
  let prisma: any;
  let auditLogService: any;

  const mockBooking = {
    id: 'booking-123',
    customerId: 'cust-1',
    vendorId: 'vendor-1',
    status: BookingStatus.PENDING,
    startDate: new Date('2026-09-01'),
    endDate: new Date('2026-09-05'),
    totalFare: 5000,
    vendor: {
      id: 'vendor-1',
      userId: 'vendor-user-1',
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
        findUnique: jest.fn(),
      },
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue({ id: 'audit-1' }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: BookingLockService,
          useValue: {
            acquireCancellationLock: jest.fn(),
            releaseCancellationLock: jest.fn(),
          },
        },
        { provide: CommissionResolverService, useValue: {} },
        { provide: FareCalculatorService, useValue: {} },
        {
          provide: PaymentsService,
          useValue: {
            refund: jest.fn(),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            notifyUser: jest.fn().mockResolvedValue({}),
          },
        },
        { provide: CancellationPolicyService, useValue: {} },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
  });

  describe('Vendor Booking Confirmation Gating', () => {
    it('1. should reject vendor confirmation when no Payment record exists', async () => {
      prisma.payment.findUnique.mockResolvedValue(null);

      await expect(
        service.updateStatus('booking-123', BookingStatus.CONFIRMED, {
          userId: 'vendor-user-1',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('2. should reject vendor confirmation when Payment status is CREATED', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'booking-123',
        status: PaymentStatus.CREATED,
      });

      await expect(
        service.updateStatus('booking-123', BookingStatus.CONFIRMED, {
          userId: 'vendor-user-1',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('3. should reject vendor confirmation when Payment status is FAILED', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'booking-123',
        status: PaymentStatus.FAILED,
      });

      await expect(
        service.updateStatus('booking-123', BookingStatus.CONFIRMED, {
          userId: 'vendor-user-1',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('4. should reject vendor confirmation when Payment status is REFUNDED', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'booking-123',
        status: PaymentStatus.REFUNDED,
      });

      await expect(
        service.updateStatus('booking-123', BookingStatus.CONFIRMED, {
          userId: 'vendor-user-1',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('5. should allow vendor confirmation when Payment status is PAID', async () => {
      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay-1',
        bookingId: 'booking-123',
        status: PaymentStatus.PAID,
      });

      const result = await service.updateStatus(
        'booking-123',
        BookingStatus.CONFIRMED,
        {
          userId: 'vendor-user-1',
          role: Role.VENDOR,
        },
      );

      expect(result.status).toBe(BookingStatus.CONFIRMED);
      expect(prisma.booking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'booking-123' },
          data: expect.objectContaining({ status: BookingStatus.CONFIRMED }),
        }),
      );
    });
  });

  describe('Customer and Admin Booking Status Transitions', () => {
    it('6. should reject customer attempting to manually confirm booking', async () => {
      await expect(
        service.updateStatus('booking-123', BookingStatus.CONFIRMED, {
          userId: 'cust-1',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('7. should reject admin confirmation of unpaid booking without adequate justification', async () => {
      prisma.payment.findUnique.mockResolvedValue(null);

      // Empty or short justification (< 10 chars)
      await expect(
        service.updateStatus(
          'booking-123',
          BookingStatus.CONFIRMED,
          {
            userId: 'admin-1',
            role: Role.ADMIN,
          },
          'short',
        ),
      ).rejects.toThrow(BadRequestException);

      expect(auditLogService.log).not.toHaveBeenCalled();
      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('8. should allow admin confirmation of unpaid booking with explicit justification and audit log', async () => {
      prisma.payment.findUnique.mockResolvedValue(null);

      const justification = 'Corporate offline invoice settled via bank wire #UTR998877';

      const result = await service.updateStatus(
        'booking-123',
        BookingStatus.CONFIRMED,
        {
          userId: 'admin-1',
          role: Role.ADMIN,
        },
        justification,
      );

      expect(result.status).toBe(BookingStatus.CONFIRMED);
      expect(auditLogService.log).toHaveBeenCalledWith(
        'admin-1',
        'BOOKING_ADMIN_FORCE_CONFIRMED',
        'Booking',
        'booking-123',
        expect.objectContaining({
          justification,
          paymentStatus: 'NONE',
        }),
      );
    });
  });
});
