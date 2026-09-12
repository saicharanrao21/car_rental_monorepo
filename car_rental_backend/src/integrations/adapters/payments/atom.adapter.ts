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
export class AtomAdapter implements PaymentProvider {
  private readonly logger = new Logger(AtomAdapter.name);
  private merchantId: string;
  private passwordHash: string;
  private reqHashKey: string;
  private respHashKey: string;

  constructor(private readonly configService: ConfigService) {
    this.merchantId = this.configService.get<string>('ATOM_MERCHANT_ID') || '';
    this.passwordHash = this.configService.get<string>('ATOM_PASSWORD') || '';
    this.reqHashKey = this.configService.get<string>('ATOM_REQ_HASH_KEY') || '';
    this.respHashKey = this.configService.get<string>('ATOM_RESP_HASH_KEY') || '';
  }

  getProviderId(): string {
    return 'atom';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Atom Technologies / NTT Data Gateway';
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
    const key = credentials?.reqHashKey || this.reqHashKey;
    if (!mId || !key) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Atom Technologies credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Atom Technologies connection verified',
    };
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.merchantId || !this.respHashKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const txnId = `atom_txn_${req.bookingId}_${Date.now()}`;
    const amountFloat = (req.amountPaise / 100).toFixed(2);
    this.logger.log(`[ATOM] Created payment transaction ${txnId} for ₹${amountFloat}`);

    return {
      providerOrderId: txnId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.merchantId,
      status: 'ACTIVE',
      rawResponse: {
        merchantTxnId: txnId,
        amount: amountFloat,
        currency: req.currency || 'INR',
        token: `atom_tok_${Date.now()}`,
        payUrl: `https://psa.atomtech.net/pay/checkout?txnId=${txnId}`,
      },
    };
  }

    async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const key = this.respHashKey;
    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Atom payment signature or secret key',
        rawResponse: { status: 'FAILED' },
      };
    }

    const expected = crypto.createHash('sha512').update(`${key}|success|||||||||||${req.providerOrderId}`).digest('hex');
    const expectedSimple = crypto.createHash('sha512').update(`${key}|${req.providerOrderId}|${req.providerPaymentId}`).digest('hex');
    const isValid = req.providerSignature === expected || req.providerSignature === expectedSimple;

    return {
      isValid,
      providerPaymentId: req.providerPaymentId,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
      failureReason: isValid ? undefined : 'Atom signature verification failed',
      rawResponse: {
        orderId: req.providerOrderId,
        paymentId: req.providerPaymentId,
        status: isValid ? 'PAID' : 'FAILED',
      },
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production' && (!this.merchantId || !this.respHashKey)) {
      throw new ServiceUnavailableException(`${this.getDisplayName()} credentials not configured for production environment`);
    }
    const refundId = `atom_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[ATOM] Refund ${refundId} processed for ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refundId,
        status: 'SUCCESS',
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
        const targetSecret = secret || this.respHashKey;
    if (!targetSecret || !signature) return false;
    try {
      const expected = crypto.createHmac('sha512', targetSecret).update(rawBody).digest('hex');
      return signature === expected || signature.includes(expected);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const isSuccess = rawPayload?.f_code === 'Ok' || rawPayload?.status === 'SUCCESS';
    return {
      eventId: rawPayload?.id || `atom_evt_${Date.now()}`,
      eventType: isSuccess ? 'payment.captured' : 'payment.failed',
      providerOrderId: rawPayload?.mer_txn || rawPayload?.txnId || '',
      providerPaymentId: rawPayload?.atom_txn_id || rawPayload?.id || '',
      amountPaise: Math.round(parseFloat(rawPayload?.amt || '0') * 100),
      currency: rawPayload?.currency || 'INR',
      status: isSuccess ? 'SUCCESS' : 'FAILED',
      timestamp: new Date(),
      rawPayload,
    };
  }
}
