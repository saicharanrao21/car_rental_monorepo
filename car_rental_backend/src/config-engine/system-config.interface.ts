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

export interface NotificationConfig {
  enableFcmPush: boolean;
  enableSmsNotifications: boolean;
  enableEmailNotifications: boolean;
  enableWhatsAppNotifications: boolean;
  maxBatchMulticastSize: number;
  retentionDaysTransactional: number;
  retentionDaysMarketing: number;
}

export interface SupportSlaConfig {
  firstResponseMinutesUrgent: number;
  firstResponseMinutesHigh: number;
  firstResponseMinutesNormal: number;
  resolutionMinutesUrgent: number;
  resolutionMinutesHigh: number;
  resolutionMinutesNormal: number;
  maxOpenTicketsPerCustomer: number;
}

export interface PayoutConfig {
  minPayoutAmount: number;
  maxSinglePayoutAmount: number;
  dailyVendorPayoutCap: number;
  payoutApprovalThreshold: number;
  autoPayoutEnabled: boolean;
  settlementHoldDays: number;
}

export interface ReconciliationConfig {
  autoHealMinorDrifts: boolean;
  alertDiscrepancyThreshold: number;
  cronIntervalMinutes: number;
}

export interface AnalyticsConfig {
  rawEventRetentionDays: number;
  enableRealtimeEventTracking: boolean;
  aggregationIntervalMinutes: number;
  churnInactivityDays: number;
  vendorRiskInactivityDays: number;
  alertPaymentFailureSpikeRate: number;
  alertCancellationSpikeRate: number;
}

export interface PlatformFeatureFlags {
  enableDoorstepDelivery: boolean;
  enableSplitPayments: boolean;
  enableWalletCashback: boolean;
  enableInstantBooking: boolean;
  enableWhatsAppNotifications: boolean;
}

export interface TaxConfig {
  gstRate: number; // e.g. 18 (%)
}

export interface QuoteConfig {
  validityMinutes: number; // e.g. 15 (minutes)
}

export interface DurationDiscountTier {
  minDays: number;
  discountPercent: number;
}

export interface CancellationTier {
  minHoursBeforePickup: number; // e.g. 24, 6, 0
  feePercent: number; // e.g. 0, 25, 50
  tier: string;
  description: string;
}

export interface CancellationMatrixConfig {
  tiers: CancellationTier[];
  afterStartFeePercent: number; // e.g. 100
  afterStartTier?: string;
  afterStartDescription?: string;
}

export interface CommissionConfig {
  defaultPercent: number; // e.g. 10 (%)
}

