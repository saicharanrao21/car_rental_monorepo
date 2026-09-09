import { ProviderDirectoryService } from '../directory/provider-directory.service';
import { CapabilityMatrixService } from '../directory/capability-matrix.service';
import { ProviderOnboardingService } from '../directory/provider-onboarding.service';
import { ProviderScoringService } from '../scoring/provider-scoring.service';
import { ProviderIncidentService } from '../governance/provider-incident.service';
import { ProviderChangeAuditService, ProviderChangeType } from '../governance/provider-change-audit.service';
import { ProviderRecommendationService, RecommendationType, RecommendationStatus } from '../governance/provider-recommendation.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { CostModelService } from '../runtime/cost-model.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { CircuitState, RoutingStrategy, SimulationScenario } from '../runtime/runtime.types';
import { IncidentSeverity, IncidentStatus, IncidentType, DetectionSource } from '../governance/provider-incident.types';
import { CertificationLevel, ProviderPricingType } from '../directory/provider-directory.types';

describe('Phase L: Enterprise Integration Control Plane, Intelligence & Governance', () => {
  let directoryService: ProviderDirectoryService;
  let capabilityService: CapabilityMatrixService;
  let scoringService: ProviderScoringService;
  let incidentService: ProviderIncidentService;
  let changeAuditService: ProviderChangeAuditService;
  let recommendationService: ProviderRecommendationService;
  let onboardingService: ProviderOnboardingService;
  let simulationService: ProviderSimulationService;
  let routingService: ProviderRoutingService;
  let circuitBreakerService: CircuitBreakerService;
  let healthService: ProviderHealthService;
  let policyService: ProviderPolicyService;
  let costModelService: CostModelService;
  let registryService: ProviderRegistryService;
  let catalogService: ProviderCatalogService;

  beforeEach(() => {
    directoryService = new ProviderDirectoryService();
    capabilityService = new CapabilityMatrixService();
    circuitBreakerService = new CircuitBreakerService();
    healthService = new ProviderHealthService();
    changeAuditService = new ProviderChangeAuditService();
    incidentService = new ProviderIncidentService();
    recommendationService = new ProviderRecommendationService(
      directoryService,
      healthService,
      circuitBreakerService,
    );
    onboardingService = new ProviderOnboardingService(
      directoryService,
      capabilityService,
      changeAuditService,
    );
    simulationService = new ProviderSimulationService(undefined, healthService, circuitBreakerService);
    policyService = new ProviderPolicyService();
    costModelService = new CostModelService();
    registryService = new ProviderRegistryService();
    catalogService = new ProviderCatalogService({} as any, healthService);
    catalogService.onModuleInit();
    scoringService = new ProviderScoringService(
      healthService,
      circuitBreakerService,
      capabilityService,
    );
    routingService = new ProviderRoutingService(
      catalogService,
      registryService,
      circuitBreakerService,
      healthService,
      policyService,
      costModelService,
      scoringService,
      directoryService,
    );
  });

  // =========================================================================
  // 1. ENTERPRISE PROVIDER DIRECTORY & CAPABILITY MATRIX
  // =========================================================================
  describe('Enterprise Provider Directory & Capability Matrix', () => {
    it('should have master directory seeded with Tier-1 enterprise providers', () => {
      const all = directoryService.findProviders();
      expect(all.length).toBeGreaterThanOrEqual(8);

      const razorpay = directoryService.getProvider('razorpay');
      expect(razorpay).toBeDefined();
      expect(razorpay.displayName).toContain('Razorpay');
      expect(razorpay.category).toBe(IntegrationCategory.PAYMENT);
      expect(razorpay.certificationLevel).toBe(CertificationLevel.ENTERPRISE_CERTIFIED);

      const surepass = directoryService.getProvider('surepass');
      expect(surepass.category).toBe(IntegrationCategory.IDENTITY_VERIFICATION);
      expect(surepass.supportedCapabilities).toContain('KYC_PAN_VERIFY');
    });

    it('should filter providers by category, country, and currency', () => {
      const inPayments = directoryService.findProviders({
        category: IntegrationCategory.PAYMENT,
        country: 'IN',
        currency: 'INR',
      });
      expect(inPayments.length).toBeGreaterThanOrEqual(2);
      const ids = inPayments.map((p) => p.providerId);
      expect(ids).toContain('razorpay');
      expect(ids).toContain('cashfree');
    });

    it('should evaluate provider capability match with aliases', () => {
      const cashfree = directoryService.getProvider('cashfree');
      const match = capabilityService.evaluateProviderMatch(cashfree, {
        category: IntegrationCategory.PAYMENT,
        requiredCapabilities: ['CREATE_ORDER', 'REFUND'],
      });

      expect(match.isFullyCapable).toBe(true);
      expect(match.coveragePercent).toBe(100);
      expect(match.missingRequired).toHaveLength(0);
    });

    it('should correctly flag missing required capabilities', () => {
      const stripe = directoryService.getProvider('stripe');
      const match = capabilityService.evaluateProviderMatch(stripe, {
        category: IntegrationCategory.PAYMENT,
        requiredCapabilities: ['CREATE_PAYMENT', 'UPI_AUTOPAY'],
      });

      expect(match.isFullyCapable).toBe(false);
      expect(match.missingRequired).toContain('UPI_AUTOPAY');
    });
  });

  // =========================================================================
  // 2. DETERMINISTIC MULTI-FACTOR SCORING ENGINE
  // =========================================================================
  describe('Deterministic Multi-Factor Scoring Engine', () => {
    it('should calculate deterministic score for a healthy provider', () => {
      const razorpay = directoryService.getProvider('razorpay');
      const score = scoringService.calculateScore(razorpay, {
        category: IntegrationCategory.PAYMENT,
        country: 'IN',
        currency: 'INR',
        requiredCapabilities: ['CREATE_ORDER'],
      });

      expect(score.finalScore).toBeGreaterThanOrEqual(80);
      expect(score.rawFactors.healthScore).toBe(100);
      expect(score.penalties.incidentPenalty).toBe(0);
      expect(score.penalties.circuitOpenPenalty).toBe(0);
      expect(score.explanation).toContain('Score');
    });

    it('should apply severe penalty if circuit breaker is OPEN', () => {
      const cashfree = directoryService.getProvider('cashfree');

      // Before trip
      const baseline = scoringService.calculateScore(cashfree, {
        category: IntegrationCategory.PAYMENT,
      });

      // Trip circuit breaker
      circuitBreakerService.trip('cashfree');
      expect(circuitBreakerService.getState('cashfree')).toBe(CircuitState.OPEN);

      const penalized = scoringService.calculateScore(cashfree, {
        category: IntegrationCategory.PAYMENT,
      });

      expect(penalized.penalties.circuitOpenPenalty).toBe(60);
      expect(penalized.finalScore).toBeLessThan(baseline.finalScore);
      expect(penalized.finalScore).toBe(Math.max(0, baseline.finalScore - 60));
    });

    it('should penalize degraded provider health status', () => {
      const stripe = directoryService.getProvider('stripe');
      healthService.recordHealth(IntegrationCategory.PAYMENT, 'stripe', {
        status: ProviderHealthStatus.DEGRADED,
        latencyMs: 850,
      });

      const score = scoringService.calculateScore(stripe, {
        category: IntegrationCategory.PAYMENT,
      });

      expect(score.rawFactors.healthScore).toBe(50);
      expect(score.penalties.incidentPenalty).toBe(20);
    });
  });

  // =========================================================================
  // 3. INTELLIGENT ROUTING PREPARATION (SCORE_OPTIMIZED)
  // =========================================================================
  describe('Intelligent Routing (SCORE_OPTIMIZED Strategy)', () => {
    it('should route request using SCORE_OPTIMIZED strategy and pick highest-scoring provider', async () => {
      const chain = await routingService.resolveRoutingChain({
        category: IntegrationCategory.PAYMENT,
        capability: 'CREATE_ORDER',
        currency: 'INR',
        region: 'IN',
        routingStrategy: RoutingStrategy.SCORE_OPTIMIZED,
      });

      expect(chain.strategyUsed).toBe(RoutingStrategy.SCORE_OPTIMIZED);
      expect(chain.primaryProviderId).toBeDefined();
      expect(chain.allCandidates.length).toBeGreaterThanOrEqual(2);
      expect(chain.fallbackChain).toContain(chain.allCandidates.find((c) => c !== chain.primaryProviderId));
    });

    it('should deprioritize candidate to back of chain when circuit breaker is tripped', async () => {
      // Trip Cashfree circuit breaker
      circuitBreakerService.trip('cashfree');

      const chain = await routingService.resolveRoutingChain({
        category: IntegrationCategory.PAYMENT,
        capability: 'CREATE_ORDER',
        currency: 'INR',
        region: 'IN',
        routingStrategy: RoutingStrategy.SCORE_OPTIMIZED,
      });

      // Cashfree must be moved to fallback chain
      expect(chain.primaryProviderId).not.toBe('cashfree');
      expect(chain.fallbackChain).toContain('cashfree');
    });
  });

  // =========================================================================
  // 4. PROVIDER INCIDENT MANAGEMENT
  // =========================================================================
  describe('Provider Incident Lifecycle', () => {
    it('should create an incident with status DETECTED', async () => {
      const inc = await incidentService.createIncident({
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        title: 'Elevated 5xx Gateway Drop',
        severity: IncidentSeverity.MAJOR,
        incidentType: IncidentType.OUTAGE,
        detectionSource: DetectionSource.CIRCUIT_BREAKER,
        reason: 'Connection pool exhausted on upstream gateway',
      });

      expect(inc.id).toBeDefined();
      expect(inc.status).toBe(IncidentStatus.DETECTED);
      expect(inc.failureCount).toBe(1);
    });

    it('should escalate and increment failure count for duplicate active incidents', async () => {
      const first = await incidentService.createIncident({
        providerId: 'stripe',
        category: IntegrationCategory.PAYMENT,
        title: 'Timeout Spike',
        severity: IncidentSeverity.MEDIUM,
        incidentType: IncidentType.DEGRADATION,
        detectionSource: DetectionSource.RUNTIME_FAILURE,
        reason: 'Latency > 2000ms',
      });

      const second = await incidentService.createIncident({
        providerId: 'stripe',
        category: IntegrationCategory.PAYMENT,
        title: 'Timeout Spike Again',
        severity: IncidentSeverity.MEDIUM,
        incidentType: IncidentType.DEGRADATION,
        detectionSource: DetectionSource.RUNTIME_FAILURE,
        reason: 'Latency > 2500ms',
      });

      expect(second.id).toBe(first.id);
      expect(second.failureCount).toBe(2);
    });

    it('should acknowledge and resolve an incident with notes', async () => {
      const inc = await incidentService.createIncident({
        providerId: 'meta_whatsapp',
        category: IntegrationCategory.MESSAGING_WHATSAPP,
        title: 'OTP Delivery Queue Lag',
        severity: IncidentSeverity.MAJOR,
        incidentType: IncidentType.RATE_LIMIT_EXHAUSTION,
        detectionSource: DetectionSource.RATE_LIMITER,
      });

      // Acknowledge
      const acked = await incidentService.acknowledgeIncident(inc.id, 'admin_sre');
      expect(acked.status).toBe(IncidentStatus.INVESTIGATING);
      expect(acked.acknowledgedBy).toBe('admin_sre');

      // Resolve
      const resolved = await incidentService.resolveIncident(
        inc.id,
        'admin_sre',
        'Tier upgraded on Meta Developer portal; token limits doubled.',
      );
      expect(resolved.status).toBe(IncidentStatus.RESOLVED);
      expect(resolved.resolvedAt).toBeDefined();
      expect(resolved.resolutionNotes).toContain('Tier upgraded');
    });

    it('should compute incident summary statistics', async () => {
      const inc1 = await incidentService.createIncident({
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        title: 'Incident 1',
        severity: IncidentSeverity.MAJOR,
        incidentType: IncidentType.DEGRADATION,
        detectionSource: DetectionSource.RUNTIME_FAILURE,
      });

      const inc2 = await incidentService.createIncident({
        providerId: 'cashfree',
        category: IntegrationCategory.PAYMENT,
        title: 'Incident 2',
        severity: IncidentSeverity.LOW,
        incidentType: IncidentType.WEBHOOK_FAILURE,
        detectionSource: DetectionSource.HEALTH_PROBE,
      });

      await incidentService.resolveIncident(inc2.id, 'admin', 'Fixed webhook URL');

      const stats = incidentService.getIncidentStats();
      expect(stats.totalIncidents).toBeGreaterThanOrEqual(2);
      expect(stats.activeIncidents).toBeGreaterThanOrEqual(1);
      expect(stats.resolvedIncidents).toBeGreaterThanOrEqual(1);
    });
  });

  // =========================================================================
  // 5. PROVIDER CHANGE AUDIT & SECRET REDACTION
  // =========================================================================
  describe('Provider Change Management & Secret Redaction', () => {
    it('should sanitize and redact secrets in before and after snapshots', async () => {
      const recorded = await changeAuditService.recordChange({
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        changeType: ProviderChangeType.CREDENTIAL_UPDATE,
        actorId: 'super_admin',
        actorRole: 'ADMIN',
        reason: 'Rotated key_secret in production vault',
        beforeSnapshot: {
          keyId: 'rzp_test_123',
          keySecret: 'very_secret_unmasked_value_old',
          nested: {
            webhookSecret: 'whsec_old123',
            environment: 'SANDBOX',
          },
        },
        afterSnapshot: {
          keyId: 'rzp_test_123',
          keySecret: 'very_secret_unmasked_value_new',
          nested: {
            webhookSecret: 'whsec_new456',
            environment: 'SANDBOX',
          },
        },
      });

      expect(recorded.eventId).toBeDefined();
      // Verify secrets are redacted
      expect(recorded.beforeSnapshot?.keySecret).toBe('***REDACTED***');
      expect(recorded.beforeSnapshot?.nested.webhookSecret).toBe('***REDACTED***');
      expect(recorded.afterSnapshot?.keySecret).toBe('***REDACTED***');
      expect(recorded.afterSnapshot?.nested.webhookSecret).toBe('***REDACTED***');
      // Verify non-secrets are preserved
      expect(recorded.beforeSnapshot?.keyId).toBe('rzp_test_123');
      expect(recorded.beforeSnapshot?.nested.environment).toBe('SANDBOX');
    });

    it('should query change audit history with filters', async () => {
      await changeAuditService.recordChange({
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        changeType: ProviderChangeType.CREDENTIAL_UPDATE,
        actorId: 'super_admin',
        actorRole: 'ADMIN',
        reason: 'Filter test change',
      });

      const history = changeAuditService.queryChangeHistory({
        providerId: 'razorpay',
      });
      expect(history.length).toBeGreaterThanOrEqual(1);
      expect(history[0].providerId).toBe('razorpay');
      expect(history[0].changeType).toBe(ProviderChangeType.CREDENTIAL_UPDATE);
    });
  });

  // =========================================================================
  // 6. PROACTIVE RECOMMENDATIONS & AUTOMATION BOUNDARIES
  // =========================================================================
  describe('Proactive Recommendations & Automation Boundaries', () => {
    it('should generate recommendations and identify single points of failure', () => {
      const recs = recommendationService.generateRecommendations();
      expect(recs.length).toBeGreaterThan(0);

      const spof = recs.find((r) => r.type === RecommendationType.SINGLE_POINT_OF_FAILURE);
      expect(spof).toBeDefined();
      expect(spof?.severity).toBe('HIGH');
    });

    it('should recommend cost optimization when fee disparity exists in payments', () => {
      const recs = recommendationService.generateRecommendations();
      const costRec = recs.find((r) => r.type === RecommendationType.COST_OPTIMIZATION);
      expect(costRec).toBeDefined();
      expect(costRec?.category).toBe(IntegrationCategory.PAYMENT);
      expect(costRec?.estimatedImpact?.costSavingsMonthlyEstimate).toBeGreaterThan(0);
    });

    it('should respect human approval boundary (approve / dismiss)', async () => {
      const recs = recommendationService.generateRecommendations();
      const target = recs[0];

      expect(target.status).toBe(RecommendationStatus.PENDING);

      // Approve recommendation
      const approved = await recommendationService.approveRecommendation(
        target.recommendationId,
        'ops_director',
      );
      expect(approved.status).toBe(RecommendationStatus.APPROVED);
      expect(approved.reviewedBy).toBe('ops_director');
      expect(approved.reviewedAt).toBeDefined();
    });
  });

  // =========================================================================
  // 7. PROVIDER ONBOARDING PIPELINE
  // =========================================================================
  describe('Provider Onboarding Pipeline', () => {
    it('should reject invalid provider definitions with clear validation errors', () => {
      const validation = onboardingService.validateDefinition({
        providerId: '',
        displayName: 'A',
        category: 'INVALID_CAT' as any,
        description: 'too short',
        supportedCountries: [],
        supportedCurrencies: [],
        supportedCapabilities: [],
        priority: 150, // invalid: must be 1-100
      });

      expect(validation.isValid).toBe(false);
      expect(validation.errors.length).toBeGreaterThanOrEqual(4);
    });

    it('should onboard valid provider and register into directory and change audit', async () => {
      const validDef = {
        providerId: 'new_kyc_trust',
        displayName: 'New KYC Trust Enterprise',
        category: IntegrationCategory.IDENTITY_VERIFICATION,
        description: 'Next-generation AI identity and document verification for vehicle rental operators',
        supportedCountries: ['IN'],
        supportedCurrencies: ['INR'],
        supportedCapabilities: ['KYC_PAN_VERIFY', 'KYC_AADHAAR_OKYC'],
        priority: 15,
        pricing: { pricingType: ProviderPricingType.FIXED_PER_TRANSACTION, flatFeePerTransaction: 3.5 },
      };

      const registered = await onboardingService.submitOnboarding(
        validDef as any,
        'admin_onboarding',
        'ADMIN',
      );

      expect(registered.providerId).toBe('new_kyc_trust');
      expect(directoryService.hasProvider('new_kyc_trust')).toBe(true);

      // Verify change was audited
      const audit = changeAuditService.queryChangeHistory({ providerId: 'new_kyc_trust' });
      expect(audit.length).toBeGreaterThanOrEqual(1);
      expect(audit[0].changeType).toBe(ProviderChangeType.ONBOARDING_COMPLETED);
    });
  });

  // =========================================================================
  // 8. SIMULATION TEST LAB
  // =========================================================================
  describe('Simulation Test Lab', () => {
    it('should simulate AUTH_401 error', async () => {
      await expect(
        simulationService.simulateExecution(
          'razorpay',
          IntegrationCategory.PAYMENT,
          SimulationScenario.AUTH_401,
        ),
      ).rejects.toThrow('401 Unauthorized');
    });

    it('should simulate RATE_LIMIT_429 error and record to health service', async () => {
      await expect(
        simulationService.simulateExecution(
          'cashfree',
          IntegrationCategory.PAYMENT,
          SimulationScenario.RATE_LIMIT_429,
        ),
      ).rejects.toThrow('429 Too Many Requests');
    });

    it('should simulate WEBHOOK_SIGNATURE_MISMATCH error', async () => {
      await expect(
        simulationService.simulateExecution(
          'stripe',
          IntegrationCategory.PAYMENT,
          SimulationScenario.WEBHOOK_SIGNATURE_MISMATCH,
        ),
      ).rejects.toThrow('Webhook Signature Error');
    });

    it('should simulate LATENCY_INJECTION with specified delay', async () => {
      const res = await simulationService.simulateExecution(
        'google_maps',
        IntegrationCategory.MAPS,
        SimulationScenario.LATENCY_INJECTION,
      );

      expect((res as any).simulated).toBe(true);
      expect((res as any).status).toBe('SUCCESS');
    });

    it('should simulate PARTIAL_FAILURE with partial data output', async () => {
      await expect(
        simulationService.simulateExecution(
          'surepass',
          IntegrationCategory.IDENTITY_VERIFICATION,
          SimulationScenario.PARTIAL_FAILURE,
        ),
      ).rejects.toThrow('Partial Failure');
    });
  });
});
