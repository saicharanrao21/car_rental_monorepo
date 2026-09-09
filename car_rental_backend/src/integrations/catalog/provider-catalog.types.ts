import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';

export enum ProviderEnvironment {
  SANDBOX = 'SANDBOX',
  LIVE = 'LIVE',
}

export enum ProviderActivationState {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  DEPRECATED = 'DEPRECATED',
  COMING_SOON = 'COMING_SOON',
}

export type CredentialFieldType =
  | 'string'
  | 'password'
  | 'url'
  | 'textarea'
  | 'number'
  | 'boolean';

export interface CredentialFieldSchema {
  key: string;
  label: string;
  type: CredentialFieldType;
  required: boolean;
  isSecret: boolean;
  description: string;
  placeholder?: string;
  validationRegex?: string;
  environmentScoped?: boolean; // If true, separate values are kept for SANDBOX vs LIVE
  defaultValue?: any;
}

export interface ProviderDocumentationMetadata {
  overview: string;
  docsUrl: string;
  setupGuide: string;
  webhookGuide?: string;
  supportEmail?: string;
}

export interface CatalogProviderMetadata {
  providerId: string;
  category: IntegrationCategory;
  name: string;
  tagline: string;
  description: string;
  icon: string;
  websiteUrl: string;
  documentation: ProviderDocumentationMetadata;
  version: string;
  apiVersion?: string;
  author: string;
  tags: string[];
  supportedEnvironments: ProviderEnvironment[];
  defaultEnvironment: ProviderEnvironment;
  credentialSchema: CredentialFieldSchema[];
  supportedCapabilities: string[];
  supportedCurrencies: string[];
  supportedCountries: string[]; // ISO country codes: 'IN', 'US', 'AE', 'GB', etc.
  supportedWebhookEvents?: string[];
  webhookSignatureHeader?: string;
  platformAvailability: boolean;
  tenantTierAvailability: string[]; // 'ALL', 'BASIC', 'PRO', 'ENTERPRISE'
  activationState: ProviderActivationState;
  priority: number;
  fallbackProviderId?: string;
}

export interface CatalogFilter {
  category?: IntegrationCategory;
  capability?: string;
  country?: string;
  currency?: string;
  environment?: ProviderEnvironment;
  activationState?: ProviderActivationState;
  tenantTier?: string;
  search?: string;
}

export interface MarketplaceProviderView extends CatalogProviderMetadata {
  isConfigured: boolean;
  activeEnvironment: ProviderEnvironment;
  health: {
    status: ProviderHealthStatus;
    latencyMs: number;
    lastChecked?: Date | null;
    message?: string;
  };
  isActive: boolean;
  isEnabled: boolean;
  hasCredentials: boolean;
  maskedCredentials: Record<string, string>;
  effectiveSettings: Record<string, any>;
  lastHealthCheck?: Date | null;
}
