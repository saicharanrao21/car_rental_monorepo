export enum IntegrationCategory {
  PAYMENT = 'PAYMENT',
  PAYMENTS = 'PAYMENT',
  MESSAGING_WHATSAPP = 'MESSAGING_WHATSAPP',
  MESSAGING_SMS = 'MESSAGING_SMS',
  MESSAGING_EMAIL = 'MESSAGING_EMAIL',
  MESSAGING_PUSH = 'MESSAGING_PUSH',
  VOICE_IVR = 'VOICE_IVR',
  STORAGE = 'STORAGE',
  CDN_IMAGE = 'CDN_IMAGE',
  MAPS = 'MAPS',
  ROUTING_DISTANCE = 'ROUTING_DISTANCE',
  PLACES_POI = 'PLACES_POI',
  IDENTITY_VERIFICATION = 'IDENTITY_VERIFICATION',
  DOCUMENT_VERIFICATION = 'DOCUMENT_VERIFICATION',
  OCR = 'OCR',
  FACE_LIVENESS = 'FACE_LIVENESS',
  VEHICLE_TRACKING = 'VEHICLE_TRACKING',
  FLEET_IOT = 'FLEET_IOT',
  ACCOUNTING = 'ACCOUNTING',
  ERP = 'ERP',
  TAX_GST = 'TAX_GST',
  INVOICING = 'INVOICING',
  SEARCH = 'SEARCH',
  ANALYTICS = 'ANALYTICS',
  CUSTOMER_SUPPORT = 'CUSTOMER_SUPPORT',
  CRM = 'CRM',
  MARKETING_AUTOMATION = 'MARKETING_AUTOMATION',
  AI = 'AI',
  TRANSLATION = 'TRANSLATION',
  ADDRESS_VALIDATION = 'ADDRESS_VALIDATION',
  FRAUD_RISK = 'FRAUD_RISK',
  PAYMENT_RISK = 'PAYMENT_RISK',
  OTP = 'OTP',
  VIDEO = 'VIDEO',
  ESIGNATURE = 'ESIGNATURE',
  DOCUMENT_GENERATION = 'DOCUMENT_GENERATION',
  NOTIFICATION_ORCHESTRATION = 'NOTIFICATION_ORCHESTRATION',
  WEBHOOK_DELIVERY = 'WEBHOOK_DELIVERY',
  DATA_EXPORT = 'DATA_EXPORT',
  BANK_ACCOUNT_VERIFICATION = 'BANK_ACCOUNT_VERIFICATION',
  PAYOUTS = 'PAYOUTS',
  OPEN_BANKING = 'OPEN_BANKING',
  TOLL_FASTAG = 'TOLL_FASTAG',
  FUEL_CHARGING = 'FUEL_CHARGING',
  PARKING = 'PARKING',
  TRAFFIC = 'TRAFFIC',
  WEATHER = 'WEATHER',
  CALENDAR = 'CALENDAR',
  SOCIAL_CHANNELS = 'SOCIAL_CHANNELS',
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
