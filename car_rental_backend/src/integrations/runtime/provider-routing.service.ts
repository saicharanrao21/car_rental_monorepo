import { Injectable, Logger, Optional } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { CircuitBreakerService } from './circuit-breaker.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { ProviderPolicyService } from './provider-policy.service';
import { CostModelService } from './cost-model.service';
import { ProviderScoringService } from '../scoring/provider-scoring.service';
import { ProviderDirectoryService } from '../directory/provider-directory.service';
import {
  ProviderDirectoryMetadata,
  ProviderPricingType,
  CertificationLevel,
} from '../directory/provider-directory.types';
import {
  CircuitState,
  IntegrationExecutionRequest,
  RoutingStrategy,
  RoutingDecisionExplanation,
  CandidateEvaluationExplanation,
} from './runtime.types';
import { CatalogProviderMetadata } from '../catalog/provider-catalog.types';

@Injectable()
export class ProviderRoutingService {
  private readonly logger = new Logger(ProviderRoutingService.name);
  private roundRobinCounters = new Map<string, number>();
  private categoryDefaultStrategies = new Map<IntegrationCategory, RoutingStrategy>();
  private categoryCustomFallbacks = new Map<string, string[]>(); // key: `${category}:${vendorId || 'platform'}`

  constructor(
    private readonly catalogService: ProviderCatalogService,
    private readonly registryService: ProviderRegistryService,
    private readonly circuitBreakerService: CircuitBreakerService,
    private readonly healthService: ProviderHealthService,
    private readonly policyService: ProviderPolicyService,
    private readonly costModelService: CostModelService,
    @Optional() private readonly scoringService?: ProviderScoringService,
    @Optional() private readonly directoryService?: ProviderDirectoryService,
  ) {}

  public setCategoryDefaultStrategy(category: IntegrationCategory, strategy: RoutingStrategy): void {
    this.categoryDefaultStrategies.set(category, strategy);
  }

  public setCustomFallbackChain(category: IntegrationCategory, chain: string[], vendorId = 'platform'): void {
    const key = `${category}:${vendorId}`.toLowerCase();
    this.categoryCustomFallbacks.set(key, chain);
  }

