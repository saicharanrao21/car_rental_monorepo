import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { FulfillmentController } from '../fulfillment.controller';
import { FulfillmentOrchestratorService } from '../fulfillment-orchestrator.service';
import { VehicleSubstitutionService } from '../../fleet/vehicle-substitution.service';
import { CommandCenterController } from '../../operations/command-center.controller';
import { SlaEscalationEngineService } from '../../operations/sla-escalation.service';
import { BranchOperationsService } from '../../operations/branch-operations.service';
import { InventoryRebalancingService } from '../../fleet/inventory-rebalancing.service';
import { BookingLifecycleService } from '../../bookings/booking-lifecycle.service';
import { RentalAutomationService } from '../../bookings/rental-automation.service';
import { BookingOutboxService } from '../../bookings/booking-outbox.service';
import { CancellationPolicyService } from '../../bookings/cancellation-policy.service';
import { HandoverOtpService } from '../../bookings/handover-otp.service';
import { PaymentsService } from '../../payments/payments.service';
import { AuditLogService } from '../../admin/audit-log.service';
import { BookingLockService } from '../../redis/booking-lock.service';
import { PricingService } from '../../pricing/pricing.service';
import { CommissionResolverService } from '../../common/commission-resolver.service';
import { FareCalculatorService } from '../../common/fare-calculator.service';
import { DemandAwarePricingService } from '../../pricing/demand-aware-pricing.service';
import { MarketplaceCommissionService } from '../../finance/marketplace-commission.service';
import { CorporateAccountsService } from '../../corporate/corporate-accounts.service';
import {
  BookingStatus,
  FulfillmentStage,
  Role,
  CarCategory,
  SlaSeverity,
  SalesChannel,
  PaymentStatus,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { ForbiddenException, ConflictException } from '@nestjs/common';

describe('Phase O: Enterprise Reservation, Fulfillment & Financial Integrity Hardening', () => {
  let fulfillmentController: FulfillmentController;
  let commandCenterController: CommandCenterController;
  let bookingLifecycle: BookingLifecycleService;
  let pricingService: PricingService;
  let rentalAutomation: RentalAutomationService;
  let slaEscalation: SlaEscalationEngineService;
  let corporateAccounts: CorporateAccountsService;

  let mockPrisma: any;
  let mockFulfillmentOrchestrator: any;
  let mockSubstitutionService: any;
  let mockBranchOperations: any;
  let mockRebalancing: any;
  let mockDemandPricing: any;
  let mockCommissionService: any;
  let mockOutbox: any;
  let mockCancellationPolicy: any;
  let mockHandoverOtp: any;
  let mockPaymentsService: any;
  let mockAuditLog: any;
  let mockLockService: any;
  let mockCommissionResolver: any;
  let mockFareCalculator: any;

  beforeEach(async () => {
    mockPrisma = {
      $transaction: jest.fn(async (cb) => {
        if (typeof cb === 'function') {
          return cb(mockPrisma);
        }
        return cb;
      }),
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn(),
        update: jest.fn(),
      },
      fulfillmentRecord: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        upsert: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        count: jest.fn(),
      },
      car: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
      },
      inspection: {
        findUnique: jest.fn().mockResolvedValue({ finalized: true }),
      },
      vehicleHold: {
        findMany: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn(),
      },
      slaBreachIncident: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
      },
      slaPolicyDefinition: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      corporateAccount: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      unconfirmedReservation: {
        findMany: jest.fn(),
        deleteMany: jest.fn(),
      },
      bookingQuote: {
        updateMany: jest.fn(),
        create: jest.fn().mockImplementation((args) => ({
          id: 'quote-123',
          quoteNumber: 'Q-123',
          ...args.data,
          lineItems: Array.isArray(args.data.lineItems?.create) ? args.data.lineItems.create : [],
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 15 * 60000),
        })),
      },
      pricingRule: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      systemSetting: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      coupon: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
      insurancePackage: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
      locationFulfillmentConfig: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      outboxEvent: {
        create: jest.fn(),
      },
      bookingOutboxEvent: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'evt-1' }),
      },
    };

    mockFulfillmentOrchestrator = {
      startPreparation: jest.fn(),
      markCleaned: jest.fn(),
      markInspected: jest.fn(),
      markReadyForPickup: jest.fn(),
      recordCustomerArrival: jest.fn(),
      getFulfillmentRecord: jest.fn(),
      getBranchOperationalQueue: jest.fn(),
      getQueueMetrics: jest.fn(),
    };

    mockSubstitutionService = {
      evaluateSubstitution: jest.fn(),
      executeSubstitution: jest.fn(),
    };

    mockBranchOperations = {
      getBranchOperationalDashboard: jest.fn(),
      getHubOperationalQueue: jest.fn(),
    };

    mockRebalancing = {
      generateTransferRecommendations: jest.fn(),
      listTransferRecommendations: jest.fn(),
    };

    mockDemandPricing = {
      evaluatePrice: jest.fn(),
    };

    mockCommissionService = {
      calculateCommission: jest.fn(),
    };

    mockOutbox = {
      publish: jest.fn().mockResolvedValue(undefined),
      dispatchEvent: jest.fn().mockResolvedValue(undefined),
    };

    mockCancellationPolicy = {
      calculateRefund: jest.fn().mockResolvedValue({ refundAmount: 0, cancellationFee: 0 }),
      calculateCancellation: jest.fn().mockReturnValue({ refundAmountInPaise: 0, cancellationFeeInPaise: 0 }),
    };

    mockHandoverOtp = {
      generateOtp: jest.fn().mockResolvedValue('123456'),
      verifyOtp: jest.fn().mockResolvedValue(true),
    };

    mockPaymentsService = {
      capturePreAuthorization: jest.fn().mockResolvedValue({ success: true }),
      releasePreAuthorization: jest.fn().mockResolvedValue({ success: true }),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue(undefined),
      record: jest.fn().mockResolvedValue(undefined),
    };

    mockLockService = {
      acquireBookingLock: jest.fn().mockResolvedValue('token-123'),
      releaseBookingLock: jest.fn().mockResolvedValue(true),
      acquireCancellationLock: jest.fn().mockResolvedValue('test_lock'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    mockCommissionResolver = {
      resolveCommission: jest.fn().mockResolvedValue({
        platformRatePct: 15,
        gatewayFeePct: 2,
        taxRatePct: 18,
      }),
      resolveCommissionPercent: jest.fn().mockResolvedValue(15),
    };

    mockFareCalculator = {
      calculateFare: jest.fn().mockReturnValue({
        baseFare: 2400,
        distanceFee: 0,
        durationDays: 1,
        totalTaxes: 432,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FulfillmentController,
        CommandCenterController,
        CorporateAccountsService,
        SlaEscalationEngineService,
        BookingLifecycleService,
        PricingService,
        RentalAutomationService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: FulfillmentOrchestratorService,
          useValue: mockFulfillmentOrchestrator,
        },
        {
          provide: VehicleSubstitutionService,
          useValue: mockSubstitutionService,
        },
        {
          provide: BranchOperationsService,
          useValue: mockBranchOperations,
        },
        {
          provide: InventoryRebalancingService,
          useValue: mockRebalancing,
        },
        {
          provide: DemandAwarePricingService,
          useValue: mockDemandPricing,
        },
        {
          provide: MarketplaceCommissionService,
          useValue: mockCommissionService,
        },
        {
          provide: BookingOutboxService,
          useValue: mockOutbox,
        },
        {
          provide: CancellationPolicyService,
          useValue: mockCancellationPolicy,
        },
        {
          provide: HandoverOtpService,
          useValue: mockHandoverOtp,
        },
        {
          provide: PaymentsService,
          useValue: mockPaymentsService,
        },
        {
          provide: AuditLogService,
          useValue: mockAuditLog,
        },
        {
          provide: BookingLockService,
          useValue: mockLockService,
        },
        {
          provide: CommissionResolverService,
          useValue: mockCommissionResolver,
        },
        {
          provide: FareCalculatorService,
          useValue: mockFareCalculator,
        },
      ],
    }).compile();

    fulfillmentController = module.get<FulfillmentController>(FulfillmentController);
    commandCenterController = module.get<CommandCenterController>(CommandCenterController);
    bookingLifecycle = module.get<BookingLifecycleService>(BookingLifecycleService);
    pricingService = module.get<PricingService>(PricingService);
    rentalAutomation = module.get<RentalAutomationService>(RentalAutomationService);
    slaEscalation = module.get<SlaEscalationEngineService>(SlaEscalationEngineService);
    corporateAccounts = module.get<CorporateAccountsService>(CorporateAccountsService);
  });

  describe('1. Controller Security & Role-Based Access Control', () => {
    it('should properly protect fulfillment preparation endpoint and delegate to orchestrator', async () => {
      mockFulfillmentOrchestrator.startPreparation.mockResolvedValue({
        id: 'ful-1',
        bookingId: 'b-100',
        stage: FulfillmentStage.PREPARATION,
      });

      const req = { user: { userId: 'admin-1', role: Role.ADMIN } };
      const dto = {
        bookingId: 'b-100',
        assignedStaffId: 'staff-42',
        notes: 'Priority turnaround for VIP',
      };

      const result = await fulfillmentController.startPreparation(dto, req);
      expect(result).toBeDefined();
      expect(result.stage).toBe(FulfillmentStage.PREPARATION);
      expect(mockFulfillmentOrchestrator.startPreparation).toHaveBeenCalledWith({
        bookingId: 'b-100',
        assignedStaffId: 'staff-42',
        notes: 'Priority turnaround for VIP',
        actorId: 'admin-1',
        actorRole: Role.ADMIN,
      });
    });

    it('should enforce vendor tenant isolation when retrieving fulfillment records', async () => {
      mockFulfillmentOrchestrator.getFulfillmentRecord.mockResolvedValue({
        id: 'ful-99',
        bookingId: 'b-foreign',
        vendorId: 'vendor-legit',
      });

      const vendorUserReq = {
        user: { userId: 'usr-v2', role: Role.VENDOR, vendorId: 'vendor-attacker' },
      };

      await expect(
        fulfillmentController.getFulfillmentStatus('b-foreign', vendorUserReq),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should delegate vendor command-center operations with correct vendor scoping', async () => {
      const vendorReq = { user: { userId: 'usr-v1', role: Role.VENDOR, vendorId: 'v-999' } };
      mockPrisma.fulfillmentRecord.count.mockResolvedValue(3);
      mockPrisma.slaBreachIncident.count.mockResolvedValue(0);
      mockPrisma.booking.count.mockResolvedValue(5);
      mockPrisma.car.count.mockResolvedValue(10);

      const dashboard = await commandCenterController.getVendorCommandCenter(vendorReq);
      expect(dashboard).toBeDefined();
      expect(dashboard.vendorId).toBe('v-999');
      expect(mockPrisma.booking.count).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ vendorId: 'v-999' }),
        }),
      );
    });

    it('should allow incident resolution via command center with audit action notes', async () => {
      const adminReq = { user: { userId: 'adm-1', role: Role.ADMIN } };
      mockPrisma.slaBreachIncident.findUnique.mockResolvedValue({
        id: 'inc-101',
        status: 'TRIGGERED',
        severity: SlaSeverity.CRITICAL,
      });
      mockPrisma.slaBreachIncident.update.mockResolvedValue({
        id: 'inc-101',
        status: 'RESOLVED',
        resolvedAt: new Date(),
        actionTaken: 'Manually expedited vehicle turnaround',
      });

      const res = await commandCenterController.resolveIncident(
        'inc-101',
        { resolutionNotes: 'Manually expedited vehicle turnaround' },
        adminReq,
      );

      expect(res).toBeDefined();
      expect(res.status).toBe('RESOLVED');
      expect(res.actionTaken).toBe('Manually expedited vehicle turnaround');
    });

    it('should reject customer attempting to view another customer\'s fulfillment status', async () => {
      mockFulfillmentOrchestrator.getFulfillmentRecord.mockResolvedValue({
        id: 'ful-10',
        bookingId: 'b-victim',
        vendorId: 'vendor-1',
        booking: {
          customerId: 'customer-legit',
        },
      });

      const maliciousCustomerReq = {
        user: { userId: 'customer-attacker', role: Role.CUSTOMER },
      };

      await expect(
        fulfillmentController.getFulfillmentStatus('b-victim', maliciousCustomerReq),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reject vendor attempting to query branch dashboard for another vendor', async () => {
      const maliciousVendorReq = {
        user: { userId: 'usr-v2', role: Role.VENDOR, vendorId: 'vendor-legit' },
      };

      await expect(
        commandCenterController.getBranchDashboard(
          'branch-1',
          maliciousVendorReq,
          'vendor-foreign-target',
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reject vendor attempting to query SLA incidents for another vendor', async () => {
      const maliciousVendorReq = {
        user: { userId: 'usr-v2', role: Role.VENDOR, vendorId: 'vendor-legit' },
      };

      await expect(
        commandCenterController.listIncidents(
          maliciousVendorReq,
          undefined,
          undefined,
          'vendor-foreign-target',
        ),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('2. Booking <-> Fulfillment Transactional Bridge', () => {
    it('should synchronize FulfillmentRecord to READY_FOR_PICKUP on HANDOVER_READY transition', async () => {
      const mockBooking = {
        id: 'b-200',
        customerId: 'cust-1',
        status: BookingStatus.CONFIRMED,
        carId: 'car-99',
        vendorId: 'vendor-1',
        startDate: new Date(),
        endDate: new Date(Date.now() + 86400000),
        customer: { name: 'Bob', phone: '+919876543210' },
        vendor: { businessName: 'Speedy Fleet', userId: 'v-1' },
        car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'KA-01-MJ-9988' },
      };

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.booking.update.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.HANDOVER_READY,
      });

      await bookingLifecycle.executeTransition({
        bookingId: 'b-200',
        targetStatus: BookingStatus.HANDOVER_READY,
        actorId: 'admin-1',
        actorRole: Role.ADMIN,
      });

      expect(mockPrisma.fulfillmentRecord.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { bookingId: 'b-200' },
          data: expect.objectContaining({
            stage: FulfillmentStage.READY_FOR_PICKUP,
          }),
        }),
      );
    });

    it('should automatically set FulfillmentRecord to CANCELLED and unassign vehicle on CANCELLED transition', async () => {
      const mockBooking = {
        id: 'b-201',
        customerId: 'cust-1',
        status: BookingStatus.CONFIRMED,
        carId: 'car-99',
        vendorId: 'vendor-1',
        startDate: new Date(),
        endDate: new Date(Date.now() + 86400000),
        customer: { name: 'Bob', phone: '+919876543210' },
        vendor: { businessName: 'Speedy Fleet', userId: 'v-1' },
        car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'KA-01-MJ-9988' },
      };

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.booking.update.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.CANCELLED,
      });

      await bookingLifecycle.executeTransition({
        bookingId: 'b-201',
        targetStatus: BookingStatus.CANCELLED,
        actorId: 'cust-1',
        actorRole: Role.CUSTOMER,
        reason: 'Customer schedule change',
      });

      expect(mockPrisma.fulfillmentRecord.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { bookingId: 'b-201' },
          data: expect.objectContaining({
            stage: FulfillmentStage.CANCELLED,
          }),
        }),
      );
    });

    it('should calculate and persist multilateral commission split upon booking CONFIRMED', async () => {
      const mockBooking = {
        id: 'b-202',
        customerId: 'cust-2',
        status: BookingStatus.PENDING,
        carId: 'car-77',
        vendorId: 'vendor-5',
        totalFare: new Decimal(10000),
        startDate: new Date(),
        endDate: new Date(Date.now() + 86400000 * 3),
        customer: { name: 'Alice', phone: '+919876543210' },
        vendor: { businessName: 'Prime Rentals', userId: 'v-5' },
        car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'KA-01-MJ-9988' },
        payment: {
          status: PaymentStatus.PAID,
          amount: new Decimal(10000),
        },
        priceSnapshot: {
          baseFare: 8000,
          taxes: 2000,
        },
      };

      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car-77',
        category: CarCategory.SUV,
      });

      mockCommissionService.calculateCommission.mockReturnValue({
        grossTotal: 10000,
        platformCommissionRatePct: 15,
        platformCommissionAmount: 1500,
        gstRatePct: 18,
        platformGst: 270,
        gatewayFee: 200,
        netVendorPayout: 8030,
        holdbackSecurityDeposit: 0,
        policyApplied: 'STANDARD_MARKETPLACE_V1',
      });

      mockPrisma.booking.update.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.CONFIRMED,
      });

      await bookingLifecycle.executeTransition({
        bookingId: 'b-202',
        targetStatus: BookingStatus.CONFIRMED,
        actorId: 'system',
        actorRole: Role.ADMIN,
      });

      expect(mockCommissionService.calculateCommission).toHaveBeenCalledWith(
        expect.objectContaining({
          grossAmount: 10000,
          vendorId: 'vendor-5',
        }),
      );

      expect(mockPrisma.booking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            priceSnapshot: expect.objectContaining({
              commissionSplit: expect.objectContaining({
                platformCommissionAmount: 1500,
                netVendorPayout: 8030,
              }),
            }),
          }),
        }),
      );
    });
  });

  describe('3. Dynamic Pricing Integration into Quotes', () => {
    it('should inject demand-aware surge multiplier into quote generation when dynamic pricing is enabled', async () => {
      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car-999',
        pricePerDay: new Decimal(2000),
        securityDeposit: new Decimal(5000),
        category: CarCategory.SEDAN,
        type: CarCategory.SEDAN,
        vendorId: 'v-10',
        hubId: 'hub-1',
        isAvailable: true,
        vendor: {
          city: 'Mumbai',
          verificationStatus: 'VERIFIED',
          subscriptionTier: 'PRO',
        },
      });

      mockDemandPricing.evaluatePrice.mockResolvedValue({
        effectiveDailyRate: 2400,
        baseDailyRate: 2000,
        multiplier: 1.2,
        utilizationRate: 0.85,
        policyApplied: 'PEAK_DEMAND_SURGE',
        isSurge: true,
        isDiscount: false,
        explanation: 'High fleet utilization in branch (+20%)',
      });

      const now = new Date();
      const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

      const quote = await pricingService.generateQuote({
        carId: 'car-999',
        startDate: now,
        endDate: tomorrow,
        salesChannel: SalesChannel.CUSTOMER_APP,
      });

      expect(quote).toBeDefined();
      expect(mockDemandPricing.evaluatePrice).toHaveBeenCalled();
      expect(quote.totalPayable).toBeGreaterThan(2000);
      expect(quote.lineItems.length).toBeGreaterThan(0);
    });
  });

  describe('4. Autonomous Operational Automation Sweeps', () => {
    it('should sweep and release expired vehicle holds', async () => {
      const expiredHolds = [
        {
          id: 'hold-1',
          carId: 'c-1',
          bookingId: 'b-1',
          expiresAt: new Date(Date.now() - 60000),
          status: 'ACTIVE',
        },
        {
          id: 'hold-2',
          carId: 'c-2',
          bookingId: 'b-2',
          expiresAt: new Date(Date.now() - 120000),
          status: 'ACTIVE',
        },
      ];

      mockPrisma.vehicleHold.findMany.mockResolvedValue(expiredHolds);
      mockPrisma.vehicleHold.update.mockResolvedValue({});

      const result = await rentalAutomation.expireStaleVehicleHolds();
      expect(result.processedCount).toBe(2);
      expect(result.successCount).toBe(2);
      expect(mockPrisma.vehicleHold.update).toHaveBeenCalledTimes(2);
    });
  });

  describe('5. SLA Incident Lifecycle Management', () => {
    it('should resolve an active SLA incident with audit action', async () => {
      mockPrisma.slaBreachIncident.findUnique.mockResolvedValue({
        id: 'inc-200',
        status: 'TRIGGERED',
        severity: SlaSeverity.HIGH,
      });

      mockPrisma.slaBreachIncident.update.mockResolvedValue({
        id: 'inc-200',
        status: 'RESOLVED',
        resolvedAt: new Date(),
        actionTaken: 'Dispatched emergency buffer vehicle',
      });

      const resolved = await slaEscalation.resolveIncident(
        'inc-200',
        'admin-1',
        'Dispatched emergency buffer vehicle',
      );

      expect(resolved.status).toBe('RESOLVED');
      expect(mockPrisma.slaBreachIncident.update).toHaveBeenCalledWith({
        where: { id: 'inc-200' },
        data: {
          status: 'RESOLVED',
          resolvedAt: expect.any(Date),
          actionTaken: 'Dispatched emergency buffer vehicle',
        },
      });
    });

    it('should list SLA incidents scoped by status and vendor', async () => {
      mockPrisma.slaBreachIncident.findMany.mockResolvedValue([
        {
          id: 'inc-301',
          vendorId: 'v-1',
          status: 'TRIGGERED',
          severity: SlaSeverity.CRITICAL,
        },
      ]);

      const incidents = await slaEscalation.listIncidents({
        vendorId: 'v-1',
        status: 'TRIGGERED',
      });

      expect(incidents).toHaveLength(1);
      expect(mockPrisma.slaBreachIncident.findMany).toHaveBeenCalledWith({
        where: {
          vendorId: 'v-1',
          status: 'TRIGGERED',
        },
        include: {
          policy: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 50,
      });
    });

    it('should prevent duplicate SLA incident creation if an incident is already triggered or resolved', async () => {
      mockPrisma.slaPolicyDefinition.findFirst.mockResolvedValue({
        id: 'pol-1',
        targetProcess: 'ALLOCATION',
      });

      // An incident already exists in RESOLVED status
      mockPrisma.slaBreachIncident.findFirst.mockResolvedValue({
        id: 'inc-prev',
        bookingId: 'b-999',
        targetProcess: 'ALLOCATION',
        status: 'RESOLVED',
      });

      mockPrisma.booking.findMany.mockResolvedValue([
        {
          id: 'b-999',
          vendorId: 'v-1',
          updatedAt: new Date(Date.now() - 3600000),
          pickupHubId: 'hub-1',
        },
      ]);

      const result = await slaEscalation.evaluateAllSlas();
      expect(result.incidentsCreated).toBe(0);
      expect(mockPrisma.slaBreachIncident.create).not.toHaveBeenCalled();
    });
  });

  describe('6. B2B Corporate Accounts Credit Validation & Usage', () => {
    it('should approve credit reservation when credit line is within limit', async () => {
      mockPrisma.corporateAccount.findUnique.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        creditLimit: new Decimal(100000),
        usedCredit: new Decimal(25000),
        negotiatedDiscountPct: new Decimal(15),
        isActive: true,
      });

      const validation = await corporateAccounts.validateCredit({
        corporateCode: 'CORP-GOOGLE',
        estimatedAmount: 15000,
      });

      expect(validation.eligible).toBe(true);
      expect(validation.availableCredit).toBe(75000);
      expect(validation.reason).toContain('Credit line approved');
    });

    it('should reject credit reservation when estimated amount exceeds available credit', async () => {
      mockPrisma.corporateAccount.findUnique.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        creditLimit: new Decimal(50000),
        usedCredit: new Decimal(45000),
        negotiatedDiscountPct: new Decimal(15),
        isActive: true,
      });

      const validation = await corporateAccounts.validateCredit({
        corporateCode: 'CORP-GOOGLE',
        estimatedAmount: 10000,
      });

      expect(validation.eligible).toBe(false);
      expect(validation.availableCredit).toBe(5000);
      expect(validation.reason).toContain('Credit limit exceeded');
    });

    it('should debit usedCredit upon recording corporate usage', async () => {
      mockPrisma.corporateAccount.findUnique.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        creditLimit: new Decimal(100000),
        usedCredit: new Decimal(20000),
        isActive: true,
      });

      mockPrisma.corporateAccount.update.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        usedCredit: new Decimal(32000),
      });

      const updated = await corporateAccounts.recordUsage('CORP-GOOGLE', 12000);
      expect(updated).toBeDefined();
      expect(mockPrisma.corporateAccount.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'corp-1' },
          data: {
            usedCredit: { increment: expect.any(Decimal) },
          },
        }),
      );
    });

    it('should reject credit reservation with ConflictException when overdraft occurs', async () => {
      mockPrisma.corporateAccount.findUnique.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        creditLimit: new Decimal(50000),
        usedCredit: new Decimal(45000),
        isActive: true,
      });

      await expect(
        corporateAccounts.reserveCredit('CORP-GOOGLE', 10000),
      ).rejects.toThrow(ConflictException);
    });

    it('should safely release corporate credit upon booking cancellation', async () => {
      mockPrisma.corporateAccount.findUnique.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        creditLimit: new Decimal(50000),
        usedCredit: new Decimal(20000),
        isActive: true,
      });

      mockPrisma.corporateAccount.update.mockResolvedValue({
        id: 'corp-1',
        corporateCode: 'CORP-GOOGLE',
        companyName: 'Google LLC',
        usedCredit: new Decimal(10000),
      });

      const released = await corporateAccounts.releaseCredit('CORP-GOOGLE', 10000);
      expect(released).toBeDefined();
      expect(mockPrisma.corporateAccount.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'corp-1' },
          data: {
            usedCredit: { decrement: expect.any(Decimal) },
          },
        }),
      );
    });
  });
});
