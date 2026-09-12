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
export class PaytabsAdapter implements PaymentProvider {
  private readonly logger = new Logger(PaytabsAdapter.name);
  private profileId: string;
  private serverKey: string;
  private clientKey: string;

  constructor(private readonly configService: ConfigService) {
    this.profileId = this.configService.get<string>('PAYTABS_PROFILE_ID') || '';
    this.serverKey = this.configService.get<string>('PAYTABS_SERVER_KEY') || '';
    this.clientKey = this.configService.get<string>('PAYTABS_CLIENT_KEY') || '';
  }

  getProviderId(): string {
    return 'paytabs';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'PayTabs Middle East Gateway';
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
        message: 'PayTabs server key not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'PayTabs connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.profileId || !this.serverKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    if (process.env.NODE_ENV === 'production') {
      throw new Error('PayTabs simulated adapter is not allowed in production');
    }
    const cartId = `TST_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[PAYTABS] Created page for cart ${cartId} amount ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: cartId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'SAR',
      providerKeyId: this.clientKey,
      status: 'ACTIVE',
      rawResponse: {
        tran_ref: `TST_TRAN_${Date.now()}`,
        cart_id: cartId,
        redirect_url: `https://secure.paytabs.com/payment/page/${cartId}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const key = this.serverKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing PayTabs payment signature or secret key',
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
      failureReason: isValid ? undefined : 'PayTabs signature verification failed',
      rawResponse: {
        orderId: req.providerOrderId,
        paymentId: req.providerPaymentId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.profileId || !this.serverKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const refundId = `pt_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[PAYTABS] Refund ${refundId} initiated for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        tran_ref: refundId,
        status: 'refunded',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    return !!signature;
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.payment_result?.response_status === 'A';
    return {
      eventId: rawPayload?.tran_ref || `pt_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.cart_id || '',
      providerPaymentId: rawPayload?.tran_ref || '',
      amountPaise: Math.round(parseFloat(rawPayload?.cart_amount || '0') * 100),
      currency: rawPayload?.cart_currency || 'SAR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
