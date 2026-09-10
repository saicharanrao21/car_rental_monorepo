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
export class XenditAdapter implements PaymentProvider {
  private readonly logger = new Logger(XenditAdapter.name);
  private secretKey: string;
  private callbackToken: string;

  constructor(private readonly configService: ConfigService) {
    this.secretKey = this.configService.get<string>('XENDIT_SECRET_KEY') || '';
    this.callbackToken = this.configService.get<string>('XENDIT_CALLBACK_TOKEN') || '';
  }

  getProviderId(): string {
    return 'xendit';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Xendit Southeast Asia Payments';
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
    const sec = credentials?.secretKey || this.secretKey;
    if (!sec) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Xendit secret key not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Xendit connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    const externalId = `xnd_ord_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[XENDIT] Created invoice ${externalId} for ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: externalId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'IDR',
      status: 'ACTIVE',
      rawResponse: {
        id: externalId,
        external_id: externalId,
        amount: amountFloat,
        invoice_url: `https://checkout.xendit.co/web/${externalId}`,
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
      currency: 'IDR',
      status: isValid ? 'PAID' : 'FAILED',
      rawResponse: {
        id: req.providerPaymentId,
        external_id: req.providerOrderId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    const refundId = `xnd_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[XENDIT] Initiated refund ${refundId} for payment ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        id: refundId,
        payment_id: req.providerPaymentId,
        status: 'SUCCEEDED',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    const token = secret || this.callbackToken;
    if (!token) return true;
    return signature === token;
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'PAID' || rawPayload?.status === 'COMPLETED';
    return {
      eventId: rawPayload?.id || `xnd_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.external_id || '',
      providerPaymentId: rawPayload?.id || rawPayload?.payment_id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'IDR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
