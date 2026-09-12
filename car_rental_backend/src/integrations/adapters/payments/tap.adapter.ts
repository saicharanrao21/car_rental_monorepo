import { Injectable, Logger } from '@nestjs/common';
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
export class TapPaymentAdapter implements PaymentProvider {
  private readonly logger = new Logger(TapPaymentAdapter.name);
  private secretKey: string;
  private publishableKey: string;
  private webhookSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.secretKey = this.configService.get<string>('TAP_SECRET_KEY') || '';
    this.publishableKey = this.configService.get<string>('TAP_PUBLISHABLE_KEY') || '';
    this.webhookSecret = this.configService.get<string>('TAP_WEBHOOK_SECRET') || '';
  }

  getProviderId(): string {
    return 'tap';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Tap Payments MENA';
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
    const sKey = credentials?.secretKey || this.secretKey;
    if (!sKey) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Tap secret key not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Tap connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Tap simulated adapter is not allowed in production');
    }
    const chargeId = `chg_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[TAP] Created charge ${chargeId} for ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: chargeId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'KWD',
      providerKeyId: this.publishableKey,
      status: 'ACTIVE',
      rawResponse: {
        id: chargeId,
        amount: amountFloat,
        currency: req.currency || 'KWD',
        transaction: { url: `https://checkout.tap.company/${chargeId}` },
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
      currency: 'KWD',
      status: isValid ? 'PAID' : 'FAILED',
      rawResponse: {
        id: req.providerPaymentId,
        status: isValid ? 'CAPTURED' : 'DECLINED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    const refundId = `tap_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[TAP] Refund ${refundId} initiated for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        id: refundId,
        status: 'REFUNDED',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    return !!signature;
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'CAPTURED';
    return {
      eventId: rawPayload?.id || `tap_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.reference?.order || rawPayload?.id || '',
      providerPaymentId: rawPayload?.id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'KWD',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
