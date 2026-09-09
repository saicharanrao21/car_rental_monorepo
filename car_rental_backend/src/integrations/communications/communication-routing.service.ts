import { Injectable, Logger } from '@nestjs/common';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { CostModelService } from '../runtime/cost-model.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { IntegrationCategory } from '../registry/provider.types';
import {
  CommunicationChannel,
  CommunicationMessageType,
  CommunicationPriority,
  CommunicationRecipient,
  CommunicationRoutingDecision,
  FallbackSafetyCheck,
  DeliveryStatus,
  RoutingOptimizationGoal,
} from './communication.types';

@Injectable()
export class CommunicationRoutingService {
  private readonly logger = new Logger(CommunicationRoutingService.name);

  // Default channel preference chains based on message type
  private readonly defaultChannelChains: Record<CommunicationMessageType, CommunicationChannel[]> = {
    [CommunicationMessageType.OTP]: [
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.SMS,
      CommunicationChannel.VOICE,
    ],
    [CommunicationMessageType.TRANSACTIONAL]: [
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.SMS,
      CommunicationChannel.EMAIL,
    ],
    [CommunicationMessageType.OPERATIONAL]: [
      CommunicationChannel.PUSH,
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.SMS,
    ],
    [CommunicationMessageType.CRITICAL_ALERT]: [
      CommunicationChannel.PUSH,
      CommunicationChannel.SMS,
      CommunicationChannel.VOICE,
    ],
    [CommunicationMessageType.MARKETING]: [
      CommunicationChannel.PUSH,
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.EMAIL,
    ],
    [CommunicationMessageType.PROMOTIONAL]: [
      CommunicationChannel.PUSH,
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.EMAIL,
    ],
    [CommunicationMessageType.SECURITY]: [
      CommunicationChannel.SMS,
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.EMAIL,
      CommunicationChannel.VOICE,
    ],
    [CommunicationMessageType.SYSTEM]: [
      CommunicationChannel.EMAIL,
      CommunicationChannel.PUSH,
      CommunicationChannel.SMS,
    ],
    [CommunicationMessageType.ALERT]: [
      CommunicationChannel.PUSH,
      CommunicationChannel.SMS,
      CommunicationChannel.WHATSAPP,
    ],
    [CommunicationMessageType.SUPPORT]: [
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.EMAIL,
      CommunicationChannel.SMS,
    ],
    [CommunicationMessageType.CRITICAL]: [
      CommunicationChannel.SMS,
      CommunicationChannel.VOICE,
      CommunicationChannel.PUSH,
      CommunicationChannel.WHATSAPP,
    ],
    [CommunicationMessageType.LIFECYCLE]: [
      CommunicationChannel.EMAIL,
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.PUSH,
    ],
  };

  constructor(
    private readonly catalogService: ProviderCatalogService,
    private readonly circuitBreaker: CircuitBreakerService,
    private readonly costModel: CostModelService,
    private readonly configService: IntegrationConfigService,
  ) {}

  /**
   * Maps a high-level CommunicationChannel to the underlying IntegrationCategory.
   */
  mapChannelToCategory(channel: CommunicationChannel): IntegrationCategory {
    switch (channel) {
      case CommunicationChannel.WHATSAPP:
        return IntegrationCategory.MESSAGING_WHATSAPP;
      case CommunicationChannel.SMS:
        return IntegrationCategory.MESSAGING_SMS;
      case CommunicationChannel.EMAIL:
        return IntegrationCategory.MESSAGING_EMAIL;
      case CommunicationChannel.PUSH:
        return IntegrationCategory.MESSAGING_PUSH;
      case CommunicationChannel.VOICE:
        return IntegrationCategory.VOICE_IVR;
      case CommunicationChannel.OTP:
        return IntegrationCategory.MESSAGING_SMS;
      default:
        return IntegrationCategory.MESSAGING_SMS;
    }
  }

  /**
   * Returns the ordered channel fallback chain for a given message type.
   */
  resolveChannelFallbackChain(messageType: CommunicationMessageType): CommunicationChannel[] {
    return this.defaultChannelChains[messageType] || [
      CommunicationChannel.WHATSAPP,
      CommunicationChannel.SMS,
      CommunicationChannel.EMAIL,
    ];
  }

