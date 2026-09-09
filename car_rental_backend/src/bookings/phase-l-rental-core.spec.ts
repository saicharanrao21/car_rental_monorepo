import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RentalPricingResolutionService } from '../pricing/rental-pricing-resolution.service';
import { FleetAvailabilityService } from '../fleet/fleet-availability.service';
import { FleetLifecycleService } from '../fleet/fleet-lifecycle.service';
import { VehicleAllocationService } from '../fleet/vehicle-allocation.service';
import { RentalOperationsService } from './rental-operations.service';
import { RentalAutomationService } from './rental-automation.service';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { HandoverOtpService } from './handover-otp.service';
import { InspectionsService } from './inspections.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  BookingStatus,
  CarCategory,
  FuelType,
  HandoverOtpType,
  InspectionType,
  PricingRuleScope,
  Role,
  SecurityDepositStatus,
  TripType,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { FleetOperationalState } from '../fleet/fleet-domain.types';

describe('Phase L: Enterprise Booking & Rental Core Engine', () => {
  let pricingResolutionService: RentalPricingResolutionService;
  let availabilityService: FleetAvailabilityService;
  let allocationService: VehicleAllocationService;
  let operationsService: RentalOperationsService;
  let automationService: RentalAutomationService;
  let prisma: any;
  let lifecycleService: any;
  let bookingLifecycle: any;
  let bookingLockService: any;

  beforeEach(async () => {
    prisma = {
      rentalPricingRule: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
      },
      car: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
      },
      vehicleAllocationRecord: {
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      customerKyc: {
        findUnique: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn(),
      },
      handoverOtp: {
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      inspection: {
        create: jest.fn(),
      },
      securityDeposit: {
        update: jest.fn(),
      },
      bookingQuote: {
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
      },
      bookingOutboxEvent: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'outbox-1' }),
      },
      $transaction: jest.fn().mockImplementation((cb) => cb(prisma)),
    };

    lifecycleService = {
      getVehicleState: jest.fn().mockResolvedValue(FleetOperationalState.AVAILABLE),
      getVehicleStateReason: jest.fn().mockReturnValue(null),
      transitionState: jest.fn().mockResolvedValue({
        carId: 'car-1',
        fromState: FleetOperationalState.AVAILABLE,
        toState: FleetOperationalState.ON_RENT,
      }),
    };

    bookingLifecycle = {
      startRental: jest.fn().mockResolvedValue({ success: true }),
      completeBooking: jest.fn().mockResolvedValue({ success: true }),
      expireBooking: jest.fn().mockResolvedValue({ success: true }),
    };

    bookingLockService = {
      acquireCancellationLock: jest.fn().mockResolvedValue('lock-token-123'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RentalPricingResolutionService,
        FleetAvailabilityService,
        VehicleAllocationService,
        RentalOperationsService,
        RentalAutomationService,
        { provide: PrismaService, useValue: prisma },
        { provide: FleetLifecycleService, useValue: lifecycleService },
        { provide: BookingLifecycleService, useValue: bookingLifecycle },
        { provide: BookingLockService, useValue: bookingLockService },
        { provide: HandoverOtpService, useValue: {} },
        { provide: InspectionsService, useValue: {} },
      ],
    }).compile();

    pricingResolutionService = module.get<RentalPricingResolutionService>(RentalPricingResolutionService);
    availabilityService = module.get<FleetAvailabilityService>(FleetAvailabilityService);
    allocationService = module.get<VehicleAllocationService>(VehicleAllocationService);
    operationsService = module.get<RentalOperationsService>(RentalOperationsService);
    automationService = module.get<RentalAutomationService>(RentalAutomationService);
  });

  // =========================================================================
  // 1. ENTERPRISE PRICING RESOLUTION TESTS
  // =========================================================================
  describe('Enterprise Pricing Engine (Hierarchical Resolution & Structured Breakdown)', () => {
    it('calculates standard daily pricing breakdown with GST and deposit', async () => {
      const start = new Date('2026-10-01T10:00:00Z');
      const end = new Date('2026-10-04T10:00:00Z'); // 3 days

      const res = await pricingResolutionService.resolvePricing({
        vendorId: 'vendor-1',
        vehicleClass: CarCategory.SUV,
        startDate: start,
        endDate: end,
        tripType: TripType.SELF_DRIVE,
      });

      expect(res.version).toContain('v2.0-enterprise');
      expect(res.duration.totalDays).toBe(3);
      expect(res.rates.dailyRate).toBe(3499); // default SUV rate
      expect(res.subtotal).toBe(3499 * 3);
      expect(res.depositTotal).toBe(3000);
      expect(res.lineItems.some((li) => li.code === 'BASE_FARE_DAILY')).toBe(true);
      expect(res.lineItems.some((li) => li.code === 'GST_TAX_18')).toBe(true);
      expect(res.lineItems.some((li) => li.code === 'REFUNDABLE_SECURITY_DEPOSIT')).toBe(true);
    });

    it('hierarchically overrides platform pricing with branch-level rule', async () => {
      prisma.rentalPricingRule.findMany.mockResolvedValue([
        {
          id: 'rule-branch-1',
          scope: PricingRuleScope.BRANCH,
          name: 'Airport Branch Premium Rate',
          dailyRate: new Decimal(4200),
          weekendMultiplier: new Decimal(1.2),
          priority: 50,
          isActive: true,
        },
      ]);

      const start = new Date('2026-10-02T10:00:00Z'); // Friday
      const end = new Date('2026-10-05T10:00:00Z'); // Monday (includes weekend)

      const res = await pricingResolutionService.resolvePricing({
        vendorId: 'vendor-1',
        branchId: 'hub-airport-1',
        vehicleClass: CarCategory.SEDAN,
        startDate: start,
        endDate: end,
        tripType: TripType.SELF_DRIVE,
      });

      expect(res.resolvedScope).toBe(PricingRuleScope.BRANCH);
      expect(res.rates.dailyRate).toBe(4200);
      expect(res.rates.weekendMultiplier).toBe(1.2);
      expect(res.lineItems.some((li) => li.code === 'WEEKEND_SURCHARGE')).toBe(true);
    });

    it('applies duration discounts for extended monthly and weekly rentals', async () => {
      const start = new Date('2026-10-01T10:00:00Z');
      const end = new Date('2026-10-11T10:00:00Z'); // 10 days (> 7 days)

      prisma.rentalPricingRule.findMany.mockResolvedValue([
        {
          id: 'rule-weekly',
          scope: PricingRuleScope.PLATFORM,
          name: 'Platform 15% Weekly Discount',
          weeklyDiscountPct: 15,
          priority: 10,
          isActive: true,
        },
      ]);

      const res = await pricingResolutionService.resolvePricing({
        vendorId: 'vendor-1',
        vehicleClass: CarCategory.HATCHBACK,
        startDate: start,
        endDate: end,
        tripType: TripType.SELF_DRIVE,
      });

      expect(res.lineItems.some((li) => li.code === 'WEEKLY_DURATION_DISCOUNT')).toBe(true);
      expect(res.discountTotal).toBeGreaterThan(0);
    });

    it('adds inter-branch one-way relocation fee when return branch differs', async () => {
      const start = new Date('2026-10-01T10:00:00Z');
      const end = new Date('2026-10-02T10:00:00Z');

      const res = await pricingResolutionService.resolvePricing({
        vendorId: 'vendor-1',
        branchId: 'hub-city-center',
        returnBranchId: 'hub-airport',
        vehicleClass: CarCategory.SEDAN,
        startDate: start,
        endDate: end,
        tripType: TripType.SELF_DRIVE,
      });

      expect(res.lineItems.some((li) => li.code === 'ONE_WAY_RELOCATION_FEE')).toBe(true);
    });
  });

  // =========================================================================
  // 2. FLEET AVAILABILITY ENGINE TESTS
  // =========================================================================
  describe('Enterprise Availability Engine (Buffer Turnaround & Double-Booking Guard)', () => {
    it('aggregates class availability across branch inventory with turnaround buffer', async () => {
      const start = new Date('2026-10-01T10:00:00Z');
      const end = new Date('2026-10-03T10:00:00Z');

      prisma.car.findMany.mockResolvedValue([
        {
          id: 'car-suv-1',
          type: CarCategory.SUV,
          make: 'Toyota',
          model: 'Fortuner',
          year: 2024,
          registrationNumber: 'KA-01-AB-1234',
          pricePerDay: new Decimal(3500),
          pricePerHour: new Decimal(200),
          pickupHubId: 'hub-1',
          seating: 7,
          fuelType: FuelType.DIESEL,
          bookings: [],
          blocks: [],
          holds: [],
        },
        {
          id: 'car-suv-2',
          type: CarCategory.SUV,
          make: 'Mahindra',
          model: 'XUV700',
          year: 2023,
          registrationNumber: 'KA-01-CD-5678',
          pricePerDay: new Decimal(3200),
          pricePerHour: new Decimal(180),
          pickupHubId: 'hub-1',
          seating: 7,
          fuelType: FuelType.DIESEL,
          bookings: [
            {
              id: 'conflict-b1',
              startDate: new Date('2026-10-02T10:00:00Z'),
              endDate: new Date('2026-10-04T10:00:00Z'),
            },
          ],
          blocks: [],
          holds: [],
        },
      ]);

      const results = await availabilityService.searchClassAvailability({
        vendorId: 'vendor-1',
        branchId: 'hub-1',
        vehicleClass: CarCategory.SUV,
        startDate: start,
        endDate: end,
        turnaroundBufferMinutes: 60,
      });

      expect(results.length).toBe(1);
      const suvSummary = results[0];
      expect(suvSummary.totalFleet).toBe(2);
      expect(suvSummary.availableCount).toBe(1);
      expect(suvSummary.blockedCount).toBe(1);
      expect(suvSummary.availableVehicles[0].id).toBe('car-suv-1');
      expect(suvSummary.blockingReasons[0].type).toBe('BOOKING_CONFLICT');
    });

    it('throws ConflictException on double-booking collision within turnaround buffer', async () => {
      const start = new Date('2026-10-01T10:00:00Z');
      const end = new Date('2026-10-02T10:00:00Z');

      prisma.car.findUnique.mockResolvedValue({
        id: 'car-1',
        pickupHubId: 'hub-1',
        blocks: [],
        holds: [],
      });

      prisma.booking.findMany.mockResolvedValue([
        {
          id: 'existing-b1',
          startDate: new Date('2026-10-02T10:30:00Z'), // Collides with 60-min buffer!
          endDate: new Date('2026-10-03T10:30:00Z'),
        },
      ]);

      await expect(
        availabilityService.assertVehicleAvailableForBooking('car-1', start, end, 60),
      ).rejects.toThrow(ConflictException);
    });
  });

  // =========================================================================
  // 3. VEHICLE ALLOCATION ENGINE TESTS
  // =========================================================================
  describe('Vehicle Allocation Engine (Strategies & Audit History)', () => {
    it('successfully allocates specific vehicle via EXACT_VEHICLE strategy', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'booking-1',
        status: BookingStatus.CONFIRMED,
        vendorId: 'vendor-1',
        carId: 'car-default',
        startDate: new Date('2026-10-01T10:00:00Z'),
        endDate: new Date('2026-10-03T10:00:00Z'),
        car: { id: 'car-default', type: CarCategory.SEDAN },
        allocationRecords: [],
      });

      prisma.car.findUnique.mockResolvedValue({
        id: 'car-exact-1',
        vendorId: 'vendor-1',
        registrationNumber: 'KA-05-MH-9999',
        make: 'Honda',
        model: 'City',
        type: CarCategory.SEDAN,
        blocks: [],
        holds: [],
      });

      prisma.booking.findMany.mockResolvedValue([]); // no conflict

      prisma.vehicleAllocationRecord.create.mockResolvedValue({
        id: 'alloc-rec-1',
        bookingId: 'booking-1',
        carId: 'car-exact-1',
        allocatedAt: new Date(),
      });

      const res = await allocationService.allocateVehicle({
        bookingId: 'booking-1',
        targetCarId: 'car-exact-1',
        strategy: 'EXACT_VEHICLE',
        allocatedBy: 'admin-1',
        allocatedByRole: Role.ADMIN,
      });

      expect(res.success).toBe(true);
      expect(res.allocatedCarId).toBe('car-exact-1');
      expect(res.vehicleRegistration).toBe('KA-05-MH-9999');
      expect(prisma.booking.update).toHaveBeenCalledWith({
        where: { id: 'booking-1' },
        data: expect.objectContaining({
          carId: 'car-exact-1',
          allocationStatus: 'ALLOCATED',
          allocationStrategy: 'EXACT_VEHICLE',
        }),
      });
    });

    it('safely reassigns vehicle with full audit history deactivation', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'booking-reassign',
        status: BookingStatus.CONFIRMED,
        vendorId: 'vendor-1',
        carId: 'car-old',
        startDate: new Date('2026-10-01T10:00:00Z'),
        endDate: new Date('2026-10-03T10:00:00Z'),
        car: { id: 'car-old', type: CarCategory.SUV },
        allocationRecords: [
          {
            id: 'alloc-old',
            carId: 'car-old',
            isActive: true,
            allocatedAt: new Date('2026-09-20T10:00:00Z'),
          },
        ],
      });

      prisma.car.findUnique.mockResolvedValue({
        id: 'car-new',
        vendorId: 'vendor-1',
        registrationNumber: 'KA-05-NEW-1111',
        make: 'Hyundai',
        model: 'Creta',
        type: CarCategory.SUV,
        blocks: [],
        holds: [],
      });

      prisma.booking.findMany.mockResolvedValue([]);

      prisma.vehicleAllocationRecord.create.mockResolvedValue({
        id: 'alloc-new',
        bookingId: 'booking-reassign',
        carId: 'car-new',
      });

      const res = await allocationService.allocateVehicle({
        bookingId: 'booking-reassign',
        targetCarId: 'car-new',
        strategy: 'MANUAL_OVERRIDE',
        reason: 'Original vehicle scheduled for emergency brake inspection',
        allocatedBy: 'dispatcher-1',
        allocatedByRole: Role.ADMIN,
      });

      expect(res.success).toBe(true);
      expect(res.previousCarId).toBe('car-old');
      expect(res.allocatedCarId).toBe('car-new');
      expect(prisma.vehicleAllocationRecord.update).toHaveBeenCalledWith({
        where: { id: 'alloc-old' },
        data: expect.objectContaining({ isActive: false }),
      });
    });

    it('rejects cross-vendor unauthorized allocation attempt', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'booking-vendor-lock',
        status: BookingStatus.CONFIRMED,
        vendorId: 'vendor-1',
        carId: 'car-1',
        car: { type: CarCategory.SEDAN },
        allocationRecords: [],
      });

      prisma.vendor.findUnique.mockResolvedValue({
        id: 'vendor-2', // Different vendor!
      });

      await expect(
        allocationService.allocateVehicle({
          bookingId: 'booking-vendor-lock',
          strategy: 'SAME_CLASS',
          allocatedBy: 'user-vendor-2',
          allocatedByRole: Role.VENDOR,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  // =========================================================================
  // 4. RENTAL OPERATIONS & DIGITAL HANDOVER TESTS
  // =========================================================================
  describe('Rental Operations (Digital Pickup, Return Settlement & Security Deposit)', () => {
    it('fails pickup if customer KYC is not VERIFIED', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b-kyc-fail',
        status: BookingStatus.CONFIRMED,
        customerId: 'cust-unverified',
        car: { registrationNumber: 'KA-01-1234' },
      });

      prisma.customerKyc.findUnique.mockResolvedValue({
        status: 'PENDING',
      });

      await expect(
        operationsService.executePickup({
          bookingId: 'b-kyc-fail',
          actorId: 'agent-1',
          actorRole: Role.VENDOR,
          odometerReading: 15400,
          fuelPercent: 100,
          handoverOtpCode: '123456',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('executes pickup successfully with verified OTP and PRE_TRIP inspection', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b-pickup-ok',
        status: BookingStatus.CONFIRMED,
        customerId: 'cust-ok',
        carId: 'car-pickup-1',
        customer: { name: 'Rahul Sharma' },
        car: { registrationNumber: 'KA-01-4444' },
      });

      prisma.customerKyc.findUnique.mockResolvedValue({ status: 'VERIFIED' });
      prisma.handoverOtp.findFirst.mockResolvedValue({ id: 'otp-rec-1' });
      prisma.inspection.create.mockResolvedValue({ id: 'insp-pre-1' });

      const res = await operationsService.executePickup({
        bookingId: 'b-pickup-ok',
        actorId: 'agent-1',
        actorRole: Role.VENDOR,
        odometerReading: 25000,
        fuelPercent: 95,
        handoverOtpCode: '998877',
      });

      expect(res.success).toBe(true);
      expect(res.status).toBe(BookingStatus.ONGOING);
      expect(res.inspectionId).toBe('insp-pre-1');
      expect(lifecycleService.transitionState).toHaveBeenCalledWith(
        'car-pickup-1',
        FleetOperationalState.ON_RENT,
        expect.any(Object),
        expect.any(Object),
      );
    });

    it('executes return settlement with extra km charge and partial deposit refund', async () => {
      const startDate = new Date('2026-10-01T10:00:00Z');
      const endDate = new Date('2026-10-03T10:00:00Z'); // 2 days -> 600 included km

      prisma.booking.findUnique.mockResolvedValue({
        id: 'b-return-settle',
        status: BookingStatus.ONGOING,
        startDate,
        endDate,
        carId: 'car-return-1',
        includedKmTotal: 600,
        extraKmRate: new Decimal(15),
        car: { pricePerHour: new Decimal(150), pricePerKm: new Decimal(15) },
        securityDeposit: {
          id: 'sec-dep-1',
          amount: new Decimal(5000),
          status: SecurityDepositStatus.HELD,
        },
        inspections: [
          {
            type: InspectionType.PRE_TRIP,
            odometer: new Decimal(20000),
            fuelPercent: 100,
          },
        ],
      });

      prisma.handoverOtp.findFirst.mockResolvedValue({ id: 'otp-return-1' });
      prisma.inspection.create.mockResolvedValue({ id: 'insp-post-1' });

      // Customer drove 750 km (150 extra km @ ₹15 = ₹2,250 deduction)
      const res = await operationsService.executeReturn({
        bookingId: 'b-return-settle',
        actorId: 'agent-1',
        actorRole: Role.VENDOR,
        odometerReading: 20750,
        fuelPercent: 100,
        handoverOtpCode: '654321',
      });

      expect(res.totalTripKm).toBe(750);
      expect(res.extraKm).toBe(150);
      expect(res.extraKmCharge).toBe(2250);
      expect(res.depositStatus).toBe('PARTIAL_REFUND');
      expect(res.depositRefundAmount).toBe(5000 - 2250);
      expect(prisma.securityDeposit.update).toHaveBeenCalledWith({
        where: { id: 'sec-dep-1' },
        data: expect.objectContaining({
          status: SecurityDepositStatus.PARTIALLY_REFUNDED,
          deductedAmount: new Decimal(2250),
          refundedAmount: new Decimal(2750),
        }),
      });
      expect(lifecycleService.transitionState).toHaveBeenCalledWith(
        'car-return-1',
        FleetOperationalState.CLEANING,
        expect.any(Object),
        expect.any(Object),
      );
    });
  });

  // =========================================================================
  // 5. AUTOMATION FOUNDATION TESTS
  // =========================================================================
  describe('Background Automation Engine', () => {
    it('expires stale quotes and unconfirmed pending reservations idempotently', async () => {
      prisma.bookingQuote.findMany.mockResolvedValue([
        { id: 'quote-stale-1' },
        { id: 'quote-stale-2' },
      ]);

      const quoteResult = await automationService.expireStaleQuotes();
      expect(quoteResult.processedCount).toBe(2);
      expect(quoteResult.successCount).toBe(2);

      prisma.booking.findMany.mockResolvedValue([
        { id: 'booking-unconfirmed-1' },
      ]);

      const resResult = await automationService.expireUnconfirmedReservations(30);
      expect(resResult.processedCount).toBe(1);
      expect(resResult.successCount).toBe(1);
      expect(bookingLifecycle.expireBooking).toHaveBeenCalled();
    });

    it('detects overdue rentals and dispatches operational alert events', async () => {
      prisma.booking.findMany.mockResolvedValue([
        {
          id: 'trip-overdue-1',
          customerId: 'cust-1',
          vendorId: 'vendor-1',
          endDate: new Date(Date.now() - 3 * 60 * 60 * 1000), // 3 hours late!
          car: { registrationNumber: 'KA-01-OVERDUE' },
        },
      ]);

      const result = await automationService.detectOverdueReturns(45);
      expect(result.processedCount).toBe(1);
      expect(result.successCount).toBe(1);
      expect(prisma.bookingOutboxEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            eventType: 'RENTAL_OVERDUE_ALERT',
            bookingId: 'trip-overdue-1',
          }),
        }),
      );
    });
  });
});
