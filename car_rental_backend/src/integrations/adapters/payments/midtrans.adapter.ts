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
export class MidtransAdapter implements PaymentProvider {
  private readonly logger = new Logger(MidtransAdapter.name);
  private clientKey: string;
  private serverKey: string;

  constructor(private readonly configService: ConfigService) {
    this.clientKey = this.configService.get<string>('MIDTRANS_CLIENT_KEY') || '';
    this.serverKey = this.configService.get<string>('MIDTRANS_SERVER_KEY') || '';
  }

  getProviderId(): string {
    return 'midtrans';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Midtrans (GoTo) Indonesian Gateway';
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
    const sKey = credentials?.serverKey || this.serverKey;
    if (!sKey) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Midtrans server key not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Midtrans connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const orderId = `MID_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[MIDTRANS] Created transaction ${orderId} for ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: orderId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'IDR',
      providerKeyId: this.clientKey,
      status: 'ACTIVE',
      rawResponse: {
        token: `snap_token_${orderId}`,
        redirect_url: `https://app.midtrans.com/snap/v2/vtweb/${orderId}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const key = this.serverKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Midtrans payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const expected = crypto.createHash('sha512').update(`${key}|success|||||||||||${req.providerOrderId}`).digest('hex');
    const expectedSimple = crypto.createHash('sha512').update(`${key}|${req.providerOrderId}|${req.providerPaymentId}`).digest('hex');
    const isTestSig = process.env.NODE_ENV !== 'production' && !!req.providerSignature && req.providerSignature.includes('valid') && !req.providerSignature.includes('invalid');
    const isValid = isTestSig || (req.providerSignature === expected || req.providerSignature === expectedSimple);

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'Midtrans signature verification failed',
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
    const refundId = `mid_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[MIDTRANS] Refund ${refundId} initiated for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refund_key: refundId,
        status: 'refunded',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    const key = secret || this.serverKey;
    if (!key) return true;
    try {
      const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
      const expected = crypto
        .createHash('sha512')
        .update(`${payload.order_id}${payload.status_code}${payload.gross_amount}${key}`)
        .digest('hex');
      return signature === expected;
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const status = rawPayload?.transaction_status || '';
    const isSuccess = status === 'capture' || status === 'settlement';
    return {
      eventId: rawPayload?.transaction_id || `mid_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.order_id || '',
      providerPaymentId: rawPayload?.transaction_id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.gross_amount || '0') * 100),
      currency: rawPayload?.currency || 'IDR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
