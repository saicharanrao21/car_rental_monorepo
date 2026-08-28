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
import { HandoverOtpService } from './handover-otp.service';
import { CouponsService } from '../coupons/coupons.service';
import { BookingStatus, PaymentStatus, Role } from '@prisma/client';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase 23A: Owner Confirmation Gate & Host Details Privacy Security Suite', () => {
  let bookingsService: BookingsService;
  let prisma: any;
  let paymentsService: any;
  let notificationsService: any;
  let cancellationPolicyService: any;

  const mockVendor = {
    id: 'vendor_123',
    userId: 'vendor_user_123',
    businessName: 'Royal Auto Rentals Pvt Ltd',
    ownerName: 'Vikram Malhotra',
    city: 'Mumbai',
    locality: 'Bandra West',
    latitude: 19.059559,
    longitude: 72.829529,
    gstNumber: '27AABCR1234F1Z5',
    panNumber: 'AABCR1234F',
    bankDetails: 'HDFC Bank - AC: 9876543210',
    phone: '+919876543210',
    user: {
      id: 'vendor_user_123',
      name: 'Vikram Malhotra',
      email: 'vikram@royalautorentals.com',
      phone: '+919876543210',
    },
  };

  const mockCar = {
    id: 'car_123',
    vendorId: 'vendor_123',
    make: 'Hyundai',
    model: 'Creta',
    year: 2023,
    registrationNumber: 'MH02CL9988',
    city: 'Mumbai',
  };

  const createMockBooking = (status: BookingStatus, paymentStatus: PaymentStatus = PaymentStatus.CREATED) => ({
    id: 'bk_gate_001',
    customerId: 'cust_001',
    vendorId: 'vendor_123',
    carId: 'car_123',
    status,
    startDate: new Date(Date.now() + 86400000),
    endDate: new Date(Date.now() + 2 * 86400000),
    totalFare: new Decimal(5000),
    car: mockCar,
    vendor: mockVendor,
    payment: {
      id: 'pay_001',
      bookingId: 'bk_gate_001',
      amount: new Decimal(5000),
      status: paymentStatus,
    },
  });

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn().mockImplementation(({ data }) => ({
          ...createMockBooking(BookingStatus.CONFIRMED, PaymentStatus.PAID),
          ...data,
        })),
        count: jest.fn().mockResolvedValue(1),
      },
      payment: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      securityDeposit: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };

    paymentsService = {
      refund: jest.fn().mockResolvedValue({
        refundId: 'rfnd_mock_123',
        refundAmount: new Decimal(5000),
        refundStatus: 'PROCESSED',
      }),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue({}),
    };

    cancellationPolicyService = {
      calculateCancellation: jest.fn().mockReturnValue({
        tier: 'VENDOR_CANCELLED',
        tierDescription: 'Cancelled or rejected by fleet owner (100% refund)',
        cancellationFee: new Decimal(0),
        refundAmount: new Decimal(5000),
        refundAmountInPaise: 500000,
        isEligibleForRefund: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: BookingLockService,
          useValue: {
            acquireCancellationLock: jest.fn().mockResolvedValue('lock_token_123'),
            releaseCancellationLock: jest.fn().mockResolvedValue(true),
          },
        },
        { provide: CommissionResolverService, useValue: {} },
        { provide: FareCalculatorService, useValue: {} },
        { provide: PaymentsService, useValue: paymentsService },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: CancellationPolicyService, useValue: cancellationPolicyService },
        { provide: AuditLogService, useValue: { log: jest.fn().mockResolvedValue({}) } },
        { provide: HandoverOtpService, useValue: { verifyOtp: jest.fn() } },
        { provide: CouponsService, useValue: { validateCoupon: jest.fn() } },
      ],
    }).compile();

    bookingsService = module.get<BookingsService>(BookingsService);
  });

  describe('1. Host Details Privacy Gate on Unconfirmed Bookings', () => {
    it('should strictly REDACT host details when booking is PENDING even if payment is PAID', async () => {
      // Setup: Booking is PENDING, Payment is PAID (waiting for owner confirmation)
      const pendingPaidBooking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(pendingPaidBooking);

      const result = await bookingsService.getBookingById('bk_gate_001', {
        userId: 'cust_001',
        role: Role.CUSTOMER,
      });

      // Assert: Sensitive personal host details are hidden/masked
      expect(result.vendor.businessName).toBe('Partner in Bandra West'); // Masked to generic locality
      expect(result.vendor.ownerName).toBeUndefined(); // Personal owner name stripped
      expect(result.vendor.phone).toBeUndefined(); // Raw phone stripped
      expect(result.vendor.gstNumber).toBeUndefined();
      expect(result.vendor.panNumber).toBeUndefined();
      expect(result.vendor.bankDetails).toBeUndefined();

      // Coordinates rounded to 2 decimals (~1km fuzzing)
      expect(result.vendor.latitude).toBe(19.06);
      expect(result.vendor.longitude).toBe(72.83);
    });

    it('should REVEAL real business name and exact coordinates ONLY when booking is CONFIRMED', async () => {
      // Setup: Booking is CONFIRMED, Payment is PAID
      const confirmedBooking = createMockBooking(BookingStatus.CONFIRMED, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(confirmedBooking);

      const result = await bookingsService.getBookingById('bk_gate_001', {
        userId: 'cust_001',
        role: Role.CUSTOMER,
      });

      // Assert: Real business name revealed for pickup coordination
      expect(result.vendor.businessName).toBe('Royal Auto Rentals Pvt Ltd');
      expect(result.vendor.latitude).toBe(19.059559);
      expect(result.vendor.longitude).toBe(72.829529);

      // Raw financial data remains stripped for customer
      expect(result.vendor.gstNumber).toBeUndefined();
      expect(result.vendor.panNumber).toBeUndefined();
      expect(result.vendor.bankDetails).toBeUndefined();
    });

    it('should keep host details redacted for customer list queries (GET /bookings/me)', async () => {
      const pendingPaidBooking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findMany.mockResolvedValue([pendingPaidBooking]);

      const result = await bookingsService.getBookingsForCustomer('cust_001');

      expect(result.data[0].vendor.businessName).toBe('Partner in Bandra West');
      expect(result.data[0].vendor.ownerName).toBeUndefined();
    });
  });

  describe('2. Vendor Authorization & State Transition Security', () => {
    it('should reject a non-assigned vendor attempting to accept/reject another vendor booking', async () => {
      const booking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(booking);

      await expect(
        bookingsService.updateStatus(
          'bk_gate_001',
          BookingStatus.CONFIRMED,
          {
            userId: 'intruder_vendor_user',
            role: Role.VENDOR,
          },
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should allow assigned vendor to accept a PAID pending booking', async () => {
      const booking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(booking);
      prisma.payment.findUnique.mockResolvedValue({
        bookingId: 'bk_gate_001',
        status: PaymentStatus.PAID,
      });

      const updated = await bookingsService.updateStatus(
        'bk_gate_001',
        BookingStatus.CONFIRMED,
        {
          userId: 'vendor_user_123',
          role: Role.VENDOR,
        },
      );

      expect(updated.status).toBe(BookingStatus.CONFIRMED);
      expect(prisma.booking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'bk_gate_001' },
          data: expect.objectContaining({ status: BookingStatus.CONFIRMED }),
        }),
      );
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'cust_001',
        'Booking Confirmed',
        expect.stringContaining('accepted'),
      );
    });

    it('should reject vendor confirming an unpaid booking', async () => {
      const booking = createMockBooking(BookingStatus.PENDING, PaymentStatus.CREATED);
      prisma.booking.findUnique.mockResolvedValue(booking);
      prisma.payment.findUnique.mockResolvedValue({
        bookingId: 'bk_gate_001',
        status: PaymentStatus.CREATED,
      });

      await expect(
        bookingsService.updateStatus(
          'bk_gate_001',
          BookingStatus.CONFIRMED,
          {
            userId: 'vendor_user_123',
            role: Role.VENDOR,
          },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should process 100% full refund when vendor rejects a booking with mandatory reason', async () => {
      const booking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(booking);
      prisma.payment.findUnique.mockResolvedValue({
        bookingId: 'bk_gate_001',
        status: PaymentStatus.PAID,
        amount: new Decimal(5000),
      });

      const updated = await bookingsService.updateStatus(
        'bk_gate_001',
        BookingStatus.CANCELLED,
        {
          userId: 'vendor_user_123',
          role: Role.VENDOR,
        },
        'Vehicle undergoing scheduled maintenance',
      );

      expect(updated.status).toBe(BookingStatus.CANCELLED);
      expect(paymentsService.refund).toHaveBeenCalledWith(
        'bk_gate_001',
        500000, // 5000 INR in paise
        'Vehicle undergoing scheduled maintenance',
        'VENDOR_CANCELLED',
      );
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'cust_001',
        'Booking Cancelled',
        expect.stringContaining('rejected/cancelled'),
      );
    });

    it('should reject vendor attempting to reject without providing a reason', async () => {
      const booking = createMockBooking(BookingStatus.PENDING, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(booking);

      await expect(
        bookingsService.updateStatus(
          'bk_gate_001',
          BookingStatus.CANCELLED,
          {
            userId: 'vendor_user_123',
            role: Role.VENDOR,
          },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject invalid transition from CANCELLED to CONFIRMED', async () => {
      const booking = createMockBooking(BookingStatus.CANCELLED, PaymentStatus.PAID);
      prisma.booking.findUnique.mockResolvedValue(booking);

      await expect(
        bookingsService.updateStatus(
          'bk_gate_001',
          BookingStatus.CONFIRMED,
          {
            userId: 'vendor_user_123',
            role: Role.VENDOR,
          },
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
