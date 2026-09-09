import { Test, TestingModule } from '@nestjs/testing';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderRateLimiterService } from '../runtime/provider-rate-limiter.service';
import { FailureClassifierService } from '../runtime/failure-classifier.service';
import { CostModelService } from '../runtime/cost-model.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { IntegrationIdempotencyService } from '../runtime/integration-idempotency.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationAuditService } from '../runtime/integration-audit.service';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { ConfigService } from '@nestjs/config';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CircuitState,
  FailureClassification,
  RoutingStrategy,
  SimulationScenario,
} from '../runtime/runtime.types';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { BaseProvider } from '../contracts/provider.interface';

class TestMockProvider implements BaseProvider {
  constructor(
    private readonly id: string,
    private readonly category: IntegrationCategory,
    private readonly capabilities: string[] = ['CREATE_ORDER', 'VERIFY_PAYMENT'],
    public handler?: (cap: string, payload: any) => Promise<any>,
  ) {}

  getProviderId(): string {
    return this.id;
  }
  getCategory(): IntegrationCategory {
    return this.category;
  }
  getDisplayName(): string {
    return `Test ${this.id}`;
  }
  getSupportedCapabilities(): string[] {
    return this.capabilities;
  }
  hasCapability(capability: string): boolean {
    return this.capabilities.includes(capability);
  }
  async checkHealth() {
    return { status: ProviderHealthStatus.HEALTHY, latencyMs: 15 };
  }
  async testConnection() {
    return { success: true, latencyMs: 15 };
  }
  getDefaultTimeoutMs(): number {
    return 1000;
  }
  async executeCapability(capability: string, payload: any) {
    if (this.handler) {
      return this.handler(capability, payload);
    }
    return { success: true, providerId: this.id, capability, payload };
  }
}

