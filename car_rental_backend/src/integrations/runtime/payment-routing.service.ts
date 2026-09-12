import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderCertificationLevel } from '../catalog/provider-catalog.types';
import { CostModelService } from './cost-model.service';
import { CircuitBreakerService } from './circuit-breaker.service';
import { ProviderPolicyService } from './provider-policy.service';
import { ProviderRoutingService } from './provider-routing.service';
import {
  RoutingDecisionExplanation,
  CandidateEvaluationExplanation,
  RoutingStrategy,
} from './runtime.types';

export interface PaymentRoutingRequest {
  country?: string;
  currency?: string;
  paymentMethod?: string; // 'UPI' | 'CREDIT_CARD' | 'DEBIT_CARD' | 'NET_BANKING' | 'WALLET' | 'BNPL' | 'INTERNATIONAL_CARD'
  amountPaise: number;
  customerId?: string;
  vendorId?: string;
  branchId?: string;
  tenantId?: string;
  preferCheapest?: boolean;
  preferReliable?: boolean;
}

export interface PaymentRoutingDecision {
  primaryProviderId: string;
  fallbackChain: string[];
  allCandidates: string[];
  explanation: RoutingDecisionExplanation;
  estimatedFee: {
    amount: number;
    currency: string;
    percentage: number;
    fixed: number;
  };
}

export interface FallbackSafetyEvaluation {
  safeToFailover: boolean;
  action?: string;
  reason: string;
  recommendedPaymentStatus: 'PENDING_RECONCILIATION' | 'UNKNOWN' | 'FAILED';
}

@Injectable()
export class PaymentRoutingService {
  private readonly logger = new Logger(PaymentRoutingService.name);

  constructor(
    private readonly catalogService: ProviderCatalogService,
    private readonly costModelService: CostModelService,
    private readonly circuitBreaker: CircuitBreakerService,
    private readonly policyService: ProviderPolicyService,
    private readonly providerRoutingService: ProviderRoutingService,
  ) {}

  /**
   * Intelligently selects the optimal payment gateway and computes a deterministic fallback chain
   * based on Country, Currency, Payment Method, Amount, Circuit Breakers, and Economics.
   */
  async resolvePaymentRoute(req: PaymentRoutingRequest): Promise<PaymentRoutingDecision> {
    const country = (req.country || 'IN').toUpperCase();
    const currency = (req.currency || 'INR').toUpperCase();
    const method = req.paymentMethod ? req.paymentMethod.toUpperCase() : undefined;
    const amount = req.amountPaise / 100;

    // 1. Get all payment catalog providers
    const allProviders = this.catalogService.getCategoryProviders(IntegrationCategory.PAYMENT);

    const candidatesWithScores: Array<{
      providerId: string;
      eligible: boolean;
      score: number;
      rejectionReason?: string;
      factorScores: Record<string, number>;
      cost: { fee: number; percentage: number; fixed: number; currency: string };
    }> = [];

    for (const provider of allProviders) {
      let eligible = true;
      let rejectionReason: string | undefined;

      // Check country support
      const countryMatch =
        provider.supportedCountries.includes('ALL') ||
        provider.supportedCountries.some((c) => c.toUpperCase() === country);
      if (!countryMatch) {
        eligible = false;
        rejectionReason = `Does not support country ${country}`;
      }

      // Check currency support
      const currencyMatch =
        provider.supportedCurrencies.length === 0 ||
        provider.supportedCurrencies.some((c) => c.toUpperCase() === currency);
      if (eligible && !currencyMatch) {
        eligible = false;
        rejectionReason = `Does not support currency ${currency}`;
      }

      // Check payment method support
      if (eligible && method && provider.supportedPaymentMethods) {
        const methodMatch = provider.supportedPaymentMethods.some((m) => {
          const normM = m.toUpperCase();
          if (method === 'UPI' && (normM === 'UPI' || normM === 'UPI_INTENT')) return true;
          if (method === 'CARD' && (normM.includes('CARD') || normM === 'CREDIT_CARD')) return true;
          if (method === 'INTERNATIONAL_CARD' && (normM === 'INTERNATIONAL_CARD' || normM === 'LOCAL_CARD')) return true;
          return normM === method;
        });

        if (!methodMatch && provider.providerId !== 'mock_payment') {
          eligible = false;
          rejectionReason = `Does not support payment method ${method}`;
        }
      }

      // Check Circuit Breaker
      const cbState = this.circuitBreaker.getState(provider.providerId);
      if (eligible && cbState === 'OPEN') {
        eligible = false;
        rejectionReason = `Circuit breaker is OPEN (high failure rate)`;
      }

      // Safety Gate: In production, exclude Class C simulated/catalog adapters from routing tables entirely
      const isProduction = process.env.NODE_ENV === 'production';
      if (
        eligible &&
        isProduction &&
        provider.certificationLevel !== ProviderCertificationLevel.PRODUCTION_VALIDATED
      ) {
        eligible = false;
        rejectionReason = `Class C simulated provider '${provider.providerId}' is strictly excluded from live production routing tables. Only certified live gateways (Razorpay, Stripe) are permitted.`;
      }

      // Calculate factor scores
      const factorScores: Record<string, number> = {};

      // Health Score
      if (cbState === 'CLOSED') factorScores.health = 30;
      else if (cbState === 'HALF_OPEN') factorScores.health = 15;
      else factorScores.health = 0;

      // Method Match Score
      factorScores.methodMatch = eligible && method ? 25 : 10;

      // Regional Fit Score
      factorScores.regionalFit = countryMatch ? 15 : 0;

      // Priority Base Score (lower priority number = higher preference)
      const basePriority = Math.max(0, 30 - Math.min(provider.priority, 30));
      factorScores.priorityScore = basePriority;

      // Cost Calculation
      const estimatedFee = this.costModelService.estimateCost(
        provider.providerId,
        amount,
        currency,
        country,
      );
      const costModel = this.costModelService.getCostModel(
        IntegrationCategory.PAYMENT,
        provider.providerId,
      );

      // Lower cost = higher cost score (inverted)
      const maxPossibleFee = Math.max(1, amount * 0.05 + 1);
      const costScore = Math.max(0, Math.round((1 - estimatedFee / maxPossibleFee) * 20));
      factorScores.costScore = costScore;

      // Latency Score (SLA based)
      const uptime = provider.slaUptimePercent || 99.5;
      factorScores.latencyScore = uptime >= 99.9 ? 10 : 5;

      const totalScore =
        factorScores.health +
        factorScores.methodMatch +
        factorScores.regionalFit +
        factorScores.priorityScore +
        factorScores.costScore +
        factorScores.latencyScore;

      candidatesWithScores.push({
        providerId: provider.providerId,
        eligible,
        score: eligible ? totalScore : -1,
        rejectionReason,
        factorScores,
        cost: {
          fee: estimatedFee,
          percentage: costModel?.percentageFee || 0,
          fixed: costModel?.fixedFee || 0,
          currency,
        },
      });
    }

    // Sort eligible candidates by score descending
    const eligibleCandidates = candidatesWithScores
      .filter((c) => c.eligible)
      .sort((a, b) => b.score - a.score);

    if (eligibleCandidates.length === 0) {
      throw new BadRequestException(
        `No eligible payment gateway available for country: ${country}, currency: ${currency}, method: ${method || 'ANY'}`,
      );
    }

    const winner = eligibleCandidates[0];
    const fallbackChain = eligibleCandidates.slice(1).map((c) => c.providerId);
    const allCandidates = eligibleCandidates.map((c) => c.providerId);

    // Build structured explanation
    const candidateExplanations: CandidateEvaluationExplanation[] = candidatesWithScores.map((c) => ({
      providerId: c.providerId,
      eligible: c.eligible,
      score: c.score > 0 ? c.score : 0,
      rejectionReason: c.rejectionReason,
      factorScores: {
        healthScore: c.factorScores.health,
        latencyScore: c.factorScores.latencyScore,
        costScore: c.factorScores.costScore,
        capabilityScore: c.factorScores.methodMatch + c.factorScores.regionalFit,
        priorityScore: c.factorScores.priorityScore,
        policyScore: 0,
      },
    }));

    const explanation: RoutingDecisionExplanation = {
      selectedProviderId: winner.providerId,
      strategyUsed: RoutingStrategy.PRIORITY,
      reasons: [
        `Selected ${winner.providerId} with highest score (${winner.score}) for ${country}/${currency}/${method || 'DEFAULT'}`,
      ],
      candidatesEvaluated: candidateExplanations,
      fallbackChain,
    };

    return {
      primaryProviderId: winner.providerId,
      fallbackChain,
      allCandidates,
      explanation,
      estimatedFee: {
        amount: winner.cost.fee,
        currency,
        percentage: winner.cost.percentage,
        fixed: winner.cost.fixed,
      },
    };
  }

