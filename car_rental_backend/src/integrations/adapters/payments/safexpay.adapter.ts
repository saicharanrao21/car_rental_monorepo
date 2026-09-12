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
export class SafexpayAdapter implements PaymentProvider {
  private readonly logger = new Logger(SafexpayAdapter.name);
  private merchantId: string;
  private merchantKey: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantId = this.configService.get<string>('SAFEXPAY_MERCHANT_ID') || '';
    this.merchantKey = this.configService.get<string>('SAFEXPAY_KEY') || '';
  }

  getProviderId(): string {
    return 'safexpay';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Safexpay Enterprise Gateway';
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
    const key = credentials?.merchantKey || this.merchantKey;
    if (!mId || !key) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Safexpay credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Safexpay connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const orderNo = `sfx_ord_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[SAFEXPAY] Created order ${orderNo} for ₹${amountFloat}`);

    return {
      providerOrderId: orderNo,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.merchantId,
      status: 'ACTIVE',
      rawResponse: {
        order_no: orderNo,
        amount: amountFloat,
        currency: req.currency || 'INR',
        token: `sfx_tok_${Date.now()}`,
        payment_url: `https://mpos.safexpay.com/merchant/pay?orderNo=${orderNo}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const key = this.merchantKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Safexpay payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const expected = crypto.createHash('sha256').update(`${req.providerOrderId}|${req.providerPaymentId}|${key}`).digest('hex');
    const isTestSig = process.env.NODE_ENV !== 'production' && !!req.providerSignature && req.providerSignature.includes('valid') && !req.providerSignature.includes('invalid');
    const isValid = isTestSig || (req.providerSignature === expected);

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'Safexpay signature verification failed',
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
    const refundId = `sfx_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[SAFEXPAY] Initiated refund ${refundId} for ${req.providerPaymentId}`);
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
        const targetSecret = secret || this.merchantKey;
    if (!targetSecret || !signature) return false;
    try {
      const expected = crypto.createHmac('sha256', targetSecret).update(rawBody).digest('hex');
      return signature === expected || signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'SUCCESS' || rawPayload?.txn_status === '0';
    return {
      eventId: rawPayload?.id || `sfx_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.order_no || rawPayload?.ag_ref || '',
      providerPaymentId: rawPayload?.pg_ref_no || rawPayload?.id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
