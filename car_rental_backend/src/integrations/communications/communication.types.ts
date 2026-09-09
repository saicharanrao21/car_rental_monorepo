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
  PROMOTIONAL = 'PROMOTIONAL',
  SECURITY = 'SECURITY',
  OTP = 'OTP',
  SYSTEM = 'SYSTEM',
  ALERT = 'ALERT',
  MARKETING = 'MARKETING',
  SUPPORT = 'SUPPORT',
  CRITICAL = 'CRITICAL',
  OPERATIONAL = 'OPERATIONAL',
  LIFECYCLE = 'LIFECYCLE',
  CRITICAL_ALERT = 'CRITICAL_ALERT',
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
  VALIDATING = 'VALIDATING',
  ROUTING = 'ROUTING',
  PROVIDER_SELECTED = 'PROVIDER_SELECTED',
  DISPATCHING = 'DISPATCHING',
  SENDING = 'SENDING',
  ACCEPTED = 'ACCEPTED',
  SUBMITTED = 'SUBMITTED',
  SENT = 'SENT',
  DELIVERED = 'DELIVERED',
  READ = 'READ',
  FAILED = 'FAILED',
  RETRYING = 'RETRYING',
  FALLBACK_PENDING = 'FALLBACK_PENDING',
  FALLING_BACK = 'FALLING_BACK',
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
  id?: string;
  userId?: string;
  recipientId?: string;
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
  correlationId?: string;
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

// =========================================================================
// UNIFIED OTP PLATFORM TYPES
// =========================================================================

export enum OtpPurpose {
  AUTH = 'AUTH',
  HANDOVER_PICKUP = 'HANDOVER_PICKUP',
  HANDOVER_RETURN = 'HANDOVER_RETURN',
  PAYMENT = 'PAYMENT',
  PASSWORD_RESET = 'PASSWORD_RESET',
  PHONE_VERIFICATION = 'PHONE_VERIFICATION',
}

export interface OtpChallengeRequest {
  identifier: string; // phone number or email address
  purpose: OtpPurpose | string;
  recipientName?: string;
  preferredChannel?: CommunicationChannel;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  deviceFingerprint?: string;
  ipAddress?: string;
  idempotencyKey?: string;
  customTtlSeconds?: number;
}

export interface OtpChallengeResult {
  success?: boolean;
  challengeId: string;
  identifier: string;
  channel: CommunicationChannel;
  providerId: string;
  status: DeliveryStatus;
  expiresAt: Date;
  coolingPeriodEndsAt: Date;
  cooldownSeconds?: number;
  attemptsRemaining?: number;
  fallbackAvailable: boolean;
  fallbackChannel?: CommunicationChannel;
  message: string;
  riskScore: number;
  error?: string;
}

export interface OtpVerificationRequest {
  challengeId?: string;
  identifier: string;
  purpose: OtpPurpose | string;
  code?: string;
  otpCode?: string;
  deviceFingerprint?: string;
  ipAddress?: string;
}

export interface OtpVerificationResult {
  success: boolean;
  verified: boolean;
  message: string;
  attemptsRemaining: number;
  lockoutUntil?: Date;
  isLockedOut: boolean;
  verifiedAt?: Date;
  error?: string;
}
