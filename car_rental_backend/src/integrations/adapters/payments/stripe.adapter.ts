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

  private hasLiveCredentials(): boolean {
    if (!this.secretKey) return false;
    if (
      this.secretKey.startsWith('placeholder') ||
      this.secretKey.startsWith('mock') ||
      this.secretKey.startsWith('test') ||
      this.secretKey.startsWith('sk_test_')
    ) {
      return false;
    }
    if (process.env.NODE_ENV === 'test') {
      return false;
    }
    return true;
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }

    if (hasLive) {
      try {
        const body = new URLSearchParams();
        body.append('amount', String(req.amountPaise));
        body.append('currency', (req.currency || 'inr').toLowerCase());
        body.append('metadata[bookingId]', req.bookingId);
        if (req.customerId) {
          body.append('metadata[customerId]', req.customerId);
        }
        body.append('payment_method_types[]', 'card');

        const response = await fetch('https://api.stripe.com/v1/payment_intents', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.secretKey}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body.toString(),
        });

        const data: any = await response.json();
        if (!response.ok) {
          this.logger.error(`[STRIPE] createOrder failed: ${JSON.stringify(data.error || data)}`);
          throw new ServiceUnavailableException(`Stripe API error: ${data.error?.message || response.statusText}`);
        }

        return {
          providerOrderId: data.id,
          amountPaise: data.amount,
          currency: data.currency ? data.currency.toUpperCase() : (req.currency || 'INR'),
          providerKeyId: this.publishableKey || 'pk_live_configured',
          status: data.status,
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`[STRIPE] createOrder network error: ${err?.message}`);
        throw new ServiceUnavailableException(`Stripe service unreachable: ${err?.message}`);
      }
    }

    // Sandbox / Test fallback
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
    const hasLiveCredentials = Boolean(this.secretKey && !this.secretKey.startsWith('placeholder'));

    if (hasLiveCredentials && req.providerPaymentId && !req.providerPaymentId.startsWith('mock_')) {
      try {
        const response = await fetch(`https://api.stripe.com/v1/payment_intents/${encodeURIComponent(req.providerPaymentId)}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${this.secretKey}`,
          },
        });

        if (response.ok) {
          const data: any = await response.json();
          const isValid = data.status === 'succeeded' || data.status === 'requires_capture';
          return {
            isValid,
            providerPaymentId: data.id,
            providerOrderId: data.id,
            status: isValid ? 'PAID' : 'FAILED',
            failureReason: isValid ? undefined : `Stripe payment status is ${data.status}`,
            rawResponse: data,
          };
        }
      } catch (err: any) {
        this.logger.warn(`[STRIPE] API verification check error: ${err?.message}`);
      }
    }

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
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }

    if (hasLive && req.providerPaymentId && !req.providerPaymentId.startsWith('mock_')) {
      try {
        const body = new URLSearchParams();
        body.append('payment_intent', req.providerPaymentId);
        body.append('amount', String(req.amountPaise));

        const response = await fetch('https://api.stripe.com/v1/refunds', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.secretKey}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body.toString(),
        });

        const data: any = await response.json();
        if (!response.ok) {
          throw new ServiceUnavailableException(`Stripe refund failed: ${data.error?.message || response.statusText}`);
        }

        return {
          providerRefundId: data.id,
          amountPaise: data.amount,
          status: 'PROCESSED',
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        throw new ServiceUnavailableException(`Stripe refund network error: ${err?.message}`);
      }
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
      if (signature.includes('t=') && signature.includes('v1=')) {
        const elements = signature.split(',');
        let timestamp = '';
        const signatures: string[] = [];
        for (const element of elements) {
          const [key, value] = element.split('=');
          if (key.trim() === 't') timestamp = value.trim();
          if (key.trim() === 'v1') signatures.push(value.trim());
        }
        const signedPayload = `${timestamp}.${rawBody}`;
        const expected = crypto.createHmac('sha256', targetSecret).update(signedPayload).digest('hex');
        return signatures.includes(expected);
      }

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

    const start = Date.now();
    try {
      const response = await fetch('https://api.stripe.com/v1/balance', {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${testSecret}` },
      });

      if (response.ok) {
        return {
          success: true,
          latencyMs: Date.now() - start,
          message: 'Stripe API connection verified',
        };
      }

      const data: any = await response.json();
      return {
        success: false,
        latencyMs: Date.now() - start,
        error: `Stripe authentication rejected: ${data.error?.message || response.statusText}`,
      };
    } catch (err: any) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        error: `Stripe connection error: ${err?.message}`,
      };
    }
  }
}
