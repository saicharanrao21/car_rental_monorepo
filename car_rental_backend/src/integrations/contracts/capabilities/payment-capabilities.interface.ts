import {
  NormalizedPaymentOrderRequest,
  NormalizedPaymentOrderResponse,
  NormalizedPaymentVerifyRequest,
  NormalizedPaymentVerifyResponse,
  NormalizedRefundRequest,
  NormalizedRefundResponse,
  NormalizedPaymentWebhookEvent,
} from '../payment-provider.interface';

export interface PaymentOrderCreationCapability {
  createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse>;
}

export interface PaymentCaptureCapability {
  capturePayment(providerPaymentId: string, amountPaise: number, currency?: string): Promise<{
    providerPaymentId: string;
    amountPaise: number;
    status: 'CAPTURED' | 'FAILED';
    rawResponse?: any;
  }>;
}

export interface PaymentVerifyCapability {
  verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse>;
}

export interface PaymentRefundCapability {
  refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse>;
}

export interface PaymentPayoutCapability {
  createPayout(req: {
    beneficiaryId: string;
    accountNumber?: string;
    ifscOrIban?: string;
    amountPaise: number;
    currency: string;
    purpose?: string;
    idempotencyKey?: string;
  }): Promise<{
    providerPayoutId: string;
    amountPaise: number;
    status: 'PROCESSED' | 'QUEUED' | 'FAILED';
    rawResponse?: any;
  }>;
}

export interface PaymentWebhookCapability {
  verifyWebhookSignature(rawBody: string, signature: string, secret: string, headers?: any): boolean;
  normalizeWebhook(rawPayload: any, headers?: any): NormalizedPaymentWebhookEvent;
}

export interface PaymentStatusCapability {
  fetchPaymentDetails(providerPaymentId: string): Promise<any>;
}

export interface PaymentSplitCapability {
  createSplitTransfer(req: {
    providerPaymentId: string;
    transfers: Array<{
      account: string;
      amountPaise: number;
      currency?: string;
      notes?: Record<string, string>;
    }>;
  }): Promise<{
    transferId: string;
    status: string;
    rawResponse?: any;
  }>;
}
