/**
 * DRIVEGO ENTERPRISE COMMUNICATIONS & MESSAGING DOMAIN TYPES
 * Phase M: Comprehensive multi-channel, multi-provider communication definitions.
 */

export enum CommunicationChannel {
  WHATSAPP = 'WHATSAPP',
  SMS = 'SMS',
  EMAIL = 'EMAIL',
  PUSH = 'PUSH',
  VOICE = 'VOICE',
  OTP = 'OTP',
}

export enum CommunicationMessageType {
  TRANSACTIONAL = 'TRANSACTIONAL',
  OPERATIONAL = 'OPERATIONAL',
  CRITICAL_ALERT = 'CRITICAL_ALERT',
  OTP = 'OTP',
  MARKETING = 'MARKETING',
  LIFECYCLE = 'LIFECYCLE',
}

export enum CommunicationPriority {
  CRITICAL = 'CRITICAL',
  HIGH = 'HIGH',
  NORMAL = 'NORMAL',
  LOW = 'LOW',
  MARKETING = 'MARKETING',
}

export enum DeliveryStatus {
  CREATED = 'CREATED',
  QUEUED = 'QUEUED',
  ROUTING = 'ROUTING',
  DISPATCHING = 'DISPATCHING',
  ACCEPTED = 'ACCEPTED',
  SENT = 'SENT',
  DELIVERED = 'DELIVERED',
  READ = 'READ',
  FAILED = 'FAILED',
  RETRYING = 'RETRYING',
  FALLBACK_PENDING = 'FALLBACK_PENDING',
  FALLBACK_SENT = 'FALLBACK_SENT',
  EXPIRED = 'EXPIRED',
  CANCELLED = 'CANCELLED',
  UNKNOWN = 'UNKNOWN',
}

export enum CommunicationFailureClassification {
  INVALID_NUMBER = 'INVALID_NUMBER',
  UNDELIVERABLE = 'UNDELIVERABLE',
  BLOCKED = 'BLOCKED',
  TEMPLATE_REJECTED = 'TEMPLATE_REJECTED',
  OPT_OUT = 'OPT_OUT',
  RATE_LIMITED = 'RATE_LIMITED',
  PROVIDER_DOWN = 'PROVIDER_DOWN',
  NETWORK_FAILURE = 'NETWORK_FAILURE',
  AUTH_FAILURE = 'AUTH_FAILURE',
  INVALID_TEMPLATE = 'INVALID_TEMPLATE',
  CONTENT_REJECTED = 'CONTENT_REJECTED',
  RECIPIENT_UNAVAILABLE = 'RECIPIENT_UNAVAILABLE',
  TIMEOUT = 'TIMEOUT',
  DUPLICATE = 'DUPLICATE',
  UNKNOWN = 'UNKNOWN',
}

export enum RoutingOptimizationGoal {
  DELIVERY_RELIABILITY = 'DELIVERY_RELIABILITY',
  LOWEST_COST = 'LOWEST_COST',
  LOWEST_LATENCY = 'LOWEST_LATENCY',
  BALANCED = 'BALANCED',
  CUSTOM_POLICY = 'CUSTOM_POLICY',
}

export interface CommunicationRecipient {
  userId?: string;
  name?: string;
  phone?: string;          // E.164 normalized
  email?: string;
  deviceTokens?: string[]; // Push tokens (FCM/APNs)
  country?: string;        // ISO 2-letter (e.g. IN, US, AE)
  language?: string;       // ISO 639-1 (e.g. en, hi, te, ta, kn)
  timeZone?: string;       // e.g. Asia/Kolkata
  marketingOptIn?: boolean;
  whatsappConsent?: boolean;
  smsConsent?: boolean;
  emailConsent?: boolean;
  pushConsent?: boolean;
  voiceConsent?: boolean;
  dndRegistered?: boolean;
}