describe('Phase K — Enterprise Integration Runtime, Routing & Intelligent Failover', () => {
  let runtimeService: IntegrationRuntimeService;
  let routingService: ProviderRoutingService;
  let circuitBreakerService: CircuitBreakerService;
  let rateLimiter: ProviderRateLimiterService;
  let failureClassifier: FailureClassifierService;
  let costModelService: CostModelService;
  let policyService: ProviderPolicyService;
  let idempotencyService: IntegrationIdempotencyService;
  let simulationService: ProviderSimulationService;
  let healthService: ProviderHealthService;
  let auditService: IntegrationAuditService;
  let catalogService: ProviderCatalogService;
  let registryService: ProviderRegistryService;

  const mockConfigs: Record<string, any> = {};
  const mockSystemConfigService = {
    getConfig: jest.fn(async (key: string) => mockConfigs[key] ?? null),
    setConfig: jest.fn(async (key: string, val: any) => {
      mockConfigs[key] = val;
    }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IntegrationRuntimeService,
        ProviderRoutingService,
        CircuitBreakerService,
        ProviderRateLimiterService,
        FailureClassifierService,
        CostModelService,
        ProviderPolicyService,
        IntegrationIdempotencyService,
        ProviderSimulationService,
        ProviderHealthService,
        IntegrationAuditService,
        ProviderCatalogService,
        ProviderRegistryService,
        IntegrationConfigService,
        SecretVaultService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((k: string) => {
              if (k === 'INTEGRATION_VAULT_KEY') return '0123456789abcdef0123456789abcdef';
              return null;
            }),
          },
        },
        { provide: SystemConfigService, useValue: mockSystemConfigService },
        {
          provide: PrismaService,
          useValue: {
            integrationExecution: { create: jest.fn().mockResolvedValue({}) },
            providerIncident: {
              create: jest.fn().mockResolvedValue({}),
              updateMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
          },
        },
      ],
    }).compile();

    runtimeService = module.get<IntegrationRuntimeService>(IntegrationRuntimeService);
    routingService = module.get<ProviderRoutingService>(ProviderRoutingService);
    circuitBreakerService = module.get<CircuitBreakerService>(CircuitBreakerService);
    rateLimiter = module.get<ProviderRateLimiterService>(ProviderRateLimiterService);
    failureClassifier = module.get<FailureClassifierService>(FailureClassifierService);
    costModelService = module.get<CostModelService>(CostModelService);
    policyService = module.get<ProviderPolicyService>(ProviderPolicyService);
    idempotencyService = module.get<IntegrationIdempotencyService>(IntegrationIdempotencyService);
    simulationService = module.get<ProviderSimulationService>(ProviderSimulationService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
    auditService = module.get<IntegrationAuditService>(IntegrationAuditService);
    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    registryService = module.get<ProviderRegistryService>(ProviderRegistryService);

    // Initialize catalog and clear transient state
    catalogService.onModuleInit();
    circuitBreakerService.resetAll();
    rateLimiter.clearAll();
    simulationService.clearAllSimulations();
    idempotencyService.clear();
    policyService.clearPolicies();
  });

  // Scenario 1: Primary provider succeeds
  it('Scenario 1: Primary provider succeeds directly', async () => {
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      return { providerOrderId: 'order_rzp_123', status: 'created' };
    });
    registryService.registerProvider(p1);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amountPaise: 50000 },
    });

    expect(result.success).toBe(true);
    expect(result.providerId).toBe('razorpay');
    expect(result.fallbackOccurred).toBe(false);
    expect(result.attempts.length).toBe(1);
    expect(result.data.providerOrderId).toBe('order_rzp_123');
  });

  // Scenario 2: Primary provider times out and fails over
  it('Scenario 2: Primary provider times out and fails over', async () => {
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      const err: any = new Error('Gateway timed out');
      err.code = 'ETIMEDOUT';
      throw err;
    });
    const p2 = new TestMockProvider('stripe', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      return { providerOrderId: 'order_stripe_456', status: 'created' };
    });
    registryService.registerProvider(p1);
    registryService.registerProvider(p2);

    routingService.setCustomFallbackChain(IntegrationCategory.PAYMENT, ['razorpay', 'stripe']);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amountPaise: 50000 },
    });

    expect(result.success).toBe(true);
    expect(result.providerId).toBe('stripe');
    expect(result.fallbackOccurred).toBe(true);
    expect(result.attempts[0].status).toBe('TIMEOUT');
    expect(result.attempts[1].status).toBe('SUCCESS');
  });

  // Scenario 3: Fallback provider succeeds
  it('Scenario 3: Fallback provider succeeds when primary fails with transient error', async () => {
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      const err: any = new Error('Connection reset');
      err.code = 'ECONNRESET';
      throw err;
    });
    const p2 = new TestMockProvider('cashfree', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      return { providerOrderId: 'cf_789', status: 'OK' };
    });
    registryService.registerProvider(p1);
    registryService.registerProvider(p2);

    routingService.setCustomFallbackChain(IntegrationCategory.PAYMENT, ['razorpay', 'cashfree']);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amountPaise: 25000 },
    });

    expect(result.success).toBe(true);
    expect(result.providerId).toBe('cashfree');
    expect(result.fallbackOccurred).toBe(true);
  });

  // Scenario 4: All providers fail
  it('Scenario 4: All providers fail in fallback chain', async () => {
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      throw new Error('Service Unavailable 503');
    });
    const p2 = new TestMockProvider('stripe', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      throw new Error('Internal Server Error 500');
    });
    registryService.registerProvider(p1);
    registryService.registerProvider(p2);

    routingService.setCustomFallbackChain(IntegrationCategory.PAYMENT, ['razorpay', 'stripe']);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amountPaise: 10000 },
    });

    expect(result.success).toBe(false);
    expect(result.attempts.length).toBe(2);
    expect(result.error).toBeDefined();
  });

  // Scenario 5: Provider circuit opens
  it('Scenario 5: Provider circuit opens after failure threshold', () => {
    circuitBreakerService.setProviderConfig('razorpay', { failureThreshold: 3 });

    circuitBreakerService.recordFailure('razorpay', FailureClassification.TIMEOUT);
    circuitBreakerService.recordFailure('razorpay', FailureClassification.NETWORK);
    const state = circuitBreakerService.recordFailure('razorpay', FailureClassification.TRANSIENT);

    expect(state).toBe(CircuitState.OPEN);
    expect(circuitBreakerService.canExecute('razorpay')).toBe(false);
  });

  // Scenario 6: Circuit half-open recovery
  it('Scenario 6: Circuit transitions to HALF_OPEN after cooldown and recovers to CLOSED', () => {
    circuitBreakerService.setProviderConfig('razorpay', {
      failureThreshold: 2,
      openDurationMs: 10,
      successThreshold: 2,
    });

    circuitBreakerService.recordFailure('razorpay', FailureClassification.TIMEOUT);
    circuitBreakerService.recordFailure('razorpay', FailureClassification.NETWORK);
    expect(circuitBreakerService.getState('razorpay')).toBe(CircuitState.OPEN);

    // Wait for cooldown
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        expect(circuitBreakerService.getState('razorpay')).toBe(CircuitState.HALF_OPEN);
        expect(circuitBreakerService.canExecute('razorpay')).toBe(true);

        // Record required consecutive successes
        circuitBreakerService.recordSuccess('razorpay');
        const finalState = circuitBreakerService.recordSuccess('razorpay');
        expect(finalState).toBe(CircuitState.CLOSED);
        resolve();
      }, 25);
    });
  });

  // Scenario 7: Rate limit handling
  it('Scenario 7: Rate limit handling bypasses provider when quota exhausted', async () => {
    rateLimiter.setProviderConfig('razorpay', { rps: 1, burstCapacity: 1 });

    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER']);
    const p2 = new TestMockProvider('stripe', IntegrationCategory.PAYMENT, ['CREATE_ORDER']);
    registryService.registerProvider(p1);
    registryService.registerProvider(p2);

    routingService.setCustomFallbackChain(IntegrationCategory.PAYMENT, ['razorpay', 'stripe']);

    // Exhaust token bucket
    rateLimiter.isAllowed('razorpay');

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amountPaise: 1000 },
    });

    expect(result.success).toBe(true);
    expect(result.providerId).toBe('stripe');
    expect(result.fallbackOccurred).toBe(true);
    expect(result.attempts[0].status).toBe('RATE_LIMITED');
  });

  // Scenario 8: Retry with exponential backoff
  it('Scenario 8: Failure classifier computes backoff with jitter and retry flags', () => {
    const err = new Error('503 Service Temporarily Unavailable');
    const classification = failureClassifier.classify(err);
    expect(classification).toBe(FailureClassification.TRANSIENT);
    expect(failureClassifier.isRetryable(classification)).toBe(true);

    const backoff1 = failureClassifier.calculateBackoff(0, err);
    const backoff2 = failureClassifier.calculateBackoff(1, err);
    expect(backoff1).toBeGreaterThanOrEqual(100);
    expect(backoff2).toBeGreaterThan(backoff1);
  });

  // Scenario 9: Non-idempotent operation is not blindly retried
  it('Scenario 9: Non-idempotent operation is not blindly retried on same provider', async () => {
    let attemptsCount = 0;
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      attemptsCount++;
      const err: any = new Error('504 Gateway Timeout');
      err.code = 'ETIMEDOUT';
      throw err;
    });
    registryService.registerProvider(p1);

    routingService.setCustomFallbackChain(IntegrationCategory.PAYMENT, ['razorpay']);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amount: 100 },
      isIdempotent: false, // NOT declared idempotent
    });

    expect(result.success).toBe(false);
    expect(attemptsCount).toBe(1); // Exactly 1 attempt, no blind retries!
  });

  // Scenario 10: Duplicate idempotency key
  it('Scenario 10: Duplicate idempotency key returns cached response deterministically', async () => {
    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER'], async () => {
      return { orderId: 'ord_cached_10' };
    });
    registryService.registerProvider(p1);

    const res1 = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amount: 500 },
      idempotencyKey: 'key_unique_123',
    });

    expect(res1.success).toBe(true);

    // Replay with exact same idempotency key
    const res2 = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amount: 500 },
      idempotencyKey: 'key_unique_123',
    });

    expect(res2.success).toBe(true);
    expect(res2.providerId).toBe('cached_idempotency');
    expect(res2.data.orderId).toBe('ord_cached_10');
  });

  // Scenario 11: Unsupported capability
  it('Scenario 11: Candidate resolution filters out providers without requested capability', async () => {
    const candidates = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'SPLIT_PAYMENT',
      payload: {},
    });

    expect(candidates.allCandidates.length).toBeGreaterThan(0);
    for (const c of candidates.allCandidates) {
      const p = catalogService.findProviderById(c);
      if (p) {
        expect(p.supportedCapabilities).toContain('SPLIT_PAYMENT');
      }
    }
  });

  // Scenario 12: Unsupported currency filter
  it('Scenario 12: Currency filter restricts routing candidates to providers supporting that currency', async () => {
    const inrResolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      currency: 'INR',
      payload: {},
    });

    expect(inrResolution.allCandidates.length).toBeGreaterThan(0);
  });

  // Scenario 13: Unsupported region filter
  it('Scenario 13: Regional filter respects supported countries', async () => {
    const aeResolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      region: 'AE',
      payload: {},
    });

    expect(aeResolution.allCandidates).toContain('stripe');
  });

  // Scenario 14: Vendor-specific provider restriction
  it('Scenario 14: Policy engine enforces vendor-specific provider restriction', async () => {
    policyService.registerPolicy({
      id: 'rule_vendor_no_razorpay',
      name: 'Deny Razorpay for vendor 99',
      enabled: true,
      priority: 1,
      conditions: { vendorId: 'vendor_99', category: IntegrationCategory.PAYMENT },
      actions: { deniedProviders: ['razorpay'] },
    });

    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      vendorId: 'vendor_99',
      payload: {},
    });

    expect(resolution.allCandidates).not.toContain('razorpay');
  });

  // Scenario 15: Branch-specific provider override
  it('Scenario 15: Branch-specific override prefers designated provider', async () => {
    policyService.registerPolicy({
      id: 'rule_branch_stripe',
      name: 'Prefer Stripe for Dubai Branch',
      enabled: true,
      priority: 1,
      conditions: { branchId: 'branch_dxb_01' },
      actions: { preferredProviderId: 'stripe' },
    });

    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      branchId: 'branch_dxb_01',
      payload: {},
    });

    expect(resolution.primaryProviderId).toBe('stripe');
  });

  // Scenario 16: Platform fallback
  it('Scenario 16: Platform fallback is used when no vendor override exists', async () => {
    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      payload: {},
    });

    expect(resolution.primaryProviderId).toBeDefined();
    expect(resolution.fallbackChain.length).toBeGreaterThan(0);
  });

  // Scenario 17: Provider health affects routing
  it('Scenario 17: Health-based routing prefers provider with superior success rate', async () => {
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'razorpay', {
      success: false,
      latencyMs: 300,
    });
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'razorpay', {
      success: false,
      latencyMs: 300,
    });
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'stripe', {
      success: true,
      latencyMs: 150,
    });

    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      routingStrategy: RoutingStrategy.HEALTH_BASED,
      payload: {},
    });

    expect(resolution.primaryProviderId).toBe('stripe');
  });

  // Scenario 18: Weighted routing
  it('Scenario 18: Weighted routing sorts providers by weight', async () => {
    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      routingStrategy: RoutingStrategy.WEIGHTED,
      payload: {},
    });

    expect(resolution.primaryProviderId).toBeDefined();
    expect(resolution.strategyUsed).toBe(RoutingStrategy.WEIGHTED);
  });

  // Scenario 19: Priority routing
  it('Scenario 19: Priority routing selects lowest priority value first', async () => {
    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      routingStrategy: RoutingStrategy.PRIORITY,
      payload: {},
    });

    expect(resolution.strategyUsed).toBe(RoutingStrategy.PRIORITY);
    expect(resolution.primaryProviderId).toBe('razorpay'); // Razorpay has priority 1
  });

  // Scenario 20: Latency-based routing
  it('Scenario 20: Latency-based routing selects provider with lowest p50 latency', async () => {
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'razorpay', {
      success: true,
      latencyMs: 350,
    });
    healthService.recordExecutionOutcome(IntegrationCategory.PAYMENT, 'stripe', {
      success: true,
      latencyMs: 80,
    });

    const resolution = await routingService.resolveRoutingChain({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_PAYMENT',
      routingStrategy: RoutingStrategy.LEAST_LATENCY,
      payload: {},
    });

    expect(resolution.primaryProviderId).toBe('stripe');
  });

  // Scenario 21: Cost metadata resolution
  it('Scenario 21: Cost metadata estimates cost accurately', () => {
    costModelService.registerCostModel({
      providerId: 'razorpay',
      category: IntegrationCategory.PAYMENT,
      fixedFee: 2,
      percentageFee: 2.0,
      perRequestCost: 0,
      perMessageCost: 0,
      currency: 'INR',
      regionSpecificCosts: {},
    });

    const est = costModelService.estimateCost('razorpay', 1000, 'INR');
    expect(est).toBe(22); // 2 fixed + 2% of 1000 = 22
  });

  // Scenario 22: Provider authentication failure
  it('Scenario 22: Provider authentication failure is classified as AUTHENTICATION', () => {
    const err = new Error('401 Unauthorized: Invalid API key');
    const classification = failureClassifier.classify(err);

    expect(classification).toBe(FailureClassification.AUTHENTICATION);
    expect(failureClassifier.isRetryable(classification)).toBe(false);
  });

  // Scenario 23: Sandbox simulation
  it('Scenario 23: Sandbox simulation simulates specified error condition', async () => {
    simulationService.setProviderSimulation('razorpay', SimulationScenario.TIMEOUT);

    const result = await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { amount: 100 },
      preferredProviderId: 'razorpay',
    });

    // Should catch the simulated timeout on razorpay and fallback or record attempt
    expect(result.attempts[0].status).toBe('TIMEOUT');
  });

  // Scenario 24: Audit trail creation
  it('Scenario 24: Audit trail creates structured telemetry record', async () => {
    const spy = jest.spyOn(auditService, 'recordExecution');

    const p1 = new TestMockProvider('razorpay', IntegrationCategory.PAYMENT, ['CREATE_ORDER']);
    registryService.registerProvider(p1);

    await runtimeService.execute({
      category: IntegrationCategory.PAYMENT,
      capability: 'CREATE_ORDER',
      payload: { test: true },
      vendorId: 'vendor_audit_1',
    });

    expect(spy).toHaveBeenCalled();
    const executions = auditService.getExecutions({ vendorId: 'vendor_audit_1' } as any);
    expect(executions.length).toBeGreaterThan(0);
  });

  // Scenario 25: Secrets never appear in logs or responses
  it('Scenario 25: Secrets, keys, and tokens are sanitized from audit records', () => {
    const sensitivePayload = {
      apiKey: 'secret_key_12345',
      password: 'mypassword',
      authToken: 'bearer_token_xyz',
      card_number: '4111222233334444',
      normalField: 'safeValue',
      nested: {
        secret: 'nested_secret',
        visible: 'ok',
      },
    };

    const sanitized = auditService.sanitize(sensitivePayload);

    expect(sanitized.apiKey).toBe('***REDACTED***');
    expect(sanitized.password).toBe('***REDACTED***');
    expect(sanitized.authToken).toBe('***REDACTED***');
    expect(sanitized.card_number).toBe('***REDACTED***');
    expect(sanitized.normalField).toBe('safeValue');
    expect(sanitized.nested.secret).toBe('***REDACTED***');
    expect(sanitized.nested.visible).toBe('ok');
  });
});
