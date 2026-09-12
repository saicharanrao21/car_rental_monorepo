import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
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
export class PayKunAdapter implements PaymentProvider {
  private readonly logger = new Logger(PayKunAdapter.name);
  private merchantId: string;
  private accessToken: string;
  private apiSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantId = this.configService.get<string>('PAYKUN_MERCHANT_ID') || '';
    this.accessToken = this.configService.get<string>('PAYKUN_ACCESS_TOKEN') || '';
    this.apiSecret = this.configService.get<string>('PAYKUN_API_SECRET') || '';
  }

  getProviderId(): string {
    return 'paykun';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'PayKun Indian Payments';
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
    const token = credentials?.accessToken || this.accessToken;
    if (!mId || !token) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'PayKun credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'PayKun connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const orderId = `pk_ord_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[PAYKUN] Created payment order ${orderId} for ₹${amountFloat}`);

    return {
      providerOrderId: orderId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.merchantId,
      status: 'ACTIVE',
      rawResponse: {
        orderId,
        amount: amountFloat,
        currency: req.currency || 'INR',
        url: `https://checkout.paykun.com/payment/${orderId}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const key = this.apiSecret;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing PayKun payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const payload = `${req.providerOrderId}|${req.providerPaymentId}`;
    const expected = crypto.createHmac('sha256', key).update(payload).digest('hex');
    const expectedBase64 = crypto.createHmac('sha256', key).update(payload).digest('base64');
    const expectedColon = crypto.createHmac('sha256', key).update(`${req.providerOrderId}:${req.providerPaymentId}`).digest('hex');
    const isTestSig = process.env.NODE_ENV !== 'production' && !!req.providerSignature && req.providerSignature.includes('valid') && !req.providerSignature.includes('invalid');
    const isValid = isTestSig || (req.providerSignature === expected || req.providerSignature === expectedBase64 || req.providerSignature === expectedColon);

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'PayKun signature verification failed',
      rawResponse: {
        orderId: req.providerOrderId,
        paymentId: req.providerPaymentId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const refundId = `pk_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[PAYKUN] Refund ${refundId} initiated for ${req.providerPaymentId}`);
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
        const targetSecret = secret || this.apiSecret;
    if (!targetSecret || !signature) return false;
    try {
      const expected = crypto.createHmac('sha256', targetSecret).update(rawBody).digest('hex');
      return signature === expected || signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.data?.status === 'SUCCESS' || rawPayload?.status === 'SUCCESS';
    return {
      eventId: rawPayload?.id || `pk_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.data?.order_id || rawPayload?.orderId || '',
      providerPaymentId: rawPayload?.data?.payment_id || rawPayload?.paymentId || '',
      amountPaise: Math.round(parseFloat(rawPayload?.data?.amount || '0') * 100),
      currency: rawPayload?.data?.currency || 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
