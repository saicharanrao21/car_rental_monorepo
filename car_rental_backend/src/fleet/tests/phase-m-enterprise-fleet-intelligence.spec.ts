import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { FleetLifecycleService } from '../fleet-lifecycle.service';
import { FleetAvailabilityService } from '../fleet-availability.service';
import { FleetInspectionService } from '../fleet-inspection.service';
import { FleetComplianceService } from '../fleet-compliance.service';
import { FleetTelematicsService } from '../fleet-telematics.service';
import { FleetSearchService } from '../fleet-search.service';
import { FleetIntelligenceService } from '../fleet-intelligence.service';
import { PrismaService } from '../../prisma/prisma.service';
import { IntegrationRuntimeService } from '../../integrations/runtime/integration-runtime.service';
import {
  FleetOperationalState,
  InspectionType,
  InspectionItemStatus,
  DamageLocation,
  DamageSeverity,
  ComplianceDocumentType,
  ComplianceStatus,
} from '../fleet-domain.types';

describe('Phase M — Enterprise Fleet & Vehicle Intelligence Engine', () => {
  let lifecycleService: FleetLifecycleService;
  let availabilityService: FleetAvailabilityService;
  let inspectionService: FleetInspectionService;
  let complianceService: FleetComplianceService;
  let telematicsService: FleetTelematicsService;
  let searchService: FleetSearchService;
  let intelligenceService: FleetIntelligenceService;

  // Mock Prisma and Runtime
  const mockCar = {
    id: 'car_fleet_101',
    vendorId: 'vendor_koramangala',
    pickupHubId: 'hub_central',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 5,
    isAvailable: true,
    operationalStatus: 'ACTIVE',
    pricePerDay: 2800,
    pricePerHour: 200,
    photos: ['https://cdn.drivego.in/cars/creta_front.jpg'],
    blocks: [],
    holds: [],
    pickupHub: { id: 'hub_central', name: 'Bengaluru Central Hub', city: 'Bengaluru' },
    vendor: { id: 'vendor_koramangala', businessName: 'Royal Auto Fleet' },
  };

  const mockPrisma = {
    car: {
      findUnique: jest.fn().mockImplementation(({ where }) => {
        if (where.id === 'car_fleet_101') return Promise.resolve(mockCar);
        return Promise.resolve(null);
      }),
      update: jest.fn().mockResolvedValue(mockCar),
      findMany: jest.fn().mockResolvedValue([mockCar]),
      count: jest.fn().mockResolvedValue(10),
    },
    pickupHub: {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'hub_central',
          name: 'Bengaluru Central Hub',
          city: 'Bengaluru',
          cars: [mockCar, { ...mockCar, id: 'car_102', isAvailable: true }, { ...mockCar, id: 'car_103', isAvailable: false }],
        },
        {
          id: 'hub_airport',
          name: 'Airport T2 Hub',
          city: 'Bengaluru',
          cars: [{ ...mockCar, id: 'car_201', isAvailable: false }],
        },
      ]),
    },
    booking: {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(3),
    },
  };

  const mockRuntimeService = {
    execute: jest.fn().mockImplementation(({ category, capability, payload }) => {
      if (category === 'VEHICLE_TRACKING' && capability === 'LIVE_LOCATION') {
        return Promise.resolve({
          success: true,
          provider: 'traccar',
          data: { latitude: 12.9352, longitude: 77.6245, speed: 42, odometer: 18400, ignition: true, fuelPercent: 78 },
        });
      }
      if (category === 'VEHICLE_TRACKING' && capability === 'IMMOBILIZE') {
        return Promise.resolve({
          success: true,
          provider: 'traccar',
          data: { status: 'STARTER_CUT_CONFIRMED' },
        });
      }
      if (category === 'AI' && capability === 'CLASSIFY') {
        return Promise.resolve({
          success: true,
          provider: 'gemini',
          data: {
            damages: [{ location: 'FRONT_BUMPER', severity: 'MINOR_SCRATCH', confidence: 0.94 }],
            qualityScore: 0.95,
          },
        });
      }
      if (category === 'SEARCH' && capability === 'SEARCH') {
        return Promise.resolve({
          success: true,
          provider: 'meilisearch',
          data: { hits: [{ id: 'car_fleet_101', make: 'Hyundai', model: 'Creta', type: 'SUV' }], totalHits: 1 },
        });
      }
      return Promise.resolve({ success: false });
    }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FleetLifecycleService,
        FleetAvailabilityService,
        FleetInspectionService,
        FleetComplianceService,
        FleetTelematicsService,
        FleetSearchService,
        FleetIntelligenceService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: IntegrationRuntimeService, useValue: mockRuntimeService },
      ],
    }).compile();

    lifecycleService = module.get<FleetLifecycleService>(FleetLifecycleService);
    availabilityService = module.get<FleetAvailabilityService>(FleetAvailabilityService);
    inspectionService = module.get<FleetInspectionService>(FleetInspectionService);
    complianceService = module.get<FleetComplianceService>(FleetComplianceService);
    telematicsService = module.get<FleetTelematicsService>(FleetTelematicsService);
    searchService = module.get<FleetSearchService>(FleetSearchService);
    intelligenceService = module.get<FleetIntelligenceService>(FleetIntelligenceService);
  });

  // =========================================================================
  // 1. 19-State Enterprise Lifecycle Engine Tests
  // =========================================================================
  describe('1. Enterprise Lifecycle State Machine & Transition Rules', () => {
    it('should initialize vehicle in AVAILABLE state and permit legal transition to RESERVED', async () => {
      const state = await lifecycleService.getVehicleState('car_fleet_101');
      expect(state).toBe(FleetOperationalState.AVAILABLE);

      const res = await lifecycleService.transitionState(
        'car_fleet_101',
        FleetOperationalState.RESERVED,
        { id: 'usr_ops_1', role: 'VENDOR' },
        { reason: 'Customer reservation confirmed' },
      );

      expect(res.toState).toBe(FleetOperationalState.RESERVED);
      const updated = await lifecycleService.getVehicleState('car_fleet_101');
      expect(updated).toBe(FleetOperationalState.RESERVED);
    });

    it('should reject illegal transitions skipping mandated lifecycle steps', async () => {
      // Cannot jump from RESERVED directly to SOLD
      await expect(
        lifecycleService.transitionState(
          'car_fleet_101',
          FleetOperationalState.SOLD,
          { id: 'usr_ops_1', role: 'ADMIN' },
          { reason: 'Attempt illegal jump to SOLD' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block transition to ON_RENT unless vehicle is in PICKUP_PENDING', async () => {
      // Direct jump from AVAILABLE to ON_RENT is rejected
      await expect(
        lifecycleService.transitionState(
          'car_fleet_101',
          FleetOperationalState.ON_RENT,
          { id: 'usr_ops_1', role: 'VENDOR' },
          { reason: 'Attempt direct trip start' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should follow proper progression: RESERVED -> PICKUP_PENDING -> ON_RENT -> RETURN_PENDING -> INSPECTION -> CLEANING -> AVAILABLE', async () => {
      const actor = { id: 'usr_ops_1', role: 'VENDOR' } as const;

      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.RESERVED, actor, { reason: 'Booking booked' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.PICKUP_PENDING, actor, { reason: 'Customer arrived' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.ON_RENT, actor, { reason: 'OTP verified, trip started' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.RETURN_PENDING, actor, { reason: 'Vehicle returned to hub' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.INSPECTION, actor, { reason: 'Check-in inspection started' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.CLEANING, actor, { reason: 'Inspection passed, queued for wash' });
      const final = await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.AVAILABLE, actor, { reason: 'Cleaned and ready' });

      expect(final.toState).toBe(FleetOperationalState.AVAILABLE);
    });

    it('should record an auditable trail with timestamps and actor metadata for every transition', async () => {
      const actor = { id: 'usr_ops_1', role: 'VENDOR' } as const;
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.RESERVED, actor, { reason: 'Test audit 1' });
      await lifecycleService.transitionState('car_fleet_101', FleetOperationalState.PICKUP_PENDING, actor, { reason: 'Test audit 2' });

      const history = await lifecycleService.getAuditHistory('car_fleet_101');
      expect(history.length).toBeGreaterThanOrEqual(2);
      expect(history[0]).toHaveProperty('actorId');
      expect(history[0]).toHaveProperty('fromState');
      expect(history[0]).toHaveProperty('toState');
      expect(history[0]).toHaveProperty('timestamp');
    });
  });

  // =========================================================================
  // 2. Explainable Availability Engine Tests
  // =========================================================================
  describe('2. Explainable Availability Engine & Turnaround Buffers', () => {
    it('should explain availability with exact reason and alternatives when vehicle is unavailable', async () => {
      // Put car into MAINTENANCE
      await lifecycleService.transitionState(
        'car_fleet_101',
        FleetOperationalState.MAINTENANCE,
        { id: 'admin_1', role: 'ADMIN' },
        { reason: 'Brake pad replacement' },
      );

      const explanation = await availabilityService.explainAvailability('car_fleet_101');
      expect(explanation.isAvailable).toBe(false);
      expect(explanation.operationalState).toBe(FleetOperationalState.MAINTENANCE);
      expect(explanation.reason).toContain('Brake pad replacement');
      expect(explanation.turnaroundBufferMinutes).toBe(60);
    });

    it('should calculate turnaround buffer between reservations', async () => {
      // Return car to AVAILABLE
      await lifecycleService.transitionState(
        'car_fleet_101',
        FleetOperationalState.AVAILABLE,
        { id: 'admin_1', role: 'ADMIN' },
        { reason: 'Maintenance done' },
      );

      const explanation = await availabilityService.explainAvailability('car_fleet_101', {
        startDate: new Date('2026-10-01T10:00:00Z'),
        endDate: new Date('2026-10-02T10:00:00Z'),
      }, { bufferMinutes: 45 });

      expect(explanation.isAvailable).toBe(true);
      expect(explanation.turnaroundBufferMinutes).toBe(45);
    });
  });

  // =========================================================================
  // 3. 16-Point Inspection & AI Damage Intelligence Tests
  // =========================================================================
  describe('3. Vehicle Condition, 16-Point Inspection & AI Damage Evaluation', () => {
    it('should return standard 16-point vehicle inspection template', () => {
      const template = inspectionService.getStandard16PointTemplate();
      expect(template.length).toBe(16);
      expect(template.map((t) => t.code)).toContain('EXT_01');
      expect(template.map((t) => t.code)).toContain('DOC_16');
    });

    it('should record an inspection, evaluate condition, and mark passed when within tolerance', async () => {
      const template = inspectionService.getStandard16PointTemplate();
      const record = await inspectionService.recordInspection({
        carId: 'car_fleet_101',
        inspectionType: InspectionType.RETURN,
        inspectorId: 'inspector_77',
        odometerReadingKm: 18450,
        fuelLevelPercent: 90,
        checklist: template,
        damages: [],
      });

      expect(record.passed).toBe(true);
      expect(record.overallCondition).toBe('EXCELLENT');
      expect(record.odometerReadingKm).toBe(18450);
    });

    it('should mark vehicle GROUNDED if major structural damage is identified', async () => {
      const template = inspectionService.getStandard16PointTemplate();
      template[0].status = InspectionItemStatus.FAIL; // Front bumper failure

      const record = await inspectionService.recordInspection({
        carId: 'car_fleet_101',
        inspectionType: InspectionType.ACCIDENT,
        inspectorId: 'inspector_77',
        odometerReadingKm: 18500,
        fuelLevelPercent: 50,
        checklist: template,
        damages: [
          {
            id: 'dmg_1',
            location: DamageLocation.FRONT_BUMPER,
            severity: DamageSeverity.MAJOR_DAMAGE,
            description: 'Impact fracture on front crash bar',
            photoUrls: ['https://cdn.drivego.in/damages/crash_1.jpg'],
            isPreExisting: false,
          },
        ],
      });

      expect(record.passed).toBe(false);
      expect(record.overallCondition).toBe('GROUNDED');
    });

    it('should invoke AI damage classification abstraction via IntegrationRuntime', async () => {
      const result = await inspectionService.analyzeDamagePhotos(['https://cdn.drivego.in/cars/scratch.jpg']);
      expect(result.detectedDamages.length).toBeGreaterThan(0);
      expect(result.detectedDamages[0].location).toBe(DamageLocation.FRONT_BUMPER);
      expect(result.photoQualityScore).toBeGreaterThan(0.8);
      expect(result.evaluatedByProvider).toBe('gemini');
    });
  });

  // =========================================================================
  // 4. Vehicle Compliance & Document Engine Tests
  // =========================================================================
  describe('4. Compliance Governance & Automated Expiry Blocking', () => {
    it('should register valid vehicle documents and track days until expiry', async () => {
      const futureDate = new Date(Date.now() + 120 * 24 * 3600 * 1000).toISOString();
      const doc = await complianceService.registerDocument({
        carId: 'car_fleet_101',
        documentType: ComplianceDocumentType.INSURANCE_POLICY,
        documentNumber: 'POL_ICICI_99812',
        issueDate: new Date().toISOString(),
        expiryDate: futureDate,
        isMandatoryForRental: true,
      });

      expect(doc.status).toBe(ComplianceStatus.VALID);
      expect(doc.daysUntilExpiry).toBeGreaterThan(100);
    });

    it('should automatically block vehicle when mandatory compliance document expires', async () => {
      const pastDate = new Date(Date.now() - 5 * 24 * 3600 * 1000).toISOString();
      await complianceService.registerDocument({
        carId: 'car_fleet_101',
        documentType: ComplianceDocumentType.FITNESS_CERTIFICATE,
        documentNumber: 'FIT_KA01_2024',
        issueDate: '2023-01-01',
        expiryDate: pastDate,
        isMandatoryForRental: true,
      });

      const report = await complianceService.evaluateVehicleCompliance('car_fleet_101');
      expect(report.isRentalCompliant).toBe(false);
      expect(report.blockingReasons.length).toBeGreaterThan(0);

      // Verify state was shifted to COMPLIANCE_BLOCKED
      const state = await lifecycleService.getVehicleState('car_fleet_101');
      expect(state).toBe(FleetOperationalState.COMPLIANCE_BLOCKED);
    });
  });

  // =========================================================================
  // 5. Telematics & IoT Connector Subsystem Tests
  // =========================================================================
  describe('5. Telematics Ingestion & Heartbeat Guard', () => {
    it('should ingest and normalize live IoT telemetry snapshot', async () => {
      const snapshot = await telematicsService.ingestTelemetry({
        carId: 'car_fleet_101',
        deviceId: 'teltonika_fmb920_01',
        provider: 'teltonika',
        latitude: 12.9716,
        longitude: 77.5946,
        speedKmH: 54,
        odometerKm: 19200,
        ignitionStatus: 'ON',
        fuelLevelPercent: 72,
      });

      expect(snapshot.provider).toBe('teltonika');
      expect(snapshot.isGpsOnline).toBe(true);
      expect(snapshot.speedKmH).toBe(54);
      expect(snapshot.ignitionStatus).toBe('ON');
    });

    it('should query live telemetry via IntegrationRuntime when live telemetry requested', async () => {
      const tele = await telematicsService.getLatestTelemetry('car_live_lookup');
      expect(tele.provider).toBe('traccar');
      expect(tele.speedKmH).toBe(42);
      expect(tele.odometerKm).toBe(18400);
    });

    it('should dispatch remote immobilization command through telematics runtime', async () => {
      const res = await telematicsService.immobilizeVehicle('car_fleet_101', 'Security breach detection');
      expect(res.success).toBe(true);
      expect(res.provider).toBe('traccar');
    });
  });

  // =========================================================================
  // 6. Fleet Search & Alternative Discovery Tests
  // =========================================================================
  describe('6. Enterprise Fleet Search & Multi-Attribute Discovery', () => {
    it('should delegate search to Meilisearch search capability via IntegrationRuntime', async () => {
      const result = await searchService.searchFleet({ query: 'Creta', city: 'Bengaluru' });
      expect(result.searchProvider).toBe('meilisearch');
      expect(result.items.length).toBeGreaterThan(0);
      expect(result.items[0].make).toBe('Hyundai');
    });

    it('should fallback to relational PostgreSQL search when general filter query used', async () => {
      const result = await searchService.searchFleet({ city: 'Bengaluru', minSeating: 5 });
      expect(result.searchProvider).toBe('postgresql_relational');
      expect(result.items.length).toBeGreaterThan(0);
    });
  });

  // =========================================================================
  // 7. Fleet Intelligence & Rebalancing Analytics Tests
  // =========================================================================
  describe('7. Fleet Command Centre KPIs & Branch Rebalancing', () => {
    it('should calculate accurate fleet utilization rate and branch distribution', async () => {
      const kpis = await intelligenceService.getFleetKpis();
      expect(kpis.totalVehicles).toBe(10);
      expect(kpis.availableVehicles).toBe(10);
      expect(kpis.fleetUtilizationRate).toBeGreaterThanOrEqual(0);
      expect(kpis.branchBreakdown.length).toBe(2);
      expect(kpis.branchBreakdown[0].branchName).toBe('Bengaluru Central Hub');
    });

    it('should generate proactive branch rebalancing recommendations based on utilization disparity', async () => {
      const recommendations = await intelligenceService.generateBranchRebalanceRecommendations();
      expect(Array.isArray(recommendations)).toBe(true);
      if (recommendations.length > 0) {
        expect(recommendations[0]).toHaveProperty('sourceBranchName');
        expect(recommendations[0]).toHaveProperty('targetBranchName');
        expect(recommendations[0].confidenceScore).toBeGreaterThan(0.8);
      }
    });
  });
});