  /**
   * Resolves an ordered list of candidate providers for a given execution request.
   * The first candidate is the primary; subsequent candidates are the fallback chain.
   */
  public async resolveRoutingChain(
    request: IntegrationExecutionRequest,
  ): Promise<{
    primaryProviderId: string;
    fallbackChain: string[];
    allCandidates: string[];
    strategyUsed: RoutingStrategy;
    explanation?: RoutingDecisionExplanation;
  }> {
    const category = request.category;
    const capability = request.capability;

    // 1. Evaluate policies first
    const policyDecision = this.policyService.evaluatePolicies({
      category,
      region: request.region,
      currency: request.currency,
      vendorId: request.vendorId,
      branchId: request.branchId,
      capabilities: capability ? [capability] : [],
    });

    const effectiveStrategy =
      request.routingStrategy ||
      policyDecision.routingStrategyOverride ||
      this.categoryDefaultStrategies.get(category) ||
      RoutingStrategy.PRIORITY;

    // 2. Discover all candidate providers in catalog for this category
    let catalogCandidates = this.catalogService.getCategoryProviders(category);

    // Filter by capability
    if (capability) {
      const capNorm = capability.toLowerCase();
      catalogCandidates = catalogCandidates.filter((p) => {
        if (
          (capNorm === 'create_payment' || capNorm === 'create_order') &&
          p.supportedCapabilities.some((c) => {
            const sc = c.toLowerCase();
            return sc === 'create_order' || sc === 'create_payment';
          })
        ) {
          return true;
        }
        if (
          (capNorm === 'send_whatsapp' || capNorm === 'send_template') &&
          p.supportedCapabilities.some((c) => {
            const sc = c.toLowerCase();
            return sc === 'send_template' || sc === 'send_whatsapp';
          })
        ) {
          return true;
        }
        return p.supportedCapabilities.some(
          (c) => c.toLowerCase() === capNorm,
        );
      });
    }

    // Filter by region / country if provided
    if (request.region) {
      const regionUpper = request.region.toUpperCase();
      const regionalMatches = catalogCandidates.filter(
        (p) =>
          p.supportedCountries.includes('ALL') ||
          p.supportedCountries.some((c) => c.toUpperCase() === regionUpper),
      );
      if (regionalMatches.length > 0) {
        catalogCandidates = regionalMatches;
      }
    }

    // Filter by currency if provided
    if (request.currency) {
      const currUpper = request.currency.toUpperCase();
      const currencyMatches = catalogCandidates.filter(
        (p) =>
          p.supportedCurrencies.includes('ALL') ||
          p.supportedCurrencies.some((c) => c.toUpperCase() === currUpper),
      );
      if (currencyMatches.length > 0) {
        catalogCandidates = currencyMatches;
      }
    }

    // Filter by environment if provided
    if (request.environment) {
      catalogCandidates = catalogCandidates.filter((p) =>
        p.supportedEnvironments.includes(request.environment!),
      );
    }

    // Filter by Policy rules (allowed/denied providers)
    if (policyDecision.deniedProviders && policyDecision.deniedProviders.length > 0) {
      const deniedSet = new Set(policyDecision.deniedProviders.map((d) => d.toLowerCase()));
      catalogCandidates = catalogCandidates.filter(
        (p) => !deniedSet.has(p.providerId.toLowerCase()),
      );
    }

    if (policyDecision.allowedProviders && policyDecision.allowedProviders.length > 0) {
      const allowedSet = new Set(policyDecision.allowedProviders.map((a) => a.toLowerCase()));
      catalogCandidates = catalogCandidates.filter((p) =>
        allowedSet.has(p.providerId.toLowerCase()),
      );
    }

    if (catalogCandidates.length === 0) {
      // If no catalog candidate matched filters, fallback to any registered adapter for this category
      const allRegistered = this.registryService.getProvidersByCategory(category);
      if (allRegistered.length > 0) {
        return {
          primaryProviderId: allRegistered[0].getProviderId(),
          fallbackChain: allRegistered.slice(1).map((p) => p.getProviderId()),
          allCandidates: allRegistered.map((p) => p.getProviderId()),
          strategyUsed: effectiveStrategy,
        };
      }
      throw new Error(
        `No suitable provider found for category '${category}' supporting capability '${capability}' and currency '${request.currency || 'ANY'}'`,
      );
    }

    // 3. Check custom fallback chain override for vendor or platform
    const customKey = `${category}:${request.vendorId || 'platform'}`.toLowerCase();
    const customFallback = this.categoryCustomFallbacks.get(customKey);
    if (customFallback && customFallback.length > 0) {
      const candidateMap = new Map(catalogCandidates.map((c) => [c.providerId.toLowerCase(), c]));
      const ordered: CatalogProviderMetadata[] = [];
      for (const id of customFallback) {
        const found = candidateMap.get(id.toLowerCase());
        if (found) {
          ordered.push(found);
        } else {
          ordered.push({
            providerId: id,
            category,
            name: id,
            tagline: id,
            description: id,
            icon: 'extension',
            version: '1.0.0',
            apiVersion: '1',
            supportedEnvironments: [],
            defaultEnvironment: 'SANDBOX' as any,
            credentialSchema: [],
            supportedCapabilities: [capability || 'default'],
            supportedCurrencies: ['ALL'],
            supportedCountries: ['ALL'],
            supportedWebhookEvents: [],
            platformAvailability: true,
            tenantTierAvailability: ['ALL'],
            activationState: 'ACTIVE' as any,
            priority: 1,
            websiteUrl: '',
            documentation: { overview: '', docsUrl: '', setupGuide: '' },
            author: 'System',
            tags: [],
          });
        }
      }
      catalogCandidates = ordered;
    } else {
      // 4. Sort / select according to the routing strategy
      catalogCandidates = this.applyRoutingStrategy(
        catalogCandidates,
        effectiveStrategy,
        request,
      );
    }

    // 5. If explicit preferred provider or policy preferred provider is defined, elevate to top
    const preferredId =
      request.preferredProviderId || policyDecision.preferredProviderId;
    if (preferredId) {
      const idx = catalogCandidates.findIndex(
        (c) => c.providerId.toLowerCase() === preferredId.toLowerCase(),
      );
      if (idx > -1) {
        const [preferred] = catalogCandidates.splice(idx, 1);
        catalogCandidates.unshift(preferred);
      }
    }

    // 6. Filter / deprioritize providers with OPEN circuits
    // Providers with OPEN circuits are moved to the very back of the fallback chain
    const closedOrHalfOpen: CatalogProviderMetadata[] = [];
    const openCircuits: CatalogProviderMetadata[] = [];

    for (const c of catalogCandidates) {
      const cState = this.circuitBreakerService.getState(c.providerId);
      if (cState === CircuitState.OPEN) {
        openCircuits.push(c);
      } else {
        closedOrHalfOpen.push(c);
      }
    }

    const finalCandidates = [...closedOrHalfOpen, ...openCircuits];
    const candidateIds = finalCandidates.map((c) => c.providerId);

    const primaryProviderId = candidateIds[0];
    const fallbackChain = candidateIds.slice(1);

    const explanation = this.computeDecisionExplanation(
      request,
      finalCandidates,
      primaryProviderId,
      fallbackChain,
      effectiveStrategy,
      policyDecision,
    );

    return {
      primaryProviderId,
      fallbackChain,
      allCandidates: candidateIds,
      strategyUsed: effectiveStrategy,
      explanation,
    };
  }

