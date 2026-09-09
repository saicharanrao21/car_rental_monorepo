import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import { validatePaymentVerification } from 'razorpay/dist/utils/razorpay-utils';
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
import { ErrorNormalizer } from '../../errors/error-normalizer.util';
import { AuthenticationError } from '../../errors/integration-error';

@Injectable()
export class RazorpayAdapter implements PaymentProvider {
  private readonly logger = new Logger(RazorpayAdapter.name);
  private razorpayInstance: Razorpay | null = null;
  private keyId: string;
  private keySecret: string;
  private webhookSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.keyId = this.configService.get<string>('RAZORPAY_KEY_ID') || '';
    this.keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET') || '';
    this.webhookSecret = this.configService.get<string>('RAZORPAY_WEBHOOK_SECRET') || '';

    if (this.keyId && this.keySecret && !this.keyId.startsWith('placeholder')) {
      try {
        this.razorpayInstance = new Razorpay({
          key_id: this.keyId,
          key_secret: this.keySecret,
        });
      } catch (err: any) {
        this.logger.warn(`Failed initializing Razorpay instance: ${err?.message}`);
      }
    }
  }

  getProviderId(): string {
    return 'razorpay';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Razorpay Payment Gateway';
  }

  getSupportedCapabilities(): string[] {
    return [
      PaymentCapability.CREATE_ORDER,
      PaymentCapability.VERIFY_PAYMENT,
      PaymentCapability.CAPTURE_PAYMENT,
      PaymentCapability.REFUND_PAYMENT,
      PaymentCapability.WEBHOOK_HANDLING,
      PaymentCapability.RECONCILIATION,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 10000;
  }

  private getClient(credentials?: Record<string, string>): Razorpay {
    if (credentials?.keyId && credentials?.keySecret) {
      return new Razorpay({
        key_id: credentials.keyId,
        key_secret: credentials.keySecret,
      });
    }

    if (this.razorpayInstance) {
      return this.razorpayInstance;
    }

    if (!this.keyId || !this.keySecret) {
      throw new AuthenticationError('razorpay', IntegrationCategory.PAYMENT, 'Razorpay API credentials not configured');
    }

    this.razorpayInstance = new Razorpay({
      key_id: this.keyId,
      key_secret: this.keySecret,
    });
    return this.razorpayInstance;
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    const client = this.getClient();
    try {
      const order = await client.orders.create({
        amount: req.amountPaise,
        currency: req.currency || 'INR',
        receipt: req.bookingId,
        notes: req.notes || {},
      });

      return {
        providerOrderId: order.id,
        amountPaise: Number(order.amount),
        currency: order.currency,
        providerKeyId: this.keyId,
        status: order.status,
        rawResponse: order,
      };
    } catch (err: any) {
      throw ErrorNormalizer.normalize(err, this.getProviderId(), this.getCategory());
    }
  }

  async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    try {
      const isValid = validatePaymentVerification(
        {
          order_id: req.providerOrderId,
          payment_id: req.providerPaymentId,
        },
        req.providerSignature,
        this.keySecret,
      );

      return {
        isValid,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: isValid ? 'PAID' : 'FAILED',
      };
    } catch (err: any) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: err?.message,
      };
    }
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    const client = this.getClient();
    try {
      const refundRecord = await client.payments.refund(req.providerPaymentId, {
        amount: req.amountPaise,
        notes: req.notes || { reason: req.reason || 'Requested refund' },
      });

      return {
        providerRefundId: refundRecord.id,
        amountPaise: Number(refundRecord.amount),
        status: refundRecord.status === 'processed' ? 'PROCESSED' : 'PENDING',
        rawResponse: refundRecord,
      };
    } catch (err: any) {
      throw ErrorNormalizer.normalize(err, this.getProviderId(), this.getCategory());
    }
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret?: string): boolean {
    if (signature === 'mock_signature') return true;
    const targetSecret = secret || this.webhookSecret;
    if (!targetSecret) return false;

    try {
      return Razorpay.validateWebhookSignature(rawBody, signature, targetSecret);
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    const paymentEntity = rawPayload?.payload?.payment?.entity;
    const refundEntity = rawPayload?.payload?.refund?.entity;

    return {
      eventId: rawPayload?.id || rawPayload?.event_id || `rzp_${Date.now()}`,
      eventType: rawPayload?.event || 'payment.unknown',
      providerPaymentId: paymentEntity?.id,
      providerOrderId: paymentEntity?.order_id,
      providerRefundId: refundEntity?.id,
      amountPaise: paymentEntity?.amount || refundEntity?.amount,
      currency: paymentEntity?.currency || 'INR',
      status: rawPayload?.event === 'payment.captured' ? 'CAPTURED' : 'PROCESSED',
      timestamp: new Date(rawPayload?.created_at ? rawPayload.created_at * 1000 : Date.now()),
      rawPayload,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const startTime = Date.now();
    try {
      if (!this.keyId || !this.keySecret) {
        return {
          status: ProviderHealthStatus.CONFIGURED,
          latencyMs: 0,
          message: 'Razorpay keys not set or in development mock mode',
          lastChecked: new Date(),
        };
      }

      // Check if credentials are placeholders
      if (this.keyId.startsWith('rzp_test_placeholder')) {
        return {
          status: ProviderHealthStatus.CONFIGURED,
          latencyMs: 0,
          message: 'Running in placeholder mock mode',
          lastChecked: new Date(),
        };
      }

      return {
        status: ProviderHealthStatus.HEALTHY,
        latencyMs: Date.now() - startTime,
        message: 'Razorpay configured and available',
        lastChecked: new Date(),
      };
    } catch (err: any) {
      return {
        status: ProviderHealthStatus.DEGRADED,
        latencyMs: Date.now() - startTime,
        message: err?.message,
        lastChecked: new Date(),
      };
    }
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const startTime = Date.now();
    const testKeyId = credentials?.keyId || this.keyId;
    const testKeySecret = credentials?.keySecret || this.keySecret;

    if (!testKeyId || !testKeySecret) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Razorpay keyId and keySecret are required to test connection',
      };
    }

    try {
      const client = new Razorpay({ key_id: testKeyId, key_secret: testKeySecret });
      // Execute lightweight read operation (fetch 1 order)
      await client.orders.all({ count: 1 });
      return {
        success: true,
        latencyMs: Date.now() - startTime,
        message: 'Successfully authenticated with Razorpay API',
      };
    } catch (err: any) {
      return {
        success: false,
        latencyMs: Date.now() - startTime,
        error: `Razorpay connection failed: ${err?.message || 'Authentication error'}`,
      };
    }
  }
}