  /**
   * Evaluates whether it is strictly safe to execute a payment fallback after an attempt failure.
   * Prevents duplicate customer debit if the transaction state on the primary gateway is indeterminate.
   */
  evaluateFallbackSafety(attemptContext: {
    providerId: string;
    errorClass?: string;
    failureClassification?: string;
    stage?: 'PRE_FLIGHT' | 'POST_ORDER_DISPATCH' | 'GATEWAY_RESPONSE' | 'SIGNATURE_VERIFY';
    requestDispatchedToGateway?: boolean;
    lastKnownStatus?: string;
    transactionId?: string;
    errorMessage?: string;
  }): FallbackSafetyEvaluation {
    const errorClass = attemptContext.errorClass || attemptContext.failureClassification || '';
    const isDispatched =
      attemptContext.stage === 'POST_ORDER_DISPATCH' ||
      attemptContext.requestDispatchedToGateway === true;
    const isIndeterminate =
      attemptContext.lastKnownStatus === 'INDETERMINATE' ||
      errorClass === 'TIMEOUT' ||
      errorClass === 'NETWORK' ||
      errorClass === 'TRANSIENT';

    // If the error occurred AFTER sending payment dispatch to the gateway,
    // and resulted in TIMEOUT or NETWORK failure, fallback is DANGEROUS (double debit risk).
    if (isDispatched && isIndeterminate) {
      return {
        safeToFailover: false,
        action: 'PENDING_RECONCILIATION',
        reason: `Payment order was already dispatched to gateway. INDETERMINATE state (${errorClass || 'INDETERMINATE'}) forbids blind failover to prevent duplicate charge.`,
        recommendedPaymentStatus: 'PENDING_RECONCILIATION',
      };
    }

    if (errorClass === 'INVALID_REQUEST' || errorClass === 'AUTHENTICATION') {
      return {
        safeToFailover: false,
        action: 'ABORT',
        reason: `Request configuration error (${errorClass}): ${attemptContext.errorMessage || 'Invalid parameters'}. Failover aborted.`,
        recommendedPaymentStatus: 'FAILED',
      };
    }

    // Pre-flight failures (circuit open, rate limited, unsupported method, downtime) are safe to failover
    return {
      safeToFailover: true,
      action: 'FAILOVER',
      reason: `Pre-flight failure on ${attemptContext.providerId} (${errorClass}). Safe to execute secondary fallback gateway.`,
      recommendedPaymentStatus: 'FAILED',
    };
  }
}
