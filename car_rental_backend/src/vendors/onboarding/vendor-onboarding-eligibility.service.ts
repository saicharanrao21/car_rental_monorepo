import { Injectable, Logger, Optional } from '@nestjs/common';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../../redis/redis-namespace.constants';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { VendorOnboardingRequirementsService } from './vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from './vendor-security-deposit.service';
import {
  VendorEligibilityResult,
  RequirementFulfillmentStatus,
  OnboardingEligibilityState,
} from './onboarding.types';

@Injectable()
export class VendorOnboardingEligibilityService {
  private readonly logger = new Logger(VendorOnboardingEligibilityService.name);

  constructor(
    private readonly requirementsService: VendorOnboardingRequirementsService,
    private readonly depositService: VendorSecurityDepositService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {}

  /**
   * Evaluates vendor onboarding and compliance readiness.
   * Cached in Redis for performance and invalidated on any state change.
   */
  async evaluateEligibility(
    vendorId: string,
    bypassCache: boolean = false,
  ): Promise<VendorEligibilityResult> {
    const cacheKey = REDIS_NAMESPACES.CACHE.VENDOR_ONBOARDING_ELIGIBILITY(vendorId);

    if (!bypassCache) {
      const cached = await this.cacheService.get<VendorEligibilityResult>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const [requirements, depositSummary] = await Promise.all([
      this.requirementsService.resolveRequirementsForVendor(vendorId),
      this.depositService.getDepositSummary(vendorId),
    ]);

    let approvedCount = 0;
    let pendingCount = 0;
    let underReviewCount = 0;
    let rejectedCount = 0;
    let waivedCount = 0;
    let expiredCount = 0;

    const blockingReasons: string[] = [];

    for (const req of requirements) {
      switch (req.status) {
        case RequirementFulfillmentStatus.APPROVED:
          approvedCount++;
          break;
        case RequirementFulfillmentStatus.WAIVED:
          waivedCount++;
          break;
        case RequirementFulfillmentStatus.PENDING:
          pendingCount++;
          if (req.isRequired) {
            blockingReasons.push(`Mandatory requirement [${req.name}] is pending submission.`);
          }
          break;
        case RequirementFulfillmentStatus.SUBMITTED:
        case RequirementFulfillmentStatus.UNDER_REVIEW:
          underReviewCount++;
          if (req.isRequired) {
            blockingReasons.push(`Mandatory requirement [${req.name}] is currently under review.`);
          }
          break;
        case RequirementFulfillmentStatus.REJECTED:
          rejectedCount++;
          if (req.isRequired) {
            blockingReasons.push(
              `Mandatory requirement [${req.name}] was rejected: ${req.rejectionReason ?? 'Proof unacceptable'}.`,
            );
          }
          break;
        case RequirementFulfillmentStatus.EXPIRED:
          expiredCount++;
          if (req.isRequired) {
            blockingReasons.push(`Mandatory requirement [${req.name}] has expired.`);
          }
          break;
      }
    }

    // Security deposit check
    if (!depositSummary.isSatisfied) {
      blockingReasons.push(
        `Security deposit requirement is unsatisfied (INR ${depositSummary.paidAmount} of INR ${depositSummary.requiredAmount} deposited). Status: ${depositSummary.status}.`,
      );
    }

    let strictEnforcement = true;
    if (this.systemConfigService) {
      try {
        const config = await this.systemConfigService.getVendorOnboardingConfig();
        if (config && config.strictActivationEnforcement !== undefined) {
          strictEnforcement = config.strictActivationEnforcement;
        }
      } catch {
        // fallback to strict enforcement
      }
    }

    const hasFatalBlocks = rejectedCount > 0 || expiredCount > 0;
    const isEligible = strictEnforcement
      ? blockingReasons.length === 0
      : !hasFatalBlocks;

    let eligibilityState: OnboardingEligibilityState = 'INCOMPLETE';
    if (isEligible) {
      eligibilityState = 'ELIGIBLE';
    } else if (rejectedCount > 0 || expiredCount > 0) {
      eligibilityState = 'BLOCKED';
    } else if (underReviewCount > 0 && pendingCount === 0) {
      eligibilityState = 'UNDER_REVIEW';
    } else {
      eligibilityState = 'INCOMPLETE';
    }

    const result: VendorEligibilityResult = {
      vendorId,
      isEligible,
      eligibilityState,
      summary: {
        totalRequirements: requirements.length,
        approvedCount,
        pendingCount,
        underReviewCount,
        rejectedCount,
        waivedCount,
        expiredCount,
      },
      depositSummary,
      requirements,
      blockingReasons,
      evaluatedAt: new Date(),
    };

    await this.cacheService.set(cacheKey, result, DEFAULT_CACHE_TTLS.MEDIUM_TERM);
    return result;
  }
}
