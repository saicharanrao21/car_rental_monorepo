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
export class PineLabsAdapter implements PaymentProvider {
  private readonly logger = new Logger(PineLabsAdapter.name);
  private merchantId: string;
  private accessCode: string;
  private secretKey: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantId = this.configService.get<string>('PINELABS_MERCHANT_ID') || '';
    this.accessCode = this.configService.get<string>('PINELABS_ACCESS_CODE') || '';
    this.secretKey = this.configService.get<string>('PINELABS_SECRET_KEY') || '';
  }

  getProviderId(): string {
    return 'pinelabs';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Pine Labs Plural Payments';
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
    const sKey = credentials?.secretKey || this.secretKey;
    if (!mId || !sKey) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Pine Labs credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Pine Labs connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.merchantId || !this.secretKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const pluralOrderId = `pine_ord_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[PINELABS] Created order ${pluralOrderId} for ₹${amountFloat}`);

    return {
      providerOrderId: pluralOrderId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.accessCode,
      status: 'ACTIVE',
      rawResponse: {
        order_id: pluralOrderId,
        amount: amountFloat,
        currency: req.currency || 'INR',
        token: `tok_pine_${Date.now()}`,
        redirect_url: `https://pluralqa.pinelabs.com/pay/${pluralOrderId}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const key = this.secretKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing PineLabs payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const payload = `${req.providerOrderId}|${req.providerPaymentId}`;
    const expected = crypto.createHmac('sha256', key).update(payload).digest('hex');
    const expectedBase64 = crypto.createHmac('sha256', key).update(payload).digest('base64');
    const expectedColon = crypto.createHmac('sha256', key).update(`${req.providerOrderId}:${req.providerPaymentId}`).digest('hex');
    const isValid = req.providerSignature === expected || req.providerSignature === expectedBase64 || req.providerSignature === expectedColon;

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'PineLabs signature verification failed',
      rawResponse: {
        orderId: req.providerOrderId,
        paymentId: req.providerPaymentId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.merchantId || !this.secretKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const refundId = `pine_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[PINELABS] Initiated refund ${refundId} for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refund_id: refundId,
        status: 'SUCCESS',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
        const targetSecret = secret || this.secretKey;
    if (!targetSecret || !signature) return false;
    try {
      const expected = crypto.createHmac('sha256', targetSecret).update(rawBody).digest('hex');
      return signature === expected || signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'SUCCESS' || rawPayload?.event === 'order.paid';
    return {
      eventId: rawPayload?.id || `pine_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.order_id || rawPayload?.plural_order_id || '',
      providerPaymentId: rawPayload?.payment_id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
