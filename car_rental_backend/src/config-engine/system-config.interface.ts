export interface WalletConfig {
  maxSingleDeposit: number;
  minSingleDeposit: number;
  maxWalletBalanceCap: number;
  maxWalletPaymentPercentage: number; // e.g. 100% or 30%
  minBookingAmountForWalletUse: number; // e.g. ₹500
  maxPromoCreditPerBooking: number; // e.g. ₹1000
  maxDailyWalletUsage: number; // e.g. ₹25000
  isDepositsEnabled: boolean;
}

export interface ReferralConfig {
  defaultReferrerReward: number;
  defaultRefereeReward: number;
  minBookingAmount: number;
  maxReferralsPerUser: number;
  isReferralsEnabled: boolean;
}

export interface GrowthCampaignConfig {
  enablePromotionalCampaigns: boolean;
  enableSponsoredListings: boolean;
  enableFeaturedListings: boolean;
  sponsoredMaxBoostMultiplier: number;
  featuredMaxBoostMultiplier: number;
}

export interface SearchRankingConfig {
  relevanceWeight: number; // 0.0 - 1.0
  distanceWeight: number; // 0.0 - 1.0
  ratingWeight: number; // 0.0 - 1.0
  availabilityWeight: number; // 0.0 - 1.0
  sponsoredBoostMultiplier: number; // e.g. 1.25x
  featuredBoostMultiplier: number; // e.g. 1.15x
}

export interface BookingPolicyConfig {
  handoverOtpTtlMinutes: number;
  cancellationGraceMinutes: number;
  maxAdvanceBookingDays: number;
  doorstepDeliveryMaxRadiusKm: number;
}

export interface PlatformFeatureFlags {
  enableDoorstepDelivery: boolean;
  enableSplitPayments: boolean;
  enableWalletCashback: boolean;
  enableInstantBooking: boolean;
  enableWhatsAppNotifications: boolean;
}

export const DEFAULT_SYSTEM_CONFIGS: Record<string, { category: string; value: any; isPublic: boolean; description: string }> = {
  'wallet.rules': {
    category: 'WALLET',
    value: {
      maxSingleDeposit: 50000,
      minSingleDeposit: 100,
      maxWalletBalanceCap: 100000,
      maxWalletPaymentPercentage: 100,
      minBookingAmountForWalletUse: 0,
      maxPromoCreditPerBooking: 5000,
      maxDailyWalletUsage: 50000,
      isDepositsEnabled: true,
    } as WalletConfig,
    isPublic: true,
    description: 'Wallet deposit limits, checkout usage caps, and promotional credit bounds',
  },
  'growth.campaigns': {
    category: 'GROWTH',
    value: {
      enablePromotionalCampaigns: true,
      enableSponsoredListings: true,
      enableFeaturedListings: true,
      sponsoredMaxBoostMultiplier: 2.0,
      featuredMaxBoostMultiplier: 1.5,
    } as GrowthCampaignConfig,
    isPublic: false,
    description: 'Growth and marketplace monetization campaign controls and multiplier ceilings',
  },
  'referral.rules': {
    category: 'REFERRAL',
    value: {
      defaultReferrerReward: 250,
      defaultRefereeReward: 250,
      minBookingAmount: 1000,
      maxReferralsPerUser: 20,
      isReferralsEnabled: true,
    } as ReferralConfig,
    isPublic: true,
    description: 'Referral program reward values and qualification thresholds',
  },
  'search.ranking': {
    category: 'SEARCH',
    value: {
      relevanceWeight: 0.35,
      distanceWeight: 0.35,
      ratingWeight: 0.20,
      availabilityWeight: 0.10,
      sponsoredBoostMultiplier: 1.25,
      featuredBoostMultiplier: 1.15,
    } as SearchRankingConfig,
    isPublic: false,
    description: 'Multi-variable ranking algorithm weights and sponsored placement multipliers',
  },
  'booking.policies': {
    category: 'BOOKING',
    value: {
      handoverOtpTtlMinutes: 15,
      cancellationGraceMinutes: 60,
      maxAdvanceBookingDays: 90,
      doorstepDeliveryMaxRadiusKm: 50,
    } as BookingPolicyConfig,
    isPublic: true,
    description: 'Operational booking constraints and time limits',
  },
  'platform.feature_flags': {
    category: 'FEATURE_FLAGS',
    value: {
      enableDoorstepDelivery: true,
      enableSplitPayments: true,
      enableWalletCashback: true,
      enableInstantBooking: true,
      enableWhatsAppNotifications: true,
    } as PlatformFeatureFlags,
    isPublic: true,
    description: 'Global dynamic feature flags controlling client application features',
  },
};
