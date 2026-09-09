import { BaseProvider } from './provider.interface';
import { Decimal } from '@prisma/client/runtime/library';

export enum PaymentCapability {
  CREATE_ORDER = 'CREATE_ORDER',
  VERIFY_PAYMENT = 'VERIFY_PAYMENT',
  CAPTURE_PAYMENT = 'CAPTURE_PAYMENT',
  REFUND_PAYMENT = 'REFUND_PAYMENT',
  WEBHOOK_HANDLING = 'WEBHOOK_HANDLING',
  RECONCILIATION = 'RECONCILIATION',
  SPLIT_PAYMENT = 'SPLIT_PAYMENT',
}

export interface NormalizedPaymentOrderRequest {
  bookingId: string;
  amountPaise: number;
  currency: string;
  customerId: string;
  customerEmail?: string;
  customerPhone?: string;
  idempotencyKey?: string;
  notes?: Record<string, string>;
}

export interface NormalizedPaymentOrderResponse {
  providerOrderId: string;
  amountPaise: number;
  currency: string;
  providerKeyId?: string;
  status: string;
  rawResponse?: any;
}

export interface NormalizedPaymentVerifyRequest {
  providerOrderId: string;
  providerPaymentId: string;
  providerSignature: string;
  bookingId?: string;
  rawBody?: string;
}

export interface NormalizedPaymentVerifyResponse {
  isValid: boolean;
  providerPaymentId: string;
  providerOrderId: string;
  amountPaise?: number;
  currency?: string;
  paymentMethod?: string;
  status: string;
  failureReason?: string;
  rawResponse?: any;
}

export interface NormalizedRefundRequest {
  paymentId: string;
  providerPaymentId: string;
  amountPaise: number;
  reason?: string;
  idempotencyKey?: string;
  notes?: Record<string, string>;
}

export interface NormalizedRefundResponse {
  providerRefundId: string;
  amountPaise: number;
  status: 'PROCESSED' | 'PENDING' | 'FAILED';
  failureReason?: string;
  rawResponse?: any;
}

export interface NormalizedPaymentWebhookEvent {
  eventId: string;
  eventType: string; // 'payment.captured' | 'order.paid' | 'refund.processed' | etc.
  providerPaymentId?: string;
  providerOrderId?: string;
  providerRefundId?: string;
  amountPaise?: number;
  currency?: string;
  status: string;
  failureReason?: string;
  timestamp: Date;
  rawPayload: any;
}

export interface PaymentProvider extends BaseProvider {
  createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse>;
  verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse>;
  refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse>;
  verifyWebhookSignature(rawBody: string, signature: string, secret: string, headers?: any): boolean;
  normalizeWebhook(rawPayload: any, headers?: any): NormalizedPaymentWebhookEvent;
  fetchPaymentDetails?(providerPaymentId: string): Promise<any>;
}
