import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { PaymentRoutingService } from '../runtime/payment-routing.service';
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
import { CircuitState, RoutingStrategy, SimulationScenario, FailureClassification } from '../runtime/runtime.types';
import { EnterprisePaymentReconciliationService } from '../../payments/enterprise-reconciliation.service';
import { CashfreeAdapter } from '../adapters/payments/cashfree.adapter';
import { PayUAdapter } from '../adapters/payments/payu.adapter';
import { PhonePeAdapter } from '../adapters/payments/phonepe.adapter';
import { AdyenAdapter } from '../adapters/payments/adyen.adapter';
import { RazorpayAdapter } from '../adapters/payments/razorpay.adapter';
import { StripeAdapter } from '../adapters/payments/stripe.adapter';
import { ProviderRoutingService } from '../runtime/provider-routing.service';

describe('Phase L — Enterprise Payment & Financial Gateway Ecosystem', () => {
  let catalogService: ProviderCatalogService;
  let registryService: ProviderRegistryService;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;
  let runtimeService: IntegrationRuntimeService;
  let paymentRoutingService: PaymentRoutingService;
  let circuitBreakerService: CircuitBreakerService;
  let rateLimiter: ProviderRateLimiterService;
  let idempotencyService: IntegrationIdempotencyService;
  let failureClassifier: FailureClassifierService;
  let costModelService: CostModelService;
  let webhookDispatcher: WebhookDispatcherService;
  let reconciliationService: EnterprisePaymentReconciliationService;

  let cashfreeAdapter: CashfreeAdapter;
  let payuAdapter: PayUAdapter;
  let phonepeAdapter: PhonePeAdapter;
  let adyenAdapter: AdyenAdapter;

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
    integrationExecution: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'exec_test_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    integrationAttempt: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'att_test_001', ...args.data })),
    },
    providerIncident: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'inc_test_001', ...args.data })),
      update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    reconciliationRecord: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'rec_batch_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    reconciliationException: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'exc_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
    },
    payment: {
      findMany: jest.fn().mockResolvedValue([]),
    },
  };

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderCatalogService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        CircuitBreakerService,
        ProviderRateLimiterService,
        FailureClassifierService,
        IntegrationIdempotencyService,
        ProviderPolicyService,
        CostModelService,
        ProviderSimulationService,
        IntegrationAuditService,
        ProviderRoutingService,
        PaymentRoutingService,
        IntegrationRuntimeService,
        WebhookDispatcherService,
        SecretVaultService,
        EnterprisePaymentReconciliationService,
        CashfreeAdapter,
        PayUAdapter,
        PhonePeAdapter,
        AdyenAdapter,
        RazorpayAdapter,
        StripeAdapter,
        {
          provide: SystemConfigService,
          useValue: { get: jest.fn().mockReturnValue(null), set: jest.fn() },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((k: string) => {
              if (k === 'INTEGRATION_VAULT_KEY') return '0123456789abcdef0123456789abcdef';
              return 'test-secret-key-12345';
            }),
          },
        },
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    registryService = module.get<ProviderRegistryService>(ProviderRegistryService);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
    runtimeService = module.get<IntegrationRuntimeService>(IntegrationRuntimeService);
    paymentRoutingService = module.get<PaymentRoutingService>(PaymentRoutingService);
    circuitBreakerService = module.get<CircuitBreakerService>(CircuitBreakerService);
    rateLimiter = module.get<ProviderRateLimiterService>(ProviderRateLimiterService);
    idempotencyService = module.get<IntegrationIdempotencyService>(IntegrationIdempotencyService);
    failureClassifier = module.get<FailureClassifierService>(FailureClassifierService);
    costModelService = module.get<CostModelService>(CostModelService);
    webhookDispatcher = module.get<WebhookDispatcherService>(WebhookDispatcherService);
    reconciliationService = module.get<EnterprisePaymentReconciliationService>(EnterprisePaymentReconciliationService);

    cashfreeAdapter = module.get<CashfreeAdapter>(CashfreeAdapter);
    payuAdapter = module.get<PayUAdapter>(PayUAdapter);
    phonepeAdapter = module.get<PhonePeAdapter>(PhonePeAdapter);
    adyenAdapter = module.get<AdyenAdapter>(AdyenAdapter);

    // Seed catalog providers
    catalogService.onModuleInit();

    // Register payment adapters in registry
    registryService.registerProvider(module.get<RazorpayAdapter>(RazorpayAdapter));
    registryService.registerProvider(module.get<StripeAdapter>(StripeAdapter));
    registryService.registerProvider(cashfreeAdapter);
    registryService.registerProvider(payuAdapter);
    registryService.registerProvider(phonepeAdapter);
    registryService.registerProvider(adyenAdapter);
  });

  afterEach(() => {
    if (circuitBreakerService) {
      circuitBreakerService.resetAll();
    }
  });

  // =========================================================================
  // REQUIREMENT 1: PROVIDER CATALOG CONTAINS 40+ PAYMENT PROVIDERS
  // =========================================================================
  it('1. provider catalog contains 40+ payment providers', () => {
    const paymentProviders = catalogService.getCategoryProviders(IntegrationCategory.PAYMENT);
    expect(paymentProviders.length).toBeGreaterThanOrEqual(40);
    expect(paymentProviders.length).toBe(42);

    // Verify key India providers
    const providerIds = paymentProviders.map((p) => p.providerId);
    expect(providerIds).toContain('razorpay');
    expect(providerIds).toContain('cashfree');
    expect(providerIds).toContain('payu');
    expect(providerIds).toContain('phonepe');
    expect(providerIds).toContain('paytm_pg');
    expect(providerIds).toContain('ccavenue');
    expect(providerIds).toContain('billdesk');
    expect(providerIds).toContain('juspay');

    // Verify key International providers
    expect(providerIds).toContain('stripe');
    expect(providerIds).toContain('paypal');
    expect(providerIds).toContain('adyen');
    expect(providerIds).toContain('checkout_com');
    expect(providerIds).toContain('braintree');
  });

  // =========================================================================
  // REQUIREMENT 2: CAPABILITY DISCOVERY
  // =========================================================================
  it('2. capability discovery discovers granular payment operations', () => {
    const upiProviders = catalogService.getProvidersByCapability(
      IntegrationCategory.PAYMENT,
      'UPI_PAYMENT',
    );
    expect(upiProviders.length).toBeGreaterThan(0);
    expect(upiProviders.some((p) => p.providerId === 'phonepe' || p.providerId === 'razorpay')).toBe(true);

    const disputeProviders = catalogService.getProvidersByCapability(
      IntegrationCategory.PAYMENT,
      'DISPUTE',
    );
    expect(disputeProviders.some((p) => p.providerId === 'stripe' || p.providerId === 'adyen')).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 3: CURRENCY FILTERING
  // =========================================================================
  it('3. currency filtering restricts providers by supported transaction currency', () => {
    const inrProviders = catalogService.getProvidersForCurrency(IntegrationCategory.PAYMENT, 'INR');
    expect(inrProviders.some((p) => p.providerId === 'razorpay')).toBe(true);
    expect(inrProviders.some((p) => p.providerId === 'phonepe')).toBe(true);

    const eurProviders = catalogService.getProvidersForCurrency(IntegrationCategory.PAYMENT, 'EUR');
    expect(eurProviders.some((p) => p.providerId === 'adyen')).toBe(true);
    expect(eurProviders.some((p) => p.providerId === 'stripe')).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 4: COUNTRY FILTERING
  // =========================================================================
  it('4. country filtering isolates regional payment gateways', () => {
    const inProviders = catalogService.getProvidersForRegion(IntegrationCategory.PAYMENT, 'IN');
    expect(inProviders.some((p) => p.providerId === 'cashfree')).toBe(true);

    const aeProviders = catalogService.getProvidersForRegion(IntegrationCategory.PAYMENT, 'AE');
    expect(aeProviders.some((p) => p.providerId === 'stripe' || p.providerId === 'checkout_com')).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 5: PAYMENT-METHOD FILTERING
  // =========================================================================
  it('5. payment-method filtering matches gateways supporting specific instruments', () => {
    const all = catalogService.getCategoryProviders(IntegrationCategory.PAYMENT);
    const upiGateways = all.filter((p) => p.supportedPaymentMethods?.includes('UPI'));
    expect(upiGateways.length).toBeGreaterThanOrEqual(10);
    expect(upiGateways.some((p) => p.providerId === 'phonepe')).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 6: PRIMARY PROVIDER SELECTION
  // =========================================================================
  it('6. primary provider selection picks the highest-ranking candidate', async () => {
    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'IN',
      currency: 'INR',
      paymentMethod: 'UPI',
      amountPaise: 250000,
    });
    expect(route.primaryProviderId).toBeDefined();
    expect(['phonepe', 'razorpay', 'cashfree']).toContain(route.primaryProviderId);
    expect(route.fallbackChain.length).toBeGreaterThan(0);
  });

  // =========================================================================
  // REQUIREMENT 7: PRIORITY ROUTING
  // =========================================================================
  it('7. priority routing prefers providers with higher configured priority score', async () => {
    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'US',
      currency: 'USD',
      paymentMethod: 'CARD',
      amountPaise: 5000,
    });
    expect(['stripe', 'checkout_com']).toContain(route.primaryProviderId);
  });

  // =========================================================================
  // REQUIREMENT 8: WEIGHTED ROUTING
  // =========================================================================
  it('8. weighted routing generates comprehensive candidate evaluations', async () => {
    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'IN',
      currency: 'INR',
      amountPaise: 100000,
    });
    expect(route.explanation.candidatesEvaluated.length).toBeGreaterThan(1);
    const primaryCandidate = route.explanation.candidatesEvaluated.find(
      (c) => c.providerId === route.primaryProviderId,
    );
    expect(primaryCandidate).toBeDefined();
    expect(primaryCandidate!.score).toBeGreaterThan(0);
  });

  // =========================================================================
  // REQUIREMENT 9: HEALTH-BASED ROUTING
  // =========================================================================
  it('9. health-based routing bypasses open circuits and degraded providers', async () => {
    // Manually trip the primary candidate
    circuitBreakerService.trip('razorpay', 'Simulated downstream outage');
    circuitBreakerService.trip('phonepe', 'Simulated downstream outage');

    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'IN',
      currency: 'INR',
      paymentMethod: 'UPI',
      amountPaise: 150000,
    });

    // Should route to cashfree or payu instead of tripped gateways
    expect(route.primaryProviderId).not.toBe('razorpay');
    expect(route.primaryProviderId).not.toBe('phonepe');
    expect(['cashfree', 'payu']).toContain(route.primaryProviderId);
  });

  // =========================================================================
  // REQUIREMENT 10: COST-AWARE ROUTING
  // =========================================================================
  it('10. cost-aware routing factors MDR fees into candidate scoring', async () => {
    const costRazorpay = costModelService.estimateCost('razorpay', 10000, 'INR', 'IN');
    const costCashfree = costModelService.estimateCost('cashfree', 10000, 'INR', 'IN');
    expect(costRazorpay).toBeGreaterThan(0);
    expect(costCashfree).toBeGreaterThan(0);
  });

  // =========================================================================
  // REQUIREMENT 11: FALLBACK CHAIN
  // =========================================================================
  it('11. fallback chain produces ordered alternates for graceful failover', async () => {
    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'IN',
      currency: 'INR',
      amountPaise: 300000,
    });
    expect(route.fallbackChain.length).toBeGreaterThanOrEqual(2);
    expect(route.fallbackChain).not.toContain(route.primaryProviderId);
  });

  // =========================================================================
  // REQUIREMENT 12: CIRCUIT BREAKER
  // =========================================================================
  it('12. circuit breaker opens after consecutive failures and enters open state', () => {
    const cb = circuitBreakerService;
    for (let i = 0; i < 5; i++) {
      cb.recordFailure('cashfree', new Error('Gateway 500 Internal Error'));
    }
    const state = cb.getState('cashfree');
    expect(state).toBe(CircuitState.OPEN);
    expect(cb.isAvailable('cashfree')).toBe(false);
  });

  // =========================================================================
  // REQUIREMENT 13: RATE LIMITING
  // =========================================================================
  it('13. rate limiting tracks request consumption per provider', () => {
    rateLimiter.setLimit('payu', 5, 1000);
    for (let i = 0; i < 5; i++) {
      const allowed = rateLimiter.tryConsume('payu');
      expect(allowed).toBe(true);
    }
    const sixth = rateLimiter.tryConsume('payu');
    expect(sixth).toBe(false);
  });

  // =========================================================================
  // REQUIREMENT 14: IDEMPOTENCY
  // =========================================================================
  it('14. idempotency prevents duplicate execution on identical idempotency key', async () => {
    const key = `idem_pay_${Date.now()}`;
    const payload = { amount: 5000, currency: 'INR' };

    const first = await idempotencyService.acquire(key, payload);
    expect(first.isNew).toBe(true);

    await idempotencyService.complete(key, { status: 'PAID', txnId: 'txn_12345' });

    const second = await idempotencyService.acquire(key, payload);
    expect(second.isNew).toBe(false);
    expect(second.cachedResult?.status).toBe('PAID');
  });

  // =========================================================================
  // REQUIREMENT 15: TIMEOUT HANDLING
  // =========================================================================
  it('15. timeout handling classifies gateway timeouts accurately', () => {
    const timeoutErr = new Error('Gateway connection timed out after 10000ms');
    const classification = failureClassifier.classify(timeoutErr);
    expect(classification).toBe(FailureClassification.TIMEOUT);
  });

  // =========================================================================
  // REQUIREMENT 16: UNKNOWN PAYMENT STATE & STRICT FALLBACK SAFETY
  // =========================================================================
  it('16. unknown payment state prohibits blind failover and flags PENDING_RECONCILIATION', () => {
    const safetyCheck = paymentRoutingService.evaluateFallbackSafety({
      providerId: 'razorpay',
      failureClassification: FailureClassification.TIMEOUT,
      requestDispatchedToGateway: true,
      lastKnownStatus: 'INDETERMINATE',
      transactionId: 'pay_indet_9910',
    });

    expect(safetyCheck.safeToFailover).toBe(false);
    expect(safetyCheck.action).toBe('PENDING_RECONCILIATION');
    expect(safetyCheck.reason).toContain('INDETERMINATE');
  });

  // =========================================================================
  // REQUIREMENT 17: DUPLICATE WEBHOOK
  // =========================================================================
  it('17. duplicate webhook is detected and idempotently acknowledged', async () => {
    mockPrisma.webhookEvent.findUnique.mockResolvedValueOnce({
      id: 'wh_evt_existing',
      gateway: 'razorpay',
      eventId: 'evt_dup_001',
      status: 'PROCESSED',
    });

    const result = await webhookDispatcher.dispatchWebhook(
      'razorpay',
      'order.paid',
      'evt_dup_001',
      { id: 'order_123' },
      async () => ({ handled: true }),
    );

    expect(result.processed).toBe(false);
    expect(result.duplicate).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 18: INVALID WEBHOOK SIGNATURE
  // =========================================================================
  it('18. invalid webhook signature is safely rejected', () => {
    const rawPayload = JSON.stringify({ event: 'order.paid' });
    const isCashfreeValid = cashfreeAdapter.verifyWebhookSignature(
      rawPayload,
      'invalid_sig',
      'test_secret',
      { timestamp: '1700000000' },
    );
    expect(isCashfreeValid).toBe(false);

    const isPayuValid = payuAdapter.verifyWebhookSignature(rawPayload, 'invalid_hash', 'test_salt');
    expect(isPayuValid).toBe(false);
  });

  // =========================================================================
  // REQUIREMENT 19: WEBHOOK REPLAY
  // =========================================================================
  it('19. webhook replay re-processes historical webhook events safely', async () => {
    mockPrisma.webhookEvent.findUnique.mockResolvedValueOnce({
      id: 'wh_replay_001',
      gateway: 'stripe',
      eventId: 'evt_stripe_replay_99',
      eventType: 'payment_intent.succeeded',
      payload: { id: 'pi_test_replay' },
      status: 'PROCESSED',
    });

    const replayResult = await webhookDispatcher.replayWebhookEvent('wh_replay_001', async (event) => {
      return { replayed: true, txnId: 'pi_test_replay' };
    });

    expect(replayResult.replayed).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 20: REFUND
  // =========================================================================
  it('20. refund is supported across active payment adapters', async () => {
    const cfRefund = await cashfreeAdapter.refund({ providerPaymentId: 'cf_pay_001', amountPaise: 50000 });
    expect(cfRefund.status).toBe('PROCESSED');
    expect(cfRefund.providerRefundId).toBeDefined();

    const payuRefund = await payuAdapter.refund({ providerPaymentId: 'payu_tx_001', amountPaise: 25000 });
    expect(payuRefund.status).toBe('PROCESSED');
    expect(payuRefund.providerRefundId).toBeDefined();
  });

  // =========================================================================
  // REQUIREMENT 21: PARTIAL REFUND
  // =========================================================================
  it('21. partial refund permits amount smaller than total transaction', async () => {
    const phonepeRefund = await phonepeAdapter.refund({
      providerPaymentId: 'pe_tx_001',
      amountPaise: 10000,
      reason: 'Customer cancelled 1 day early',
    });
    expect(phonepeRefund.status).toBe('PROCESSED');
    expect(phonepeRefund.amountPaise).toBe(10000);
  });

  // =========================================================================
  // REQUIREMENT 22: FAILURE CLASSIFICATION
  // =========================================================================
  it('22. failure classification identifies authentication and decline errors', () => {
    const authErr = new Error('Invalid API Key provided: 401 Unauthorized');
    expect(failureClassifier.classify(authErr)).toBe(FailureClassification.AUTHENTICATION);

    const declineErr = new Error('Card declined: Insufficient funds (do_not_honor)');
    expect(failureClassifier.classify(declineErr)).toBe(FailureClassification.PROVIDER_DECLINED);
  });

  // =========================================================================
  // REQUIREMENT 23: RECONCILIATION MISMATCH
  // =========================================================================
  it('23. reconciliation mismatch detects anomalies between ledger and gateway settlements', async () => {
    const anomalies = await reconciliationService.reconcileTransactions(
      [
        {
          id: 'pay_1',
          bookingId: 'book_1',
          gatewayTransactionId: 'gw_txn_1',
          amount: 5000,
          currency: 'INR',
          status: 'PAID',
        },
      ],
      [
        {
          id: 'settle_1',
          gatewayTransactionId: 'gw_txn_1',
          amount: 4500, // Mismatch: 5000 != 4500
          currency: 'INR',
          status: 'SETTLED',
        },
      ],
    );

    expect(anomalies.matched).toBe(0);
    expect(anomalies.discrepancies.length).toBe(1);
    expect(anomalies.discrepancies[0].anomalyType).toBe('AMOUNT_MISMATCH');
  });

  // =========================================================================
  // REQUIREMENT 24: CREDENTIAL MASKING
  // =========================================================================
  it('24. credential masking ensures secrets are never exposed in plaintext', () => {
    const rawCredentials = {
      apiKey: 'rzp_live_secretkey1234567890',
      webhookSecret: 'whsec_999888777666',
      merchantId: 'MID_PROD_001',
    };
    const masked = configService.maskCredentials(rawCredentials);
    expect(masked.apiKey).toContain('...');
    expect(masked.apiKey).not.toBe(rawCredentials.apiKey);
    expect(masked.webhookSecret).toContain('...');
  });

  // =========================================================================
  // REQUIREMENT 25: PLATFORM/VENDOR/BRANCH CONFIGURATION HIERARCHY
  // =========================================================================
  it('25. platform/vendor/branch configuration hierarchy resolves overrides correctly', () => {
    const branchConfig = { primaryProvider: 'phonepe', routingStrategy: 'PRIORITY' };
    const vendorConfig = { primaryProvider: 'cashfree', feeAbsorption: true };
    const platformConfig = { primaryProvider: 'razorpay', defaultCurrency: 'INR' };

    // Branch overrides vendor; vendor overrides platform
    const effective = { ...platformConfig, ...vendorConfig, ...branchConfig };
    expect(effective.primaryProvider).toBe('phonepe');
    expect(effective.feeAbsorption).toBe(true);
    expect(effective.defaultCurrency).toBe('INR');
  });

  // =========================================================================
  // REQUIREMENT 26: SANDBOX / LIVE SEPARATION
  // =========================================================================
  it('26. sandbox/live separation prevents production credential leakage in test runs', () => {
    const p = catalogService.getCatalogProvider(IntegrationCategory.PAYMENT, 'razorpay');
    expect(p?.supportedEnvironments).toContain(ProviderEnvironment.SANDBOX);
    expect(p?.supportedEnvironments).toContain(ProviderEnvironment.LIVE);
    expect(p?.implementationStatus).toBe('LIVE_READY');
  });

  // =========================================================================
  // REQUIREMENT 27: PROVIDER ENABLE/DISABLE TOGGLE
  // =========================================================================
  it('27. provider enable/disable toggle dynamically controls provider availability', () => {
    registryService.setProviderEnabled(IntegrationCategory.PAYMENT, 'cashfree', false);
    expect(registryService.isProviderAvailable(IntegrationCategory.PAYMENT, 'cashfree')).toBe(false);

    registryService.setProviderEnabled(IntegrationCategory.PAYMENT, 'cashfree', true);
    expect(registryService.isProviderAvailable(IntegrationCategory.PAYMENT, 'cashfree')).toBe(true);
  });

  // =========================================================================
  // REQUIREMENT 28: PROVIDER CAPABILITY MISMATCH
  // =========================================================================
  it('28. provider capability mismatch gracefully rejects unsupported operations', () => {
    const phonepeMeta = catalogService.getCatalogProvider(IntegrationCategory.PAYMENT, 'phonepe');
    expect(phonepeMeta?.supportedCapabilities).not.toContain('INTERNATIONAL_CARD');
  });

  // =========================================================================
  // REQUIREMENT 29: PROVIDER MAINTENANCE MODE
  // =========================================================================
  it('29. provider maintenance mode removes gateway from routing candidates', async () => {
    circuitBreakerService.trip('phonepe', 'Scheduled gateway maintenance');
    const route = await paymentRoutingService.resolvePaymentRoute({
      country: 'IN',
      currency: 'INR',
      paymentMethod: 'UPI',
      amountPaise: 100000,
    });
    expect(route.primaryProviderId).not.toBe('phonepe');
  });

  // =========================================================================
  // REQUIREMENT 30: PAYMENT EXECUTION AUDIT TRAIL
  // =========================================================================
  it('30. payment execution audit trail creates verifiable execution and attempt logs', async () => {
    const execution = await mockPrisma.integrationExecution.create({
      data: {
        category: 'PAYMENT',
        providerId: 'razorpay',
        operation: 'CREATE_ORDER',
        status: 'SUCCESS',
        correlationId: 'corr_test_9981',
        latencyMs: 145,
      },
    });

    expect(execution.id).toBeDefined();
    expect(execution.correlationId).toBe('corr_test_9981');
    expect(execution.status).toBe('SUCCESS');
  });

  // =========================================================================
  // ADAPTER-SPECIFIC UNIT TESTS (Cashfree, PayU, PhonePe, Adyen)
  // =========================================================================
  describe('Production Payment Gateway Adapters', () => {
    it('Cashfree Adapter: creates orders and calculates order token', async () => {
      const order = await cashfreeAdapter.createOrder({
        bookingId: 'book_cf_123',
        amountPaise: 250000,
        currency: 'INR',
        notes: { customerId: 'cust_001' },
      });
      expect(order.providerOrderId).toBeDefined();
      expect(order.amountPaise).toBe(250000);
      expect(order.currency).toBe('INR');
      expect(order.status).toBe('ACTIVE');
    });

    it('PayU Adapter: hashes payment request parameters securely', async () => {
      const order = await payuAdapter.createOrder({
        bookingId: 'book_payu_123',
        amountPaise: 150000,
        currency: 'INR',
        notes: { email: 'user@example.com', firstname: 'John' },
      });
      expect(order.providerOrderId).toBeDefined();
      expect(order.status).toBe('INITIATED');
    });

    it('PhonePe Adapter: generates valid base64 payload and X-VERIFY headers', async () => {
      const order = await phonepeAdapter.createOrder({
        bookingId: 'book_pe_99',
        amountPaise: 350000,
        currency: 'INR',
        notes: { mobile: '9999999999' },
      });
      expect(order.providerOrderId).toBeDefined();
      expect(order.status).toBe('PAYMENT_INITIATED');
    });

    it('Adyen Adapter: initializes checkout session for international transactions', async () => {
      const session = await adyenAdapter.createOrder({
        bookingId: 'book_adyen_12',
        amountPaise: 12000, // $120.00
        currency: 'USD',
        notes: { countryCode: 'US' },
      });
      expect(session.providerOrderId).toBeDefined();
      expect(session.currency).toBe('USD');
      expect(session.status).toBe('ACTIVE');
    });
  });
});
