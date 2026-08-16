import { Test, TestingModule } from '@nestjs/testing';
import { TripExtensionsService } from './trip-extensions.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { InvoicesService } from '../invoices/invoices.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  BookingStatus,
  ExtensionStatus,
  Role,
  TripType,
  Prisma,
} from '@prisma/client';
import { BadRequestException, ConflictException } from '@nestjs/common';

describe('TripExtensionsService (Phase 4 Feature 10)', () => {
  let service: TripExtensionsService;
  let prisma: any;
  let commissionResolver: any;
  let fareCalculator: any;
  let invoicesService: any;
  let notificationsService: any;
  let auditLogService: any;

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      tripExtension: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      $transaction: jest.fn((cb) => cb(prisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    commissionResolver = {
      resolveCommissionPercent: jest.fn().mockResolvedValue(10),
    };

    fareCalculator = {
      calculateFare: jest.fn().mockReturnValue({
        baseFare: new Prisma.Decimal(3000),
        platformFee: new Prisma.Decimal(300),
        gst: new Prisma.Decimal(54),
        total: new Prisma.Decimal(3354),
        netToVendor: new Prisma.Decimal(3000),
      }),
    };

    invoicesService = {
      generateInvoiceForBooking: jest.fn().mockResolvedValue({ id: 'inv_ext_1' }),
    };

    notificationsService = {
      createNotification: jest.fn().mockResolvedValue(true),
      notifyUser: jest.fn().mockResolvedValue({ id: 'notif_1' }),
    };

    auditLogService = {
      logAction: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripExtensionsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key) => (key === 'RAZORPAY_USE_MOCK' ? 'true' : null)),
          },
        },
        { provide: CommissionResolverService, useValue: commissionResolver },
        { provide: FareCalculatorService, useValue: fareCalculator },
        { provide: InvoicesService, useValue: invoicesService },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<TripExtensionsService>(TripExtensionsService);
  });

  describe('getQuote', () => {
    it('calculates extension quote for ONGOING booking', async () => {
      const now = new Date();
      const currentEnd = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const requestedEnd = new Date(now.getTime() + 48 * 60 * 60 * 1000);

      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_ongoing_1',
        customerId: 'cust_1',
        status: BookingStatus.ONGOING,
        startDate: now,
        endDate: currentEnd,
        tripType: TripType.SELF_DRIVE,
        carId: 'car_1',
        car: {
          id: 'car_1',
          type: 'SUV',
          pricePerDay: new Prisma.Decimal(3000),
          pricePerHour: new Prisma.Decimal(200),
          blockedDates: [],
          vendor: { city: 'Mumbai' },
        },
      });

      prisma.booking.findFirst.mockResolvedValue(null); // No conflicting future bookings

      const quote = await service.getQuote(
        'book_ongoing_1',
        requestedEnd.toISOString(),
        { userId: 'cust_1', role: Role.CUSTOMER },
      );

      expect(quote.totalFare).toBe(3354);
      expect(quote.baseFare).toBe(3000);
      expect(quote.gstAmount).toBe(54);
    });

    it('rejects extension if booking is not ONGOING', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_completed_1',
        customerId: 'cust_1',
        status: BookingStatus.COMPLETED,
        endDate: new Date(),
        car: { vendor: { city: 'Mumbai' } },
      });

      await expect(
        service.getQuote('book_completed_1', new Date(Date.now() + 100000).toISOString(), {
          userId: 'cust_1',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects extension if car has conflicting future booking', async () => {
      const now = new Date();
      const currentEnd = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const requestedEnd = new Date(now.getTime() + 48 * 60 * 60 * 1000);

      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_ongoing_2',
        customerId: 'cust_1',
        status: BookingStatus.ONGOING,
        startDate: now,
        endDate: currentEnd,
        tripType: TripType.SELF_DRIVE,
        carId: 'car_1',
        car: {
          id: 'car_1',
          type: 'SUV',
          pricePerDay: new Prisma.Decimal(3000),
          blockedDates: [],
          vendor: { city: 'Mumbai' },
        },
      });

      // Conflicting booking already confirmed
      prisma.booking.findFirst.mockResolvedValue({ id: 'future_book_1' });

      await expect(
        service.getQuote('book_ongoing_2', requestedEnd.toISOString(), {
          userId: 'cust_1',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('verifyExtensionPayment', () => {
    it('confirms extension and atomically extends booking end date', async () => {
      const requestedEnd = new Date('2026-08-25T10:00:00Z');
      const currentEnd = new Date('2026-08-24T10:00:00Z');

      prisma.tripExtension.findUnique.mockResolvedValue({
        id: 'ext_1',
        bookingId: 'book_1',
        currentEndDate: currentEnd,
        requestedEndDate: requestedEnd,
        status: ExtensionStatus.PENDING_PAYMENT,
        booking: {
          id: 'book_1',
          customerId: 'cust_1',
          carId: 'car_1',
          car: { make: 'Hyundai', model: 'Creta' },
          vendor: { userId: 'vend_user_1' },
          customer: { id: 'cust_1' },
        },
      });

      prisma.booking.findFirst.mockResolvedValue(null);
      prisma.tripExtension.update.mockResolvedValue({ id: 'ext_1', status: ExtensionStatus.CONFIRMED });
      prisma.booking.update.mockResolvedValue({ id: 'book_1', endDate: requestedEnd });

      const res = await service.verifyExtensionPayment(
        'book_1',
        'ext_1',
        {
          razorpayOrderId: 'order_1',
          razorpayPaymentId: 'pay_1',
          razorpaySignature: 'sig_mock',
        },
        'cust_1',
      );

      expect(res.success).toBe(true);
      expect(prisma.booking.update).toHaveBeenCalledWith({
        where: { id: 'book_1' },
        data: { endDate: requestedEnd },
      });
      expect(prisma.tripExtension.update).toHaveBeenCalledWith({
        where: { id: 'ext_1' },
        data: {
          status: ExtensionStatus.CONFIRMED,
          razorpayPaymentId: 'pay_1',
        },
      });
    });
  });
});
