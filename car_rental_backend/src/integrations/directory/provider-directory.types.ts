import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { CredentialFieldSchema, ProviderEnvironment } from '../catalog/provider-catalog.types';

export enum ProviderStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  DEPRECATED = 'DEPRECATED',
  BETA = 'BETA',
}

export enum CertificationLevel {
  COMMUNITY = 'COMMUNITY',
  CATALOG = 'CATALOG',
  CONTRACT_VALIDATED = 'CONTRACT_VALIDATED',
  SANDBOX_VALIDATED = 'SANDBOX_VALIDATED',
  FAILOVER_VALIDATED = 'FAILOVER_VALIDATED',
  PRODUCTION_READY = 'PRODUCTION_READY',
  ENTERPRISE_CERTIFIED = 'ENTERPRISE_CERTIFIED',
}

export enum ProviderPricingType {
  TRANSACTIONAL = 'TRANSACTIONAL',
  SUBSCRIPTION = 'SUBSCRIPTION',
  TIERED = 'TIERED',
  HYBRID = 'HYBRID',
  FREE_TIER = 'FREE_TIER',
  FREE_TIER_THEN_USAGE = 'FREE_TIER_THEN_USAGE',
}

export interface ProviderSlaInfo {
  uptimeCommitmentPercent: number; // e.g. 99.95
  responseTimeCommitmentMs: number; // e.g. 200
  supportTier: 'COMMUNITY' | 'STANDARD_8X5' | 'PRIORITY_24X7' | 'MISSION_CRITICAL';
  refundSlaDays?: number;
  chargebackWindowDays?: number;
}

export interface ProviderPricingSchema {
  type: ProviderPricingType;
  fixedFee: number;
  percentageFee: number;
  currency: string;
  monthlyPlatformFee?: number;
  setupFee?: number;
  minimumMonthlyCommitment?: number;
  volumeDiscounts?: Array<{ minVolume: number; percentageDiscount: number }>;
}

export interface ProviderRateLimitInfo {
  requestsPerSecond: number;
  burstCapacity: number;
  maxConcurrentRequests: number;
  dailyQuota?: number;
}

export interface ProviderDirectoryMetadata {
  providerId: string;
  displayName: string;
  legalEntityName?: string;
  category: IntegrationCategory;
  subcategories: string[];
  description: string;
  icon: string;
  websiteUrl: string;
  documentationUrl: string;
  supportedCountries: string[]; // ISO codes: 'IN', 'US', 'AE', 'GB', etc.
  supportedCurrencies: string[]; // 'INR', 'USD', 'EUR', 'AED', etc.
  supportedLanguages: string[]; // 'en', 'hi', 'ar', 'es', etc.
  supportedCapabilities: string[]; // Normalized capability codes
  supportedPaymentMethods?: string[]; // 'UPI', 'CARD', 'NETBANKING', 'WALLET', 'BNPL', 'EMI'
  supportedApis: Array<'REST' | 'GRAPHQL' | 'WEBHOOK' | 'GRPC' | 'SDK'>;
  environments: ProviderEnvironment[];
  defaultEnvironment: ProviderEnvironment;
  webhookSupport: {
    supported: boolean;
    signatureHeader?: string;
    eventTypes?: string[];
  };
  complianceCertifications: string[]; // 'PCI_DSS_L1', 'SOC2_TYPE2', 'ISO_27001', 'GDPR', 'RBI_COMPLIANT'
  onboardingRequirements: string[];
  credentialSchema: CredentialFieldSchema[];
  pricing: ProviderPricingSchema;
  sla: ProviderSlaInfo;
  rateLimits: ProviderRateLimitInfo;
  expectedLatencyP50Ms: number;
  expectedLatencyP95Ms: number;
  reliabilityScore: number; // 0.0 to 1.0 (e.g. 0.992)
  priority: number; // 1 to 100
  status: 'ACTIVE' | 'INACTIVE' | 'DEPRECATED' | 'BETA';
  certificationLevel: CertificationLevel;
  version: string;
  apiVersion?: string;
  fallbackCompatibility: string[]; // IDs of providers this provider can seamlessly fall back to
  migrationCompatibility?: {
    compatibleFrom?: string[];
    migrationGuideUrl?: string;
  };
  createdAt: string;
  updatedAt: string;
}

export interface DirectoryFilterQuery {
  category?: IntegrationCategory;
  capability?: string;
  country?: string;
  currency?: string;
  environment?: ProviderEnvironment;
  certificationLevel?: CertificationLevel;
  pricingType?: ProviderPricingType;
  paymentMethod?: string;
  status?: string;
  search?: string;
}
