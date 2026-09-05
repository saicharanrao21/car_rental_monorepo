import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PricingService, QUOTE_VALIDITY_MINUTES } from './pricing.service';
import { PrismaService } from '../prisma/prisma.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CouponsService } from '../coupons/coupons.service';
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { LocationsService } from '../locations/locations.service';
import { VehicleAvailabilityService } from '../cars/vehicle-availability.service';
import { BookingsService } from '../bookings/bookings.service';
import { PaymentsService } from '../payments/payments.service';
import {
  CarCategory,
  Prisma,
  QuoteLineItemType,
  QuoteStatus,
  Role,
  TripType,
} from '@prisma/client';

describe('Phase 35 — Dynamic Pricing, Quote & Price Integrity Engine', () => {
  let pricingService: PricingService;
  let mockPrisma: any;
  let mockCommissionResolver: any;
  let mockFareCalculator: any;
  let mockCouponsService: any;
  let mockDepositRulesService: any;
  let mockLocationsService: any;
  let mockAvailabilityService: any;

  const mockCar = {
    id: 'car-sedan-1',
    vendorId: 'vendor-1',
    make: 'Honda',
    model: 'City',
    registrationNumber: 'KA-01-AB-1234',
    type: CarCategory.SEDAN,
    pricePerDay: new Prisma.Decimal(2500),
    pricePerHour: new Prisma.Decimal(150),
    pricePerKm: new Prisma.Decimal(12),
    weeklyDiscountPercent: 10,
    monthlyDiscountPercent: 20,
    isAvailable: true,
    availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL, TripType.OUTSTATION],
    vendor: {
      id: 'vendor-1',
      userId: 'vendor-user-1',
      city: 'Bangalore',
      verificationStatus: 'VERIFIED',
    },
    mileagePackages: [
      {
        id: 'pkg-1',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        name: 'Standard 250km/day',
        includedKmPerDay: 250,
        basePricePerDay: new Prisma.Decimal(3000),
        extraKmRate: new Prisma.Decimal(15),
        isActive: true,
      },
    ],
  };

  beforeEach(async () => {
    mockPrisma = {
      car: {
        findUnique: jest.fn().mockResolvedValue(mockCar),
      },
      bookingQuote: {
        create: jest.fn().mockImplementation((args) => ({
          id: 'quote-generated-123',
          ...args.data,
          lineItems: args.data.lineItems?.create || [],
          car: mockCar,
          createdAt: new Date(),
        })),
        findUnique: jest.fn(),
        update: jest.fn().mockImplementation((args) => ({
          id: args.where.id,
          ...args.data,
        })),
      },
      protectionPackage: {
        findUnique: jest.fn(),
      },
      vendor: {
        findUnique: jest.fn().mockResolvedValue({ id: 'vendor-1', userId: 'vendor-user-1' }),
      },
      booking: {
        findUnique: jest.fn(),
        create: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        delete: jest.fn(),
        create: jest.fn(),
      },
      $transaction: jest.fn((cb) => cb(mockPrisma)),
    };

    mockCommissionResolver = {
      resolveCommissionPercent: jest.fn().mockResolvedValue(new Prisma.Decimal(10.0)),
    };

    mockFareCalculator = new FareCalculatorService();

    mockCouponsService = {
      validateCoupon: jest.fn(),
    };

    mockDepositRulesService = {
      getDepositAmount: jest.fn().mockResolvedValue(4000),
    };

    mockLocationsService = {
      calculateDeliveryQuote: jest.fn(),
    };

    mockAvailabilityService = {
      checkAvailability: jest.fn().mockResolvedValue({ available: true, conflicts: [] }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PricingService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: CommissionResolverService, useValue: mockCommissionResolver },
        { provide: FareCalculatorService, useValue: mockFareCalculator },
        { provide: CouponsService, useValue: mockCouponsService },
        { provide: DepositRulesService, useValue: mockDepositRulesService },
        { provide: LocationsService, useValue: mockLocationsService },
        { provide: VehicleAvailabilityService, useValue: mockAvailabilityService },
      ],
    }).compile();

    pricingService = module.get<PricingService>(PricingService);
  });

  describe('1. Canonical Quote Generation & Duration Calculation', () => {
    it('1. should calculate deterministic 1-day daily rate, platform fee, GST, and security deposit', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000); // 24 hours = 1 day

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Daily rate: ₹2500 * 1 = ₹2500
      expect(quote.subtotal).toBe(2500);
      expect(quote.durationDays).toBe(1);
      expect(quote.discountTotal).toBe(0);

      // Platform fee (10% of ₹2500) = ₹250
      expect(quote.feesTotal).toBe(250);

      // GST (18% of ₹250) = ₹45
      expect(quote.taxTotal).toBe(45);

      // Dynamic deposit for Sedan = ₹4000
      expect(quote.depositTotal).toBe(4000);

      // Trip fare = 2500 + 250 + 45 = ₹2795
      expect(quote.tripFare).toBe(2795);

      // Total payable = 2795 + 4000 = ₹6795
      expect(quote.totalPayable).toBe(6795);
      expect(quote.currency).toBe('INR');
      expect(quote.status).toBe('ACTIVE');

      // Assert structured line items
      expect(quote.lineItems.length).toBeGreaterThanOrEqual(4);
      expect(quote.lineItems[0].type).toBe(QuoteLineItemType.BASE_RENTAL);
      expect(quote.lineItems[0].amount).toBe(2500);

      const depositItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.SECURITY_DEPOSIT);
      expect(depositItem).toBeDefined();
      expect(depositItem?.isRefundable).toBe(true);
      expect(depositItem?.amount).toBe(4000);
    });

    it('2. should calculate multi-day rental for 3 days without discount', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 3 * 86400000); // 3 days

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Subtotal = 2500 * 3 = ₹7500
      expect(quote.subtotal).toBe(7500);
      expect(quote.durationDays).toBe(3);
      expect(quote.discountTotal).toBe(0);

      // Platform fee = 10% of 7500 = ₹750
      expect(quote.feesTotal).toBe(750);
      // GST = 18% of 750 = ₹135
      expect(quote.taxTotal).toBe(135);
      // Trip fare = 7500 + 750 + 135 = ₹8385
      expect(quote.tripFare).toBe(8385);
    });

    it('3. should apply 10% weekly discount for rentals >= 7 days', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 7 * 86400000); // 7 days

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Initial base = 2500 * 7 = ₹17500
      expect(quote.subtotal).toBe(17500);
      // 10% weekly discount = ₹1750
      expect(quote.discountTotal).toBe(1750);

      // Base after discount = 17500 - 1750 = ₹15750
      // Platform fee = 10% of 15750 = ₹1575
      expect(quote.feesTotal).toBe(1575);
      // GST = 18% of 1575 = ₹283.50
      expect(quote.taxTotal).toBe(283.5);

      const discountItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.DURATION_DISCOUNT);
      expect(discountItem).toBeDefined();
      expect(discountItem?.amount).toBe(-1750);
    });

    it('4. should apply 20% monthly discount for rentals >= 30 days', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 30 * 86400000); // 30 days

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      // Initial base = 2500 * 30 = ₹75000
      expect(quote.subtotal).toBe(75000);
      // 20% discount = ₹15000
      expect(quote.discountTotal).toBe(15000);

      // Base after discount = 75000 - 15000 = ₹60000
      // Platform fee = 10% of 60000 = ₹6000
      expect(quote.feesTotal).toBe(6000);
      // GST = 18% of 6000 = ₹1080
      expect(quote.taxTotal).toBe(1080);
    });

    it('5. should calculate hourly rental for LOCAL trip type', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 5 * 3600000); // 5 hours

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.LOCAL,
      });

      // 5 hours @ ₹150/hr = ₹750
      expect(quote.subtotal).toBe(750);
      expect(quote.durationHours).toBe(5);
      expect(quote.lineItems[0].type).toBe(QuoteLineItemType.HOURLY_RENTAL);
    });

    it('6. should calculate package tier rate when mileagePackageId is specified', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 2 * 86400000); // 2 days

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
        mileagePackageId: 'pkg-1',
      });

      // Package rate: ₹3000/day * 2 days = ₹6000
      expect(quote.subtotal).toBe(6000);
      expect(quote.lineItems[0].type).toBe(QuoteLineItemType.PACKAGE_TIER);
      expect(quote.lineItems[0].name).toContain('Standard 250km/day');
    });
  });

  describe('2. Location, Protection & Coupon Integrations', () => {
    it('7. should include doorstep delivery fee and one-way surcharge in quote', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      mockLocationsService.calculateDeliveryQuote.mockResolvedValue({
        isAvailable: true,
        deliveryFee: 300,
        pickupFee: 100,
        returnFee: 0,
        oneWaySurcharge: 500,
        distanceKm: 15,
      });

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
        deliveryAddress: '123 MG Road, Bangalore',
        pickupHubId: 'hub-1',
        returnHubId: 'hub-2',
      });

      const delItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.DELIVERY_FEE);
      expect(delItem?.amount).toBe(300);

      const oneWayItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.ONE_WAY_SURCHARGE);
      expect(oneWayItem?.amount).toBe(500);

      // FeesTotal should include platform fee (250) + delivery (300) + pickup (100) + oneWay (500) = 1150
      expect(quote.feesTotal).toBe(1150);
    });

    it('8. should apply coupon discount and adjust customer payable total', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 86400000);

      mockCouponsService.validateCoupon.mockResolvedValue({
        code: 'DRIVE500',
        discountAmount: 500,
        couponId: 'cpn-1',
      });

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
        couponCode: 'DRIVE500',
      });

      expect(quote.discountTotal).toBe(500);
      const couponItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.COUPON_DISCOUNT);
      expect(couponItem?.amount).toBe(-500);

      // Trip fare = (2500 - 500) + 250 + 45 = ₹2295
      expect(quote.tripFare).toBe(2295);
    });

    it('9. should calculate protection package fee and include deductible metadata', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() + 2 * 86400000); // 2 days

      mockPrisma.protectionPackage.findUnique.mockResolvedValue({
        id: 'prot-prem',
        name: 'Zero Liability Premium',
        dailyRate: new Prisma.Decimal(400),
        deductibleAmount: new Prisma.Decimal(0),
        isActive: true,
        city: 'Bangalore',
      });

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        tripType: TripType.SELF_DRIVE,
        protectionPackageId: 'prot-prem',
      });

      const protItem = quote.lineItems.find((li) => li.type === QuoteLineItemType.PROTECTION_FEE);
      expect(protItem).toBeDefined();
      expect(protItem?.amount).toBe(800); // 400 * 2 days
    });
  });

  describe('3. Validation, Expiry & Idempotency', () => {
    it('10. should reject invalid date range where startDate >= endDate', async () => {
      const start = new Date(Date.now() + 86400000);
      const end = new Date(start.getTime() - 3600000); // End before start

      await expect(
        pricingService.generateQuote({
          carId: 'car-sedan-1',
          startDate: start.toISOString(),
          endDate: end.toISOString(),
          tripType: TripType.SELF_DRIVE,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('11. should reject past start date', async () => {
      const start = new Date(Date.now() - 3600000 * 24); // 1 day in past
      const end = new Date(Date.now() + 3600000 * 24);

      await expect(
        pricingService.generateQuote({
          carId: 'car-sedan-1',
          startDate: start.toISOString(),
          endDate: end.toISOString(),
          tripType: TripType.SELF_DRIVE,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('12. should return existing quote idempotently if idempotencyKey matches and quote is active', async () => {
      const activeQuote = {
        id: 'quote-existing-999',
        tenantId: 'vendor-1',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 2 * 86400000),
        durationDays: 1,
        durationHours: 24,
        subtotal: new Prisma.Decimal(2500),
        discountTotal: new Prisma.Decimal(0),
        feesTotal: new Prisma.Decimal(250),
        taxTotal: new Prisma.Decimal(45),
        depositTotal: new Prisma.Decimal(4000),
        totalPayable: new Prisma.Decimal(6795),
        netToVendor: new Prisma.Decimal(2500),
        currency: 'INR',
        pricingVersion: 'v1.0',
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 mins left
        createdAt: new Date(),
        lineItems: [],
        car: mockCar,
      };

      mockPrisma.bookingQuote.findUnique.mockResolvedValue(activeQuote);

      const quote = await pricingService.generateQuote({
        carId: 'car-sedan-1',
        startDate: activeQuote.startDate.toISOString(),
        endDate: activeQuote.endDate.toISOString(),
        tripType: TripType.SELF_DRIVE,
        idempotencyKey: 'idem-key-abc-123',
      });

      expect(quote.quoteId).toBe('quote-existing-999');
      expect(mockPrisma.bookingQuote.create).not.toHaveBeenCalled();
    });

    it('13. should mark quote as EXPIRED when inspected past TTL', async () => {
      const expiredQuote = {
        id: 'quote-old-expired',
        tenantId: 'vendor-1',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 2 * 86400000),
        durationDays: 1,
        durationHours: 24,
        subtotal: new Prisma.Decimal(2500),
        discountTotal: new Prisma.Decimal(0),
        feesTotal: new Prisma.Decimal(250),
        taxTotal: new Prisma.Decimal(45),
        depositTotal: new Prisma.Decimal(4000),
        totalPayable: new Prisma.Decimal(6795),
        netToVendor: new Prisma.Decimal(2500),
        currency: 'INR',
        pricingVersion: 'v1.0',
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() - 5000), // 5s in past
        createdAt: new Date(Date.now() - 16 * 60 * 1000),
        lineItems: [],
        car: mockCar,
      };

      mockPrisma.bookingQuote.findUnique.mockResolvedValue(expiredQuote);
      mockPrisma.bookingQuote.update.mockResolvedValue({
        ...expiredQuote,
        status: QuoteStatus.EXPIRED,
      });

      const res = await pricingService.getQuoteById('quote-old-expired');
      expect(res.status).toBe(QuoteStatus.EXPIRED);
    });

    it('14. should refresh an expired quote with current vehicle rates', async () => {
      const expiredQuote = {
        id: 'quote-to-refresh',
        tenantId: 'vendor-1',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 2 * 86400000),
        status: QuoteStatus.EXPIRED,
        metadata: {},
        lineItems: [],
      };

      mockPrisma.bookingQuote.findUnique.mockResolvedValue(expiredQuote);

      const refreshed = await pricingService.refreshQuote('quote-to-refresh');
      expect(refreshed.status).toBe(QuoteStatus.ACTIVE);
      expect(refreshed.quoteId).toBeDefined();
    });
  });

  describe('4. Quote Verification, Acceptance & Immutability', () => {
    it('15. should verify and atomically transition quote to ACCEPTED inside transaction', async () => {
      const activeQuote = {
        id: 'quote-valid-for-booking',
        tenantId: 'vendor-1',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date('2026-09-10T10:00:00.000Z'),
        endDate: new Date('2026-09-12T10:00:00.000Z'),
        durationDays: 2,
        durationHours: 48,
        subtotal: new Prisma.Decimal(5000),
        discountTotal: new Prisma.Decimal(0),
        feesTotal: new Prisma.Decimal(500),
        taxTotal: new Prisma.Decimal(90),
        depositTotal: new Prisma.Decimal(4000),
        totalPayable: new Prisma.Decimal(9590),
        netToVendor: new Prisma.Decimal(5000),
        currency: 'INR',
        pricingVersion: 'v1.0',
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        lineItems: [
          {
            type: QuoteLineItemType.BASE_RENTAL,
            name: 'Daily Rental Rate',
            rate: new Prisma.Decimal(2500),
            quantity: new Prisma.Decimal(2),
            amount: new Prisma.Decimal(5000),
            isRefundable: false,
          },
        ],
        car: mockCar,
      };

      const mockTx = {
        bookingQuote: {
          findUnique: jest.fn().mockResolvedValue(activeQuote),
          update: jest.fn().mockImplementation((args) => ({
            ...activeQuote,
            ...args.data,
            lineItems: activeQuote.lineItems,
          })),
        },
      };

      const { quote, priceSnapshot } = await pricingService.verifyAndAcceptQuote(
        mockTx,
        'quote-valid-for-booking',
        'cust-123',
        {
          carId: 'car-sedan-1',
          startDate: '2026-09-10T10:00:00.000Z',
          endDate: '2026-09-12T10:00:00.000Z',
          tripType: TripType.SELF_DRIVE,
        },
      );

      expect(quote.status).toBe(QuoteStatus.ACCEPTED);
      expect(quote.customerId).toBe('cust-123');
      expect(priceSnapshot.totalPayable).toBe(9590);
      expect(priceSnapshot.tripFare).toBe(5590);
      expect(priceSnapshot.depositTotal).toBe(4000);
      expect(priceSnapshot.lineItems.length).toBe(1);
    });

    it('16. should reject quote acceptance if quote is EXPIRED', async () => {
      const expiredQuote = {
        id: 'quote-expired-acceptance',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date('2026-09-10T10:00:00.000Z'),
        endDate: new Date('2026-09-12T10:00:00.000Z'),
        status: QuoteStatus.EXPIRED,
        expiresAt: new Date(Date.now() - 60000),
        car: mockCar,
      };

      const mockTx = {
        bookingQuote: {
          findUnique: jest.fn().mockResolvedValue(expiredQuote),
        },
      };

      await expect(
        pricingService.verifyAndAcceptQuote(
          mockTx,
          'quote-expired-acceptance',
          'cust-123',
          {
            carId: 'car-sedan-1',
            startDate: '2026-09-10T10:00:00.000Z',
            endDate: '2026-09-12T10:00:00.000Z',
            tripType: TripType.SELF_DRIVE,
          },
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('17. should reject quote acceptance if carId does not match quote', async () => {
      const quote = {
        id: 'quote-car-mismatch',
        carId: 'car-sedan-1',
        tripType: TripType.SELF_DRIVE,
        startDate: new Date('2026-09-10T10:00:00.000Z'),
        endDate: new Date('2026-09-12T10:00:00.000Z'),
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 600000),
        car: mockCar,
      };

      const mockTx = {
        bookingQuote: {
          findUnique: jest.fn().mockResolvedValue(quote),
        },
      };

      await expect(
        pricingService.verifyAndAcceptQuote(
          mockTx,
          'quote-car-mismatch',
          'cust-123',
          {
            carId: 'different-car-id',
            startDate: '2026-09-10T10:00:00.000Z',
            endDate: '2026-09-12T10:00:00.000Z',
            tripType: TripType.SELF_DRIVE,
          },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('18. should enforce tenant isolation when vendor inspects quote', async () => {
      const quote = {
        id: 'quote-tenant-a',
        tenantId: 'vendor-tenant-a',
        customerId: 'cust-1',
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 600000),
        lineItems: [],
        car: mockCar,
      };

      mockPrisma.bookingQuote.findUnique.mockResolvedValue(quote);
      mockPrisma.vendor.findUnique.mockResolvedValue({ id: 'vendor-tenant-b' });

      await expect(
        pricingService.getQuoteById('quote-tenant-a', {
          userId: 'vendor-user-b',
          role: Role.VENDOR,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('5. Payment Integrity & Gateway Amount Assertion', () => {
    it('19. should detect payment amount mismatch if booking was modified after quote acceptance', async () => {
      const mockPaymentsService = new PaymentsService(
        mockPrisma,
        { get: jest.fn().mockReturnValue('true') } as any, // useMock
        { notifyUser: jest.fn() } as any,
        {} as any,
      );

      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking-tampered-fare',
        customerId: 'cust-alice',
        status: 'PENDING',
        totalFare: new Prisma.Decimal(99999), // Tampered total
        quoteId: 'quote-123',
        quote: {
          totalPayable: new Prisma.Decimal(6795), // Authoritative quote total
        },
        securityDeposit: {
          amount: new Prisma.Decimal(4000),
        },
      });

      await expect(
        mockPaymentsService.createOrder('booking-tampered-fare', 'cust-alice', false),
      ).rejects.toThrow(ConflictException);
    });

    it('20. should successfully create payment order when booking amount matches authoritative quote', async () => {
      const mockPaymentsService = new PaymentsService(
        mockPrisma,
        { get: jest.fn().mockReturnValue('true') } as any,
        { notifyUser: jest.fn() } as any,
        {} as any,
      );

      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'booking-verified-fare',
        customerId: 'cust-alice',
        status: 'PENDING',
        totalFare: new Prisma.Decimal(2795), // Trip fare
        quoteId: 'quote-123',
        quote: {
          totalPayable: new Prisma.Decimal(6795), // 2795 + 4000 = 6795
        },
        securityDeposit: {
          amount: new Prisma.Decimal(4000),
        },
      });

      mockPrisma.payment.findUnique.mockResolvedValue(null);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'pay-1',
        amount: new Prisma.Decimal(6795),
        status: 'CREATED',
      });

      const order = await mockPaymentsService.createOrder(
        'booking-verified-fare',
        'cust-alice',
        false,
      );

      expect(order).toBeDefined();
      expect(order.amount).toBe(679500); // 6795 * 100 paise
      expect(order.currency).toBe('INR');
    });
  });
});
