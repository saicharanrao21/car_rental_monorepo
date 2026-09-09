import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { MarketplaceSearchService } from '../marketplace-search.service';
import { MarketplaceRankingService } from '../marketplace-ranking.service';
import { MarketplaceQuoteService } from '../marketplace-quote.service';
import { PromotionEngineService } from '../promotion-engine.service';
import { AncillaryProductsService } from '../ancillary-products.service';
import { CheckoutOrchestratorService } from '../checkout-orchestrator.service';
import { CancellationPreviewService } from '../cancellation-preview.service';
import { FleetAvailabilityService } from '../../fleet/fleet-availability.service';
import { RentalPricingResolutionService } from '../../pricing/rental-pricing-resolution.service';
import { PaymentRoutingService } from '../../integrations/runtime/payment-routing.service';
import { IntegrationRuntimeService } from '../../integrations/runtime/integration-runtime.service';
import { VehicleAllocationService } from '../../fleet/vehicle-allocation.service';
import { CancellationPolicyService } from '../../bookings/cancellation-policy.service';
import {
  CarCategory,
  TripType,
  FuelType,
  BookingStatus,
  QuoteStatus,
  DiscountType,
  CheckoutSessionStatus,
  Prisma,
} from '@prisma/client';
import { MarketplaceRankingStrategyType } from '../dto/marketplace-query.dto';
import { ConflictException, NotFoundException, BadRequestException } from '@nestjs/common';

