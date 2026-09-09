import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderRateLimiterService } from '../runtime/provider-rate-limiter.service';
import { FailureClassifierService } from '../runtime/failure-classifier.service';
import { IntegrationIdempotencyService } from '../runtime/integration-idempotency.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { CostModelService } from '../runtime/cost-model.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { IntegrationAuditService } from '../runtime/integration-audit.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { GeospatialService } from '../../geospatial/geospatial.service';
import { ProviderPackRegistryService } from '../packs/provider-pack-registry.service';
import { ConnectorLifecycleState, MultiTenantOwnershipScope } from '../packs/provider-pack.types';
import { MASTER_PROVIDER_ECOSYSTEM } from '../catalog/master-provider-ecosystem.data';
import { MapboxMapsAdapter } from '../adapters/maps/mapbox-maps.adapter';
import { TraccarTelematicsAdapter } from '../adapters/tracking/traccar-telematics.adapter';
import { HyperVergeKycAdapter } from '../adapters/verification/hyperverge-kyc.adapter';
import { ZohoBooksAdapter } from '../adapters/accounting/zoho-books.adapter';
import { GoogleGeminiAdapter } from '../adapters/ai/google-gemini.adapter';
import { MeilisearchAdapter } from '../adapters/search/meilisearch.adapter';
import { PostHogAnalyticsAdapter } from '../adapters/analytics/posthog-analytics.adapter';

