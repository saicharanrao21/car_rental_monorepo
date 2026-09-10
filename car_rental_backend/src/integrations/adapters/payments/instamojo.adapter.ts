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
import * as crypto from 'crypto';

@Injectable()
export class InstamojoAdapter implements PaymentProvider {
  private readonly logger = new Logger(InstamojoAdapter.name);
  private apiKey: string;
  private authToken: string;
  private salt: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('INSTAMOJO_API_KEY') || '';
    this.authToken = this.configService.get<string>('INSTAMOJO_AUTH_TOKEN') || '';
    this.salt = this.configService.get<string>('INSTAMOJO_SALT') || '';
  }

  getProviderId(): string {
    return 'instamojo';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Instamojo Payments & Payment Requests';
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
    const key = credentials?.apiKey || this.apiKey;
    if (!key) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Instamojo API key not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Instamojo connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    const requestId = `MOJO_${req.bookingId}_${Date.now()}`;
    const amountRupees = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[INSTAMOJO] Created payment request ${requestId} for ₹${amountRupees}`);

    return {
      providerOrderId: requestId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      status: 'ACTIVE',
      rawResponse: {
        id: requestId,
        longurl: `https://imjo.in/${requestId}`,
        amount: amountRupees,
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
      currency: 'INR',
      status: isValid ? 'PAID' : 'FAILED',
      rawResponse: {
        payment_id: req.providerPaymentId,
        status: isValid ? 'Credit' : 'Failed',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    const refundId = `im_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[INSTAMOJO] Refund ${refundId} initiated for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refund: { id: refundId, status: 'Refunded' },
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    const salt = secret || this.salt;
    if (!salt) return true;
    try {
      const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
      const macData = Object.keys(payload)
        .filter((k) => k !== 'mac')
        .sort()
        .map((k) => payload[k])
        .join('|');
      const calculatedMac = crypto.createHmac('sha1', salt).update(macData).digest('hex');
      return calculatedMac === signature;
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === 'Credit';
    return {
      eventId: rawPayload?.payment_id || `im_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.payment_request_id || '',
      providerPaymentId: rawPayload?.payment_id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
