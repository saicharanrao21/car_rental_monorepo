import { Injectable, Logger } from '@nestjs/common';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { ProviderDirectoryMetadata } from '../directory/provider-directory.types';
import { CapabilityMatrixService } from '../directory/capability-matrix.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { CircuitState } from '../runtime/runtime.types';
import {
  ProviderScoreBreakdown,
  ScoringContext,
  ScoringWeights,
} from './provider-scoring.types';

@Injectable()
export class ProviderScoringService {
  private readonly logger = new Logger(ProviderScoringService.name);

  // Default scoring weights: sum to 1.0
  private defaultWeights: ScoringWeights = {
    healthWeight: 0.25,
    reliabilityWeight: 0.20,
    latencyWeight: 0.15,
    capabilityWeight: 0.15,
    regionalWeight: 0.10,
    costWeight: 0.05,
    priorityWeight: 0.10,
  };

  // Category-specific weight overrides
  private categoryWeights = new Map<IntegrationCategory, ScoringWeights>();

  constructor(
    private readonly healthService: ProviderHealthService,
    private readonly circuitBreakerService: CircuitBreakerService,
    private readonly capabilityService: CapabilityMatrixService,
  ) {}

  /**
   * Calculates the deterministic score (0 - 100) for a provider given the scoring context.
   */
  public calculateScore(
    provider: ProviderDirectoryMetadata,
    context: ScoringContext,
  ): ProviderScoreBreakdown {
    const weights = this.getWeights(context.category);

    // 1. Health factor (0 - 100)
    const healthRec = this.healthService.getHealth(provider.category, provider.providerId);
    let healthScore = 100;
    if (healthRec.status === ProviderHealthStatus.DEGRADED) {
      healthScore = 50;
    } else if (
      healthRec.status === ProviderHealthStatus.UNAVAILABLE ||
      healthRec.status === ProviderHealthStatus.CREDENTIAL_FAILURE
    ) {
      healthScore = 0;
    }

    // 2. Reliability factor (0 - 100)
    // Uses historical reliability score
    const reliabilityScore = Math.round(provider.reliabilityScore * 100);

    // 3. Latency factor (0 - 100)
    const maxLatency = context.maxAcceptableLatencyMs || 1000;
    const actualLatency = healthRec.latencyMs || provider.expectedLatencyP50Ms || 200;
    const latencyScore = Math.max(0, Math.min(100, Math.round(100 - (actualLatency / maxLatency) * 100)));

    // 4. Capability match factor (0 - 100)
    let capabilityScore = 100;
    if (context.requiredCapabilities && context.requiredCapabilities.length > 0) {
      const match = this.capabilityService.evaluateProviderMatch(provider, {
        category: context.category,
        requiredCapabilities: context.requiredCapabilities,
        preferredCapabilities: context.preferredCapabilities,
      });
      capabilityScore = match.coveragePercent;
      if (match.matchedPreferred.length > 0) {
        capabilityScore = Math.min(100, capabilityScore + 10);
      }
    }

    // 5. Regional suitability factor (0 - 100)
    let regionalScore = 70; // neutral base
    const country = context.country?.toUpperCase();
    const currency = context.currency?.toUpperCase();

    if (country && (provider.supportedCountries.includes(country) || provider.supportedCountries.includes('GLOBAL'))) {
      regionalScore += 15;
    }
    if (currency && provider.supportedCurrencies.includes(currency)) {
      regionalScore += 15;
    }

    // 6. Cost efficiency factor (0 - 100)
    // Providers with lower percentage fees receive higher scores
    const feePct = provider.pricing?.percentageFee || 2.0;
    const costScore = Math.max(20, Math.min(100, Math.round(100 - feePct * 20)));

    // 7. Configured business priority (0 - 100)
    const priorityScore = Math.min(100, Math.max(0, provider.priority || 50));

    // Calculate weighted sum
    const weightedSum =
      weights.healthWeight * healthScore +
      weights.reliabilityWeight * reliabilityScore +
      weights.latencyWeight * latencyScore +
      weights.capabilityWeight * capabilityScore +
      weights.regionalWeight * regionalScore +
      weights.costWeight * costScore +
      weights.priorityWeight * priorityScore;

    // Evaluate Penalties
    let incidentPenalty = 0;
    if (healthRec.status === ProviderHealthStatus.DEGRADED) {
      incidentPenalty = 20;
    } else if (healthRec.status === ProviderHealthStatus.UNAVAILABLE) {
      incidentPenalty = 50;
    }

    let circuitOpenPenalty = 0;
    const circuitState = this.circuitBreakerService.getState(provider.providerId);
    if (circuitState === CircuitState.OPEN) {
      circuitOpenPenalty = 60;
    } else if (circuitState === CircuitState.HALF_OPEN) {
      circuitOpenPenalty = 25;
    }

    let rateLimitPenalty = 0;
    const failureStreak = (this.healthService as any).rollingStats?.get(
      `${provider.category}:${provider.providerId}`.toLowerCase(),
    )?.rateLimitCount || 0;
    if (failureStreak > 0) {
      rateLimitPenalty = Math.min(30, failureStreak * 10);
    }

    const totalPenalties = incidentPenalty + circuitOpenPenalty + rateLimitPenalty;
    const finalScore = Math.max(0, Math.min(100, Math.round(weightedSum - totalPenalties)));

    const explanation = `Score ${finalScore}/100: [Health: ${healthScore}*${weights.healthWeight}, Rel: ${reliabilityScore}*${weights.reliabilityWeight}, Lat: ${latencyScore}*${weights.latencyWeight}, Cap: ${capabilityScore}*${weights.capabilityWeight}, Reg: ${regionalScore}*${weights.regionalWeight}, Cost: ${costScore}*${weights.costWeight}, Prio: ${priorityScore}*${weights.priorityWeight}] - Penalties: ${totalPenalties}`;

    return {
      providerId: provider.providerId,
      category: provider.category,
      finalScore,
      rawFactors: {
        healthScore,
        reliabilityScore,
        latencyScore,
        capabilityScore,
        regionalScore,
        costScore,
        priorityScore,
      },
      penalties: {
        incidentPenalty,
        rateLimitPenalty,
        circuitOpenPenalty,
      },
      weightedSum: Math.round(weightedSum * 10) / 10,
      explanation,
      evaluatedAt: new Date().toISOString(),
    };
  }

  /**
   * Ranks an array of candidate providers by composite score in descending order.
   */
  public rankProviders(
    providers: ProviderDirectoryMetadata[],
    context: ScoringContext,
  ): Array<{ provider: ProviderDirectoryMetadata; score: ProviderScoreBreakdown }> {
    return providers
      .map((p) => ({
        provider: p,
        score: this.calculateScore(p, context),
      }))
      .sort((a, b) => b.score.finalScore - a.score.finalScore);
  }

  public getWeights(category?: IntegrationCategory): ScoringWeights {
    if (category && this.categoryWeights.has(category)) {
      return this.categoryWeights.get(category)!;
    }
    return this.defaultWeights;
  }

  public updateCategoryWeights(category: IntegrationCategory, weights: Partial<ScoringWeights>): void {
    const current = this.getWeights(category);
    this.categoryWeights.set(category, { ...current, ...weights });
    this.logger.log(`[SCORING_WEIGHTS_UPDATED] Weights for ${category} updated.`);
  }
}
