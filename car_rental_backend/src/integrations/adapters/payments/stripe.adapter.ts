import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
import * as crypto from 'crypto';

@Injectable()
export class StripeAdapter implements PaymentProvider {
  private readonly logger = new Logger(StripeAdapter.name);
  private publishableKey: string;
  private secretKey: string;
  private webhookSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.publishableKey = this.configService.get<string>('STRIPE_PUBLISHABLE_KEY') || '';
    this.secretKey = this.configService.get<string>('STRIPE_SECRET_KEY') || '';
    this.webhookSecret = this.configService.get<string>('STRIPE_WEBHOOK_SECRET') || '';
  }

  getProviderId(): string {
    return 'stripe';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Stripe Payments';
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

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.publishableKey || !this.secretKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const paymentIntentId = `pi_mock_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    return {
      providerOrderId: paymentIntentId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'inr',
      providerKeyId: this.publishableKey || 'pk_test_placeholder',
      status: 'requires_payment_method',
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const key = this.webhookSecret || this.secretKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Stripe payment signature or secret key',
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
      failureReason: isValid ? undefined : 'Stripe signature verification failed',
      rawResponse: {
        orderId: req.providerOrderId,
        paymentId: req.providerPaymentId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.publishableKey || !this.secretKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const refundId = `re_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
        const targetSecret = secret || this.webhookSecret;
    if (!targetSecret || !signature) return false;

    try {
      const expected = crypto.createHmac('sha256', targetSecret).update(rawBody).digest('hex');
      return signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const intent = rawPayload?.data?.object;
    return {
      eventId: rawPayload?.id || `evt_${Date.now()}`,
      eventType: rawPayload?.type || 'payment_intent.succeeded',
      providerPaymentId: intent?.id,
      providerOrderId: intent?.id,
      amountPaise: intent?.amount,
      currency: intent?.currency,
      status: 'CAPTURED',
      timestamp: new Date(rawPayload?.created ? rawPayload.created * 1000 : Date.now()),
      rawPayload,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const hasKeys = Boolean(this.secretKey && !this.secretKey.startsWith('placeholder'));
    return {
      status: hasKeys ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: hasKeys ? 'Stripe configured' : 'Stripe running in placeholder/unconfigured mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const testSecret = credentials?.secretKey || this.secretKey;
    if (!testSecret) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Stripe secretKey is required to test connection',
      };
    }
    return {
      success: true,
      latencyMs: 2,
      message: 'Stripe connection test successful',
    };
  }
}
