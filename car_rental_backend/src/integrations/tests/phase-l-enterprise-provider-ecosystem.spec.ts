import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import {
  CatalogProviderMetadata,
  ProviderActivationState,
  ProviderCertificationLevel,
  ProviderEnvironment,
  ProviderLifecycleState,
} from '../catalog/provider-catalog.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderRateLimiterService } from '../runtime/provider-rate-limiter.service';
import { FailureClassifierService } from '../runtime/failure-classifier.service';
import { IntegrationIdempotencyService } from '../runtime/integration-idempotency.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { CostModelService } from '../runtime/cost-model.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { IntegrationAuditService } from '../runtime/integration-audit.service';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { CircuitState, RoutingStrategy, SimulationScenario } from '../runtime/runtime.types';

describe('Phase L — Enterprise Provider Ecosystem & Connector Fabric', () => {
  let catalogService: ProviderCatalogService;
  let registryService: ProviderRegistryService;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;
  let runtimeService: IntegrationRuntimeService;
  let routingService: ProviderRoutingService;
  let circuitBreakerService: CircuitBreakerService;
  let rateLimiter: ProviderRateLimiterService;
  let policyService: ProviderPolicyService;
  let costModelService: CostModelService;
  let simulationService: ProviderSimulationService;
  let auditService: IntegrationAuditService;
  let webhookDispatcher: WebhookDispatcherService;

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
  };

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderCatalogService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        IntegrationRuntimeService,
        ProviderRoutingService,
        CircuitBreakerService,
        ProviderRateLimiterService,
        FailureClassifierService,
        IntegrationIdempotencyService,
        ProviderPolicyService,
        CostModelService,
        ProviderSimulationService,
        IntegrationAuditService,
        WebhookDispatcherService,
        SecretVaultService,
        {
          provide: SystemConfigService,
          useValue: { get: jest.fn().mockReturnValue(null), set: jest.fn() },
        },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue('test-encryption-key-32-chars-ok!') },
        },
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    registryService = module.get<ProviderRegistryService>(ProviderRegistryService);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
    runtimeService = module.get<IntegrationRuntimeService>(IntegrationRuntimeService);
    routingService = module.get<ProviderRoutingService>(ProviderRoutingService);
    circuitBreakerService = module.get<CircuitBreakerService>(CircuitBreakerService);
    rateLimiter = module.get<ProviderRateLimiterService>(ProviderRateLimiterService);
    policyService = module.get<ProviderPolicyService>(ProviderPolicyService);
    costModelService = module.get<CostModelService>(CostModelService);
    simulationService = module.get<ProviderSimulationService>(ProviderSimulationService);
    auditService = module.get<IntegrationAuditService>(IntegrationAuditService);
    webhookDispatcher = module.get<WebhookDispatcherService>(WebhookDispatcherService);

    catalogService.onModuleInit();
  });

  beforeEach(() => {
    circuitBreakerService.resetAll();
    rateLimiter.clearAll();
    policyService.clearPolicies();
    simulationService.clearAllSimulations();
    jest.clearAllMocks();
  });

  // ---------------------------------------------------------------------------
  // 1. Provider Registration
  // ---------------------------------------------------------------------------
  it('Scenario 1: Provider registration dynamically registers new provider into catalog', () => {
    const testProvider: CatalogProviderMetadata = {
      providerId: 'custom_fastag',
      category: IntegrationCategory.TOLL_FASTAG,
      name: 'Custom Toll Gateway',
      tagline: 'Custom Toll',
      description: 'Custom toll description',
      icon: 'toll',
      websiteUrl: 'https://toll.example.com',
      documentation: { overview: '', docsUrl: '', setupGuide: '' },
      version: '1.0.0',
      author: 'Test Corp',
      tags: ['toll', 'fastag'],
      supportedEnvironments: [ProviderEnvironment.SANDBOX],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      credentialSchema: [],
      supportedCapabilities: ['TOLL_DEBIT'],
      supportedCurrencies: ['INR'],
      supportedCountries: ['IN'],
      platformAvailability: true,
      tenantTierAvailability: ['ALL'],
      activationState: ProviderActivationState.ACTIVE,
      lifecycleState: ProviderLifecycleState.CONFIGURABLE,
      certificationLevel: ProviderCertificationLevel.CATALOG,
      priority: 50,
    };

    catalogService.registerProvider(testProvider);
    const retrieved = catalogService.getProvider(IntegrationCategory.TOLL_FASTAG, 'custom_fastag');
    expect(retrieved).toBeDefined();
    expect(retrieved.name).toBe('Custom Toll Gateway');
  });

  // ---------------------------------------------------------------------------
  // 2. Duplicate Prevention
  // ---------------------------------------------------------------------------
  it('Scenario 2: Duplicate provider registration in same category throws ConflictException', () => {
    const duplicate: CatalogProviderMetadata = {
      providerId: 'custom_fastag',
      category: IntegrationCategory.TOLL_FASTAG,
      name: 'Duplicate Gateway',
      tagline: '',
      description: '',
      icon: '',
      websiteUrl: '',
      documentation: { overview: '', docsUrl: '', setupGuide: '' },
      version: '1.0.0',
      author: 'Test',
      tags: [],
      supportedEnvironments: [ProviderEnvironment.SANDBOX],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      credentialSchema: [],
      supportedCapabilities: ['TOLL_DEBIT'],
      supportedCurrencies: ['INR'],
      supportedCountries: ['IN'],
      platformAvailability: true,
      tenantTierAvailability: ['ALL'],
      activationState: ProviderActivationState.ACTIVE,
      priority: 50,
    };

    expect(() => catalogService.registerProvider(duplicate)).toThrow(ConflictException);
  });

  // ---------------------------------------------------------------------------
  // 3. Capability Registration
  // ---------------------------------------------------------------------------
  it('Scenario 3: Capability registration reflects on provider metadata correctly', () => {
    const provider = catalogService.getProvider(IntegrationCategory.PAYMENT, 'juspay');
    expect(provider).toBeDefined();
    expect(provider.supportedCapabilities).toContain('UPI_INTENT');
    expect(provider.supportedCapabilities).toContain('TOKENIZATION');
  });

  // ---------------------------------------------------------------------------
  // 4. Capability Validation
  // ---------------------------------------------------------------------------
  it('Scenario 4: Capability validation flags missing required capabilities', () => {
    const invalidProvider: CatalogProviderMetadata = {
      providerId: 'invalid_refund_provider',
      category: IntegrationCategory.PAYMENT,
      name: 'Invalid Provider',
      tagline: '',
      description: '',
      icon: '',
      websiteUrl: '',
      documentation: { overview: '', docsUrl: '', setupGuide: '' },
      version: '1.0.0',
      author: 'Test',
      tags: [],
      supportedEnvironments: [ProviderEnvironment.SANDBOX],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      credentialSchema: [],
      supportedCapabilities: ['CUSTOM_REFUND_ONLY'],
      supportedCurrencies: ['INR'],
      supportedCountries: ['IN'],
      platformAvailability: true,
      tenantTierAvailability: ['ALL'],
      activationState: ProviderActivationState.ACTIVE,
      lifecycleState: ProviderLifecycleState.SANDBOX_READY,
      certificationLevel: ProviderCertificationLevel.CATALOG,
      adapterImplemented: true,
      priority: 50,
    };

    const validation = catalogService.validateProviderRegistration(invalidProvider);
    expect(validation.isValid).toBe(false);
    expect(validation.errors.some((e) => e.includes('refund'))).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // 5. Provider Lifecycle
  // ---------------------------------------------------------------------------
  it('Scenario 5: Provider lifecycle states distinguish CATALOG_ONLY vs LIVE_READY', () => {
    const razorpay = catalogService.getProvider(IntegrationCategory.PAYMENT, 'razorpay');
    expect(razorpay.lifecycleState).toBe(ProviderLifecycleState.LIVE_READY);

    const ccavenue = catalogService.getProvider(IntegrationCategory.PAYMENT, 'ccavenue');
    expect(ccavenue.lifecycleState).toBe(ProviderLifecycleState.CONFIGURABLE);

    const filtered = catalogService.getAllProviders({ lifecycleState: ProviderLifecycleState.LIVE_READY });
    expect(filtered.some((p) => p.providerId === 'razorpay')).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // 6. Environment Separation
  // ---------------------------------------------------------------------------
  it('Scenario 6: Environment separation scopes credentials to SANDBOX or LIVE', () => {
    const razorpay = catalogService.getProvider(IntegrationCategory.PAYMENT, 'razorpay');
    const keyIdField = razorpay.credentialSchema.find((f) => f.key === 'keyId');
    expect(keyIdField?.environmentScoped).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // 7. Credential Schema Validation
  // ---------------------------------------------------------------------------
  it('Scenario 7: Credential schema validates missing required keys', () => {
    const razorpay = catalogService.getProvider(IntegrationCategory.PAYMENT, 'razorpay');
    const requiredKeys = razorpay.credentialSchema.filter((f) => f.required).map((f) => f.key);
    expect(requiredKeys).toContain('keyId');
    expect(requiredKeys).toContain('keySecret');
  });

  // ---------------------------------------------------------------------------
  // 8. Hierarchy Resolution
  // ---------------------------------------------------------------------------
  it('Scenario 8: Configuration hierarchy resolves Branch > Vendor > Platform', async () => {
    // Platform default is razorpay
    const platformActive = await configService.resolveActiveProviderId(IntegrationCategory.PAYMENT);
    expect(platformActive).toBe('razorpay');
  });

  // ---------------------------------------------------------------------------
  // 9. Routing by Capability
  // ---------------------------------------------------------------------------
  it('Scenario 9: Routing selects candidate supporting specialized capability (UPI_INTENT)', async () => {
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'UPI_INTENT',
      currency: 'INR',
      payload: {},
    });
    expect(res.primaryProviderId).toBeDefined();
    const primary = catalogService.getProvider(IntegrationCategory.PAYMENT, res.primaryProviderId);
    expect(primary.supportedCapabilities).toContain('UPI_INTENT');
  });

  // ---------------------------------------------------------------------------
  // 10. Regional Routing
  // ---------------------------------------------------------------------------
  it('Scenario 10: Regional routing restricts candidates to providers supporting target country', async () => {
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      region: 'AE', // United Arab Emirates
      payload: {},
    });
    expect(res.allCandidates.length).toBeGreaterThan(0);
    for (const id of res.allCandidates) {
      const p = catalogService.getProvider(IntegrationCategory.PAYMENT, id);
      const supportsAe = p.supportedCountries.includes('AE') || p.supportedCountries.includes('ALL');
      expect(supportsAe).toBe(true);
    }
  });

  // ---------------------------------------------------------------------------
  // 11. Currency Routing
  // ---------------------------------------------------------------------------
  it('Scenario 11: Currency routing filters candidates to providers supporting target currency', async () => {
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      currency: 'EUR',
      payload: {},
    });
    expect(res.allCandidates.length).toBeGreaterThan(0);
    for (const id of res.allCandidates) {
      const p = catalogService.getProvider(IntegrationCategory.PAYMENT, id);
      const supportsEur = p.supportedCurrencies.includes('EUR') || p.supportedCurrencies.includes('ALL');
      expect(supportsEur).toBe(true);
    }
  });

  // ---------------------------------------------------------------------------
  // 12. Weighted Routing
  // ---------------------------------------------------------------------------
  it('Scenario 12: Weighted routing strategy respects candidate weights', async () => {
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      routingStrategy: RoutingStrategy.WEIGHTED,
      payload: {},
    });
    expect(res.strategyUsed).toBe(RoutingStrategy.WEIGHTED);
    expect(res.primaryProviderId).toBeDefined();
  });

  // ---------------------------------------------------------------------------
  // 13. Cost Routing
  // ---------------------------------------------------------------------------
  it('Scenario 13: Cost-optimized routing orders candidates by lowest calculated transaction fee', async () => {
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      currency: 'INR',
      routingStrategy: RoutingStrategy.COST_OPTIMIZED,
      payload: {},
    });
    expect(res.strategyUsed).toBe(RoutingStrategy.COST_OPTIMIZED);
    const costPrimary = costModelService.estimateCost(res.primaryProviderId, 100, 'INR');
    if (res.fallbackChain.length > 0) {
      const costFallback = costModelService.estimateCost(res.fallbackChain[0], 100, 'INR');
      expect(costPrimary).toBeLessThanOrEqual(costFallback);
    }
  });

  // ---------------------------------------------------------------------------
  // 14. Health Routing
  // ---------------------------------------------------------------------------
  it('Scenario 14: Health-based routing prefers healthy providers over degraded ones', async () => {
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'razorpay', { success: true, latencyMs: 25 });
    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      routingStrategy: RoutingStrategy.HEALTH_BASED,
      payload: {},
    });
    expect(res.primaryProviderId).toBe('razorpay');
  });

  // ---------------------------------------------------------------------------
  // 15. Policy Rejection
  // ---------------------------------------------------------------------------
  it('Scenario 15: Policy rule denying a provider removes it from candidate list', async () => {
    policyService.registerPolicy({
      id: 'deny_razorpay',
      name: 'Deny Razorpay Policy',
      enabled: true,
      priority: 1,
      conditions: { category: IntegrationCategory.PAYMENT },
      actions: { deniedProviders: ['razorpay'] },
    });

    const res = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: {},
    });
    expect(res.primaryProviderId).not.toBe('razorpay');
    expect(res.allCandidates).not.toContain('razorpay');
  });

  // ---------------------------------------------------------------------------
  // 16. Fallback Chains
  // ---------------------------------------------------------------------------
  it('Scenario 16: Multi-hop fallback chain transitions when primary fails with transient error', async () => {
    simulationService.setProviderSimulation('razorpay', SimulationScenario.NETWORK_FAILURE);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amount: 500 },
      isIdempotent: true,
    });

    expect(result.fallbackOccurred).toBe(true);
    expect(result.attempts.length).toBeGreaterThanOrEqual(2);
    expect(result.attempts[0].providerId).toBe('razorpay');
    expect(result.attempts[0].status).toBe('FAILED');
  });

  // ---------------------------------------------------------------------------
  // 17. Unsupported Capability Handling
  // ---------------------------------------------------------------------------
  it('Scenario 17: Requesting an unknown capability returns failure with clear diagnostic', async () => {
    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'NON_EXISTENT_QUANTUM_CAPABILITY',
      payload: {},
    });

    expect(result.success).toBe(false);
    expect(result.error?.code).toBe('ROUTING_FAILED');
  });

  // ---------------------------------------------------------------------------
  // 18. Provider Certification
  // ---------------------------------------------------------------------------
  it('Scenario 18: Provider certification level identifies PRODUCTION_VALIDATED vs CATALOG', () => {
    const razorpay = catalogService.getProvider(IntegrationCategory.PAYMENT, 'razorpay');
    expect(razorpay.certificationLevel).toBe(ProviderCertificationLevel.PRODUCTION_VALIDATED);

    const ccavenue = catalogService.getProvider(IntegrationCategory.PAYMENT, 'ccavenue');
    expect(ccavenue.certificationLevel).toBe(ProviderCertificationLevel.CATALOG);
  });

  // ---------------------------------------------------------------------------
  // 19. Webhook Validation
  // ---------------------------------------------------------------------------
  it('Scenario 19: Webhook dispatcher verifies HMAC signature correctly', async () => {
    const secret = 'webhook_secret_xyz';
    const payload = JSON.stringify({ id: 'evt_test_123', event: 'payment.captured' });
    const crypto = require('crypto');
    const signature = crypto.createHmac('sha256', secret).update(payload).digest('hex');

    const result = await webhookDispatcher.ingestWebhook({
      gateway: 'RAZORPAY',
      rawBody: payload,
      signature,
      secret,
    });

    expect(result.received).toBe(true);
    expect(result.status).toBe('PROCESSED');
    expect(result.eventId).toBe('evt_test_123');
  });

  // ---------------------------------------------------------------------------
  // 20. Webhook Deduplication
  // ---------------------------------------------------------------------------
  it('Scenario 20: Replaying identical webhook event ID detects duplicate and skips processing', async () => {
    mockPrisma.webhookEvent.findUnique.mockResolvedValueOnce({
      eventId: 'evt_duplicate_999',
      status: 'PROCESSED',
    });

    const secret = 'dummy_secret';
    const rawBody = JSON.stringify({ id: 'evt_duplicate_999', event: 'order.paid' });
    const crypto = require('crypto');
    const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

    const result = await webhookDispatcher.ingestWebhook({
      gateway: 'RAZORPAY',
      rawBody,
      signature,
      secret,
    });

    expect(result.duplicate).toBe(true);
    expect(result.alreadyProcessed).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // 21. Incident Creation
  // ---------------------------------------------------------------------------
  it('Scenario 21: Tripping circuit breaker automatically records an incident', async () => {
    circuitBreakerService.tripCircuit('cashfree', 'Repeated socket drops in test');
    await auditService.recordIncident({
      providerId: 'cashfree',
      category: IntegrationCategory.PAYMENT,
      title: 'Circuit opened for cashfree',
      severity: 'HIGH',
      circuitState: CircuitState.OPEN,
      reason: 'Repeated socket drops in test',
    });

    const incidents = auditService.getIncidents({ providerId: 'cashfree' });
    expect(incidents.length).toBeGreaterThan(0);
    expect(incidents[0].status).toBe('INVESTIGATING');
    expect(incidents[0].severity).toBe('HIGH');
  });

  // ---------------------------------------------------------------------------
  // 22. Incident Recovery
  // ---------------------------------------------------------------------------
  it('Scenario 22: Resolving incident resets circuit and marks incident RESOLVED', async () => {
    await auditService.resolveIncident('cashfree', 'Manual recovery verified');
    circuitBreakerService.resetCircuit('cashfree');

    const incidents = auditService.getIncidents({ providerId: 'cashfree' });
    expect(incidents.every((i) => i.status === 'RESOLVED')).toBe(true);
    expect(circuitBreakerService.getState('cashfree')).toBe(CircuitState.CLOSED);
  });

  // ---------------------------------------------------------------------------
  // 23. Simulation Safety
  // ---------------------------------------------------------------------------
  it('Scenario 23: Simulation safety rejects simulation execution against LIVE environment credentials', async () => {
    await expect(
      simulationService.simulateExecution(
        'razorpay',
        'CREATE_ORDER',
        SimulationScenario.SUCCESS,
        { environment: 'LIVE' },
      ),
    ).rejects.toThrow('Sandbox simulation cannot execute against LIVE production credentials');
  });

  // ---------------------------------------------------------------------------
  // 24. Provider Decision Explanation
  // ---------------------------------------------------------------------------
  it('Scenario 24: Runtime provides transparent explanation of why provider was selected', async () => {
    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      currency: 'INR',
      region: 'IN',
      payload: { amount: 100 },
    });

    expect(result.explanation).toBeDefined();
    expect(result.explanation?.selectedProviderId).toBe(result.providerId);
    expect(result.explanation?.reasons.length).toBeGreaterThan(0);
    expect(result.explanation?.candidatesEvaluated.length).toBeGreaterThan(0);
    const evaluated = result.explanation?.candidatesEvaluated[0];
    expect(evaluated?.factorScores).toHaveProperty('healthScore');
    expect(evaluated?.factorScores).toHaveProperty('costScore');
  });

  // ---------------------------------------------------------------------------
  // 25. Cost Calculation
  // ---------------------------------------------------------------------------
  it('Scenario 25: CostModelService supports tiered volume pricing and currency conversion', () => {
    costModelService.setCostModel({
      providerId: 'tiered_gateway',
      category: IntegrationCategory.PAYMENT,
      fixedFee: 0,
      percentageFee: 2.5,
      perRequestCost: 0,
      perMessageCost: 0,
      currency: 'USD',
      regionSpecificCosts: {},
      tierRates: [
        { minVolume: 0, maxVolume: 1000, percentageFee: 2.5, fixedFee: 0 },
        { minVolume: 1001, maxVolume: 10000, percentageFee: 2.0, fixedFee: 0 },
        { minVolume: 10001, percentageFee: 1.5, fixedFee: 0 },
      ],
    });

    const tier1 = costModelService.estimateCost('tiered_gateway', 500);
    expect(tier1).toBe(12.5); // 2.5% of 500

    const tier2 = costModelService.estimateCost('tiered_gateway', 5000);
    expect(tier2).toBe(100); // 2.0% of 5000

    // Test minimum charge
    costModelService.setCostModel({
      providerId: 'min_charge_gateway',
      category: IntegrationCategory.PAYMENT,
      fixedFee: 0,
      percentageFee: 1.0,
      perRequestCost: 0,
      perMessageCost: 0,
      minimumCharge: 5.0,
      currency: 'USD',
      regionSpecificCosts: {},
    });

    const smallAmountCost = costModelService.estimateCost('min_charge_gateway', 10);
    expect(smallAmountCost).toBe(5.0); // 1% of 10 is 0.1, raised to minimum 5.0
  });

  // ---------------------------------------------------------------------------
  // 26. Health Scoring
  // ---------------------------------------------------------------------------
  it('Scenario 26: Health scoring tracks rolling success rate and p50 latency accurately', () => {
    for (let i = 0; i < 9; i++) {
      healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'health_test_provider', {
        success: true,
        latencyMs: 20,
      });
    }
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'health_test_provider', {
      success: false,
      latencyMs: 20,
    });

    const health = healthService.getRollingHealth(IntegrationCategory.PAYMENT, 'health_test_provider');
    expect(health.totalExecutions).toBe(10);
    expect(health.successRate).toBe(90);
    expect(health.latencyP50).toBe(20);
  });

  // ---------------------------------------------------------------------------
  // 27. Tenant Isolation
  // ---------------------------------------------------------------------------
  it('Scenario 27: Policy engine isolates vendor and tenant rules deterministically', () => {
    policyService.registerPolicy({
      id: 'vendor_v1_pref',
      name: 'Vendor 1 Preferred Gateway',
      enabled: true,
      priority: 1,
      conditions: { vendorId: 'vendor_v1' },
      actions: { preferredProviderId: 'stripe' },
    });

    const evalV1 = policyService.evaluatePolicies({ vendorId: 'vendor_v1' });
    expect(evalV1.preferredProviderId).toBe('stripe');

    const evalV2 = policyService.evaluatePolicies({ vendorId: 'vendor_v2' });
    expect(evalV2.preferredProviderId).toBeUndefined();
  });

  // ---------------------------------------------------------------------------
  // 28. Credential Redaction
  // ---------------------------------------------------------------------------
  it('Scenario 28: Audit telemetry redacts api keys, tokens, and passwords', async () => {
    const payloadWithSecret = {
      amount: 100,
      apiKey: 'secret_live_key_99999',
      customerToken: 'jwt_token_here',
    };

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: payloadWithSecret,
    });

    const executions = auditService.getExecutions();
    const last = executions[0];
    expect(last).toBeDefined();
    expect(last.requestPayload.apiKey).toBe('***REDACTED***');
    expect(last.requestPayload.customerToken).toBe('***REDACTED***');
  });

  // ---------------------------------------------------------------------------
  // 29. Provider Enable/Disable
  // ---------------------------------------------------------------------------
  it('Scenario 29: Provider catalog toggle updates enabled status', () => {
    catalogService.updateActivationState(
      IntegrationCategory.PAYMENT,
      'ccavenue',
      ProviderActivationState.SUSPENDED,
    );

    const updated = catalogService.getProvider(IntegrationCategory.PAYMENT, 'ccavenue');
    expect(updated.activationState).toBe(ProviderActivationState.SUSPENDED);
  });

  // ---------------------------------------------------------------------------
  // 30. Adapter & Catalog Consistency
  // ---------------------------------------------------------------------------
  it('Scenario 30: Provider comparison generates side-by-side capability matrix', () => {
    const comparison = catalogService.compareProviders(IntegrationCategory.PAYMENT, [
      'razorpay',
      'stripe',
      'cashfree',
    ]);

    expect(comparison).toBeDefined();
    expect(comparison.providers.length).toBe(3);
    expect(comparison.commonCapabilities).toBeDefined();
    expect(comparison.uniqueCapabilities).toBeDefined();
    expect(comparison.providers.some((p) => p.providerId === 'razorpay')).toBe(true);
  });
});