export interface DepositDefaultsConfig {
  HATCHBACK: number;
  SEDAN: number;
  SUV: number;
  LUXURY: number;
  TEMPO_TRAVELLER?: number;
  MINI_BUS?: number;
  [key: string]: number | undefined;
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
  'notification.orchestration': {
    category: 'NOTIFICATION',
    value: {
      enableFcmPush: true,
      enableSmsNotifications: true,
      enableEmailNotifications: true,
      enableWhatsAppNotifications: true,
      maxBatchMulticastSize: 500,
      retentionDaysTransactional: 365,
      retentionDaysMarketing: 30,
    } as NotificationConfig,
    isPublic: false,
    description: 'Cross-channel notification delivery rules and retention policies',
  },
  'support.sla': {
    category: 'SUPPORT',
    value: {
      firstResponseMinutesUrgent: 15,
      firstResponseMinutesHigh: 60,
      firstResponseMinutesNormal: 240,
      resolutionMinutesUrgent: 120,
      resolutionMinutesHigh: 480,
      resolutionMinutesNormal: 1440,
      maxOpenTicketsPerCustomer: 5,
    } as SupportSlaConfig,
    isPublic: false,
    description: 'Customer support SLA target response times and concurrency bounds',
  },
  'payout.rules': {
    category: 'FINANCE',
    value: {
      minPayoutAmount: 500,
      maxSinglePayoutAmount: 100000,
      dailyVendorPayoutCap: 200000,
      payoutApprovalThreshold: 25000,
      autoPayoutEnabled: false,
      settlementHoldDays: 2,
    } as PayoutConfig,
    isPublic: false,
    description: 'Vendor payout limits, daily ceilings, approval thresholds, and settlement hold duration',
  },
  'reconciliation.rules': {
    category: 'FINANCE',
    value: {
      autoHealMinorDrifts: false,
      alertDiscrepancyThreshold: 1.0,
      cronIntervalMinutes: 15,
    } as ReconciliationConfig,
    isPublic: false,
    description: 'Financial gateway reconciliation rules and drift alert thresholds',
  },
  'analytics.governance': {
    category: 'ANALYTICS',
    value: {
      rawEventRetentionDays: 90,
      enableRealtimeEventTracking: true,
      aggregationIntervalMinutes: 60,
      churnInactivityDays: 45,
      vendorRiskInactivityDays: 30,
      alertPaymentFailureSpikeRate: 0.15,
      alertCancellationSpikeRate: 0.25,
    } as AnalyticsConfig,
    isPublic: false,
    description: 'Marketplace analytics retention policies, aggregation cadences, and risk alert thresholds',
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
  'pricing.tax': {
    category: 'PRICING',
    value: {
      gstRate: 18,
    } as TaxConfig,
    isPublic: true,
    description: 'Goods and Services Tax (GST) rate percentage applied to platform service fees',
  },
  'pricing.quote': {
    category: 'PRICING',
    value: {
      validityMinutes: 15,
    } as QuoteConfig,
    isPublic: true,
    description: 'Booking quote validity window duration in minutes before expiration',
  },
  'pricing.duration_discounts': {
    category: 'PRICING',
    value: [
      { minDays: 7, discountPercent: 10 },
      { minDays: 30, discountPercent: 20 },
    ] as DurationDiscountTier[],
    isPublic: true,
    description: 'Ordered multi-day duration discount tiers based on rental duration in days',
  },
  'booking.cancellation_matrix': {
    category: 'BOOKING',
    value: {
      tiers: [
        {
          minHoursBeforePickup: 24,
          feePercent: 0,
          tier: 'FULL_REFUND_FREE_CANCELLATION',
          description: 'Free cancellation (> 24 hours before pickup)',
        },
        {
          minHoursBeforePickup: 6,
          feePercent: 25,
          tier: 'MODERATE_CANCELLATION',
          description: 'Cancellation between 6 and 24 hours before pickup (25% fee)',
        },
        {
          minHoursBeforePickup: 0,
          feePercent: 50,
          tier: 'LATE_CANCELLATION',
          description: 'Cancellation within 6 hours of pickup time (50% fee)',
        },
      ],
      afterStartFeePercent: 100,
      afterStartTier: 'NO_REFUND_AFTER_START',
      afterStartDescription: 'Cancellation after trip pickup time (Non-refundable)',
    } as CancellationMatrixConfig,
    isPublic: true,
    description: 'Time-based cancellation fee percentage tiers and after-start fee policy',
  },
  'pricing.commission': {
    category: 'PRICING',
    value: {
      defaultPercent: 10,
    } as CommissionConfig,
    isPublic: false,
    description: 'Default platform commission percentage fallback when no granular rule matches',
  },
  'deposits.defaults': {
    category: 'FINANCE',
    value: {
      HATCHBACK: 3000,
      SEDAN: 4000,
      SUV: 5000,
      LUXURY: 10000,
      TEMPO_TRAVELLER: 8000,
      MINI_BUS: 10000,
    } as DepositDefaultsConfig,
    isPublic: true,
    description: 'Default security deposit amount in INR per car category',
  },
};

export type ConfigSource = 'DATABASE' | 'DEFAULT_FALLBACK';

export interface DetailedConfigResult<T = any> {
  key: string;
  effectiveValue: T;
  source: ConfigSource;
  isExplicitlyConfigured: boolean;
  version: number;
  updatedAt: Date | null;
  updatedBy: string | null;
  category: string;
  description: string | null;
  isPublic: boolean;
}

export interface SetConfigOptions {
  expectedVersion?: number;
  reason?: string;
  ip?: string;
}

export interface ConfigUpdateItem {
  key: string;
  value: any;
  expectedVersion?: number;
}

export interface BatchConfigUpdateDto {
  configs: ConfigUpdateItem[];
  reason?: string;
}

export interface BatchConfigUpdateResult {
  success: boolean;
  updatedCount: number;
  updatedKeys: string[];
}

export interface ConfigAuditHistoryItem {
  id: string;
  action: string;
  key: string;
  previousValue: any;
  newValue: any;
  adminUserId: string;
  adminUser?: {
    id: string;
    name: string;
    email: string;
    role: string;
  } | null;
  version?: number;
  reason?: string;
  timestamp: Date;
}
