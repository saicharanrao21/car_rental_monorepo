import { BadRequestException } from '@nestjs/common';
import {
  TaxConfig,
  QuoteConfig,
  DurationDiscountTier,
  CancellationMatrixConfig,
  CommissionConfig,
  DepositDefaultsConfig,
} from './system-config.interface';

export class SystemConfigValidator {
  /**
   * Validates configuration payload strictly by key.
   * Throws BadRequestException with an actionable error description on failure.
   */
  static validate(key: string, payload: any): any {
    if (payload === null || payload === undefined) {
      throw new BadRequestException(`Configuration payload for [${key}] cannot be null or undefined.`);
    }

    switch (key) {
      case 'pricing.tax':
        return this.validateTaxConfig(payload);
      case 'pricing.quote':
        return this.validateQuoteConfig(payload);
      case 'pricing.duration_discounts':
        return this.validateDurationDiscountsConfig(payload);
      case 'booking.cancellation_matrix':
        return this.validateCancellationMatrixConfig(payload);
      case 'pricing.commission':
        return this.validateCommissionConfig(payload);
      case 'deposits.defaults':
        return this.validateDepositDefaultsConfig(payload);
      case 'wallet.rules':
        return this.validateWalletConfig(payload);
      case 'loyalty.rules':
        return this.validateLoyaltyConfig(payload);
      case 'search.ranking':
        return this.validateSearchRankingConfig(payload);
      case 'referral.rules':
        return this.validateReferralConfig(payload);
      case 'booking.policies':
        return this.validateBookingPoliciesConfig(payload);
      case 'location.rules':
        return this.validateLocationRulesConfig(payload);
      case 'vendor.onboarding.rules':
        return this.validateVendorOnboardingRulesConfig(payload);
      default:
        // Generic object validation for unspecified keys
        if (typeof payload !== 'object') {
          throw new BadRequestException(`Configuration payload for [${key}] must be an object.`);
        }
        return payload;
    }
  }

  private static validateTaxConfig(payload: any): TaxConfig {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('pricing.tax must be a JSON object containing gstRate.');
    }

    const { gstRate } = payload;
    if (gstRate === undefined || gstRate === null) {
      throw new BadRequestException('pricing.tax is missing required field "gstRate".');
    }

    if (typeof gstRate !== 'number' || isNaN(gstRate) || !isFinite(gstRate)) {
      throw new BadRequestException(`gstRate must be a finite number. Received: ${gstRate}`);
    }

    if (gstRate < 0 || gstRate > 100) {
      throw new BadRequestException(`gstRate must be between 0% and 100%. Received: ${gstRate}`);
    }

