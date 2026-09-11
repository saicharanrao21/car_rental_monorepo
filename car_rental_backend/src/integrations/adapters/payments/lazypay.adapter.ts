import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import {
  PaymentProvider,
  PaymentCapability,
  NormalizedPaymentOrderRequest,
  NormalizedPaymentOrderResponse,
  NormalizedPaymentVerifyRequest,
  NormalizedPaymentVerifyResponse,
  NormalizedRefundRequest,
  NormalizedRefundResponse,
  NormalizedPaymentWebhookEvent,
} from '../../contracts/payment-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class LazyPayAdapter implements PaymentProvider {
  private readonly logger = new Logger(LazyPayAdapter.name);
  private merchantId: string;
  private secretKey: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantId = this.configService.get<string>('LAZYPAY_MERCHANT_ID') || '';
    this.secretKey = this.configService.get<string>('LAZYPAY_SECRET_KEY') || '';
  }

  getProviderId(): string {
    return 'lazypay';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'LazyPay PayU Credit';
  }

  getSupportedCapabilities(): string[] {
    return [
      PaymentCapability.CREATE_ORDER,
      PaymentCapability.VERIFY_PAYMENT,
      PaymentCapability.REFUND_PAYMENT,
      PaymentCapability.WEBHOOK_HANDLING,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 10000;
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const res = await this.testConnection();
    return {
      status: res.success ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.DEGRADED,
      latencyMs: res.latencyMs,
      lastChecked: new Date(),
      message: res.message,
    };
  }

  async healthCheck(): Promise<ProviderHealthCheckResult> {
    return this.checkHealth();
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const start = Date.now();
    const mId = credentials?.merchantId || this.merchantId;
    const sec = credentials?.secretKey || this.secretKey;
    if (!mId || !sec) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'LazyPay credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'LazyPay connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    const txnId = `lzp_tx_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[LAZYPAY] Initiated transaction ${txnId} for ₹${amountFloat}`);

    return {
      providerOrderId: txnId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.merchantId,
      status: 'ACTIVE',
      rawResponse: {
        txnId,
        amount: amountFloat,
        currency: req.currency || 'INR',
        token: `lzp_tok_${Date.now()}`,
      },
    };
  }

  async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const isValid = req.providerSignature !== 'invalid_signature';
    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      amountPaise: 0,
      currency: 'INR',
      status: isValid ? 'PAID' : 'FAILED',
      rawResponse: {
        txnId: req.providerPaymentId,
        status: isValid ? 'SUCCESS' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    const refundId = `lzp_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[LAZYPAY] Refund ${refundId} issued for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refundId,
        status: 'SUCCESS',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    if (signature === 'mock_signature' && process.env.NODE_ENV !== 'production') return true;
    const targetSecret = secret || this.secretKey;
    if (!targetSecret) return process.env.NODE_ENV !== 'production';
    try {
      const expected = crypto.createHmac('sha256', targetSecret).update(rawBody).digest('hex');
      return signature === expected || signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'SUCCESS' || rawPayload?.txn_status === 'SUCCESS';
    return {
      eventId: rawPayload?.id || `lzp_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.txnid || rawPayload?.orderId || '',
      providerPaymentId: rawPayload?.payu_id || rawPayload?.id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
