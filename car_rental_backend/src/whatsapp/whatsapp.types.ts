import { WhatsAppMessageStatus, WhatsAppMessageType } from '@prisma/client';

export interface SendTemplateOptions {
  userId?: string;
  bookingId?: string;
  phoneNumber: string;
  messageType: WhatsAppMessageType;
  templateName: string;
  templateLanguage?: string;
  variables: Record<string, string | number>;
  idempotencyKey: string;
}

export interface WhatsAppProviderSendResult {
  providerMessageId: string;
  status: 'ACCEPTED' | 'FAILED';
  errorCode?: string;
  errorMessage?: string;
}

export interface WhatsAppWebhookStatusEntry {
  id: string; // providerMessageId (e.g. wamid.HBgL...)
  status: 'sent' | 'delivered' | 'read' | 'failed';
  timestamp: string;
  recipient_id: string;
  errors?: Array<{ code: number; title: string; message: string }>;
}

export interface WhatsAppWebhookPayload {
  object: string;
  entry?: Array<{
    id: string;
    changes?: Array<{
      value?: {
        messaging_product?: string;
        metadata?: {
          display_phone_number?: string;
          phone_number_id?: string;
        };
        statuses?: WhatsAppWebhookStatusEntry[];
      };
      field?: string;
    }>;
  }>;
}

export interface WhatsAppSummaryResponse {
  totalMessages: number;
  sentCount: number;
  deliveredCount: number;
  readCount: number;
  failedCount: number;
  deliveryRatePercent: number;
}
