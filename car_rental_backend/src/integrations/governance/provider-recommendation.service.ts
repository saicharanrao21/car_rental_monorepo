import { Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { ProviderDirectoryService } from '../directory/provider-directory.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { CircuitState } from '../runtime/runtime.types';

export enum RecommendationType {
  SUSTAINED_DEGRADATION_REROUTE = 'SUSTAINED_DEGRADATION_REROUTE',
  COST_OPTIMIZATION = 'COST_OPTIMIZATION',
  SINGLE_POINT_OF_FAILURE = 'SINGLE_POINT_OF_FAILURE',
  OUTDATED_API_VERSION = 'OUTDATED_API_VERSION',
  HIGH_LATENCY_WARNING = 'HIGH_LATENCY_WARNING',
}

export enum RecommendationStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  DISMISSED = 'DISMISSED',
  APPLIED = 'APPLIED',
}

export interface ProviderRecommendationRecord {
  id: string;
  recommendationId: string;
  type: RecommendationType;
  category: IntegrationCategory;
  targetProviderId: string;
  suggestedProviderId?: string;
  severity: 'HIGH' | 'MEDIUM' | 'LOW' | 'INFO';
  title: string;
  description: string;
  estimatedImpact?: {
    reliabilityDelta?: string;
    costSavingsMonthlyEstimate?: number;
    latencyReductionMs?: number;
  };
  status: RecommendationStatus;
  reviewedBy?: string;
  reviewedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class ProviderRecommendationService {
  private readonly logger = new Logger(ProviderRecommendationService.name);
  private readonly recommendations = new Map<string, ProviderRecommendationRecord>();

  constructor(
    private readonly directoryService: ProviderDirectoryService,
    private readonly healthService: ProviderHealthService,
    private readonly circuitBreakerService: CircuitBreakerService,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

  /**
   * Scans provider ecosystem and health telemetry to discover optimization opportunities.
   */
  public generateRecommendations(): ProviderRecommendationRecord[] {
    const allProviders = this.directoryService.findProviders();
    const categorized = new Map<IntegrationCategory, typeof allProviders>();

    for (const p of allProviders) {
      const list = categorized.get(p.category) || [];
      list.push(p);
      categorized.set(p.category, list);
    }

    // 1. Detect Single Point of Failure (SPOF)
    for (const [category, providers] of categorized.entries()) {
      const activeProviders = providers.filter((p) => p.status === 'ACTIVE');
      if (activeProviders.length === 1) {
        this.upsertRecommendation({
          type: RecommendationType.SINGLE_POINT_OF_FAILURE,
          category,
          targetProviderId: activeProviders[0].providerId,
          severity: 'HIGH',
          title: `Single Point of Failure in ${category}`,
          description: `Category ${category} currently relies solely on ${activeProviders[0].displayName}. Onboard a secondary provider to guarantee high availability and failover continuity.`,
          estimatedImpact: {
            reliabilityDelta: '+99.9% uptime redundancy',
          },
        });
      }
    }

    // 2. Detect Sustained Degradation / Circuit Trips
    for (const provider of allProviders) {
      const health = this.healthService.getHealth(provider.category, provider.providerId);
      const circuit = this.circuitBreakerService.getState(provider.providerId);

      if (
        circuit === CircuitState.OPEN ||
        health.status === ProviderHealthStatus.DEGRADED ||
        health.status === ProviderHealthStatus.UNAVAILABLE
      ) {
        // Find alternative healthy provider in same category
        const alternatives = (categorized.get(provider.category) || []).filter(
          (alt) =>
            alt.providerId !== provider.providerId &&
            alt.status === 'ACTIVE' &&
            this.circuitBreakerService.getState(alt.providerId) === CircuitState.CLOSED,
        );

        const bestAlt = alternatives[0];
        this.upsertRecommendation({
          type: RecommendationType.SUSTAINED_DEGRADATION_REROUTE,
          category: provider.category,
          targetProviderId: provider.providerId,
          suggestedProviderId: bestAlt ? bestAlt.providerId : undefined,
          severity: 'HIGH',
          title: `Reroute traffic from degraded provider ${provider.displayName}`,
          description: `Provider ${provider.displayName} is experiencing ${circuit === CircuitState.OPEN ? 'an open circuit breaker' : health.status.toLowerCase()}. Reroute primary traffic to ${bestAlt ? bestAlt.displayName : 'an active backup provider'}.`,
          estimatedImpact: {
            reliabilityDelta: 'Immediate error rate drop',
          },
        });
      }
    }

    // 3. Detect Cost Optimization Opportunities (e.g. Stripe vs Cashfree/Razorpay for domestic INR)
    const paymentProviders = categorized.get(IntegrationCategory.PAYMENTS) || [];
    const highFeeProviders = paymentProviders.filter(
      (p) => (p.pricing?.percentageFee || 0) >= 2.5 && p.status === 'ACTIVE',
    );
    const lowFeeProviders = paymentProviders.filter(
      (p) => (p.pricing?.percentageFee || 0) <= 2.0 && p.status === 'ACTIVE',
    );

    if (highFeeProviders.length > 0 && lowFeeProviders.length > 0) {
      const high = highFeeProviders[0];
      const low = lowFeeProviders[0];
      this.upsertRecommendation({
        type: RecommendationType.COST_OPTIMIZATION,
        category: IntegrationCategory.PAYMENTS,
        targetProviderId: high.providerId,
        suggestedProviderId: low.providerId,
        severity: 'MEDIUM',
        title: `Optimize transaction fees: Shift domestic volume to ${low.displayName}`,
        description: `${low.displayName} offers a ${low.pricing?.percentageFee}% fee compared to ${high.displayName}'s ${high.pricing?.percentageFee}% fee. Re-prioritizing for domestic INR can generate significant monthly savings.`,
        estimatedImpact: {
          costSavingsMonthlyEstimate: 45000,
          reliabilityDelta: 'Equivalent SLA (>99.9%)',
        },
      });
    }

    return this.getRecommendations();
  }

  /**
   * Retrieve all recommendations.
   */
  public getRecommendations(status?: RecommendationStatus): ProviderRecommendationRecord[] {
    let list = Array.from(this.recommendations.values());
    if (status) {
      list = list.filter((r) => r.status === status);
    }
    return list.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  /**
   * Approve a recommendation.
   */
  public async approveRecommendation(
    recommendationId: string,
    reviewerId: string,
  ): Promise<ProviderRecommendationRecord> {
    const rec = this.recommendations.get(recommendationId);
    if (!rec) {
      throw new NotFoundException(`Recommendation '${recommendationId}' not found`);
    }

    rec.status = RecommendationStatus.APPROVED;
    rec.reviewedBy = reviewerId;
    rec.reviewedAt = new Date();
    rec.updatedAt = new Date();

    this.logger.log(
      `[RECOMMENDATION_APPROVED] Recommendation [${recommendationId}] approved by [${reviewerId}]`,
    );

    await this.persistRecommendation(rec);
    return rec;
  }

  /**
   * Dismiss a recommendation.
   */
  public async dismissRecommendation(
    recommendationId: string,
    reviewerId: string,
  ): Promise<ProviderRecommendationRecord> {
    const rec = this.recommendations.get(recommendationId);
    if (!rec) {
      throw new NotFoundException(`Recommendation '${recommendationId}' not found`);
    }

    rec.status = RecommendationStatus.DISMISSED;
    rec.reviewedBy = reviewerId;
    rec.reviewedAt = new Date();
    rec.updatedAt = new Date();

    this.logger.log(
      `[RECOMMENDATION_DISMISSED] Recommendation [${recommendationId}] dismissed by [${reviewerId}]`,
    );

    await this.persistRecommendation(rec);
    return rec;
  }

  private upsertRecommendation(params: {
    type: RecommendationType;
    category: IntegrationCategory;
    targetProviderId: string;
    suggestedProviderId?: string;
    severity: 'HIGH' | 'MEDIUM' | 'LOW' | 'INFO';
    title: string;
    description: string;
    estimatedImpact?: any;
  }): void {
    const key = `${params.type}:${params.targetProviderId}`.toLowerCase();
    const existing = this.recommendations.get(key);

    if (existing) {
      if (existing.status === RecommendationStatus.PENDING) {
        existing.title = params.title;
        existing.description = params.description;
        existing.suggestedProviderId = params.suggestedProviderId;
        existing.estimatedImpact = params.estimatedImpact;
        existing.updatedAt = new Date();
      }
      return;
    }

    const rec: ProviderRecommendationRecord = {
      id: `rec_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      recommendationId: key,
      type: params.type,
      category: params.category,
      targetProviderId: params.targetProviderId,
      suggestedProviderId: params.suggestedProviderId,
      severity: params.severity,
      title: params.title,
      description: params.description,
      estimatedImpact: params.estimatedImpact,
      status: RecommendationStatus.PENDING,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.recommendations.set(key, rec);
    this.persistRecommendation(rec).catch(() => {});
  }

  private async persistRecommendation(rec: ProviderRecommendationRecord): Promise<void> {
    if (!this.prisma) return;
    try {
      await (this.prisma as any).providerRecommendation.upsert({
        where: { recommendationId: rec.recommendationId },
        create: {
          recommendationId: rec.recommendationId,
          type: rec.type,
          category: rec.category,
          targetProviderId: rec.targetProviderId,
          suggestedProviderId: rec.suggestedProviderId,
          severity: rec.severity,
          title: rec.title,
          description: rec.description,
          estimatedImpact: rec.estimatedImpact,
          status: rec.status,
          reviewedBy: rec.reviewedBy,
          reviewedAt: rec.reviewedAt,
          createdAt: rec.createdAt,
        },
        update: {
          title: rec.title,
          description: rec.description,
          suggestedProviderId: rec.suggestedProviderId,
          estimatedImpact: rec.estimatedImpact,
          status: rec.status,
          reviewedBy: rec.reviewedBy,
          reviewedAt: rec.reviewedAt,
          updatedAt: rec.updatedAt,
        },
      });
    } catch (err: any) {
      this.logger.debug(`Could not persist recommendation to DB (safely ignored): ${err.message}`);
    }
  }
}
