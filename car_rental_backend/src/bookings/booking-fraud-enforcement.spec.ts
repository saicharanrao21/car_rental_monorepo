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
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { InvoicesService } from '../invoices/invoices.service';
import { ReferralsService } from '../referrals/referrals.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { FraudService, RiskAction, RiskLevel } from '../fraud/fraud.service';
import {
  TripType,
  VerificationStatus,
  Prisma,
} from '@prisma/client';
import { ForbiddenException } from '@nestjs/common';

describe('Feature 34 — Booking Checkout Fraud Enforcement Spec', () => {
  let bookingsService: BookingsService;
  let fraudService: FraudService;
  let prisma: PrismaService;

  const mockPrismaService = {
    platformSettings: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'singleton',
        enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION', 'LOCAL', 'AIRPORT_TRANSFER'],
      }),
    },
    car: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'car_100',
        vendorId: 'vendor_100',
        type: 'SUV',
        isAvailable: true,
        availableTripTypes: ['SELF_DRIVE'],
        blockedDates: [],
        pricePerDay: new Prisma.Decimal(2500),
        pricePerHour: new Prisma.Decimal(200),
        pricePerKm: new Prisma.Decimal(15),
        weeklyDiscountPercent: 0,
        monthlyDiscountPercent: 0,
        vendor: {
          id: 'vendor_100',
          city: 'Hyderabad',
          verificationStatus: VerificationStatus.VERIFIED,
        },
      }),
    },
    protectionPackage: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
    vendor: {
      findUnique: jest.fn().mockResolvedValue({ userId: 'vendor_user_100' }),
    },
    $transaction: jest.fn(),
  };

  const mockBookingLockService = {
    acquireLock: jest.fn().mockResolvedValue('lock_token_123'),
    releaseLock: jest.fn().mockResolvedValue(true),
  };

  const mockCommissionResolver = {
    resolveCommissionPercent: jest.fn().mockResolvedValue(15),
  };

  const mockFareCalculator = {
    calculateFare: jest.fn().mockReturnValue({
      baseFare: new Prisma.Decimal(5000),
      platformFee: new Prisma.Decimal(750),
      gst: new Prisma.Decimal(900),
      total: new Prisma.Decimal(5900),
      netToVendor: new Prisma.Decimal(4250),
    }),
  };

  const mockFraudService = {
    evaluateUserRisk: jest.fn(),
  };

  const mockCouponsService = {
    validateCoupon: jest.fn(),
  };

  const validDto = {
    carId: 'car_100',
    startDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    endDate: new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(),
    tripType: TripType.SELF_DRIVE,
    pickupLocation: 'Airport Hub',
    dropLocation: 'Airport Hub',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: BookingLockService, useValue: mockBookingLockService },
        { provide: CommissionResolverService, useValue: mockCommissionResolver },
        { provide: FareCalculatorService, useValue: mockFareCalculator },
        { provide: PaymentsService, useValue: {} },
        { provide: NotificationsService, useValue: { notifyUser: jest.fn().mockResolvedValue(true) } },
        { provide: CancellationPolicyService, useValue: {} },
        { provide: AuditLogService, useValue: {} },
        { provide: HandoverOtpService, useValue: {} },
        { provide: CouponsService, useValue: mockCouponsService },
        { provide: DepositRulesService, useValue: { getDepositAmount: jest.fn().mockResolvedValue(5000) } },
        { provide: InvoicesService, useValue: {} },
        { provide: ReferralsService, useValue: { getRefereeEligibility: jest.fn().mockResolvedValue({ eligible: false }) } },
        { provide: LoyaltyService, useValue: {} },
        { provide: FraudService, useValue: mockFraudService },
      ],
    }).compile();

    bookingsService = module.get<BookingsService>(BookingsService);
    fraudService = module.get<FraudService>(FraudService);
    prisma = module.get<PrismaService>(PrismaService);

    jest.clearAllMocks();
  });

  const mockCreatedBooking = {
    id: 'bkg_clean_created',
    vendorId: 'vendor_100',
    status: 'PENDING',
    totalFare: new Prisma.Decimal(5900),
    car: {
      make: 'Hyundai',
      model: 'Creta',
      registrationNumber: 'TS09EA1234',
    },
  };

  it('should allow checkout when customer risk action is ALLOW (LOW risk)', async () => {
    mockFraudService.evaluateUserRisk.mockResolvedValue({
      userId: 'usr_clean',
      score: 0,
      riskLevel: RiskLevel.LOW,
      action: RiskAction.ALLOW,
      signals: [],
    });

    mockPrismaService.$transaction.mockResolvedValue(mockCreatedBooking);

    const result = await bookingsService.createBooking('usr_clean', validDto);

    expect(mockFraudService.evaluateUserRisk).toHaveBeenCalledWith('usr_clean', expect.any(Object));
    expect(mockPrismaService.$transaction).toHaveBeenCalled();
    expect(result.id).toBe('bkg_clean_created');
  });

  it('should allow checkout when customer risk action is MONITOR (MEDIUM risk)', async () => {
    mockFraudService.evaluateUserRisk.mockResolvedValue({
      userId: 'usr_med',
      score: 35,
      riskLevel: RiskLevel.MEDIUM,
      action: RiskAction.MONITOR,
      signals: [{ code: 'HIGH_CANCELLATION_VELOCITY', scoreDelta: 30 }],
    });

    mockPrismaService.$transaction.mockResolvedValue({
      ...mockCreatedBooking,
      id: 'bkg_med_created',
    });

    const result = await bookingsService.createBooking('usr_med', validDto);

    expect(mockFraudService.evaluateUserRisk).toHaveBeenCalled();
    expect(mockPrismaService.$transaction).toHaveBeenCalled();
    expect(result.id).toBe('bkg_med_created');
  });

  it('should allow checkout when customer risk action is REVIEW_REQUIRED (HIGH risk)', async () => {
    mockFraudService.evaluateUserRisk.mockResolvedValue({
      userId: 'usr_high',
      score: 65,
      riskLevel: RiskLevel.HIGH,
      action: RiskAction.REVIEW_REQUIRED,
      signals: [{ code: 'DUPLICATE_DRIVING_LICENCE', scoreDelta: 40 }],
    });

    mockPrismaService.$transaction.mockResolvedValue({
      ...mockCreatedBooking,
      id: 'bkg_high_created',
    });

    const result = await bookingsService.createBooking('usr_high', validDto);

    expect(mockFraudService.evaluateUserRisk).toHaveBeenCalled();
    expect(mockPrismaService.$transaction).toHaveBeenCalled();
    expect(result.id).toBe('bkg_high_created');
  });

  it('should SYNCHRONOUSLY BLOCK checkout when customer risk action is BLOCK (CRITICAL risk)', async () => {
    mockFraudService.evaluateUserRisk.mockResolvedValue({
      userId: 'usr_blocked',
      score: 85,
      riskLevel: RiskLevel.CRITICAL,
      action: RiskAction.BLOCK,
      signals: [
        { code: 'DUPLICATE_DRIVING_LICENCE', scoreDelta: 40 },
        { code: 'REPEATED_PAYMENT_FAILURES', scoreDelta: 35 },
        { code: 'FRESH_ACCOUNT_SPIKE', scoreDelta: 15 },
      ],
    });

    await expect(
      bookingsService.createBooking('usr_blocked', validDto),
    ).rejects.toThrow(ForbiddenException);

    // Verify zero database transaction entry on BLOCK
    expect(mockPrismaService.$transaction).not.toHaveBeenCalled();
  });

  it('should SYNCHRONOUSLY BLOCK checkout when customer is flagged with BANNED_USER', async () => {
    mockFraudService.evaluateUserRisk.mockResolvedValue({
      userId: 'usr_banned',
      score: 100,
      riskLevel: RiskLevel.CRITICAL,
      action: RiskAction.BLOCK,
      signals: [{ code: 'BANNED_USER', scoreDelta: 100 }],
    });

    await expect(
      bookingsService.createBooking('usr_banned', validDto),
    ).rejects.toThrow(
      new ForbiddenException('Booking request could not be processed due to security verification policy.'),
    );

    expect(mockPrismaService.$transaction).not.toHaveBeenCalled();
  });
});