describe('Phase M: Enterprise Rental Marketplace, Discovery & Booking Experience Engine', () => {
  let searchService: MarketplaceSearchService;
  let rankingService: MarketplaceRankingService;
  let quoteService: MarketplaceQuoteService;
  let promotionEngine: PromotionEngineService;
  let ancillaryService: AncillaryProductsService;
  let checkoutOrchestrator: CheckoutOrchestratorService;
  let cancellationPreview: CancellationPreviewService;

  let mockPrisma: any;
  let mockFleetAvailability: any;
  let mockPricingResolution: any;
  let mockPaymentRouting: any;
  let mockRuntimeService: any;
  let mockAllocationService: any;
  let mockCancellationPolicy: any;

  beforeEach(async () => {
    mockPrisma = {
      car: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
      booking: {
        count: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
      },
      bookingQuote: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      coupon: {
        findUnique: jest.fn(),
      },
      couponUsage: {
        count: jest.fn(),
      },
      ancillaryProduct: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        upsert: jest.fn(),
      },
      checkoutSession: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      cancellationPolicyDefinition: {
        findFirst: jest.fn(),
      },
      $transaction: jest.fn((cb) => cb(mockPrisma)),
    };

    mockFleetAvailability = {
      searchClassAvailability: jest.fn(),
      assertVehicleAvailableForBooking: jest.fn(),
    };

    mockPricingResolution = {
      resolvePricing: jest.fn().mockResolvedValue({
        version: 'v2.0-enterprise',
        appliedRuleIds: ['rule_1'],
        subtotal: 5000,
        discountTotal: 500,
        feesTotal: 250,
        taxTotal: 855,
        depositTotal: 5000,
        netToVendor: 4500,
        currency: 'INR',
        lineItems: [
          {
            code: 'BASE_DAILY',
            name: 'Daily Base Rate',
            category: 'BASE',
            rate: 2500,
            quantity: 2,
            amount: 5000,
            isRefundable: false,
            explanation: '2 days @ 2500/day',
          },
          {
            code: 'GST_18',
            name: 'Goods & Services Tax (18%)',
            category: 'TAX',
            rate: 0.18,
            quantity: 1,
            amount: 855,
            isRefundable: false,
            explanation: '18% GST',
          },
          {
            code: 'SECURITY_DEPOSIT',
            name: 'Refundable Security Deposit',
            category: 'DEPOSIT',
            rate: 5000,
            quantity: 1,
            amount: 5000,
            isRefundable: true,
            explanation: 'Refunded within 24 hours of safe return',
          },
        ],
      }),
    };

    mockPaymentRouting = {
      resolvePaymentRoute: jest.fn().mockResolvedValue({
        primaryProviderId: 'razorpay',
        fallbackChain: ['stripe', 'cashfree'],
        allCandidates: ['razorpay', 'stripe', 'cashfree'],
        estimatedFee: { amount: 15, currency: 'INR', percentage: 1.5, fixed: 0 },
      }),
      evaluateFallbackSafety: jest.fn().mockReturnValue({
        safeToFailover: true,
        action: 'FAILOVER',
        reason: 'Pre-flight failure',
      }),
    };

    mockRuntimeService = {
      execute: jest.fn().mockResolvedValue({
        success: true,
        data: { orderId: 'order_rzp_mock_123', verified: true },
      }),
    };

    mockAllocationService = {
      allocateVehicle: jest.fn().mockResolvedValue({ success: true }),
    };

    mockCancellationPolicy = {
      calculateCancellationWithConfig: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MarketplaceSearchService,
        MarketplaceRankingService,
        MarketplaceQuoteService,
        PromotionEngineService,
        AncillaryProductsService,
        CheckoutOrchestratorService,
        CancellationPreviewService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: FleetAvailabilityService, useValue: mockFleetAvailability },
        { provide: RentalPricingResolutionService, useValue: mockPricingResolution },
        { provide: PaymentRoutingService, useValue: mockPaymentRouting },
        { provide: IntegrationRuntimeService, useValue: mockRuntimeService },
        { provide: VehicleAllocationService, useValue: mockAllocationService },
        { provide: CancellationPolicyService, useValue: mockCancellationPolicy },
      ],
    }).compile();

    searchService = module.get<MarketplaceSearchService>(MarketplaceSearchService);
    rankingService = module.get<MarketplaceRankingService>(MarketplaceRankingService);
    quoteService = module.get<MarketplaceQuoteService>(MarketplaceQuoteService);
    promotionEngine = module.get<PromotionEngineService>(PromotionEngineService);
    ancillaryService = module.get<AncillaryProductsService>(AncillaryProductsService);
    checkoutOrchestrator = module.get<CheckoutOrchestratorService>(CheckoutOrchestratorService);
    cancellationPreview = module.get<CancellationPreviewService>(CancellationPreviewService);
  });

  // =========================================================================
  // 1. ENTERPRISE MARKETPLACE SEARCH & REAL-TIME AVAILABILITY
  // =========================================================================
  describe('Enterprise Marketplace Search Engine', () => {
    it('aggregates multi-vendor cars, applies filters, and returns normalized results with facets', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car_sedan_1',
          vendorId: 'vendor_fastwheels',
          pickupHubId: 'hub_mumbai_airport',
          make: 'Honda',
          model: 'City',
          year: 2023,
          type: CarCategory.SEDAN,
          fuelType: FuelType.PETROL,
          seating: 5,
          isAC: true,
          pricePerDay: new Prisma.Decimal(2500),
          photos: ['https://cdn.drivego.in/honda_city.jpg'],
          vendor: {
            id: 'vendor_fastwheels',
            businessName: 'FastWheels Enterprise',
            rating: 4.8,
            verificationStatus: 'VERIFIED',
            subscriptionTier: 'ENTERPRISE',
            city: 'Mumbai',
            yearsInOperation: 5,
          },
          pickupHub: {
            id: 'hub_mumbai_airport',
            name: 'Mumbai Airport Terminal 2 Hub',
            address: 'CSMIA Terminal 2, Mumbai',
            city: 'Mumbai',
            latitude: 19.0886,
            longitude: 72.8679,
            pickupFee: new Prisma.Decimal(100),
            allowsDelivery: true,
          },
          mileagePackages: [
            { id: 'pkg_1', isDefault: true, includedKmPerDay: 300, extraKmRate: 15 },
          ],
        },
        {
          id: 'car_suv_2',
          vendorId: 'vendor_apex',
          pickupHubId: 'hub_andheri',
          make: 'Hyundai',
          model: 'Creta',
          year: 2024,
          type: CarCategory.SUV,
          fuelType: FuelType.DIESEL,
          seating: 5,
          isAC: true,
          pricePerDay: new Prisma.Decimal(3200),
          photos: ['https://cdn.drivego.in/creta.jpg'],
          vendor: {
            id: 'vendor_apex',
            businessName: 'Apex Mobility',
            rating: 4.5,
            verificationStatus: 'VERIFIED',
            subscriptionTier: 'PRO',
            city: 'Mumbai',
            yearsInOperation: 3,
          },
          pickupHub: {
            id: 'hub_andheri',
            name: 'Andheri West Hub',
            address: 'Link Road, Andheri West',
            city: 'Mumbai',
            latitude: 19.1363,
            longitude: 72.8277,
            pickupFee: new Prisma.Decimal(0),
            allowsDelivery: true,
          },
          mileagePackages: [
            { id: 'pkg_2', isDefault: true, includedKmPerDay: 250, extraKmRate: 18 },
          ],
        },
      ]);

      mockPrisma.booking.count.mockResolvedValue(0); // Available!

      const searchRes = await searchService.searchMarketplace({
        pickupLocation: 'Mumbai',
        startDate: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
        endDate: new Date(Date.now() + 72 * 3600 * 1000).toISOString(),
        tripType: TripType.SELF_DRIVE,
      });

      expect(searchRes.success).toBe(true);
      expect(searchRes.totalResults).toBe(2);
      expect(searchRes.results).toHaveLength(2);

      // Verify normalization: no raw Prisma leaks
      const item = searchRes.results[0];
      expect(item.marketplaceId).toBeDefined();
      expect(item.exampleVehicle.make).toBeDefined();
      expect(item.vendor.name).toBeDefined();
      expect(item.branch.name).toBeDefined();
      expect(item.pricing.estimatedTotal).toBeGreaterThan(0);
      expect(item.score.compositeScore).toBeGreaterThan(0);

      // Facets verification
      expect(searchRes.facets.vehicleClasses.length).toBeGreaterThanOrEqual(1);
      expect(searchRes.facets.vendors.length).toBe(2);
    });

    it('rejects cars that are already reserved within turnaround buffer (real-time availability check)', async () => {
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car_blocked',
          vendorId: 'vendor_1',
          type: CarCategory.SEDAN,
          fuelType: FuelType.PETROL,
          seating: 5,
          isAC: true,
          pricePerDay: new Prisma.Decimal(2000),
          vendor: { id: 'vendor_1', verificationStatus: 'VERIFIED', rating: 4.0 },
          mileagePackages: [],
        },
      ]);

      // Return overlapping booking count = 1
      mockPrisma.booking.count.mockResolvedValue(1);

      const searchRes = await searchService.searchMarketplace({
        pickupLocation: 'Delhi',
        startDate: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
        endDate: new Date(Date.now() + 48 * 3600 * 1000).toISOString(),
      });

      expect(searchRes.results).toHaveLength(0);
      expect(searchRes.totalResults).toBe(0);
    });

    it('enforces chronological date ordering', async () => {
      await expect(
        searchService.searchMarketplace({
          pickupLocation: 'Delhi',
          startDate: '2026-09-15T10:00:00Z',
          endDate: '2026-09-14T10:00:00Z', // End before start!
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // =========================================================================
  // 2. INTELLIGENT SEARCH RESULT RANKING ENGINE
  // =========================================================================
  describe('Intelligent Weighted Search Result Ranking', () => {
    it('computes composite weighted scores and assigns badges', () => {
      const candidates: any[] = [
        {
          marketplaceId: 'm1',
          vendor: { rating: 4.9, isVerified: true, reviewCount: 50 },
          branch: { distanceKm: 2 },
          exampleVehicle: { year: 2024, isElectric: true },
          pricing: { estimatedTotal: 3000 },
          availability: { availableVehiclesCount: 5, instantConfirmation: true, confidenceScore: 0.99 },
          score: {},
          fulfillment: { deliveryAvailable: true },
        },
        {
          marketplaceId: 'm2',
          vendor: { rating: 3.5, isVerified: false, reviewCount: 2 },
          branch: { distanceKm: 25 },
          exampleVehicle: { year: 2018, isElectric: false },
          pricing: { estimatedTotal: 6500 },
          availability: { availableVehiclesCount: 1, instantConfirmation: false, confidenceScore: 0.70 },
          score: {},
          fulfillment: { deliveryAvailable: false },
        },
      ];

      const ranked = rankingService.rankCandidates(candidates, MarketplaceRankingStrategyType.BALANCED);

      expect(ranked[0].marketplaceId).toBe('m1');
      expect(ranked[0].score.compositeScore).toBeGreaterThan(ranked[1].score.compositeScore);
      expect(ranked[0].badges).toContain('BEST_VALUE');
      expect(ranked[0].badges).toContain('TOP_RATED');
      expect(ranked[0].badges).toContain('ELECTRIC');
    });

    it('supports pluggable ranking strategies (PRICE_LOW_HIGH)', () => {
      const candidates: any[] = [
        {
          marketplaceId: 'high_price_top_vendor',
          vendor: { rating: 5.0, isVerified: true, reviewCount: 100 },
          branch: { distanceKm: 1 },
          exampleVehicle: { year: 2024, isElectric: false },
          pricing: { estimatedTotal: 10000 },
          availability: { availableVehiclesCount: 5, instantConfirmation: true, confidenceScore: 0.99 },
          score: {},
          fulfillment: { deliveryAvailable: true },
        },
        {
          marketplaceId: 'low_price_avg_vendor',
          vendor: { rating: 4.0, isVerified: true, reviewCount: 10 },
          branch: { distanceKm: 10 },
          exampleVehicle: { year: 2020, isElectric: false },
          pricing: { estimatedTotal: 2500 },
          availability: { availableVehiclesCount: 2, instantConfirmation: true, confidenceScore: 0.85 },
          score: {},
          fulfillment: { deliveryAvailable: true },
        },
      ];

      const priceRanked = rankingService.rankCandidates(candidates, MarketplaceRankingStrategyType.PRICE_LOW_HIGH);
      expect(priceRanked[0].marketplaceId).toBe('low_price_avg_vendor');
    });
  });

  // =========================================================================
  // 3. SEARCH-TO-QUOTE CONSISTENCY & 15-MINUTE AUTHORITATIVE LOCK
  // =========================================================================
  describe('Search-to-Quote Consistency & Quote Engine', () => {
    it('creates an authoritative 15-minute quote lock with cryptographic checksum integrity', async () => {
      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car_123',
        vendorId: 'vendor_abc',
        type: CarCategory.SEDAN,
        pricePerDay: new Prisma.Decimal(2500),
      });

      mockPrisma.bookingQuote.create.mockImplementation(({ data }: any) => ({
        id: 'quote_lock_xyz',
        ...data,
        createdAt: new Date(),
        updatedAt: new Date(),
        lineItems: [
          { type: 'BASE_RENTAL', name: 'Base Rental', amount: new Prisma.Decimal(5000) },
          { type: 'GST', name: 'GST 18%', amount: new Prisma.Decimal(855) },
          { type: 'SECURITY_DEPOSIT', name: 'Security Deposit', amount: new Prisma.Decimal(5000) },
        ],
      }));

      const quote = await quoteService.createQuote({
        carId: 'car_123',
        vendorId: 'vendor_abc',
        vehicleClass: CarCategory.SEDAN,
        startDate: new Date(Date.now() + 3600 * 1000),
        endDate: new Date(Date.now() + 49 * 3600 * 1000),
      });

      expect(quote.quoteId).toBe('quote_lock_xyz');
      expect(quote.totalPayable).toBeGreaterThan(0);
      expect(quote.integrityChecksum).toHaveLength(64); // SHA-256
      expect(quote.status).toBe(QuoteStatus.ACTIVE);
      expect(new Date(quote.expiresAt).getTime()).toBeGreaterThan(Date.now());
    });

    it('detects and rejects expired quotes without silent price mutations', async () => {
      mockPrisma.bookingQuote.findUnique.mockResolvedValue({
        id: 'quote_expired',
        status: QuoteStatus.ACTIVE,
        expiresAt: new Date(Date.now() - 60 * 1000), // Expired 1 minute ago
        lineItems: [],
      });

      await expect(quoteService.getVerifiedQuote('quote_expired')).rejects.toThrow(ConflictException);
      expect(mockPrisma.bookingQuote.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { status: QuoteStatus.EXPIRED },
        }),
      );
    });
  });

  // =========================================================================
  // 4. PROMOTIONS & DISCOUNT ENGINE
  // =========================================================================
  describe('Promotions & Discount Engine', () => {
    it('validates a valid percentage coupon and applies discount capped at maxDiscount', async () => {
      mockPrisma.coupon.findUnique.mockResolvedValue({
        id: 'cpn_diwali',
        code: 'DIWALI25',
        description: '25% Festive Discount',
        isActive: true,
        discountType: DiscountType.PERCENTAGE,
        discountValue: new Prisma.Decimal(25),
        maxDiscountAmount: new Prisma.Decimal(1000),
        minBookingAmount: new Prisma.Decimal(2000),
        startDate: new Date(Date.now() - 3600 * 1000),
        expiresAt: new Date(Date.now() + 86400 * 1000),
        usageCount: 10,
        globalUsageLimit: 100,
        perCustomerLimit: 2,
        stackable: false,
      });
      mockPrisma.couponUsage.count.mockResolvedValue(0);

      const result = await promotionEngine.evaluatePromotion('DIWALI25', {
        customerId: 'cust_1',
        vendorId: 'vendor_1',
        vehicleClass: CarCategory.SEDAN,
        subtotal: 5000,
        durationDays: 3,
        startDate: new Date(),
        endDate: new Date(),
      });

      expect(result.isValid).toBe(true);
      expect(result.discountAmount).toBe(1000); // 25% of 5000 is 1250, capped at max 1000
    });

    it('rejects vendor-scoped coupon when applied against a different vendor', async () => {
      mockPrisma.coupon.findUnique.mockResolvedValue({
        id: 'cpn_vendor_exclusive',
        code: 'VENDORONLY',
        description: 'Exclusive Vendor Offer',
        isActive: true,
        vendorId: 'vendor_specific_123',
        vendor: { businessName: 'Specific Car Rentals' },
        discountType: DiscountType.FIXED,
        discountValue: new Prisma.Decimal(500),
      });

      const result = await promotionEngine.evaluatePromotion('VENDORONLY', {
        vendorId: 'vendor_other_999', // Non-matching vendor
        vehicleClass: CarCategory.SEDAN,
        subtotal: 5000,
        durationDays: 2,
        startDate: new Date(),
        endDate: new Date(),
      });

      expect(result.isValid).toBe(false);
      expect(result.rejectionReason).toContain('exclusive to vendor');
    });

    it('rejects coupon when minimum booking amount is not satisfied', async () => {
      mockPrisma.coupon.findUnique.mockResolvedValue({
        id: 'cpn_big',
        code: 'BIGSPEND',
        isActive: true,
        minBookingAmount: new Prisma.Decimal(10000),
        discountType: DiscountType.FIXED,
        discountValue: new Prisma.Decimal(2000),
      });

      const result = await promotionEngine.evaluatePromotion('BIGSPEND', {
        vendorId: 'vendor_1',
        vehicleClass: CarCategory.SUV,
        subtotal: 3500, // Below min 10000
        durationDays: 1,
        startDate: new Date(),
        endDate: new Date(),
      });

      expect(result.isValid).toBe(false);
      expect(result.rejectionReason).toContain('Minimum booking amount');
    });

    it('prevents stacking non-stackable coupons with active duration discounts', async () => {
      mockPrisma.coupon.findUnique.mockResolvedValue({
        id: 'cpn_non_stack',
        code: 'NOSTACK',
        isActive: true,
        stackable: false,
        discountType: DiscountType.FIXED,
        discountValue: new Prisma.Decimal(500),
      });

      const result = await promotionEngine.evaluatePromotion('NOSTACK', {
        vendorId: 'vendor_1',
        vehicleClass: CarCategory.SEDAN,
        subtotal: 5000,
        durationDays: 7,
        startDate: new Date(),
        endDate: new Date(),
        existingDiscountsCount: 1, // Already has duration discount
      });

      expect(result.isValid).toBe(false);
      expect(result.rejectionReason).toContain('cannot be stacked');
    });
  });

  // =========================================================================
  // 5. OPTIONAL PRODUCTS & ANCILLARIES ENGINE
  // =========================================================================
  describe('Optional Products / Ancillaries Engine', () => {
    it('calculates itemized fees and taxes for per-day and flat optional products', async () => {
      mockPrisma.ancillaryProduct.findFirst
        .mockResolvedValueOnce({
          id: 'anc_driver',
          code: 'ADDITIONAL_DRIVER',
          name: 'Additional Driver',
          category: 'DRIVER',
          pricingModel: 'PER_DAY',
          basePrice: new Prisma.Decimal(250),
          taxRate: new Prisma.Decimal(0.18),
          maxQuantity: 2,
        })
        .mockResolvedValueOnce({
          id: 'anc_roadside',
          code: 'ROADSIDE_ASSISTANCE',
          name: 'Roadside Assistance',
          category: 'ROADSIDE_ASSISTANCE',
          pricingModel: 'FLAT',
          basePrice: new Prisma.Decimal(499),
          taxRate: new Prisma.Decimal(0.18),
          maxQuantity: 1,
        });

      const res = await ancillaryService.calculateAncillariesTotal(
        [
          { code: 'ADDITIONAL_DRIVER', quantity: 1 },
          { code: 'ROADSIDE_ASSISTANCE', quantity: 1 },
        ],
        3, // 3 days rental
        5000,
      );

      expect(res.items).toHaveLength(2);
      // Item 1: 250 * 3 = 750 subtotal + 18% tax (135) = 885
      expect(res.items[0].subtotal).toBe(750);
      expect(res.items[0].taxAmount).toBe(135);
      // Item 2: 499 flat + 18% tax (89.82) = 588.82
      expect(res.items[1].subtotal).toBe(499);
      expect(res.ancillariesTotal).toBe(750 + 135 + 499 + 89.82);
    });
  });

  // =========================================================================
  // 6. CUSTOMER CHECKOUT ORCHESTRATION & STATE MACHINE
  // =========================================================================
  describe('Customer Checkout Orchestration Layer', () => {
    it('orchestrates full checkout: session create -> payment initiate -> payment verify -> confirmed booking', async () => {
      // 1. Create session
      mockPrisma.bookingQuote.findUnique.mockResolvedValue({
        id: 'quote_ok',
        tenantId: 'vendor_fastwheels',
        status: QuoteStatus.ACTIVE,
        tripType: TripType.SELF_DRIVE,
        startDate: new Date(Date.now() + 3600 * 1000),
        endDate: new Date(Date.now() + 49 * 3600 * 1000),
        durationDays: 2,
        durationHours: 48,
        pricingVersion: 'v2.0-enterprise',
        expiresAt: new Date(Date.now() + 15 * 60 * 1000),
        totalPayable: new Prisma.Decimal(6855),
        subtotal: new Prisma.Decimal(5000),
        feesTotal: new Prisma.Decimal(250),
        taxTotal: new Prisma.Decimal(855),
        depositTotal: new Prisma.Decimal(5000),
        netToVendor: new Prisma.Decimal(4500),
        currency: 'INR',
        car: { id: 'car_1', type: CarCategory.SEDAN, pickupHubId: 'hub_1' },
        lineItems: [],
      });

      mockPrisma.checkoutSession.create.mockImplementation(({ data }: any) => ({
        id: 'sess_db_1',
        ...data,
        quote: {
          id: 'quote_ok',
          totalPayable: new Prisma.Decimal(6855),
          tenantId: 'vendor_fastwheels',
          car: { id: 'car_1', type: CarCategory.SEDAN },
          lineItems: [],
        },
      }));

      const session = await checkoutOrchestrator.createCheckoutSession('quote_ok', 'cust_101');
      expect(session.sessionId).toBeDefined();
      expect(session.status).toBe(CheckoutSessionStatus.QUOTE_LOCKED);

      // 2. Initiate Payment
      mockPrisma.checkoutSession.findUnique.mockResolvedValue({
        id: 'sess_db_1',
        sessionId: session.sessionId,
        customerId: 'cust_101',
        quoteId: 'quote_ok',
        status: CheckoutSessionStatus.QUOTE_LOCKED,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
        paymentAttempts: 0,
        quote: {
          id: 'quote_ok',
          totalPayable: new Prisma.Decimal(6855),
          tenantId: 'vendor_fastwheels',
          currency: 'INR',
        },
      });

      const initPay = await checkoutOrchestrator.initiatePayment(session.sessionId, 'cust_101', 'UPI');
      expect(initPay.orderId).toBeDefined();
      expect(initPay.providerId).toBe('razorpay');
      expect(initPay.fallbackChain).toContain('stripe');

      // 3. Verify & Confirm Payment
      mockPrisma.checkoutSession.findUnique.mockResolvedValue({
        id: 'sess_db_1',
        sessionId: session.sessionId,
        customerId: 'cust_101',
        quoteId: 'quote_ok',
        status: CheckoutSessionStatus.PAYMENT_PENDING,
        selectedPaymentProvider: 'razorpay',
        quote: {
          id: 'quote_ok',
          tenantId: 'vendor_fastwheels',
          carId: 'car_1',
          tripType: TripType.SELF_DRIVE,
          startDate: new Date(),
          endDate: new Date(),
          subtotal: new Prisma.Decimal(5000),
          feesTotal: new Prisma.Decimal(250),
          taxTotal: new Prisma.Decimal(855),
          depositTotal: new Prisma.Decimal(5000),
          totalPayable: new Prisma.Decimal(6855),
          netToVendor: new Prisma.Decimal(4500),
          currency: 'INR',
          car: { id: 'car_1', type: CarCategory.SEDAN, pickupHubId: 'hub_1' },
          lineItems: [],
        },
      });

      mockPrisma.booking.create.mockResolvedValue({
        id: 'booking_confirmed_123',
        status: BookingStatus.CONFIRMED,
        totalFare: new Prisma.Decimal(6855),
      });

      const confirmed = await checkoutOrchestrator.verifyAndConfirmPayment(session.sessionId, 'cust_101', {
        orderId: initPay.orderId,
        paymentId: 'pay_rzp_mock_success',
        signature: 'valid_sig',
      });

      expect(confirmed.bookingId).toBe('booking_confirmed_123');
      expect(confirmed.bookingStatus).toBe(BookingStatus.CONFIRMED);
    });

    it('prevents dangerous failovers when payment state on gateway is indeterminate (double-debit guard)', async () => {
      mockPrisma.checkoutSession.findUnique.mockResolvedValue({
        id: 'sess_indeterminate',
        sessionId: 'cs_indet_1',
        customerId: 'cust_1',
        quote: { id: 'q1' },
        metadata: {
          routingDecision: { fallbackChain: ['stripe', 'cashfree'] },
        },
      });

      mockPaymentRouting.evaluateFallbackSafety.mockReturnValue({
        safeToFailover: false,
        action: 'PENDING_RECONCILIATION',
        reason: 'Post-dispatch timeout: double charge risk',
      });

      const failureRes = await checkoutOrchestrator.handlePaymentFailure('cs_indet_1', 'cust_1', {
        providerId: 'razorpay',
        errorCode: 'TIMEOUT',
        errorMessage: 'Gateway timed out after debit dispatch',
        dispatchedToGateway: true,
      });

      expect(failureRes.safeToFailover).toBe(false);
      expect(failureRes.action).toBe('PENDING_RECONCILIATION');
    });

    it('allows clean failover to secondary provider on pre-flight failure', async () => {
      mockPrisma.checkoutSession.findUnique.mockResolvedValue({
        id: 'sess_preflight',
        sessionId: 'cs_pref_1',
        customerId: 'cust_1',
        quote: { id: 'q1' },
        metadata: {
          routingDecision: { fallbackChain: ['stripe', 'cashfree'] },
        },
      });

      mockPaymentRouting.evaluateFallbackSafety.mockReturnValue({
        safeToFailover: true,
        action: 'FAILOVER',
        reason: 'Pre-flight circuit open',
      });

      const failureRes = await checkoutOrchestrator.handlePaymentFailure('cs_pref_1', 'cust_1', {
        providerId: 'razorpay',
        errorCode: 'CIRCUIT_OPEN',
        errorMessage: 'Provider circuit open',
        dispatchedToGateway: false,
      });

      expect(failureRes.safeToFailover).toBe(true);
      expect(failureRes.action).toBe('FAILOVER_SECONDARY');
      expect(failureRes.recommendedProviderId).toBe('stripe');
    });
  });

  // =========================================================================
  // 7. CANCELLATION & REFUND PREVIEW
  // =========================================================================
  describe('Cancellation Policy & Refund Preview Foundation', () => {
    it('previews free cancellation with 100% fare and security deposit refund > 24h before pickup', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'b_free_cancel',
        vendorId: 'vendor_1',
        status: BookingStatus.CONFIRMED,
        startDate: new Date(Date.now() + 48 * 3600 * 1000), // 48h before pickup
        totalFare: new Prisma.Decimal(5000),
        car: { type: CarCategory.SEDAN, pickupHubId: 'hub_1' },
      });

      mockPrisma.cancellationPolicyDefinition.findFirst.mockResolvedValue(null); // use platform default

      const preview = await cancellationPreview.previewCancellation('b_free_cancel');

      expect(preview.cancellationFeePercent).toBe(0);
      expect(preview.cancellationFeeAmount).toBe(0);
      expect(preview.refundableAmount).toBe(5000);
      expect(preview.securityDepositRefund).toBe(5000);
      expect(preview.netRefundToCustomer).toBe(10000);
      expect(preview.cancellationTier).toBe('FREE_CANCELLATION');
    });

    it('previews moderate cancellation fee when cancelled between 6h and 24h before pickup', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'b_mod_cancel',
        vendorId: 'vendor_1',
        status: BookingStatus.CONFIRMED,
        startDate: new Date(Date.now() + 10 * 3600 * 1000), // 10h before pickup
        totalFare: new Prisma.Decimal(6000),
        car: { type: CarCategory.SEDAN, pickupHubId: 'hub_1' },
      });

      const preview = await cancellationPreview.previewCancellation('b_mod_cancel');

      expect(preview.cancellationFeePercent).toBe(25.0);
      expect(preview.cancellationFeeAmount).toBe(1500); // 25% of 6000
      expect(preview.refundableAmount).toBe(4500);
      expect(preview.netRefundToCustomer).toBe(4500 + 5000); // refundable fare + deposit
    });
  });
});