describe('Phase L — Enterprise Connector Expansion & Capability Packs', () => {
  let packRegistry: ProviderPackRegistryService;
  let catalogService: ProviderCatalogService;
  let registryService: ProviderRegistryService;
  let runtimeService: IntegrationRuntimeService;
  let geospatialService: GeospatialService;

  let mapboxAdapter: MapboxMapsAdapter;
  let traccarAdapter: TraccarTelematicsAdapter;
  let hypervergeAdapter: HyperVergeKycAdapter;
  let zohoAdapter: ZohoBooksAdapter;
  let geminiAdapter: GoogleGeminiAdapter;
  let meilisearchAdapter: MeilisearchAdapter;
  let posthogAdapter: PostHogAnalyticsAdapter;

  const mockPrisma: any = {
    integrationConfig: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
      upsert: jest.fn().mockResolvedValue({}),
    },
    webhookEvent: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      count: jest.fn().mockResolvedValue(0),
      findMany: jest.fn().mockResolvedValue([]),
    },
    providerIncident: {
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    integrationExecution: {
      create: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
    },
    branch: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderPackRegistryService,
        ProviderCatalogService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        IntegrationRuntimeService,
        CircuitBreakerService,
        ProviderRateLimiterService,
        FailureClassifierService,
        IntegrationIdempotencyService,
        ProviderPolicyService,
        CostModelService,
        ProviderSimulationService,
        IntegrationAuditService,
        SecretVaultService,
        ProviderRoutingService,
        MapboxMapsAdapter,
        TraccarTelematicsAdapter,
        HyperVergeKycAdapter,
        ZohoBooksAdapter,
        GoogleGeminiAdapter,
        MeilisearchAdapter,
        PostHogAnalyticsAdapter,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('test-secret') } },
        {
          provide: SystemConfigService,
          useValue: {
            getString: jest.fn().mockResolvedValue('test'),
            getNumber: jest.fn().mockResolvedValue(100),
            getBoolean: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    packRegistry = module.get<ProviderPackRegistryService>(ProviderPackRegistryService);
    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    registryService = module.get<ProviderRegistryService>(ProviderRegistryService);
    runtimeService = module.get<IntegrationRuntimeService>(IntegrationRuntimeService);
    geospatialService = new GeospatialService(runtimeService);

    mapboxAdapter = module.get<MapboxMapsAdapter>(MapboxMapsAdapter);
    traccarAdapter = module.get<TraccarTelematicsAdapter>(TraccarTelematicsAdapter);
    hypervergeAdapter = module.get<HyperVergeKycAdapter>(HyperVergeKycAdapter);
    zohoAdapter = module.get<ZohoBooksAdapter>(ZohoBooksAdapter);
    geminiAdapter = module.get<GoogleGeminiAdapter>(GoogleGeminiAdapter);
    meilisearchAdapter = module.get<MeilisearchAdapter>(MeilisearchAdapter);
    posthogAdapter = module.get<PostHogAnalyticsAdapter>(PostHogAnalyticsAdapter);

    // Register real adapters with provider registry
    registryService.registerProvider(mapboxAdapter);
    registryService.registerProvider(traccarAdapter);
    registryService.registerProvider(hypervergeAdapter);
    registryService.registerProvider(zohoAdapter);
    registryService.registerProvider(geminiAdapter);
    registryService.registerProvider(meilisearchAdapter);
    registryService.registerProvider(posthogAdapter);
  });

  describe('Part 1: 35-Category Master Provider Ecosystem Audit', () => {
    it('should include all required 35 categories in the ecosystem matrix', () => {
      const categories = Object.keys(MASTER_PROVIDER_ECOSYSTEM);
      expect(categories.length).toBeGreaterThanOrEqual(35);

      const mandatoryCategories = [
        'payments', 'whatsapp', 'sms', 'email', 'push_notifications',
        'cloud_storage', 'maps', 'geocoding', 'routing', 'distance_matrix',
        'places_search', 'identity_kyc', 'vehicle_gps_telematics', 'accounting',
        'tax_gst', 'search', 'analytics', 'ai_llm', 'ocr', 'document_verification',
        'e_signature', 'cloud_messaging', 'customer_support', 'voice_calling',
        'translation', 'image_processing', 'fraud_risk_detection', 'address_validation',
        'currency_fx', 'business_verification', 'email_delivery', 'sms_otp',
        'whatsapp_otp', 'maps_navigation', 'vehicle_data_telemetry',
      ];

      for (const cat of mandatoryCategories) {
        expect(categories).toContain(cat);
        expect(MASTER_PROVIDER_ECOSYSTEM[cat].length).toBeGreaterThan(0);
      }
    });

    it('should classify every provider honestly with status REAL_ADAPTER, SIMULATION_MOCK, or CATALOG_ONLY', () => {
      let totalProviders = 0;
      let realCount = 0;
      let simCount = 0;
      let catalogCount = 0;

      for (const [category, providers] of Object.entries(MASTER_PROVIDER_ECOSYSTEM)) {
        for (const p of providers) {
          totalProviders++;
          expect(['REAL_ADAPTER', 'SIMULATION_MOCK', 'CATALOG_ONLY']).toContain(p.status);
          expect(p.providerId).toBeDefined();
          expect(p.displayName).toBeDefined();
          expect(p.supportedCountries).toBeInstanceOf(Array);
          expect(p.credentialRequirements).toBeInstanceOf(Array);

          if (p.status === 'REAL_ADAPTER') realCount++;
          else if (p.status === 'SIMULATION_MOCK') simCount++;
          else if (p.status === 'CATALOG_ONLY') catalogCount++;
        }
      }

      expect(totalProviders).toBeGreaterThanOrEqual(100);
      expect(realCount).toBeGreaterThanOrEqual(10);
      expect(catalogCount).toBeGreaterThanOrEqual(30);
    });

    it('should represent 40+ payment providers across India and Global regions', () => {
      const payments = MASTER_PROVIDER_ECOSYSTEM['payments'];
      expect(payments.length).toBeGreaterThanOrEqual(40);

      const indianGateways = ['razorpay', 'cashfree', 'payu', 'phonepe', 'paytm', 'instamojo', 'billdesk', 'ccavenue', 'easebuzz', 'juspay', 'openmoney'];
      const globalGateways = ['stripe', 'paypal', 'adyen', 'checkout_com', 'square', 'mollie', 'authorizenet', 'paddle', 'mercadopago', 'paystack', 'flutterwave', 'xendit', 'midtrans', 'paymongo', 'tap', 'paytabs'];

      for (const gw of indianGateways) {
        expect(payments.some(p => p.providerId === gw)).toBe(true);
      }
      for (const gw of globalGateways) {
        expect(payments.some(p => p.providerId === gw)).toBe(true);
      }
    });
  });

  describe('Part 2: Provider Pack Model & Built-in Packs', () => {
    it('should register built-in provider packs upon initialization', () => {
      const packs = packRegistry.getAllPacks();
      expect(packs.length).toBeGreaterThanOrEqual(10);

      const expectedIds = ['mapbox', 'traccar', 'hyperverge', 'zoho_books', 'gemini', 'meilisearch', 'posthog'];
      for (const id of expectedIds) {
        const found = packs.find(p => p.id === id);
        expect(found).toBeDefined();
        expect(found?.capabilities.length).toBeGreaterThan(0);
        expect(found?.credentialSchema.length).toBeGreaterThan(0);
      }
    });

    it('should retrieve a specific pack by category and providerId', () => {
      const mapboxPack = packRegistry.getPack(IntegrationCategory.MAPS, 'mapbox');
      expect(mapboxPack).toBeDefined();
      expect(mapboxPack?.displayName).toContain('Mapbox');
      const lifecycle = packRegistry.getLifecycleState(IntegrationCategory.MAPS, 'mapbox');
      expect(lifecycle).toBe(ConnectorLifecycleState.ACTIVE);
    });

    it('should filter packs by capability dynamically', () => {
      const geocodePacks = packRegistry.findPacksByCapability(IntegrationCategory.MAPS, 'GEOCODE');
      expect(geocodePacks.length).toBeGreaterThanOrEqual(1);
      expect(geocodePacks.some(p => p.id === 'mapbox')).toBe(true);

      const aiPacks = packRegistry.findPacksByCapability(IntegrationCategory.AI, 'CHAT');
      expect(aiPacks.some(p => p.id === 'gemini')).toBe(true);
    });
  });

  describe('Part 3: 10-State Connector Lifecycle & Transition Rules', () => {
    it('should follow proper 10-state progression from DISCOVERED to RETIRED', () => {
      packRegistry.registerPack({
        id: 'test_telematics',
        name: 'test_telematics',
        displayName: 'Test Telematics Gateway',
        category: IntegrationCategory.VEHICLE_TRACKING,
        version: { apiVersion: 'v1', adapterVersion: '1.0.0', credentialSchemaVersion: '1.0', releasedAt: '2026-01-01' },
        supportedEnvironments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
        supportedRegions: ['IN'],
        supportedCurrencies: ['INR'],
        capabilities: [
          { capability: 'LIVE_POSITION', category: IntegrationCategory.VEHICLE_TRACKING, version: '1.0', supportedEnvironments: [ProviderEnvironment.SANDBOX], description: 'Live', idempotent: true },
        ],
        credentialSchema: [{ key: 'apiKey', label: 'API Key', type: 'password', required: true, isSecret: true, description: 'Key' }],
        rateLimits: { rps: 10, rpm: 60, burstCapacity: 20, concurrencyLimit: 10 },
        costModel: { providerId: 'test_telematics', category: IntegrationCategory.VEHICLE_TRACKING, fixedFee: 0, percentageFee: 0, perRequestCost: 0.001, perMessageCost: 0, currency: 'USD', regionSpecificCosts: {} },
        webhookConfig: { supported: false, secretRequired: false, supportsReplayProtection: false },
        healthCheckConfig: { intervalSeconds: 60, timeoutMs: 3000, degradedThresholdFailures: 3 },
        retryPolicy: { maxRetries: 3, backoffFactor: 2, initialIntervalMs: 500, retryableErrorCodes: [] },
        fallbackEligibility: { eligibleAsPrimary: true, eligibleAsSecondaryFallback: true },
        implementationStatus: 'REAL_ADAPTER',
        tags: ['test'],
      });

      // Force to DISCOVERED for step-by-step test
      (packRegistry as any).lifecycleStates.set('vehicle_tracking:test_telematics', ConnectorLifecycleState.DISCOVERED);

      // 1. DISCOVERED -> CONFIGURED
      let trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.CONFIGURED, 'Configured API credentials');
      expect(trans.toState).toBe(ConnectorLifecycleState.CONFIGURED);

      // 2. CONFIGURED -> CREDENTIALS_VALIDATED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.CREDENTIALS_VALIDATED, 'Validated auth handshake');
      expect(trans.toState).toBe(ConnectorLifecycleState.CREDENTIALS_VALIDATED);

      // 3. CREDENTIALS_VALIDATED -> SANDBOX_TESTED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.SANDBOX_TESTED, 'Completed smoke test');
      expect(trans.toState).toBe(ConnectorLifecycleState.SANDBOX_TESTED);

      // 4. SANDBOX_TESTED -> WEBHOOK_VERIFIED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.WEBHOOK_VERIFIED, 'Signature verified');
      expect(trans.toState).toBe(ConnectorLifecycleState.WEBHOOK_VERIFIED);

      // 5. WEBHOOK_VERIFIED -> APPROVED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.APPROVED, 'SecOps approved');
      expect(trans.toState).toBe(ConnectorLifecycleState.APPROVED);

      // 6. APPROVED -> ACTIVE
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.ACTIVE, 'Activated for production');
      expect(trans.toState).toBe(ConnectorLifecycleState.ACTIVE);

      // 7. ACTIVE -> DEGRADED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.DEGRADED, 'High latency detected');
      expect(trans.toState).toBe(ConnectorLifecycleState.DEGRADED);

      // 8. DEGRADED -> DISABLED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.DISABLED, 'Admin disabled');
      expect(trans.toState).toBe(ConnectorLifecycleState.DISABLED);

      // 9. DISABLED -> RETIRED
      trans = packRegistry.transitionLifecycle(IntegrationCategory.VEHICLE_TRACKING, 'test_telematics', ConnectorLifecycleState.RETIRED, 'Decommissioned');
      expect(trans.toState).toBe(ConnectorLifecycleState.RETIRED);
    });

    it('should reject invalid lifecycle transitions that skip required stages', () => {
      packRegistry.registerPack({
        id: 'untested_pack',
        name: 'untested_pack',
        displayName: 'Untested Pack',
        category: IntegrationCategory.FRAUD_RISK,
        version: { apiVersion: 'v1', adapterVersion: '1.0.0', credentialSchemaVersion: '1.0', releasedAt: '2026-01-01' },
        supportedEnvironments: [ProviderEnvironment.SANDBOX],
        supportedRegions: ['US'],
        supportedCurrencies: ['USD'],
        capabilities: [],
        credentialSchema: [],
        rateLimits: { rps: 10, rpm: 60, burstCapacity: 20, concurrencyLimit: 10 },
        costModel: { providerId: 'untested_pack', category: IntegrationCategory.FRAUD_RISK, fixedFee: 0, percentageFee: 0, perRequestCost: 0, perMessageCost: 0, currency: 'USD', regionSpecificCosts: {} },
        webhookConfig: { supported: false, secretRequired: false, supportsReplayProtection: false },
        healthCheckConfig: { intervalSeconds: 60, timeoutMs: 3000, degradedThresholdFailures: 3 },
        retryPolicy: { maxRetries: 3, backoffFactor: 2, initialIntervalMs: 500, retryableErrorCodes: [] },
        fallbackEligibility: { eligibleAsPrimary: false, eligibleAsSecondaryFallback: false },
        implementationStatus: 'CATALOG_ONLY',
        tags: ['test'],
      });

      // DISCOVERED directly to ACTIVE must fail
      expect(() => {
        packRegistry.transitionLifecycle(
          IntegrationCategory.FRAUD_RISK,
          'untested_pack',
          ConnectorLifecycleState.ACTIVE,
          'Illegal jump to active',
        );
      }).toThrow(BadRequestException);
    });

    it('should reject transitions from RETIRED to any other state', () => {
      packRegistry.registerPack({
        id: 'retired_test_pack',
        name: 'retired_test_pack',
        displayName: 'Retired Test Pack',
        category: IntegrationCategory.VEHICLE_TRACKING,
        version: { apiVersion: 'v1', adapterVersion: '1.0.0', credentialSchemaVersion: '1.0', releasedAt: '2026-01-01' },
        supportedEnvironments: [ProviderEnvironment.SANDBOX],
        supportedRegions: ['IN'],
        supportedCurrencies: ['INR'],
        capabilities: [],
        credentialSchema: [],
        rateLimits: { rps: 10, rpm: 60, burstCapacity: 20, concurrencyLimit: 10 },
        costModel: { providerId: 'retired_test_pack', category: IntegrationCategory.VEHICLE_TRACKING, fixedFee: 0, percentageFee: 0, perRequestCost: 0, perMessageCost: 0, currency: 'USD', regionSpecificCosts: {} },
        webhookConfig: { supported: false, secretRequired: false, supportsReplayProtection: false },
        healthCheckConfig: { intervalSeconds: 60, timeoutMs: 3000, degradedThresholdFailures: 3 },
        retryPolicy: { maxRetries: 3, backoffFactor: 2, initialIntervalMs: 500, retryableErrorCodes: [] },
        fallbackEligibility: { eligibleAsPrimary: false, eligibleAsSecondaryFallback: false },
        implementationStatus: 'REAL_ADAPTER',
        tags: ['test'],
      });
      (packRegistry as any).lifecycleStates.set('vehicle_tracking:retired_test_pack', ConnectorLifecycleState.RETIRED);

      expect(() => {
        packRegistry.transitionLifecycle(
          IntegrationCategory.VEHICLE_TRACKING,
          'retired_test_pack',
          ConnectorLifecycleState.ACTIVE,
          'Attempt un-retire',
        );
      }).toThrow(BadRequestException);
    });

    it('should prohibit CATALOG_ONLY providers from transitioning to ACTIVE', () => {
      packRegistry.registerPack({
        id: 'catalog_only_sample',
        name: 'catalog_only_sample',
        displayName: 'Catalog Sample',
        category: IntegrationCategory.ESIGNATURE,
        version: { apiVersion: 'v1', adapterVersion: '1.0.0', credentialSchemaVersion: '1.0', releasedAt: '2026-01-01' },
        supportedEnvironments: [ProviderEnvironment.SANDBOX],
        supportedRegions: ['IN'],
        supportedCurrencies: ['INR'],
        capabilities: [],
        credentialSchema: [],
        rateLimits: { rps: 10, rpm: 60, burstCapacity: 20, concurrencyLimit: 10 },
        costModel: { providerId: 'catalog_only_sample', category: IntegrationCategory.ESIGNATURE, fixedFee: 0, percentageFee: 0, perRequestCost: 0, perMessageCost: 0, currency: 'INR', regionSpecificCosts: {} },
        webhookConfig: { supported: false, secretRequired: false, supportsReplayProtection: false },
        healthCheckConfig: { intervalSeconds: 60, timeoutMs: 3000, degradedThresholdFailures: 3 },
        retryPolicy: { maxRetries: 3, backoffFactor: 2, initialIntervalMs: 500, retryableErrorCodes: [] },
        fallbackEligibility: { eligibleAsPrimary: false, eligibleAsSecondaryFallback: false },
        implementationStatus: 'CATALOG_ONLY',
        tags: ['test'],
      });

      // Force to APPROVED
      (packRegistry as any).lifecycleStates.set('esignature:catalog_only_sample', ConnectorLifecycleState.APPROVED);

      expect(() => {
        packRegistry.transitionLifecycle(
          IntegrationCategory.ESIGNATURE,
          'catalog_only_sample',
          ConnectorLifecycleState.ACTIVE,
          'Cannot activate mock',
        );
      }).toThrow(BadRequestException);
    });
  });

  describe('Part 4: Multi-Tenant Hierarchical Connector Resolution', () => {
    it('should resolve tenant overrides when defined, falling back to platform defaults', () => {
      packRegistry.setTenantBinding({
        scope: MultiTenantOwnershipScope.ORGANIZATION,
        category: IntegrationCategory.MAPS,
        vendorId: 'vendor-456',
        preferredProviderId: 'mapbox',
        enabledProviders: ['mapbox', 'google'],
        fallbackChain: ['google'],
      });

      const binding = packRegistry.resolveTenantBinding(IntegrationCategory.MAPS, {
        vendorId: 'vendor-456',
        branchId: 'branch-789',
      });

      expect(binding).toBeDefined();
      expect(binding?.preferredProviderId).toBe('mapbox');
      expect(binding?.scope).toBe(MultiTenantOwnershipScope.ORGANIZATION);
    });

    it('should allow setting and evaluating tenant-specific preferred providers', () => {
      packRegistry.setTenantBinding({
        scope: MultiTenantOwnershipScope.ORGANIZATION,
        category: IntegrationCategory.MAPS,
        vendorId: 'vendor-special',
        preferredProviderId: 'mapbox',
        enabledProviders: ['mapbox', 'google'],
        fallbackChain: ['google'],
      });

      const binding = packRegistry.resolveTenantBinding(IntegrationCategory.MAPS, {
        tenantId: 'vendor-special',
      });

      expect(binding?.preferredProviderId).toBe('mapbox');
      expect(binding?.fallbackChain).toContain('google');
    });
  });

  describe('Part 5: Dynamic Capability Comparison & Routing Explanation', () => {
    it('should dynamically compare providers offering the same capability', () => {
      const comparison = packRegistry.compareProvidersForCapability(IntegrationCategory.MAPS, 'GEOCODE');
      expect(comparison.length).toBeGreaterThanOrEqual(1);

      const mapboxComp = comparison.find(p => p.providerId === 'mapbox');
      expect(mapboxComp).toBeDefined();
      expect(mapboxComp?.expectedLatencyMs).toBeLessThanOrEqual(150);
      expect(mapboxComp?.isFallbackSuitable).toBe(true);
    });

    it('should explain "Why was this provider selected?" with transparent policy audit', () => {
      const explanation = packRegistry.explainProviderSelection({
        category: IntegrationCategory.MAPS,
        capability: 'GEOCODE',
        region: 'IN',
        currency: 'INR',
      });

      expect(explanation.selectedProviderId).toBeDefined();
      expect(explanation.policyFactors).toBeDefined();
      expect(explanation.policyFactors.healthStatus).toBe('HEALTHY');
      expect(explanation.decisionRationale).toContain('mapbox');
    });
  });

  describe('Part 6: Concrete Enterprise Adapters Execution', () => {
    describe('MapboxMapsAdapter', () => {
      it('should geocode address successfully', async () => {
        const result = await mapboxAdapter.geocode('Kempegowda International Airport, Bengaluru');
        expect(result.length).toBeGreaterThan(0);
        expect(result[0].location.latitude).toBeCloseTo(12.9716, 1);
        expect(result[0].location.longitude).toBeCloseTo(77.5946, 1);
      });

      it('should reverse geocode coordinates', async () => {
        const result = await mapboxAdapter.reverseGeocode({ latitude: 12.9716, longitude: 77.5946 });
        expect(result).toBeDefined();
        expect(result?.formattedAddress).toContain('Bengaluru');
        expect(result?.city).toBe('Bengaluru');
      });

      it('should calculate route directions with step maneuvers', async () => {
        const route = await mapboxAdapter.getDirections(
          { latitude: 12.9716, longitude: 77.5946 },
          { latitude: 13.1986, longitude: 77.7066 },
        );
        expect(route.distanceMeters).toBeGreaterThan(20000);
        expect(route.durationSeconds).toBeGreaterThan(1800);
        expect(route.waypoints.length).toBeGreaterThan(0);
      });

      it('should compute distance matrix for multiple destinations', async () => {
        const matrix = await mapboxAdapter.calculateDistanceMatrix(
          [{ latitude: 12.9716, longitude: 77.5946 }],
          [
            { latitude: 13.1986, longitude: 77.7066 },
            { latitude: 12.9279, longitude: 77.6271 },
          ],
        );
        expect(matrix.matrix.length).toBe(1);
        expect(matrix.matrix[0].length).toBe(2);
        expect(matrix.matrix[0][0].distanceKm).toBeGreaterThan(0);
      });
    });

    describe('TraccarTelematicsAdapter', () => {
      it('should fetch live GPS telemetry for a vehicle device', async () => {
        const pos = await traccarAdapter.getTelemetry('traccar-dev-01');
        expect(pos.vehicleId).toBe('traccar-dev-01');
        expect(pos.location.latitude).toBeGreaterThan(0);
        expect(pos.location.longitude).toBeGreaterThan(0);
        expect(pos.speedKmph).toBeDefined();
        expect(pos.ignitionOn).toBe(true);
      });

      it('should send vehicle immobilization command', async () => {
        const res = await traccarAdapter.immobilizeVehicle('traccar-dev-01', 'Security hold');
        expect(res.success).toBe(true);
        expect(res.message).toContain('Engine cutoff');
      });

      it('should normalize incoming device webhook payloads into standardized telemetry', async () => {
        const normalized = traccarAdapter.normalizeWebhookEvent({
          device: { id: 'device-999' },
          position: { latitude: 12.95, longitude: 77.60, speed: 45, attributes: { ignition: true, totalDistance: 15000000 } },
        });
        expect(normalized.deviceId).toBe('device-999');
        expect(normalized.position.latitude).toBe(12.95);
        expect(normalized.ignitionOn).toBe(true);
        expect(normalized.odometerKm).toBe(15000);
      });
    });

    describe('HyperVergeKycAdapter', () => {
      it('should verify Indian Driving Licence', async () => {
        const res = await hypervergeAdapter.verifyDrivingLicence({
          licenceNumber: 'KA0120200012345',
          dateOfBirth: '1990-05-15',
          fullName: 'DRIVEGO AUTHORIZED DRIVER',
        });
        expect(res.isValid).toBe(true);
        expect(res.status).toBe('VERIFIED');
        expect(res.holderName).toBe('DRIVEGO AUTHORIZED DRIVER');
      });

      it('should verify Vehicle Registration Certificate (RC)', async () => {
        const res = await hypervergeAdapter.verifyVehicleRc({
          registrationNumber: 'KA01AB1234',
        });
        expect(res.isValid).toBe(true);
        expect(res.status).toBe('VERIFIED');
        expect(res.makerModel).toContain('Hyundai Creta');
      });

      it('should verify Indian PAN Card', async () => {
        const res = await hypervergeAdapter.verifyPan({
          panNumber: 'ABCDE1234F',
          fullName: 'DRIVEGO CUSTOMER',
        });
        expect(res.verified).toBe(true);
        expect(res.status).toBe('VERIFIED');
        expect(res.extractedData?.holderName).toBe('DRIVEGO CUSTOMER');
      });

      it('should perform biometric face match with liveness check', async () => {
        const res = await hypervergeAdapter.verifyFaceMatch({
          selfieImageUrl: 'https://cdn.drivego.io/selfie.jpg',
          idDocumentImageUrl: 'https://cdn.drivego.io/dl.jpg',
        });
        expect(res.verified).toBe(true);
        expect(res.confidenceScore).toBeGreaterThanOrEqual(0.9);
      });
    });

    describe('ZohoBooksAdapter', () => {
      it('should create an invoice and calculate GST breakdown', async () => {
        const inv = await zohoAdapter.createInvoice({
          bookingId: 'book-123',
          grandTotal: 17700,
          customerName: 'Enterprise Client Ltd',
          invoiceNumber: 'INV-2026-001',
          currency: 'INR',
          lineItems: [],
        });
        expect(inv.success).toBe(true);
        expect(inv.status).toBe('SENT');
        expect(inv.invoiceNumber).toBe('INV-2026-001');
      });

      it('should calculate inter-state and intra-state GST dynamically', async () => {
        // Intra-state (29 to 29) -> CGST + SGST
        const intraTax = await zohoAdapter.calculateTax({
          amount: 10000,
          sourceStateCode: '29',
          destinationStateCode: '29',
        });
        expect(intraTax.cgstAmount).toBe(900);
        expect(intraTax.sgstAmount).toBe(900);
        expect(intraTax.igstAmount).toBe(0);

        // Inter-state (27 to 29) -> IGST
        const interTax = await zohoAdapter.calculateTax({
          amount: 10000,
          sourceStateCode: '27',
          destinationStateCode: '29',
        });
        expect(interTax.cgstAmount).toBe(0);
        expect(interTax.sgstAmount).toBe(0);
        expect(interTax.igstAmount).toBe(1800);
      });
    });

    describe('GoogleGeminiAdapter', () => {
      it('should handle AI text generation', async () => {
        const res = await geminiAdapter.generateText({
          prompt: 'Write a welcoming email for a customer booking a BMW X5.',
        });
        expect(res.text).toBeDefined();
        expect(res.tokensUsed?.totalTokens).toBeGreaterThan(0);
      });

      it('should summarize text dynamically', async () => {
        const res = await geminiAdapter.summarize({
          text: 'The vehicle was picked up at 10:00 AM in Bengaluru. Driven 120km along NH44. Returned on time with full fuel tank. No scratches or dents observed.',
        });
        expect(res.summary).toBeDefined();
      });

      it('should classify customer feedback sentiment', async () => {
        const res = await geminiAdapter.classify({
          text: 'The car was in pristine condition and the pickup took less than 2 minutes!',
          candidateLabels: ['POSITIVE', 'NEUTRAL', 'NEGATIVE'],
        });
        expect(res.classification?.label).toBe('POSITIVE');
        expect(res.classification?.confidence).toBeGreaterThan(0.9);
      });
    });

    describe('MeilisearchAdapter', () => {
      it('should index and search vehicle records', async () => {
        await meilisearchAdapter.indexDocuments({
          indexName: 'vehicles',
          documents: [
            { id: 'v1', make: 'BMW', model: 'X5', category: 'LUXURY_SUV' },
            { id: 'v2', make: 'Hyundai', model: 'Creta', category: 'MID_SUV' },
          ],
        });

        const searchRes = await meilisearchAdapter.search({
          indexName: 'vehicles',
          query: 'BMW',
        });
        expect(searchRes.hits.length).toBeGreaterThanOrEqual(1);
        expect(searchRes.hits[0].make).toBe('BMW');
      });
    });

    describe('PostHogAnalyticsAdapter', () => {
      it('should capture single and batch business telemetry events', async () => {
        const single = await posthogAdapter.track({
          distinctId: 'user-001',
          event: 'car_reserved',
          properties: { vehicleId: 'v1', durationDays: 3 },
        });
        expect(single.success).toBe(true);

        const batch = await posthogAdapter.trackBatch({
          events: [
            { distinctId: 'user-001', event: 'page_viewed' },
            { distinctId: 'user-002', event: 'filter_applied' },
          ],
        });
        expect(batch.success).toBe(true);
        expect(batch.eventsAccepted).toBe(2);
      });
    });
  });

  describe('Part 7: Capability-Based IntegrationRuntime Execution', () => {
    it('should route maps.geocode capability request to Mapbox without caller knowing provider', async () => {
      const result = await runtimeService.executeCapability<any>({
        category: IntegrationCategory.MAPS,
        capability: 'GEOCODE',
        parameters: { address: 'Indiranagar, Bangalore' },
      });

      expect(result).toBeDefined();
      expect(result.length).toBeGreaterThan(0);
      expect(result[0].location.latitude).toBeDefined();
    });

    it('should route telematics.live_position capability to Traccar', async () => {
      const pos = await runtimeService.executeCapability<any>({
        category: IntegrationCategory.VEHICLE_TRACKING,
        capability: 'GET_LOCATION',
        parameters: { vehicleId: 'traccar-fleet-99' },
      });

      expect(pos.vehicleId).toBe('traccar-fleet-99');
      expect(pos.location.latitude).toBeDefined();
    });

    it('should route kyc.dl_verify capability to HyperVerge', async () => {
      const kyc = await runtimeService.executeCapability<any>({
        category: IntegrationCategory.IDENTITY_VERIFICATION,
        capability: 'DRIVING_LICENCE_VERIFY',
        parameters: { licenceNumber: 'DL-KA-05-2022-009', dateOfBirth: '1995-01-01' },
      });

      expect(kyc.isValid).toBe(true);
    });

    it('should route ai.chat capability to Gemini', async () => {
      const chatRes = await runtimeService.executeCapability<any>({
        category: IntegrationCategory.AI,
        capability: 'CHAT',
        parameters: { messages: [{ role: 'user', content: 'What is the refund policy?' }] },
      });

      expect(chatRes.text).toBeDefined();
    });
  });

  describe('Part 8: Business Module Refactoring — GeospatialService', () => {
    it('should use IntegrationRuntime for geocoding rather than hardcoding external vendors', async () => {
      const coords = await geospatialService.geocodeAddress('MG Road, Bengaluru');
      expect(coords).toBeDefined();
      expect(coords?.latitude).toBeCloseTo(12.9716, 1);
      expect(coords?.longitude).toBeCloseTo(77.5946, 1);
    });

    it('should use IntegrationRuntime for route calculation with Haversine safety fallback', async () => {
      const route = await geospatialService.calculateRoute(
        12.9716, 77.5946,
        13.1986, 77.7066,
      );
      expect(route.distanceKm).toBeGreaterThan(20);
      expect(route.durationMinutes).toBeGreaterThan(20);
    });

    it('should calculate distance matrix through IntegrationRuntime', async () => {
      const origins = [{ latitude: 12.9716, longitude: 77.5946 }];
      const destinations = [{ latitude: 13.1986, longitude: 77.7066 }];

      const matrix = await geospatialService.calculateDistanceMatrix(origins, destinations);
      expect(matrix.length).toBe(1);
      expect(matrix[0].length).toBe(1);
      expect(matrix[0][0].distanceKm).toBeGreaterThan(0);
    });
  });
});
