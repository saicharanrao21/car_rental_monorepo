import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { FulfillmentOrchestratorService } from '../fulfillment-orchestrator.service';
import { VehicleSubstitutionService } from '../../fleet/vehicle-substitution.service';
import { DemandAwarePricingService } from '../../pricing/demand-aware-pricing.service';
import { CompetitivePricingService } from '../../pricing/competitive-pricing.service';
import { MarketplaceSupplyService } from '../../fleet/marketplace-supply.service';
import { InventoryRebalancingService } from '../../fleet/inventory-rebalancing.service';
import { BranchOperationsService } from '../../operations/branch-operations.service';
import { SlaEscalationEngineService } from '../../operations/sla-escalation.service';
import { MarketplaceCommissionService } from '../../finance/marketplace-commission.service';
import { BookingLifecycleService } from '../../bookings/booking-lifecycle.service';
import { RentalOperationsService } from '../../bookings/rental-operations.service';
import { FleetAvailabilityService } from '../../fleet/fleet-availability.service';
import { VehicleAllocationService } from '../../fleet/vehicle-allocation.service';
import { BookingLockService } from '../../redis/booking-lock.service';
import {
  CarCategory,
  BookingStatus,
  FulfillmentStage,
  SubstitutionDecision,
  SubstitutionReason,
  SlaSeverity,
  InventoryTransferStatus,
  SalesChannel,
  Role,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase N: Enterprise Fulfillment, Pricing Intelligence & Marketplace Operations', () => {
  let fulfillmentService: FulfillmentOrchestratorService;
  let substitutionService: VehicleSubstitutionService;
  let pricingService: DemandAwarePricingService;
  let competitorPricingService: CompetitivePricingService;
  let supplyService: MarketplaceSupplyService;
  let rebalancingService: InventoryRebalancingService;
  let branchOperationsService: BranchOperationsService;
  let slaEngine: SlaEscalationEngineService;
  let commissionService: MarketplaceCommissionService;

  let mockPrisma: any;
  let mockBookingLifecycle: any;
  let mockRentalOperations: any;
  let mockAvailabilityService: any;
  let mockAllocationService: any;
  let mockLockService: any;

  beforeEach(async () => {
    mockPrisma = {
      booking: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
      },
      fulfillmentRecord: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        upsert: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      car: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      vehicleSubstitutionRecord: {
        create: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      dynamicPricingPolicy: {
        findFirst: jest.fn(),
      },
      competitorPriceObservation: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
      pickupHub: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
      },
      inventoryTransferRecommendation: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      slaPolicyDefinition: {
        findFirst: jest.fn(),
        create: jest.fn(),
      },
      slaBreachIncident: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        count: jest.fn(),
      },
      marketplaceCommissionRule: {
        findFirst: jest.fn(),
      },
      bookingOutboxEvent: {
        create: jest.fn(),
      },
    };

    mockBookingLifecycle = {
      markReadyForHandover: jest.fn().mockResolvedValue({ success: true }),
    };

    mockRentalOperations = {
      executePickup: jest.fn().mockResolvedValue({
        success: true,
        bookingId: 'booking_1',
        status: BookingStatus.ONGOING,
      }),
      executeReturn: jest.fn().mockResolvedValue({
        bookingId: 'booking_1',
        totalAdditionalCharges: 0,
        depositStatus: 'FULL_REFUND',
      }),
    };

    mockAvailabilityService = {
      isVehicleAvailable: jest.fn().mockResolvedValue(true),
    };

    mockAllocationService = {
      allocateVehicle: jest.fn().mockResolvedValue({
        success: true,
        allocationRecordId: 'alloc_rec_1',
        allocatedCarId: 'car_sub_1',
      }),
    };

    mockLockService = {
      acquireCancellationLock: jest.fn().mockResolvedValue('test_lock'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FulfillmentOrchestratorService,
        VehicleSubstitutionService,
        DemandAwarePricingService,
        CompetitivePricingService,
        MarketplaceSupplyService,
        InventoryRebalancingService,
        BranchOperationsService,
        SlaEscalationEngineService,
        MarketplaceCommissionService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: BookingLifecycleService, useValue: mockBookingLifecycle },
        { provide: RentalOperationsService, useValue: mockRentalOperations },
        { provide: FleetAvailabilityService, useValue: mockAvailabilityService },
        { provide: VehicleAllocationService, useValue: mockAllocationService },
        { provide: BookingLockService, useValue: mockLockService },
      ],
    }).compile();

    fulfillmentService = module.get<FulfillmentOrchestratorService>(FulfillmentOrchestratorService);
    substitutionService = module.get<VehicleSubstitutionService>(VehicleSubstitutionService);
    pricingService = module.get<DemandAwarePricingService>(DemandAwarePricingService);
    competitorPricingService = module.get<CompetitivePricingService>(CompetitivePricingService);
    supplyService = module.get<MarketplaceSupplyService>(MarketplaceSupplyService);
    rebalancingService = module.get<InventoryRebalancingService>(InventoryRebalancingService);
    branchOperationsService = module.get<BranchOperationsService>(BranchOperationsService);
    slaEngine = module.get<SlaEscalationEngineService>(SlaEscalationEngineService);
    commissionService = module.get<MarketplaceCommissionService>(MarketplaceCommissionService);
  });

  // =========================================================================
  // 1. FULFILLMENT ORCHESTRATION & GROUND REALITY
  // =========================================================================
  describe('Fulfillment Orchestrator & Multi-Stage Lifecycle', () => {
    const mockBooking = {
      id: 'booking_1',
      customerId: 'cust_1',
      vendorId: 'vendor_1',
      pickupHubId: 'branch_1',
      carId: 'car_1',
      status: BookingStatus.CONFIRMED,
      vehicleClass: CarCategory.SEDAN,
      startDate: new Date(),
      endDate: new Date(Date.now() + 86400000),
      customer: { id: 'cust_1', name: 'John Doe', phone: '+919876543210' },
      car: { id: 'car_1', make: 'Hyundai', model: 'Verna', registrationNumber: 'KA-01-AB-1234', type: CarCategory.SEDAN },
    };

    const mockRecord = {
      id: 'ful_1',
      bookingId: 'booking_1',
      vendorId: 'vendor_1',
      branchId: 'branch_1',
      carId: 'car_1',
      stage: FulfillmentStage.ALLOCATED,
    };

    it('should initialize fulfillment record in ALLOCATED stage when car is present', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.fulfillmentRecord.upsert.mockResolvedValue(mockRecord);

      const result = await fulfillmentService.initializeFulfillment('booking_1');

      expect(result.stage).toBe(FulfillmentStage.ALLOCATED);
      expect(mockPrisma.fulfillmentRecord.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { bookingId: 'booking_1' },
          create: expect.objectContaining({
            bookingId: 'booking_1',
            stage: FulfillmentStage.ALLOCATED,
          }),
        }),
      );
    });

    it('should transition vehicle turnaround to PREPARATION_IN_PROGRESS', async () => {
      mockPrisma.fulfillmentRecord.findUnique.mockResolvedValue(mockRecord);
      mockPrisma.fulfillmentRecord.update.mockResolvedValue({
        ...mockRecord,
        stage: FulfillmentStage.PREPARATION_IN_PROGRESS,
      });

      const res = await fulfillmentService.startPreparation({
        bookingId: 'booking_1',
        assignedStaffId: 'staff_10',
        notes: 'Express deep cleaning and sanitizer wash',
        actorId: 'vendor_1',
        actorRole: Role.VENDOR,
      });

      expect(res.success).toBe(true);
      expect(res.newStage).toBe(FulfillmentStage.PREPARATION_IN_PROGRESS);
      expect(mockPrisma.bookingOutboxEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            eventType: 'VEHICLE_PREPARATION_STARTED',
          }),
        }),
      );
    });

    it('should record cleaning and pre-trip inspection', async () => {
      mockPrisma.fulfillmentRecord.findUnique.mockResolvedValue(mockRecord);
      mockPrisma.fulfillmentRecord.update.mockResolvedValue({
        ...mockRecord,
        stage: FulfillmentStage.INSPECTION_COMPLETED,
      });

      const res = await fulfillmentService.markInspected({
        bookingId: 'booking_1',
        inspectionNotes: 'All 4 tyres and exterior in pristine condition',
        actorId: 'staff_1',
        actorRole: Role.ADMIN,
      });

      expect(res.success).toBe(true);
      expect(res.newStage).toBe(FulfillmentStage.INSPECTION_COMPLETED);
    });

    it('should mark READY_FOR_PICKUP and advance canonical booking to HANDOVER_READY', async () => {
      mockPrisma.fulfillmentRecord.findUnique.mockResolvedValue(mockRecord);
      mockPrisma.booking.findUnique.mockResolvedValue(mockBooking);
      mockPrisma.fulfillmentRecord.update.mockResolvedValue({
        ...mockRecord,
        stage: FulfillmentStage.READY_FOR_PICKUP,
      });

      const res = await fulfillmentService.markReadyForPickup({
        bookingId: 'booking_1',
        bayNumber: 'Bay-04',
        keyLocation: 'Locker-12',
        actorId: 'staff_1',
        actorRole: Role.ADMIN,
      });

      expect(res.success).toBe(true);
      expect(res.newStage).toBe(FulfillmentStage.READY_FOR_PICKUP);
      expect(mockBookingLifecycle.markReadyForHandover).toHaveBeenCalledWith('booking_1', 'staff_1', Role.ADMIN);
    });

    it('should record customer arrival check-in at branch desk', async () => {
      mockPrisma.fulfillmentRecord.findUnique.mockResolvedValue(mockRecord);
      mockPrisma.fulfillmentRecord.update.mockResolvedValue({
        ...mockRecord,
        stage: FulfillmentStage.CUSTOMER_CHECKED_IN,
      });

      const res = await fulfillmentService.recordCustomerArrival({
        bookingId: 'booking_1',
        deskNumber: 'Desk-2',
        notes: 'Customer arrived with luggage, priority handover',
        actorId: 'staff_1',
        actorRole: Role.ADMIN,
      });

      expect(res.success).toBe(true);
      expect(res.newStage).toBe(FulfillmentStage.CUSTOMER_CHECKED_IN);
    });

    it('should partition branch queues into pickup, preparation, arrival, and return queues', async () => {
      mockPrisma.booking.findMany.mockResolvedValue([
        {
          id: 'b_1',
          customerId: 'c_1',
          vendorId: 'v_1',
          pickupHubId: 'branch_1',
          startDate: new Date(),
          endDate: new Date(Date.now() + 86400000),
          status: BookingStatus.CONFIRMED,
          fulfillmentRecord: { stage: FulfillmentStage.PREPARATION_IN_PROGRESS },
          customer: { name: 'Alice' },
          car: { make: 'Maruti', model: 'Swift', type: CarCategory.HATCHBACK },
        },
        {
          id: 'b_2',
          customerId: 'c_2',
          vendorId: 'v_1',
          pickupHubId: 'branch_1',
          startDate: new Date(),
          endDate: new Date(Date.now() + 86400000),
          status: BookingStatus.HANDOVER_READY,
          fulfillmentRecord: { stage: FulfillmentStage.READY_FOR_PICKUP },
          customer: { name: 'Bob' },
          car: { make: 'Hyundai', model: 'Creta', type: CarCategory.SUV },
        },
      ]);

      const queue = await fulfillmentService.getBranchOperationalQueue('branch_1');

      expect(queue.totalActive).toBe(2);
      expect(queue.preparationQueueCount).toBe(1);
      expect(queue.readyForPickupCount).toBe(1);
    });
  });

  // =========================================================================
  // 2. VEHICLE SUBSTITUTION ENGINE
  // =========================================================================
  describe('Intelligent Vehicle Substitution Engine', () => {
    const originalBooking = {
      id: 'booking_sub_test',
      vendorId: 'vendor_1',
      pickupHubId: 'branch_1',
      carId: 'car_broken',
      vehicleClass: CarCategory.SEDAN,
      status: BookingStatus.CONFIRMED,
      startDate: new Date(),
      endDate: new Date(Date.now() + 86400000),
      car: {
        id: 'car_broken',
        make: 'Honda',
        model: 'City',
        type: CarCategory.SEDAN,
        pickupHubId: 'branch_1',
        pricePerDay: new Decimal(2000),
        year: 2022,
      },
    };

    it('should select AUTO_SUBSTITUTE when same-branch, same-class car is available', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(originalBooking);
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car_same_class',
          make: 'Hyundai',
          model: 'Verna',
          type: CarCategory.SEDAN,
          pickupHubId: 'branch_1',
          pricePerDay: new Decimal(2100),
          year: 2023,
          isAvailable: true,
          operationalStatus: 'ACTIVE',
        },
      ]);

      const evalRes = await substitutionService.evaluateSubstitution({
        bookingId: 'booking_sub_test',
        reason: SubstitutionReason.MECHANICAL_BREAKDOWN,
        actorId: 'admin_1',
        actorRole: Role.ADMIN,
      });

      expect(evalRes.recommendedDecision).toBe(SubstitutionDecision.AUTO_SUBSTITUTE);
      expect(evalRes.bestCandidate?.carId).toBe('car_same_class');
      expect(evalRes.requiresCustomerApproval).toBe(false);
    });

    it('should select UPGRADE_REQUIRED with free upgrade when only higher class is available', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(originalBooking);
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car_suv_upgrade',
          make: 'Toyota',
          model: 'Fortuner',
          type: CarCategory.SUV,
          pickupHubId: 'branch_1',
          pricePerDay: new Decimal(4500),
          year: 2024,
          isAvailable: true,
          operationalStatus: 'ACTIVE',
        },
      ]);

      const evalRes = await substitutionService.evaluateSubstitution({
        bookingId: 'booking_sub_test',
        reason: SubstitutionReason.ACCIDENT_DAMAGE,
        actorId: 'admin_1',
        actorRole: Role.ADMIN,
      });

      expect(evalRes.recommendedDecision).toBe(SubstitutionDecision.UPGRADE_REQUIRED);
      expect(evalRes.isFreeUpgrade).toBe(true);
      expect(evalRes.priceDifference).toBe(0); // Customer is not charged extra for vendor breakdown
    });

    it('should select NO_ALTERNATIVE and log incident when no fleet is available', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(originalBooking);
      mockPrisma.car.findMany.mockResolvedValue([]);

      const evalRes = await substitutionService.evaluateSubstitution({
        bookingId: 'booking_sub_test',
        reason: SubstitutionReason.MECHANICAL_BREAKDOWN,
        actorId: 'admin_1',
        actorRole: Role.ADMIN,
      });

      expect(evalRes.recommendedDecision).toBe(SubstitutionDecision.NO_ALTERNATIVE);
      expect(evalRes.bestCandidate).toBeNull();
    });

    it('should execute substitution and persist immutable audit record', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(originalBooking);
      mockPrisma.car.findMany.mockResolvedValue([
        {
          id: 'car_same_class',
          make: 'Hyundai',
          model: 'Verna',
          type: CarCategory.SEDAN,
          pickupHubId: 'branch_1',
          pricePerDay: new Decimal(2100),
          year: 2023,
          isAvailable: true,
          operationalStatus: 'ACTIVE',
        },
      ]);
      mockPrisma.car.findUnique.mockResolvedValue({
        id: 'car_same_class',
        make: 'Hyundai',
        model: 'Verna',
        type: CarCategory.SEDAN,
        registrationNumber: 'KA-05-XY-9999',
      });
      mockPrisma.vehicleSubstitutionRecord.create.mockResolvedValue({
        id: 'sub_rec_1',
        decision: SubstitutionDecision.AUTO_SUBSTITUTE,
      });

      const execRes = await substitutionService.executeSubstitution({
        bookingId: 'booking_sub_test',
        decision: SubstitutionDecision.AUTO_SUBSTITUTE,
        reason: SubstitutionReason.MECHANICAL_BREAKDOWN,
        actorId: 'admin_1',
        actorRole: Role.ADMIN,
      });

      expect(execRes.success).toBe(true);
      expect(execRes.substitutedCarId).toBe('car_same_class');
      expect(mockAllocationService.allocateVehicle).toHaveBeenCalled();
      expect(mockPrisma.vehicleSubstitutionRecord.create).toHaveBeenCalled();
    });
  });

  // =========================================================================
  // 3. DEMAND-AWARE DYNAMIC PRICING ENGINE
  // =========================================================================
  describe('Demand-Aware Dynamic Pricing & Policy Bounds', () => {
    it('should compute scarcity surge during peak utilization and clamp to maxSurgeMultiplier', async () => {
      mockPrisma.dynamicPricingPolicy.findFirst.mockResolvedValue({
        minDailyPrice: new Decimal(1500),
        maxDailyPrice: new Decimal(4000),
        maxSurgeMultiplier: new Decimal(1.50),
        minDiscountMultiplier: new Decimal(0.80),
        utilizationThresholdHigh: 0.80,
        utilizationThresholdLow: 0.30,
      });

      // 95% utilization mock
      mockPrisma.car.count.mockResolvedValue(20);
      mockPrisma.booking.count.mockResolvedValue(19);

      const res = await pricingService.evaluatePrice({
        vehicleClass: CarCategory.SUV,
        baseDailyRate: 2000,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 2 * 86400000),
      });

      expect(res.multiplier).toBeGreaterThan(1.0);
      expect(res.multiplier).toBeLessThanOrEqual(1.50);
      expect(res.effectiveDailyRate).toBeGreaterThan(2000);
      expect(res.effectiveDailyRate).toBeLessThanOrEqual(4000);
      expect(res.explanation).toContain('Base rate ₹2000/day adjusted');
    });

    it('should compute discount during low utilization without breaching minDailyPrice floor', async () => {
      mockPrisma.dynamicPricingPolicy.findFirst.mockResolvedValue({
        minDailyPrice: new Decimal(1400),
        maxDailyPrice: new Decimal(3500),
        maxSurgeMultiplier: new Decimal(1.50),
        minDiscountMultiplier: new Decimal(0.75),
        utilizationThresholdHigh: 0.85,
        utilizationThresholdLow: 0.40,
      });

      // 10% utilization mock
      mockPrisma.car.count.mockResolvedValue(30);
      mockPrisma.booking.count.mockResolvedValue(3);

      const res = await pricingService.evaluatePrice({
        vehicleClass: CarCategory.HATCHBACK,
        baseDailyRate: 1600,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 2 * 86400000),
      });

      expect(res.multiplier).toBeLessThan(1.0);
      expect(res.multiplier).toBeGreaterThanOrEqual(0.75);
      expect(res.effectiveDailyRate).toBeGreaterThanOrEqual(1400);
    });
  });

  // =========================================================================
  // 4. COMPETITIVE PRICE INTELLIGENCE LAYER
  // =========================================================================
  describe('Competitive Price Intelligence', () => {
    it('should aggregate competitor signals and compute normalized market index', async () => {
      mockPrisma.competitorPriceObservation.findMany.mockResolvedValue([
        { observedDailyPrice: new Decimal(1800), confidenceScore: 0.95, observedAt: new Date() },
        { observedDailyPrice: new Decimal(2000), confidenceScore: 0.90, observedAt: new Date() },
        { observedDailyPrice: new Decimal(2200), confidenceScore: 0.85, observedAt: new Date() },
      ]);

      const index = await competitorPricingService.getMarketPriceIndex('BANGALORE', CarCategory.SEDAN);

      expect(index).not.toBeNull();
      expect(index!.medianPrice).toBe(2000);
      expect(index!.minPrice).toBe(1800);
      expect(index!.maxPrice).toBe(2200);
      expect(index!.sampleCount).toBe(3);
    });
  });

  // =========================================================================
  // 5. INVENTORY REBALANCING & SUPPLY INTELLIGENCE
  // =========================================================================
  describe('Marketplace Supply & Branch Rebalancing', () => {
    it('should generate inter-branch transfer recommendations when deficit and surplus are detected', async () => {
      mockPrisma.pickupHub.findMany.mockResolvedValue([
        { id: 'branch_airport', name: 'Airport Hub', city: 'BANGALORE' },
        { id: 'branch_downtown', name: 'Downtown Hub', city: 'BANGALORE' },
      ]);

      // Mock supply service metrics for the two branches
      jest.spyOn(supplyService, 'getBranchSupplyMetrics').mockImplementation(async (branchId: string) => {
        if (branchId === 'branch_airport') {
          return {
            branchId,
            branchName: 'Airport Hub',
            city: 'BANGALORE',
            totalFleet: 10,
            availableFleet: 1,
            onRentFleet: 9,
            maintenanceFleet: 0,
            cleaningFleet: 0,
            utilizationRate: 0.90,
            classBreakdown: {
              [CarCategory.SUV]: { total: 4, available: 0, onRent: 4, demandScore: 3, status: 'DEFICIT' },
            } as any,
          };
        } else {
          return {
            branchId,
            branchName: 'Downtown Hub',
            city: 'BANGALORE',
            totalFleet: 15,
            availableFleet: 10,
            onRentFleet: 5,
            maintenanceFleet: 0,
            cleaningFleet: 0,
            utilizationRate: 0.33,
            classBreakdown: {
              [CarCategory.SUV]: { total: 6, available: 5, onRent: 1, demandScore: 1, status: 'SURPLUS' },
            } as any,
          };
        }
      });

      mockPrisma.inventoryTransferRecommendation.create.mockResolvedValue({
        id: 'rec_1',
        sourceBranchId: 'branch_downtown',
        destinationBranchId: 'branch_airport',
        vehicleClass: CarCategory.SUV,
        recommendedUnits: 3,
        status: InventoryTransferStatus.PROPOSED,
      });

      const recs = await rebalancingService.generateRebalancingRecommendations('BANGALORE');

      expect(recs.length).toBeGreaterThan(0);
      expect(mockPrisma.inventoryTransferRecommendation.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            sourceBranchId: 'branch_downtown',
            destinationBranchId: 'branch_airport',
            vehicleClass: CarCategory.SUV,
            recommendedUnits: 3,
          }),
        }),
      );
    });
  });

  // =========================================================================
  // 6. SLA & ESCALATION ENGINE
  // =========================================================================
  describe('SLA & Escalation Engine', () => {
    it('should detect unallocated and overdue rentals and record SlaBreachIncidents', async () => {
      mockPrisma.booking.findMany.mockImplementation((query: any) => {
        if (query.where?.status === BookingStatus.CONFIRMED) {
          // Unallocated bookings
          return [
            { id: 'b_overdue_alloc', vendorId: 'v_1', pickupHubId: 'b_1', updatedAt: new Date(Date.now() - 3600000) },
          ];
        } else if (query.where?.status === BookingStatus.ONGOING) {
          // Overdue returns
          return [
            { id: 'b_overdue_return', vendorId: 'v_1', pickupHubId: 'b_1', updatedAt: new Date(Date.now() - 3600000) },
          ];
        }
        return [];
      });

      mockPrisma.fulfillmentRecord.findMany.mockResolvedValue([]);
      mockPrisma.slaPolicyDefinition.findFirst.mockResolvedValue({
        id: 'policy_1',
        targetProcess: 'ALLOCATION',
        thresholdMinutes: 15,
        severity: SlaSeverity.WARNING,
      });
      mockPrisma.slaBreachIncident.findFirst.mockResolvedValue(null);
      mockPrisma.slaBreachIncident.create.mockResolvedValue({ id: 'inc_1' });

      const res = await slaEngine.evaluateAllSlas();

      expect(res.breachesDetected).toBeGreaterThan(0);
      expect(res.incidentsCreated).toBeGreaterThan(0);
      expect(mockPrisma.slaBreachIncident.create).toHaveBeenCalled();
    });
  });

  // =========================================================================
  // 7. MARKETPLACE COMMISSION ENGINE & FINANCIAL BREAKDOWN
  // =========================================================================
  describe('Marketplace Commission Engine', () => {
    it('should compute exact multilateral fee breakdown with balanced splits', async () => {
      mockPrisma.marketplaceCommissionRule.findFirst.mockResolvedValue({
        platformPct: new Decimal(15.00),
        vendorPct: new Decimal(80.00),
        branchPct: new Decimal(5.00),
        fixedPlatformFee: new Decimal(0),
        gatewayFeeRecovery: new Decimal(2.00),
        taxGstPct: new Decimal(18.00),
        scope: 'PLATFORM',
      });

      const breakdown = await commissionService.calculateCommission({
        vendorId: 'vendor_1',
        branchId: 'branch_1',
        vehicleClass: CarCategory.SEDAN,
        grossAmount: 10000,
        discountAmount: 1000,
        channel: SalesChannel.CUSTOMER_APP,
      });

      // Taxable = 9000
      expect(breakdown.taxableAmount).toBe(9000);
      // GST 18% = 1620
      expect(breakdown.gstAmount).toBe(1620);
      // Total customer payable = 10620
      expect(breakdown.totalCustomerPayable).toBe(10620);
      // Platform 15% of 9000 = 1350
      expect(breakdown.platformFee).toBe(1350);
      // Branch 5% of 9000 = 450
      expect(breakdown.branchShare).toBe(450);
      // Vendor 80% of 9000 = 7200
      expect(breakdown.vendorNetPayable).toBe(7200);
      // Gateway fee recovery = 2% of 10620 = 212.40
      expect(breakdown.gatewayFeeRecovery).toBe(212.4);
      // Invariant: sum of splits must balance taxable amount
      expect(breakdown.isBalanced).toBe(true);
    });
  });
});
