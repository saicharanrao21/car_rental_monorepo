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

export enum ProviderLifecycleState {
  DISCOVERED = 'DISCOVERED',
  CATALOG_ONLY = 'CATALOG_ONLY',
  CONFIGURABLE = 'CONFIGURABLE',
  SANDBOX_READY = 'SANDBOX_READY',
  LIVE_READY = 'LIVE_READY',
  HEALTHY = 'HEALTHY',
  DEGRADED = 'DEGRADED',
  DISABLED = 'DISABLED',
  DEPRECATED = 'DEPRECATED',
}

export enum ProviderCertificationLevel {
  CATALOG = 'CATALOG',
  CONTRACT_VALIDATED = 'CONTRACT_VALIDATED',
  SANDBOX_VALIDATED = 'SANDBOX_VALIDATED',
  WEBHOOK_VALIDATED = 'WEBHOOK_VALIDATED',
  FAILOVER_VALIDATED = 'FAILOVER_VALIDATED',
  PRODUCTION_VALIDATED = 'PRODUCTION_VALIDATED',
}

export enum ProviderImplementationStatus {
  CATALOG_ONLY = 'CATALOG_ONLY',
  CONTRACT_READY = 'CONTRACT_READY',
  ADAPTER_IMPLEMENTED = 'ADAPTER_IMPLEMENTED',
  SANDBOX_VERIFIED = 'SANDBOX_VERIFIED',
  LIVE_READY = 'LIVE_READY',
  LIVE_VERIFIED = 'LIVE_VERIFIED',
}

export enum PaymentCapability {
  CREATE_PAYMENT = 'CREATE_PAYMENT',
  CREATE_ORDER = 'CREATE_ORDER',
  PAYMENT_LINK = 'PAYMENT_LINK',
  CHECKOUT = 'CHECKOUT',
  CARD = 'CARD',
  CREDIT_CARD = 'CREDIT_CARD',
  DEBIT_CARD = 'DEBIT_CARD',
  UPI = 'UPI',
  UPI_INTENT = 'UPI_INTENT',
  UPI_COLLECT = 'UPI_COLLECT',
  UPI_QR = 'UPI_QR',
  CARD_PAYMENT = 'CARD_PAYMENT',
  UPI_PAYMENT = 'UPI_PAYMENT',
  NET_BANKING = 'NET_BANKING',
  WALLET = 'WALLET',
  EMI = 'EMI',
  BNPL = 'BNPL',
  INTERNATIONAL_CARD = 'INTERNATIONAL_CARD',
  TOKENIZATION = 'TOKENIZATION',
  TOKENIZE_PAYMENT_METHOD = 'TOKENIZE_PAYMENT_METHOD',
  SAVE_PAYMENT_METHOD = 'SAVE_PAYMENT_METHOD',
  DELETE_PAYMENT_METHOD = 'DELETE_PAYMENT_METHOD',
  PAYMENT_STATUS = 'PAYMENT_STATUS',
  PAYMENT_VERIFICATION = 'PAYMENT_VERIFICATION',
  VERIFY_PAYMENT = 'VERIFY_PAYMENT',
  CAPTURE = 'CAPTURE',
  CAPTURE_PAYMENT = 'CAPTURE_PAYMENT',
  AUTHORIZE_PAYMENT = 'AUTHORIZE_PAYMENT',
  VOID = 'VOID',
  VOID_PAYMENT = 'VOID_PAYMENT',
  REFUND = 'REFUND',
  REFUND_PAYMENT = 'REFUND_PAYMENT',
  PARTIAL_REFUND = 'PARTIAL_REFUND',
  REFUND_STATUS = 'REFUND_STATUS',
  PAYMENT_INTENT = 'PAYMENT_INTENT',
  CURRENCY_CONVERSION = 'CURRENCY_CONVERSION',
  PAYOUT = 'PAYOUT',
  PAYOUTS = 'PAYOUTS',
  TRANSFER = 'TRANSFER',
  SETTLEMENT = 'SETTLEMENT',
  SETTLEMENT_STATUS = 'SETTLEMENT_STATUS',
  RECONCILIATION = 'RECONCILIATION',
  SETTLEMENT_RECONCILIATION = 'SETTLEMENT_RECONCILIATION',
  DISPUTE = 'DISPUTE',
  DISPUTE_STATUS = 'DISPUTE_STATUS',
  CHARGEBACK = 'CHARGEBACK',
  WEBHOOKS = 'WEBHOOKS',
  PAYMENT_WEBHOOK = 'PAYMENT_WEBHOOK',
  PAYOUT_WEBHOOK = 'PAYOUT_WEBHOOK',
  REFUND_WEBHOOK = 'REFUND_WEBHOOK',
  SETTLEMENT_WEBHOOK = 'SETTLEMENT_WEBHOOK',
  DISPUTE_WEBHOOK = 'DISPUTE_WEBHOOK',
  SUBSCRIPTIONS = 'SUBSCRIPTIONS',
  RECURRING_PAYMENTS = 'RECURRING_PAYMENTS',
  SPLIT_PAYMENTS = 'SPLIT_PAYMENTS',
  MARKETPLACE_PAYMENTS = 'MARKETPLACE_PAYMENTS',
  ROUTE_SPLIT = 'ROUTE_SPLIT',
  INVOICE = 'INVOICE',
  TAX_INVOICE = 'TAX_INVOICE',
  FRAUD_CHECK = 'FRAUD_CHECK',
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
  // Phase L Enterprise Extensions
  lifecycleState?: ProviderLifecycleState;
  certificationLevel?: ProviderCertificationLevel;
  implementationStatus?: ProviderImplementationStatus;
  adapterImplemented?: boolean;
  supportedPaymentMethods?: string[];
  costModel?: any;
  slaUptimePercent?: number;
  maxRps?: number;
}

export interface CatalogFilter {
  category?: IntegrationCategory;
  capability?: string;
  country?: string;
  currency?: string;
  environment?: ProviderEnvironment;
  activationState?: ProviderActivationState;
  lifecycleState?: ProviderLifecycleState;
  certificationLevel?: ProviderCertificationLevel;
  implementationStatus?: ProviderImplementationStatus;
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

export interface ProviderComparisonItem {
  providerId: string;
  name: string;
  category: IntegrationCategory;
  lifecycleState: ProviderLifecycleState;
  certificationLevel: ProviderCertificationLevel;
  implementationStatus: ProviderImplementationStatus;
  adapterImplemented: boolean;
  supportedCapabilities: string[];
  supportedCurrencies: string[];
  supportedCountries: string[];
  supportedPaymentMethods: string[];
  healthStatus: ProviderHealthStatus;
  latencyP50Ms: number;
  successRatePercent: number;
  costEstimate: {
    percentageFee: number;
    fixedFee: number;
    currency: string;
  };
  webhookSupported: boolean;
  refundSupported: boolean;
  payoutSupported: boolean;
}

export interface ProviderComparisonResult {
  category: IntegrationCategory;
  providers: ProviderComparisonItem[];
  commonCapabilities: string[];
  uniqueCapabilities: Record<string, string[]>;
}
