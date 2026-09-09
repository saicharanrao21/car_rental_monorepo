import { IntegrationCategory } from '../registry/provider.types';
import {
  CredentialFieldSchema,
  ProviderEnvironment,
} from '../catalog/provider-catalog.types';
import {
  RateLimitConfig,
  ProviderCostModel,
} from '../runtime/runtime.types';

export enum ConnectorLifecycleState {
  DISCOVERED = 'DISCOVERED',
  CONFIGURED = 'CONFIGURED',
  CREDENTIALS_VALIDATED = 'CREDENTIALS_VALIDATED',
  SANDBOX_TESTED = 'SANDBOX_TESTED',
  WEBHOOK_VERIFIED = 'WEBHOOK_VERIFIED',
  APPROVED = 'APPROVED',
  ACTIVE = 'ACTIVE',
  DEGRADED = 'DEGRADED',
  DISABLED = 'DISABLED',
  RETIRED = 'RETIRED',
}

export enum MultiTenantOwnershipScope {
  PLATFORM = 'PLATFORM',
  ORGANIZATION = 'ORGANIZATION',
  BRANCH = 'BRANCH',
  OPERATIONAL_OVERRIDE = 'OPERATIONAL_OVERRIDE',
}

export type ProviderImplementationStatus =
  | 'REAL_ADAPTER'
  | 'SIMULATION_MOCK'
  | 'CATALOG_ONLY';

export interface CapabilityPack {
  capability: string;
  category: IntegrationCategory;
  version: string;
  supportedEnvironments: ProviderEnvironment[];
  description: string;
  expectedLatencyMs?: number;
  slaUptimePercent?: number;
  idempotent: boolean;
  refundable?: boolean;
}

export interface WebhookConfigMetadata {
  supported: boolean;
  signatureHeader?: string;
  algorithm?: 'HMAC-SHA256' | 'RSA-SHA256' | 'BEARER' | 'CUSTOM';
  secretRequired: boolean;
  webhookUrlPattern?: string;
  supportsReplayProtection: boolean;
}

export interface HealthCheckConfigMetadata {
  pingEndpoint?: string;
  intervalSeconds: number;
  timeoutMs: number;
  degradedThresholdFailures: number;
}

export interface RetryPolicyMetadata {
  maxRetries: number;
  backoffFactor: number;
  initialIntervalMs: number;
  retryableErrorCodes: string[];
}

export interface FallbackEligibility {
  eligibleAsPrimary: boolean;
  eligibleAsSecondaryFallback: boolean;
  preferredPrecedingProvider?: string;
  prohibitedFallbackProviders?: string[];
}

export interface ProviderVersionMetadata {
  apiVersion: string;
  adapterVersion: string;
  credentialSchemaVersion: string;
  releasedAt: string;
  deprecated?: boolean;
  sunsetDate?: string;
  migrationGuideUrl?: string;
}

export interface ProviderPackManifest {
  id: string; // e.g. "mapbox", "traccar", "hyperverge", "zoho_books", "gemini"
  name: string;
  displayName: string;
  category: IntegrationCategory;
  version: ProviderVersionMetadata;
  capabilities: CapabilityPack[];
  credentialSchema: CredentialFieldSchema[];
  supportedEnvironments: ProviderEnvironment[];
  supportedRegions: string[];
  supportedCurrencies: string[];
  rateLimits: RateLimitConfig;
  costModel: ProviderCostModel;
  webhookConfig?: WebhookConfigMetadata;
  healthCheckConfig?: HealthCheckConfigMetadata;
  retryPolicy: RetryPolicyMetadata;
  fallbackEligibility: FallbackEligibility;
  documentationUrl: string;
  implementationStatus: ProviderImplementationStatus;
  featureFlags?: Record<string, boolean>;
  tags: string[];
}

export interface LifecycleTransitionRecord {
  id: string;
  providerId: string;
  category: IntegrationCategory;
  fromState: ConnectorLifecycleState;
  toState: ConnectorLifecycleState;
  reason: string;
  actor: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}

export interface TenantConnectorBinding {
  id: string;
  scope: MultiTenantOwnershipScope;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  category: IntegrationCategory;
  preferredProviderId: string;
  fallbackChain: string[];
  enabledCapabilities: string[];
  allowedRegions?: string[];
  allowedCurrencies?: string[];
  overrides?: {
    rateLimits?: Partial<RateLimitConfig>;
    costCapMonthly?: number;
  };
  updatedAt: Date;
}