  private applyRoutingStrategy(
    candidates: CatalogProviderMetadata[],
    strategy: RoutingStrategy,
    request: IntegrationExecutionRequest,
  ): CatalogProviderMetadata[] {
    const list = [...candidates];

    switch (strategy) {
      case RoutingStrategy.PRIMARY:
      case RoutingStrategy.PRIORITY: {
        return list.sort((a, b) => a.priority - b.priority);
      }

      case RoutingStrategy.ROUND_ROBIN: {
        const key = request.category;
        const count = this.roundRobinCounters.get(key) || 0;
        this.roundRobinCounters.set(key, count + 1);
        const shift = count % list.length;
        return [...list.slice(shift), ...list.slice(0, shift)];
      }

      case RoutingStrategy.WEIGHTED: {
        // Shuffle or order by weight descending
        return list.sort((a, b) => ((b as any).weight || 1) - ((a as any).weight || 1));
      }

      case RoutingStrategy.LEAST_LATENCY: {
        return list.sort((a, b) => {
          const healthA = this.healthService.getRollingHealth(a.category, a.providerId);
          const healthB = this.healthService.getRollingHealth(b.category, b.providerId);
          return (healthA.latencyP50 || 9999) - (healthB.latencyP50 || 9999);
        });
      }

      case RoutingStrategy.HEALTH_BASED: {
        return list.sort((a, b) => {
          const healthA = this.healthService.getRollingHealth(a.category, a.providerId);
          const healthB = this.healthService.getRollingHealth(b.category, b.providerId);
          // Higher success rate first, then higher proven executions, then lower failure streak
          if (healthB.successRate !== healthA.successRate) {
            return healthB.successRate - healthA.successRate;
          }
          if (healthB.totalExecutions !== healthA.totalExecutions) {
            return healthB.totalExecutions - healthA.totalExecutions;
          }
          return healthA.failureStreak - healthB.failureStreak;
        });
      }

      case RoutingStrategy.REGION_BASED: {
        const targetRegion = (request.region || '').toUpperCase();
        return list.sort((a, b) => {
          const aMatch = a.supportedCountries.some((c) => c.toUpperCase() === targetRegion);
          const bMatch = b.supportedCountries.some((c) => c.toUpperCase() === targetRegion);
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;
          return a.priority - b.priority;
        });
      }

      case RoutingStrategy.CURRENCY_BASED: {
        const targetCurr = (request.currency || '').toUpperCase();
        return list.sort((a, b) => {
          const aMatch = a.supportedCurrencies.some((c) => c.toUpperCase() === targetCurr);
          const bMatch = b.supportedCurrencies.some((c) => c.toUpperCase() === targetCurr);
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;
          return a.priority - b.priority;
        });
      }

      case RoutingStrategy.CAPABILITY_BASED: {
        const cap = (request.capability || '').toLowerCase();
        return list.sort((a, b) => {
          const aExact = a.supportedCapabilities.some((c) => c.toLowerCase() === cap);
          const bExact = b.supportedCapabilities.some((c) => c.toLowerCase() === cap);
          if (aExact && !bExact) return -1;
          if (!aExact && bExact) return 1;
          return a.priority - b.priority;
        });
      }

      case RoutingStrategy.COST_OPTIMIZED: {
        return list.sort((a, b) => {
          const costA = this.costModelService.estimateCost(
            a.providerId,
            1,
            request.currency,
            request.region,
          );
          const costB = this.costModelService.estimateCost(
            b.providerId,
            1,
            request.currency,
            request.region,
          );
          return costA - costB;
        });
      }

      case RoutingStrategy.SCORE_OPTIMIZED: {
        if (!this.scoringService) {
          return list.sort((a, b) => a.priority - b.priority);
        }
        const scoredList = list.map((c) => {
          let dirMeta: ProviderDirectoryMetadata;
          if (this.directoryService && this.directoryService.hasProvider(c.providerId)) {
            dirMeta = this.directoryService.getProvider(c.providerId);
          } else {
            dirMeta = {
              providerId: c.providerId,
              displayName: c.name,
              category: c.category,
              description: c.description,
              supportedCountries: c.supportedCountries,
              supportedCurrencies: c.supportedCurrencies,
              supportedCapabilities: c.supportedCapabilities,
              priority: c.priority,
              reliabilityScore: 0.95,
              expectedLatencyP50Ms: 250,
              pricing: {
                type: ProviderPricingType.FREE_TIER_THEN_USAGE,
                fixedFee: 0,
                percentageFee: 0,
                currency: 'USD',
              },
              status: 'ACTIVE' as any,
              certificationLevel: CertificationLevel.PRODUCTION_READY,
            } as any;
          }
          const scoreResult = this.scoringService!.calculateScore(dirMeta, {
            category: c.category,
            region: request.region,
            country: request.region,
            currency: request.currency,
            requiredCapabilities: request.capability ? [request.capability] : [],
            maxAcceptableLatencyMs: 1000,
          });
          return { candidate: c, score: scoreResult.finalScore };
        });
        scoredList.sort((a, b) => b.score - a.score);
        return scoredList.map((s) => s.candidate);
      }

      case RoutingStrategy.CUSTOM_RULE:
      default:
        return list.sort((a, b) => a.priority - b.priority);
    }
  }

