import { Injectable, Logger } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { CircuitBreakerService } from './circuit-breaker.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { ProviderPolicyService } from './provider-policy.service';
import { CostModelService } from './cost-model.service';
import {
  CircuitState,
  IntegrationExecutionRequest,
  RoutingStrategy,
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

    return {
      primaryProviderId,
      fallbackChain,
      allCandidates: candidateIds,
      strategyUsed: effectiveStrategy,
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

      case RoutingStrategy.CUSTOM_RULE:
      default:
        return list.sort((a, b) => a.priority - b.priority);
    }
  }
}
