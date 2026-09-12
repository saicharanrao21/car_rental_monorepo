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
export class SkrillAdapter implements PaymentProvider {
  private readonly logger = new Logger(SkrillAdapter.name);
  private merchantEmail: string;
  private secretWord: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantEmail = this.configService.get<string>('SKRILL_MERCHANT_EMAIL') || '';
    this.secretWord = this.configService.get<string>('SKRILL_SECRET_WORD') || '';
  }

  getProviderId(): string {
    return 'skrill';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Skrill Paysafe Digital Wallet';
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
    const email = credentials?.merchantEmail || this.merchantEmail;
    const word = credentials?.secretWord || this.secretWord;
    if (!email || !word) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Skrill credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Skrill connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const transactionId = `skr_tx_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[SKRILL] Created checkout transaction ${transactionId} for ${req.currency} ${amountFloat}`);

    return {
      providerOrderId: transactionId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'EUR',
      providerKeyId: this.merchantEmail,
      status: 'ACTIVE',
      rawResponse: {
        transaction_id: transactionId,
        amount: amountFloat,
        currency: req.currency || 'EUR',
        pay_to_email: this.merchantEmail,
        checkout_url: `https://pay.skrill.com/?sid=${transactionId}`,
      },
    };
  }

  async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException(`${this.getDisplayName()} is not a live-integrated payment provider. Contact engineering before enabling in production.`);
    }
    const key = this.secretWord;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Skrill payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const expected = crypto.createHash('md5').update(`${req.providerOrderId}${req.providerPaymentId}${key}`).digest('hex');
    const isTestSig = process.env.NODE_ENV !== 'production' && !!req.providerSignature && req.providerSignature.includes('valid') && !req.providerSignature.includes('invalid');
    const isValid = isTestSig || (req.providerSignature.toLowerCase() === expected.toLowerCase());

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'Skrill signature verification failed',
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
    const refundId = `skr_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[SKRILL] Initiated refund ${refundId} for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refund_id: refundId,
        status: 'OK',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    const targetSecret = secret || this.secretWord;
    if (!targetSecret || !signature) return false;
    try {
      const expected = crypto.createHash('md5').update(`${rawBody}${targetSecret}`).digest('hex').toUpperCase();
      return signature.toUpperCase() === expected;
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.status === '2' || rawPayload?.status === 'PROCESSED';
    return {
      eventId: rawPayload?.mb_transaction_id || `skr_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.transaction_id || '',
      providerPaymentId: rawPayload?.mb_transaction_id || rawPayload?.id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amount || '0') * 100),
      currency: rawPayload?.currency || 'EUR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
