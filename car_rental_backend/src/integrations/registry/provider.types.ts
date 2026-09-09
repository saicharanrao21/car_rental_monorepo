export enum IntegrationCategory {
  PAYMENT = 'PAYMENT',
  MESSAGING_WHATSAPP = 'MESSAGING_WHATSAPP',
  MESSAGING_SMS = 'MESSAGING_SMS',
  MESSAGING_EMAIL = 'MESSAGING_EMAIL',
  MESSAGING_PUSH = 'MESSAGING_PUSH',
  STORAGE = 'STORAGE',
  MAPS = 'MAPS',
  IDENTITY_VERIFICATION = 'IDENTITY_VERIFICATION',
  VEHICLE_TRACKING = 'VEHICLE_TRACKING',
  ACCOUNTING = 'ACCOUNTING',
}

export enum ProviderHealthStatus {
  CONFIGURED = 'CONFIGURED',
  ACTIVE = 'ACTIVE',
  HEALTHY = 'HEALTHY',
  DEGRADED = 'DEGRADED',
  UNAVAILABLE = 'UNAVAILABLE',
  CREDENTIAL_FAILURE = 'CREDENTIAL_FAILURE',
}

export interface ProviderHealthCheckResult {
  status: ProviderHealthStatus;
  latencyMs: number;
  message?: string;
  lastChecked: Date;
  details?: Record<string, any>;
}

export interface TestConnectionResult {
  success: boolean;
  latencyMs: number;
  message?: string;
  error?: string;
  details?: Record<string, any>;
}

export interface ProviderDescriptor {
  providerId: string;
  category: IntegrationCategory;
  displayName: string;
  description?: string;
  supportedCapabilities: string[];
  isEnabled: boolean;
  isActive: boolean;
  priority: number;
  health: ProviderHealthCheckResult;
  configSchema?: Record<string, any>;
  hasCredentials: boolean;
}

export interface IntegrationContext {
  organizationId?: string;
  vendorId?: string;
  branchId?: string;
  propertyId?: string;
  city?: string;
}