  /**
   * Resolves the primary channel and candidates for a communication request.
   */
  async resolveCommunicationRoute(params: {
    channel?: CommunicationChannel;
    messageType: CommunicationMessageType;
    priority?: CommunicationPriority;
    recipient?: CommunicationRecipient;
    country?: string;
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
    optimizationGoal?: RoutingOptimizationGoal;
  }): Promise<CommunicationRoutingDecision> {
    const {
      channel: requestedChannel,
      messageType,
      recipient = {},
      optimizationGoal = RoutingOptimizationGoal.BALANCED,
    } = params;

    const country = (
      params.country ||
      recipient.country ||
      (recipient.phone?.startsWith('+91') ? 'IN' : 'US')
    ).toUpperCase();

    // 1. Resolve Channel Chain
    let targetChannel: CommunicationChannel;
    let fallbackChannels: CommunicationChannel[] = [];

    if (requestedChannel) {
      targetChannel = requestedChannel;
      // Derived fallback channels
      const chain = this.defaultChannelChains[messageType] || [CommunicationChannel.SMS];
      fallbackChannels = chain.filter((c) => c !== requestedChannel);
    } else {
      const chain = this.defaultChannelChains[messageType] || [CommunicationChannel.SMS];
      targetChannel = chain[0];
      fallbackChannels = chain.slice(1);
    }

    // 2. Resolve Providers for target channel
    const primaryCategory = this.mapChannelToCategory(targetChannel);
    const catalogProviders = this.catalogService.getCategoryProviders(primaryCategory);

    const candidateEvaluations: Array<{
      providerId: string;
      channel: CommunicationChannel;
      eligible: boolean;
      totalScore: number;
      rejectionReason?: string;
      breakdown: Record<string, number>;
    }> = [];

    for (const provider of catalogProviders) {
      let eligible = true;
      let rejectionReason: string | undefined;

      // Check Circuit Breaker
      const cbState = this.circuitBreaker.getState(provider.providerId);
      if (cbState === 'OPEN') {
        eligible = false;
        rejectionReason = `Circuit Breaker is OPEN due to downstream error rate`;
      }

      // Check Country support
      const countryMatch =
        provider.supportedCountries.length === 0 ||
        provider.supportedCountries.includes('GLOBAL') ||
        provider.supportedCountries.includes(country);

      if (eligible && !countryMatch) {
        eligible = false;
        rejectionReason = `Provider does not support destination country ${country}`;
      }

      const breakdown: Record<string, number> = {};

      // Health Score (30 pts)
      if (cbState === 'CLOSED') breakdown.health = 30;
      else if (cbState === 'HALF_OPEN') breakdown.health = 15;
      else breakdown.health = 0;

      // Regional Affinity (25 pts)
      breakdown.regionalFit = countryMatch ? 25 : 5;

      // Implementation Status (25 pts for LIVE_READY / ADAPTER_IMPLEMENTED)
      if (provider.implementationStatus === 'LIVE_READY') breakdown.readiness = 25;
      else if (provider.implementationStatus === 'ADAPTER_IMPLEMENTED') breakdown.readiness = 20;
      else if (provider.implementationStatus === 'CONTRACT_READY') breakdown.readiness = 10;
      else breakdown.readiness = 5;

      // Priority Base (20 pts)
      const basePriority = provider.priority || 100;
      breakdown.priority = Math.max(0, 20 - Math.floor(basePriority / 5));

      // Cost Optimization Score (10 pts)
      const costEstimate = provider.costModel?.fixedFee || 0.15;
      if (optimizationGoal === RoutingOptimizationGoal.LOWEST_COST) {
        breakdown.cost = Math.max(0, 20 - costEstimate * 10);
      } else {
        breakdown.cost = Math.max(0, 10 - costEstimate * 5);
      }

      const totalScore = Object.values(breakdown).reduce((sum, v) => sum + v, 0);

      candidateEvaluations.push({
        providerId: provider.providerId,
        channel: targetChannel,
        eligible,
        totalScore: eligible ? totalScore : -1,
        rejectionReason,
        breakdown,
      });
    }

    // Sort eligible candidates by score desc
    const eligibleCandidates = candidateEvaluations
      .filter((c) => c.eligible)
      .sort((a, b) => b.totalScore - a.totalScore);

    const primaryCandidate = eligibleCandidates[0];
    const primaryProviderId = primaryCandidate ? primaryCandidate.providerId : 'mock_sms';

    // 3. Build Fallback Chain across providers and channels
    const fallbackChain: Array<{ channel: CommunicationChannel; providerId: string }> = [];

    // Secondary provider on same channel
    if (eligibleCandidates.length > 1) {
      fallbackChain.push({
        channel: targetChannel,
        providerId: eligibleCandidates[1].providerId,
      });
    }

    // Secondary channel providers
    for (const fbChannel of fallbackChannels.slice(0, 2)) {
      const fbCat = this.mapChannelToCategory(fbChannel);
      const fbProviders = this.catalogService.getCategoryProviders(fbCat);
      const availableFb = fbProviders.find((p) => this.circuitBreaker.isAvailable(p.providerId));
      if (availableFb) {
        fallbackChain.push({
          channel: fbChannel,
          providerId: availableFb.providerId,
        });
      }
    }

    const winningBreakdown = primaryCandidate ? primaryCandidate.breakdown : { default: 10 };

    return {
      channel: targetChannel,
      primaryProviderId,
      fallbackChain,
      estimatedCost: 0.15,
      expectedLatencyMs: 45,
      scoreBreakdown: winningBreakdown,
      explanation: `Selected ${primaryProviderId} for ${targetChannel} (Score: ${primaryCandidate?.totalScore || 0}). Factors: health (${winningBreakdown.health || 0}), regional (${winningBreakdown.regionalFit || 0}), readiness (${winningBreakdown.readiness || 0}).`,
      candidateEvaluations: candidateEvaluations.map((c) => ({
        providerId: c.providerId,
        channel: c.channel,
        eligible: c.eligible,
        totalScore: c.totalScore,
        rejectionReason: c.rejectionReason,
      })),
    };
  }

