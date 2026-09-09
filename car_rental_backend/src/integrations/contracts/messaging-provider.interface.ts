import { BaseProvider } from './provider.interface';

// -------------------------------------------------------------
// WhatsApp
// -------------------------------------------------------------
export enum WhatsAppCapability {
  SEND_TEMPLATE = 'SEND_TEMPLATE',
  SEND_TEXT = 'SEND_TEXT',
  SEND_MEDIA = 'SEND_MEDIA',
  WEBHOOK_DELIVERY_STATUS = 'WEBHOOK_DELIVERY_STATUS',
}

export interface NormalizedWhatsAppRequest {
  to: string; // E.164 or normalized 10-12 digit mobile
  templateName: string;
  language: string;
  bodyParameters: string[];
  idempotencyKey?: string;
  metadata?: Record<string, any>;
}

export interface NormalizedWhatsAppResponse {
  success: boolean;
  providerMessageId: string;
  status: 'QUEUED' | 'ACCEPTED' | 'SENT' | 'DELIVERED' | 'FAILED';
  errorCode?: string;
  errorMessage?: string;
  rawResponse?: any;
}

export interface WhatsAppProvider extends BaseProvider {
  sendTemplateMessage(req: NormalizedWhatsAppRequest): Promise<NormalizedWhatsAppResponse>;
  verifyWebhookSignature?(rawBody: string, signature: string, secret: string, headers?: any): boolean;
  normalizeWebhook?(rawPayload: any, headers?: any): any;
}

// -------------------------------------------------------------
// SMS
// -------------------------------------------------------------
export enum SmsCapability {
  SEND_TRANSACTIONAL = 'SEND_TRANSACTIONAL',
  SEND_OTP = 'SEND_OTP',
  SEND_PROMOTIONAL = 'SEND_PROMOTIONAL',
  DELIVERY_REPORT = 'DELIVERY_REPORT',
}

export interface NormalizedSmsRequest {
  to: string;
  message: string;
  otpCode?: string;
  templateId?: string;
  senderId?: string;
  idempotencyKey?: string;
  isTransactional?: boolean;
}

export interface NormalizedSmsResponse {
  success: boolean;
  messageId: string;
  status: 'SENT' | 'DELIVERED' | 'FAILED';
  error?: string;
  isTransient?: boolean;
  rawResponse?: any;
}

export interface SmsProvider extends BaseProvider {
  sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse>;
}

// -------------------------------------------------------------
// Email
// -------------------------------------------------------------
export enum EmailCapability {
  SEND_TRANSACTIONAL = 'SEND_TRANSACTIONAL',
  SEND_HTML = 'SEND_HTML',
  SEND_ATTACHMENT = 'SEND_ATTACHMENT',
  SEND_TEMPLATE = 'SEND_TEMPLATE',
}

export interface EmailAttachment {
  filename: string;
  content: string | Buffer;
  contentType?: string;
}

export interface NormalizedEmailRequest {
  to: string;
  subject: string;
  html: string;
  from?: string;
  replyTo?: string;
  cc?: string[];
  bcc?: string[];
  attachments?: EmailAttachment[];
  idempotencyKey?: string;
}

export interface NormalizedEmailResponse {
  success: boolean;
  messageId: string;
  status: 'SENT' | 'QUEUED' | 'FAILED';
  error?: string;
  isTransient?: boolean;
  rawResponse?: any;
}

export interface EmailProvider extends BaseProvider {
  sendEmail(req: NormalizedEmailRequest): Promise<NormalizedEmailResponse>;
}

// -------------------------------------------------------------
// Push Notifications (FCM / APNs)
// -------------------------------------------------------------
export enum PushCapability {
  SEND_UNICAST = 'SEND_UNICAST',
  SEND_MULTICAST = 'SEND_MULTICAST',
  SEND_TOPIC = 'SEND_TOPIC',
  DATA_PAYLOAD = 'DATA_PAYLOAD',
}

export interface NormalizedPushRequest {
  deviceTokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
  priority?: 'normal' | 'high';
}

export interface NormalizedPushResponse {
  success: boolean;
  successCount: number;
  failureCount: number;
  messageId?: string;
  invalidTokens?: string[];
  error?: string;
  rawResponse?: any;
}

export interface PushProvider extends BaseProvider {
  sendPush(req: NormalizedPushRequest): Promise<NormalizedPushResponse>;
}