export interface CommunicationTemplatePayload {
  templateName: string;
  language?: string;
  variables?: Record<string, string | number>;
  dltTemplateId?: string; // For Indian TRAI DLT compliance
  metaTemplateId?: string;
  buttons?: Array<{ type: 'URL' | 'QUICK_REPLY'; text: string; payload?: string }>;
  headerMediaUrl?: string;
}

export interface CommunicationRequest {
  category?: string;
  channel?: CommunicationChannel;
  capability?: string;
  messageType: CommunicationMessageType;
  priority?: CommunicationPriority;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  recipient: CommunicationRecipient;
  template?: CommunicationTemplatePayload;
  directContent?: {
    subject?: string;
    body?: string;
    html?: string;
    mediaUrl?: string;
    attachments?: Array<{ filename: string; content: string | Buffer; contentType?: string }>;
    data?: Record<string, string>;
  };
  otpCode?: string;
  idempotencyKey?: string;
  metadata?: Record<string, any>;
}

export interface FallbackSafetyCheck {
  safeToFailover: boolean;
  action: 'FAILOVER' | 'PENDING_DELIVERY_CONFIRMATION' | 'ABORT';
  reason: string;
  recommendedStatus: DeliveryStatus;
}

export interface CommunicationRoutingDecision {
  channel: CommunicationChannel;
  primaryProviderId: string;
  fallbackChain: Array<{ channel: CommunicationChannel; providerId: string }>;
  estimatedCost: number;
  expectedLatencyMs: number;
  scoreBreakdown: Record<string, number>;
  explanation: string;
  candidateEvaluations: Array<{
    providerId: string;
    channel: CommunicationChannel;
    eligible: boolean;
    totalScore: number;
    rejectionReason?: string;
  }>;
}

export interface CommunicationResponse {
  success: boolean;
  communicationId: string;
  channel: CommunicationChannel;
  providerId: string;
  providerMessageId?: string;
  status: DeliveryStatus;
  fallbackChainUsed?: boolean;
  attemptsCount: number;
  costEstimate: number;
  latencyMs: number;
  explanation?: string;
  error?: string;
  errorCode?: string;
}

export interface DeliveryEvent {
  eventId: string;
  communicationId: string;
  providerId: string;
  channel: CommunicationChannel;
  eventType: 'MESSAGE_ACCEPTED' | 'MESSAGE_SENT' | 'MESSAGE_DELIVERED' | 'MESSAGE_READ' | 'MESSAGE_FAILED' | 'OTP_DELIVERED' | 'OTP_VERIFIED' | 'VOICE_COMPLETED';
  timestamp: Date;
  status: DeliveryStatus;
  rawPayload?: any;
  metadata?: Record<string, any>;
}

export interface CommunicationPolicy {
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  enabledChannels: CommunicationChannel[];
  primaryProviders: Partial<Record<CommunicationChannel, string>>;
  fallbackChains: Partial<Record<CommunicationChannel, CommunicationChannel[]>>;
  optimizationGoal: RoutingOptimizationGoal;
  quietHours?: {
    enabled: boolean;
    startHour: number; // e.g. 21 (9 PM)
    endHour: number;   // e.g. 8 (8 AM)
    timeZone: string;
  };
  maxCostPerMessage?: number;
  allowedCountries?: string[];
  defaultLanguage?: string;
}

export interface CommunicationCostConfig {
  percentageFee?: number;
  fixedFee: number;
  currency: string;
  perSms?: number;
  perWhatsAppConversation?: number;
  perEmail?: number;
  perVoiceMinute?: number;
  perOtp?: number;
  volumeTiers?: Array<{ maxMonthlyVolume: number; rate: number }>;
}

export interface CommunicationCampaign {
  id: string;
  name: string;
  channel: CommunicationChannel;
  audienceFilter: Record<string, any>;
  templateName: string;
  scheduledAt?: Date;
  status: 'DRAFT' | 'SCHEDULED' | 'RUNNING' | 'COMPLETED' | 'PAUSED' | 'CANCELLED';
  metrics: {
    totalRecipients: number;
    sent: number;
    delivered: number;
    read: number;
    failed: number;
    totalCost: number;
  };
}