  /**
   * Evaluates whether it is strictly safe to execute a communications fallback.
   * Prevents duplicate customer notification blasts when a message was already dispatched.
   */
  evaluateCommunicationFallbackSafety(attemptContext: {
    providerId: string;
    channel: CommunicationChannel;
    errorClass?: string;
    failureClassification?: string;
    requestDispatchedToProvider?: boolean;
    lastKnownStatus?: string;
    messageId?: string;
    errorMessage?: string;
  }): FallbackSafetyCheck {
    const errorClass = attemptContext.errorClass || attemptContext.failureClassification || '';
    const isDispatched = attemptContext.requestDispatchedToProvider === true;
    const isIndeterminate =
      attemptContext.lastKnownStatus === 'INDETERMINATE' ||
      errorClass === 'TIMEOUT' ||
      errorClass === 'NETWORK_FAILURE';

    // 1. Post-dispatch indeterminate state forbids blind failover (double notification hazard)
    if (isDispatched && isIndeterminate) {
      return {
        safeToFailover: false,
        action: 'PENDING_DELIVERY_CONFIRMATION',
        reason: `Message already dispatched to provider [${attemptContext.providerId}]. INDETERMINATE delivery state (${errorClass}) forbids blind failover to prevent duplicate customer notifications.`,
        recommendedStatus: DeliveryStatus.FALLBACK_PENDING,
      };
    }

    // 2. Permanent recipient errors abort delivery across all channels
    if (errorClass === 'INVALID_NUMBER' || errorClass === 'BLOCKED' || errorClass === 'OPT_OUT') {
      return {
        safeToFailover: false,
        action: 'ABORT',
        reason: `Recipient permanent delivery rejection (${errorClass}): ${attemptContext.errorMessage || 'Invalid contact'}. Aborting failover.`,
        recommendedStatus: DeliveryStatus.FAILED,
      };
    }

    // 3. Pre-flight failures (circuit open, rate limit, authentication, provider down) are safe to failover
    return {
      safeToFailover: true,
      action: 'FAILOVER',
      reason: `Pre-flight failure on ${attemptContext.providerId} (${errorClass}). Safe to engage fallback channel/provider.`,
      recommendedStatus: DeliveryStatus.FALLBACK_SENT,
    };
  }
}
