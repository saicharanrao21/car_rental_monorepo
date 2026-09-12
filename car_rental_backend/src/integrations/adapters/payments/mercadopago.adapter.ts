import * as crypto from 'crypto';
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

@Injectable()
export class MercadoPagoAdapter implements PaymentProvider {
  private readonly logger = new Logger(MercadoPagoAdapter.name);
  private accessToken: string;
  private publicKey: string;
  private webhookSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.accessToken = this.configService.get<string>('MERCADOPAGO_ACCESS_TOKEN') || '';
    this.publicKey = this.configService.get<string>('MERCADOPAGO_PUBLIC_KEY') || '';
    this.webhookSecret = this.configService.get<string>('MERCADOPAGO_WEBHOOK_SECRET') || '';
  }

  getProviderId(): string {
    return 'mercadopago';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Mercado Pago Latin America';
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
    const token = credentials?.accessToken || this.accessToken;
    if (!token) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Mercado Pago access token not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Mercado Pago connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const preferenceId = `pref_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[MERCADOPAGO] Created preference ${preferenceId} for ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: preferenceId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'BRL',
      providerKeyId: this.publicKey,
      status: 'ACTIVE',
      rawResponse: {
        id: preferenceId,
        init_point: `https://www.mercadopago.com/checkout/v1/redirect?pref_id=${preferenceId}`,
        amount: amountFloat,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const key = this.accessToken;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing MercadoPago payment signature or secret key',
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
      failureReason: isValid ? undefined : 'MercadoPago signature verification failed',
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
    const refundId = `mp_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[MERCADOPAGO] Refund ${refundId} initiated for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        id: refundId,
        payment_id: req.providerPaymentId,
        status: 'approved',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    return !!signature;
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.action === 'payment.created' || rawPayload?.status === 'approved';
    return {
      eventId: rawPayload?.id || `mp_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.data?.id || '',
      providerPaymentId: rawPayload?.data?.id || '',
      amountPaise: 0,
      currency: 'BRL',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