    return { gstRate };
  }

  private static validateQuoteConfig(payload: any): QuoteConfig {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('pricing.quote must be a JSON object containing validityMinutes.');
    }

    const { validityMinutes } = payload;
    if (validityMinutes === undefined || validityMinutes === null) {
      throw new BadRequestException('pricing.quote is missing required field "validityMinutes".');
    }

    if (typeof validityMinutes !== 'number' || isNaN(validityMinutes) || !isFinite(validityMinutes)) {
      throw new BadRequestException(`validityMinutes must be a number. Received: ${validityMinutes}`);
    }

    if (!Number.isInteger(validityMinutes)) {
      throw new BadRequestException(`validityMinutes must be an integer. Received: ${validityMinutes}`);
    }

    if (validityMinutes < 1 || validityMinutes > 1440) {
      throw new BadRequestException(
        `validityMinutes must be between 1 and 1440 minutes (24 hours). Received: ${validityMinutes}`,
      );
    }

    return { validityMinutes };
  }

  private static validateDurationDiscountsConfig(payload: any): DurationDiscountTier[] {
    let tiers: any[];
    if (Array.isArray(payload)) {
      tiers = payload;
    } else if (payload && typeof payload === 'object' && Array.isArray(payload.tiers)) {
      tiers = payload.tiers;
    } else {
      throw new BadRequestException(
        'pricing.duration_discounts must be an array of tiers or an object with a "tiers" array.',
      );
    }

    if (tiers.length === 0) {
      throw new BadRequestException('pricing.duration_discounts must contain at least one tier.');
    }

    const seenDays = new Set<number>();

    for (let i = 0; i < tiers.length; i++) {
      const tier = tiers[i];
      if (!tier || typeof tier !== 'object') {
        throw new BadRequestException(`Tier at index ${i} must be an object with minDays and discountPercent.`);
      }

      const { minDays, discountPercent } = tier;

      if (minDays === undefined || minDays === null) {
        throw new BadRequestException(`Tier at index ${i} is missing required field "minDays".`);
      }
      if (typeof minDays !== 'number' || isNaN(minDays) || !Number.isInteger(minDays) || minDays < 1) {
        throw new BadRequestException(`Tier at index ${i}: minDays must be an integer >= 1. Received: ${minDays}`);
      }

      if (seenDays.has(minDays)) {
        throw new BadRequestException(
          `Duplicate duration tier: minDays ${minDays} is defined multiple times. Thresholds must be unique.`,
        );
      }
      seenDays.add(minDays);

      if (discountPercent === undefined || discountPercent === null) {
        throw new BadRequestException(`Tier at index ${i} is missing required field "discountPercent".`);
      }
      if (typeof discountPercent !== 'number' || isNaN(discountPercent) || discountPercent < 0 || discountPercent > 100) {
        throw new BadRequestException(
          `Tier at index ${i}: discountPercent must be a number between 0 and 100. Received: ${discountPercent}`,
        );
      }
    }

    // Sort ascending by minDays to verify monotonicity
    const sorted = [...tiers].sort((a, b) => a.minDays - b.minDays);

    for (let i = 1; i < sorted.length; i++) {
      const prev = sorted[i - 1];
      const curr = sorted[i];
      if (curr.discountPercent < prev.discountPercent) {
        throw new BadRequestException(
          `Contradictory discount tiers: longer duration (${curr.minDays} days) has lower discount (${curr.discountPercent}%) than shorter duration (${prev.minDays} days, ${prev.discountPercent}%). Discounts must be non-decreasing.`,
        );
      }
    }

    return sorted.map((t) => ({
      minDays: t.minDays,
      discountPercent: t.discountPercent,
    }));
  }

  private static validateCancellationMatrixConfig(payload: any): CancellationMatrixConfig {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('booking.cancellation_matrix must be a JSON object containing "tiers".');
    }

    const { tiers, afterStartFeePercent, afterStartTier, afterStartDescription } = payload;

    if (!Array.isArray(tiers) || tiers.length === 0) {
      throw new BadRequestException('booking.cancellation_matrix must contain a non-empty "tiers" array.');
    }

    const seenHours = new Set<number>();

    for (let i = 0; i < tiers.length; i++) {
      const tier = tiers[i];
      if (!tier || typeof tier !== 'object') {
        throw new BadRequestException(`Cancellation tier at index ${i} must be an object.`);
      }

      const { minHoursBeforePickup, feePercent, tier: tierName, description } = tier;

      if (minHoursBeforePickup === undefined || minHoursBeforePickup === null) {
        throw new BadRequestException(`Tier at index ${i} is missing "minHoursBeforePickup".`);
      }
      if (typeof minHoursBeforePickup !== 'number' || isNaN(minHoursBeforePickup) || minHoursBeforePickup < 0) {
        throw new BadRequestException(
          `Tier at index ${i}: minHoursBeforePickup must be a non-negative number. Received: ${minHoursBeforePickup}`,
        );
      }

      if (seenHours.has(minHoursBeforePickup)) {
        throw new BadRequestException(
          `Duplicate cancellation tier: minHoursBeforePickup ${minHoursBeforePickup} is defined multiple times.`,
        );
      }
      seenHours.add(minHoursBeforePickup);

      if (feePercent === undefined || feePercent === null) {
        throw new BadRequestException(`Tier at index ${i} is missing "feePercent".`);
      }
      if (typeof feePercent !== 'number' || isNaN(feePercent) || feePercent < 0 || feePercent > 100) {
        throw new BadRequestException(
          `Tier at index ${i}: feePercent must be a number between 0 and 100. Received: ${feePercent}`,
        );
      }

      if (!tierName || typeof tierName !== 'string' || tierName.trim().length === 0) {
        throw new BadRequestException(`Tier at index ${i} must have a non-empty "tier" identifier string.`);
      }
    }

    // Verify fee progression: as pickup time approaches (hours decrease), fee must NOT decrease!
    // Sort descending by minHoursBeforePickup (e.g. 48h, 24h, 6h, 0h)
    const sortedDesc = [...tiers].sort((a, b) => b.minHoursBeforePickup - a.minHoursBeforePickup);

    for (let i = 1; i < sortedDesc.length; i++) {
      const earlierInTime = sortedDesc[i - 1]; // e.g. 24h before pickup
      const laterInTime = sortedDesc[i];       // e.g. 6h before pickup (closer to pickup)

      if (laterInTime.feePercent < earlierInTime.feePercent) {
        throw new BadRequestException(
          `Contradictory cancellation policy: fee at ${laterInTime.minHoursBeforePickup}h before pickup (${laterInTime.feePercent}%) cannot be lower than fee at ${earlierInTime.minHoursBeforePickup}h before pickup (${earlierInTime.feePercent}%). Cancellation fees must increase as pickup nears.`,
        );
      }
    }

    // Validate after-start fee
    const effectiveAfterStartFee = afterStartFeePercent !== undefined ? afterStartFeePercent : 100;
    if (
      typeof effectiveAfterStartFee !== 'number' ||
      isNaN(effectiveAfterStartFee) ||
      effectiveAfterStartFee < 0 ||
      effectiveAfterStartFee > 100
    ) {
      throw new BadRequestException(
        `afterStartFeePercent must be a number between 0 and 100. Received: ${effectiveAfterStartFee}`,
      );
    }

    const maxTierFee = Math.max(...tiers.map((t) => t.feePercent));
    if (effectiveAfterStartFee < maxTierFee) {
      throw new BadRequestException(
        `Invalid cancellation policy: afterStartFeePercent (${effectiveAfterStartFee}%) cannot be lower than the pre-trip cancellation fee (${maxTierFee}%).`,
      );
    }

    return {
      tiers: sortedDesc.map((t) => ({
        minHoursBeforePickup: t.minHoursBeforePickup,
        feePercent: t.feePercent,
        tier: t.tier.trim(),
        description: t.description || `Cancellation within ${t.minHoursBeforePickup}h`,
      })),
      afterStartFeePercent: effectiveAfterStartFee,
      afterStartTier: afterStartTier || 'NO_REFUND_AFTER_START',
      afterStartDescription: afterStartDescription || 'Cancellation after trip pickup time (Non-refundable)',
    };
  }

  private static validateCommissionConfig(payload: any): CommissionConfig {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('pricing.commission must be a JSON object.');
    }

    const rate = payload.defaultPercent ?? payload.defaultRate ?? payload.defaultCommissionPercent;

    if (rate === undefined || rate === null) {
      throw new BadRequestException('pricing.commission is missing required field "defaultPercent".');
    }

    if (typeof rate !== 'number' || isNaN(rate) || !isFinite(rate)) {
      throw new BadRequestException(`defaultPercent must be a number. Received: ${rate}`);
    }

    if (rate < 0 || rate > 100) {
      throw new BadRequestException(`defaultPercent must be between 0% and 100%. Received: ${rate}`);
    }

    return { defaultPercent: rate };
  }

  private static validateDepositDefaultsConfig(payload: any): DepositDefaultsConfig {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('deposits.defaults must be a category-to-amount map object.');
    }

    const recognizedCategories = ['HATCHBACK', 'SEDAN', 'SUV', 'LUXURY', 'TEMPO_TRAVELLER', 'MINI_BUS'];
    const requiredCategories = ['HATCHBACK', 'SEDAN', 'SUV', 'LUXURY'];

    for (const reqCat of requiredCategories) {
      if (payload[reqCat] === undefined || payload[reqCat] === null) {
        throw new BadRequestException(`deposits.defaults is missing required category "${reqCat}".`);
      }
    }

    const validated: Record<string, number> = {};

    for (const [cat, amount] of Object.entries(payload)) {
      if (typeof amount !== 'number' || isNaN(amount) || !isFinite(amount)) {
        throw new BadRequestException(`Deposit amount for category ${cat} must be a number. Received: ${amount}`);
      }

      if (amount < 0) {
        throw new BadRequestException(`Deposit amount for category ${cat} cannot be negative. Received: ${amount}`);
      }

      if (amount > 1000000) {
        throw new BadRequestException(`Deposit amount for category ${cat} exceeds maximum limit of ₹1,000,000.`);
      }

      validated[cat] = amount;
    }

    return validated as DepositDefaultsConfig;
  }

  private static validateWalletConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('wallet.rules must be a JSON object.');
    }

    if (payload.isEnabled !== undefined && typeof payload.isEnabled !== 'boolean') {
      throw new BadRequestException('isEnabled must be a boolean.');
    }

    if (payload.maxSingleDeposit !== undefined) {
      const v = Number(payload.maxSingleDeposit);
      if (isNaN(v) || v < 500 || v > 500000) {
        throw new BadRequestException('maxSingleDeposit must be between ₹500 and ₹500,000.');
      }
    }

    if (payload.minSingleDeposit !== undefined) {
      const v = Number(payload.minSingleDeposit);
      if (isNaN(v) || v < 10 || v > 100000) {
        throw new BadRequestException('minSingleDeposit must be between ₹10 and ₹100,000.');
      }
    }

    if (payload.maxWalletPaymentPercentage !== undefined) {
      const v = Number(payload.maxWalletPaymentPercentage);
      if (isNaN(v) || v < 5 || v > 100) {
        throw new BadRequestException('maxWalletPaymentPercentage must be between 5% and 100%.');
      }
    }

    if (payload.isDepositsEnabled !== undefined && typeof payload.isDepositsEnabled !== 'boolean') {
      throw new BadRequestException('isDepositsEnabled must be a boolean.');
    }

    return payload;
  }

  private static validateLoyaltyConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('loyalty.rules must be a JSON object.');
    }

    if (payload.isEnabled !== undefined && typeof payload.isEnabled !== 'boolean') {
      throw new BadRequestException('isEnabled must be a boolean.');
    }

    if (payload.rupeesPerPointEarned !== undefined) {
      const v = Number(payload.rupeesPerPointEarned);
      if (isNaN(v) || v <= 0 || v > 10000) {
        throw new BadRequestException('rupeesPerPointEarned must be a positive number up to 10,000.');
      }
    }

    if (payload.pointsToRupeeRatio !== undefined) {
      const v = Number(payload.pointsToRupeeRatio);
      if (isNaN(v) || v <= 0 || v > 1000) {
        throw new BadRequestException('pointsToRupeeRatio must be a positive number up to 1,000.');
      }
    }

    if (payload.minPointsToRedeem !== undefined) {
      const v = Number(payload.minPointsToRedeem);
      if (isNaN(v) || v < 1) {
        throw new BadRequestException('minPointsToRedeem must be at least 1 point.');
      }
    }

    if (payload.maxPointsPerBooking !== undefined) {
      const v = Number(payload.maxPointsPerBooking);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('maxPointsPerBooking must be a positive number.');
      }
    }

    return payload;
  }

  private static validateSearchRankingConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('search.ranking must be a JSON object.');
    }

    if (payload.sponsoredBoostMultiplier !== undefined) {
      const v = Number(payload.sponsoredBoostMultiplier);
      if (isNaN(v) || v < 1.0 || v > 3.0) {
        throw new BadRequestException('sponsoredBoostMultiplier must be between 1.0x and 3.0x.');
      }
    }

    if (payload.featuredBoostMultiplier !== undefined) {
      const v = Number(payload.featuredBoostMultiplier);
      if (isNaN(v) || v < 1.0 || v > 3.0) {
        throw new BadRequestException('featuredBoostMultiplier must be between 1.0x and 3.0x.');
      }
    }

    return payload;
  }

  private static validateReferralConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('referral.rules must be a JSON object.');
    }

    if (payload.isReferralsEnabled !== undefined && typeof payload.isReferralsEnabled !== 'boolean') {
      throw new BadRequestException('isReferralsEnabled must be a boolean.');
    }

    if (payload.rewardType !== undefined) {
      if (!['WALLET_CREDIT', 'REWARD_POINTS'].includes(payload.rewardType)) {
        throw new BadRequestException("rewardType must be either 'WALLET_CREDIT' or 'REWARD_POINTS'.");
      }
    }

    if (payload.defaultReferrerReward !== undefined) {
      const v = Number(payload.defaultReferrerReward);
      if (isNaN(v) || v < 0 || v > 10000) {
        throw new BadRequestException('defaultReferrerReward must be between ₹0 and ₹10,000.');
      }
    }

    if (payload.defaultRefereeReward !== undefined) {
      const v = Number(payload.defaultRefereeReward);
      if (isNaN(v) || v < 0 || v > 10000) {
        throw new BadRequestException('defaultRefereeReward must be between ₹0 and ₹10,000.');
      }
    }

    if (payload.minBookingAmount !== undefined) {
      const v = Number(payload.minBookingAmount);
      if (isNaN(v) || v < 0) {
        throw new BadRequestException('minBookingAmount must be a non-negative number.');
      }
    }

    if (payload.maxReferralsPerUser !== undefined) {
      const v = Number(payload.maxReferralsPerUser);
      if (isNaN(v) || v < 1 || v > 1000) {
        throw new BadRequestException('maxReferralsPerUser must be between 1 and 1,000.');
      }
    }

    return payload;
  }

  private static validateBookingPoliciesConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('booking.policies must be a JSON object.');
    }

    if (payload.handoverOtpTtlMinutes !== undefined) {
      const v = Number(payload.handoverOtpTtlMinutes);
      if (isNaN(v) || v < 1 || v > 120) {
        throw new BadRequestException('handoverOtpTtlMinutes must be between 1 and 120 minutes.');
      }
    }

    if (payload.cancellationGraceMinutes !== undefined) {
      const v = Number(payload.cancellationGraceMinutes);
      if (isNaN(v) || v < 0 || v > 1440) {
        throw new BadRequestException('cancellationGraceMinutes must be between 0 and 1440 minutes.');
      }
    }

    return payload;
  }

  private static validateLocationRulesConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('location.rules must be a JSON object.');
    }

    if (payload.defaultRadiusMeters !== undefined) {
      const v = Number(payload.defaultRadiusMeters);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('defaultRadiusMeters must be a positive number.');
      }
    }

    if (payload.maxServiceRadiusMeters !== undefined) {
      const v = Number(payload.maxServiceRadiusMeters);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('maxServiceRadiusMeters must be a positive number.');
      }
    }

    if (payload.minServiceRadiusMeters !== undefined) {
      const v = Number(payload.minServiceRadiusMeters);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('minServiceRadiusMeters must be a positive number.');
      }
    }

    if (payload.comingSoonCatchmentRadiusKm !== undefined) {
      const v = Number(payload.comingSoonCatchmentRadiusKm);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('comingSoonCatchmentRadiusKm must be a positive number.');
      }
    }

    if (payload.maxNearestAreasToSuggest !== undefined) {
      const v = Number(payload.maxNearestAreasToSuggest);
      if (isNaN(v) || v <= 0) {
        throw new BadRequestException('maxNearestAreasToSuggest must be a positive number.');
      }
    }

    return payload;
  }

  private static validateVendorOnboardingRulesConfig(payload: any): any {
    if (typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('vendor.onboarding.rules must be a JSON object.');
    }

    if (payload.defaultSecurityDepositAmount !== undefined) {
      const v = Number(payload.defaultSecurityDepositAmount);
      if (isNaN(v) || v < 0) {
        throw new BadRequestException('defaultSecurityDepositAmount must be a non-negative number.');
      }
    }

    if (payload.allowPartialDepositPayment !== undefined && typeof payload.allowPartialDepositPayment !== 'boolean') {
      throw new BadRequestException('allowPartialDepositPayment must be a boolean.');
    }

    if (payload.minInitialDepositPercentage !== undefined) {
      const v = Number(payload.minInitialDepositPercentage);
      if (isNaN(v) || v < 0 || v > 100) {
        throw new BadRequestException('minInitialDepositPercentage must be between 0 and 100.');
      }
    }

    if (payload.documentExpiryGracePeriodDays !== undefined) {
      const v = Number(payload.documentExpiryGracePeriodDays);
      if (isNaN(v) || v < 0) {
        throw new BadRequestException('documentExpiryGracePeriodDays must be a non-negative number.');
      }
    }

    if (payload.strictActivationEnforcement !== undefined && typeof payload.strictActivationEnforcement !== 'boolean') {
      throw new BadRequestException('strictActivationEnforcement must be a boolean.');
    }

    if (payload.autoCheckEligibilityOnUpload !== undefined && typeof payload.autoCheckEligibilityOnUpload !== 'boolean') {
      throw new BadRequestException('autoCheckEligibilityOnUpload must be a boolean.');
    }

    return payload;
  }
}