  private computeDecisionExplanation(
    request: IntegrationExecutionRequest,
    candidates: CatalogProviderMetadata[],
    primaryId: string,
    fallbackChain: string[],
    strategy: RoutingStrategy,
    policyDecision: any,
  ): RoutingDecisionExplanation {
    const candidateEvaluations: CandidateEvaluationExplanation[] = [];
    const reasons: string[] = [];

    const primaryCandidate = candidates.find(
      (c) => c.providerId.toLowerCase() === primaryId?.toLowerCase(),
    );

    if (primaryCandidate) {
      if (request.preferredProviderId?.toLowerCase() === primaryId.toLowerCase()) {
        reasons.push(`Explicitly requested preferred provider [${primaryId}] by caller`);
      } else if (policyDecision?.preferredProviderId?.toLowerCase() === primaryId.toLowerCase()) {
        reasons.push(`Selected [${primaryId}] as preferred by active policy rule`);
      } else {
        reasons.push(`Selected [${primaryId}] via ${strategy} routing strategy`);
      }

      if (request.region) {
        reasons.push(`Supports region ${request.region}`);
      }
      if (request.currency) {
        reasons.push(`Supports currency ${request.currency}`);
      }

      const circuit = this.circuitBreakerService.getState(primaryId);
      reasons.push(`Circuit state is ${circuit}`);

      const health = this.healthService.getRollingHealth(
        primaryCandidate.category,
        primaryId,
      );
      if (health) {
        reasons.push(
          `Rolling success rate: ${health.successRate.toFixed(1)}%, p50 latency: ${health.latencyP50}ms`,
        );
      }
    }

    for (const c of candidates) {
      const isSelected = c.providerId.toLowerCase() === primaryId?.toLowerCase();
      const circuit = this.circuitBreakerService.getState(c.providerId);
      const health = this.healthService.getRollingHealth(c.category, c.providerId);
      const costEstimate = this.costModelService.estimateCost(
        c.providerId,
        100,
        request.currency,
        request.region,
      );

      const healthScore =
        circuit === CircuitState.OPEN ? 0 : health ? health.successRate : 100;
      const latencyScore = Math.max(0, 100 - (health?.latencyP50 || 20) / 10);
      const costScore = Math.max(0, 100 - costEstimate * 10);
      const capabilityScore = 100;
      const priorityScore = Math.max(0, 100 - c.priority * 5);
      const policyScore = policyDecision?.deniedProviders?.includes(c.providerId)
        ? 0
        : 100;

      const totalScore = Number(
        (
          healthScore * 0.3 +
          latencyScore * 0.2 +
          costScore * 0.15 +
          priorityScore * 0.25 +
          policyScore * 0.1
        ).toFixed(1),
      );

      let rejectionReason: string | undefined;
      if (!isSelected) {
        if (circuit === CircuitState.OPEN) {
          rejectionReason = `Circuit is OPEN due to past failure threshold`;
        } else if (c.priority > (primaryCandidate?.priority || 1)) {
          rejectionReason = `Lower priority ranking (${c.priority}) compared to selected (${primaryCandidate?.priority || 1})`;
        } else {
          rejectionReason = `Secondary choice in fallback chain; placed at standby position`;
        }
      }

      candidateEvaluations.push({
        providerId: c.providerId,
        score: totalScore,
        eligible: circuit !== CircuitState.OPEN && policyScore > 0,
        rejectionReason,
        factorScores: {
          healthScore,
          latencyScore,
          costScore,
          capabilityScore,
          priorityScore,
          policyScore,
        },
      });
    }

    return {
      selectedProviderId: primaryId,
      strategyUsed: strategy,
      reasons,
      candidatesEvaluated: candidateEvaluations,
      fallbackChain,
    };
  }
}
