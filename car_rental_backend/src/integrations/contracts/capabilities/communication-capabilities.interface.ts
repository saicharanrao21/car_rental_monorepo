/**
 * DISCRETE COMMUNICATION CAPABILITY CONTRACTS
 * Replaces monolithic messaging interfaces with granular, capability-focused contracts.
 */

export interface SendTemplateCapability {
  sendTemplate(params: {
    to: string;
    templateName: string;
    language: string;
    variables: Record<string, string | number>;
    dltTemplateId?: string;
    metaTemplateId?: string;
    buttons?: any[];
    headerMediaUrl?: string;
    idempotencyKey?: string;
  }): Promise<{
    success: boolean;
    providerMessageId: string;
    status: string;
    error?: string;
    rawResponse?: any;
  }>;
}

export interface SendMediaCapability {
  sendMedia(params: {
    to: string;
    mediaType: 'IMAGE' | 'DOCUMENT' | 'VIDEO' | 'AUDIO';
    mediaUrl: string;
    caption?: string;
    filename?: string;
    idempotencyKey?: string;
  }): Promise<{
    success: boolean;
    providerMessageId: string;
    status: string;
    error?: string;
    rawResponse?: any;
  }>;
}

export interface SendOtpCapability {
  sendOtp(params: {
    to: string;
    otpCode: string;
    expirySeconds?: number;
    channel: 'SMS' | 'WHATSAPP' | 'VOICE';
    templateId?: string;
    idempotencyKey?: string;
  }): Promise<{
    success: boolean;
    providerMessageId: string;
    status: string;
    error?: string;
    rawResponse?: any;
  }>;
}

export interface VerifyOtpCapability {
  verifyOtp(params: {
    to: string;
    enteredCode: string;
    referenceId?: string;
  }): Promise<{
    valid: boolean;
    reason?: string;
  }>;
}

export interface SendVoiceCapability {
  initiateVoiceCall(params: {
    to: string;
    twimlOrScript: string;
    isOtp?: boolean;
    otpCode?: string;
    idempotencyKey?: string;
  }): Promise<{
    success: boolean;
    callSid: string;
    status: string;
    error?: string;
    rawResponse?: any;
  }>;
}

export interface EmailAttachmentCapability {
  sendWithAttachments(params: {
    to: string;
    subject: string;
    html: string;
    attachments: Array<{ filename: string; content: string | Buffer; contentType?: string }>;
    from?: string;
    replyTo?: string;
    idempotencyKey?: string;
  }): Promise<{
    success: boolean;
    messageId: string;
    status: string;
    error?: string;
    rawResponse?: any;
  }>;
}

export interface DeliveryStatusCapability {
  queryDeliveryStatus(providerMessageId: string): Promise<{
    providerMessageId: string;
    status: 'QUEUED' | 'SENT' | 'DELIVERED' | 'READ' | 'FAILED' | 'UNDELIVERABLE';
    deliveredAt?: Date;
    readAt?: Date;
    failureReason?: string;
  }>;
}

export interface BulkMessageCapability {
  sendBulk(params: {
    recipients: Array<{ to: string; variables?: Record<string, string | number> }>;
    templateName: string;
    batchId: string;
  }): Promise<{
    totalSubmitted: number;
    acceptedCount: number;
    rejectedCount: number;
    batchReference: string;
  }>;
}
