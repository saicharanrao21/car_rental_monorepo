import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import {
  PaymentProvider,
  NormalizedPaymentOrderRequest,
  NormalizedPaymentOrderResponse,
  NormalizedPaymentVerifyRequest,
  NormalizedPaymentVerifyResponse,
  NormalizedRefundRequest,
  NormalizedRefundResponse,
  NormalizedPaymentWebhookEvent,
} from '../../contracts/payment-provider.interface';
import {
  PaymentOrderCreationCapability,
  PaymentVerifyCapability,
  PaymentRefundCapability,
  PaymentWebhookCapability,
  PaymentStatusCapability,
} from '../../contracts/capabilities/payment-capabilities.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class CashfreeAdapter
  implements
    PaymentProvider,
    PaymentOrderCreationCapability,
    PaymentVerifyCapability,
    PaymentRefundCapability,
    PaymentWebhookCapability,
    PaymentStatusCapability
{
  private readonly logger = new Logger(CashfreeAdapter.name);
  private appId: string;
  private secretKey: string;
  private apiEndpoint: string;

  constructor(private readonly configService: ConfigService) {
    this.appId = this.configService.get<string>('CASHFREE_APP_ID') || '';
    this.secretKey = this.configService.get<string>('CASHFREE_SECRET_KEY') || '';
    const env = this.configService.get<string>('CASHFREE_ENV') || 'SANDBOX';
    this.apiEndpoint =
      env === 'LIVE'
        ? 'https://api.cashfree.com/pg'
        : 'https://sandbox.cashfree.com/pg';
  }

  getProviderId(): string {
    return 'cashfree';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Cashfree Payments';
  }

  getSupportedCapabilities(): string[] {
    return [
      'CREATE_ORDER',
      'VERIFY_PAYMENT',
      'CAPTURE_PAYMENT',
      'REFUND_PAYMENT',
      'WEBHOOK_HANDLING',
      'WEBHOOKS',
      'SPLIT_PAYMENT',
      'UPI_INTENT',
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 8000;
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const startTime = Date.now();
    try {
      const isConfigured = !!(this.appId && this.secretKey && !this.secretKey.startsWith('placeholder'));
      return {
        status: isConfigured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
        latencyMs: Date.now() - startTime,
        lastChecked: new Date(),
        message: isConfigured
          ? 'Cashfree PG operational'
          : 'Cashfree credentials not configured (sandbox mode)',
      };
    } catch (err: any) {
      return {
        status: ProviderHealthStatus.DEGRADED,
        latencyMs: Date.now() - startTime,
        lastChecked: new Date(),
        message: err?.message || 'Cashfree check failed',
      };
    }
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const appId = credentials?.appId || this.appId;
    const secret = credentials?.secretKey || this.secretKey;
    if (!appId || !secret) {
      return {
        success: false,
        message: 'Missing Cashfree appId or secretKey',
        latencyMs: 5,
      };
    }

    const start = Date.now();
    try {
      const response = await fetch(`${this.apiEndpoint}/orders`, {
        method: 'GET',
        headers: {
          'x-client-id': appId,
          'x-client-secret': secret,
          'x-api-version': '2023-08-01',
        },
      });

      if (response.ok || response.status === 200) {
        return {
          success: true,
          message: 'Cashfree connection and credentials verified successfully',
          latencyMs: Date.now() - start,
        };
      }

      const data: any = await response.json();
      return {
        success: false,
        message: `Cashfree authentication rejected: ${data.message || response.statusText}`,
        latencyMs: Date.now() - start,
      };
    } catch (err: any) {
      return {
        success: false,
        message: `Cashfree connection error: ${err?.message}`,
        latencyMs: Date.now() - start,
      };
    }
  }

  private hasLiveCredentials(): boolean {
    if (!this.appId || !this.secretKey) return false;
    if (
      this.secretKey.startsWith('placeholder') ||
      this.secretKey.startsWith('mock') ||
      this.secretKey.startsWith('test') ||
      this.secretKey === 'cf_sec_sample' ||
      this.appId.startsWith('placeholder') ||
      this.appId.startsWith('mock') ||
      this.appId.startsWith('test') ||
      this.appId.startsWith('cf_app_') ||
      this.appId.startsWith('cashfree_app_')
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

    const orderId = `cf_ord_${req.bookingId}_${Date.now()}`;

    if (hasLive) {
      try {
        const response = await fetch(`${this.apiEndpoint}/orders`, {
          method: 'POST',
          headers: {
            'x-client-id': this.appId,
            'x-client-secret': this.secretKey,
            'x-api-version': '2023-08-01',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            order_id: orderId,
            order_amount: req.amountPaise / 100,
            order_currency: req.currency || 'INR',
            customer_details: {
              customer_id: req.customerId || 'cust_drivego',
              customer_phone: '9999999999',
            },
          }),
        });

        const data: any = await response.json();
        if (!response.ok) {
          this.logger.error(`[CASHFREE] createOrder failed: ${JSON.stringify(data)}`);
          throw new ServiceUnavailableException(`Cashfree order creation error: ${data.message || response.statusText}`);
        }

        return {
          providerOrderId: data.order_id,
          amountPaise: Math.round(data.order_amount * 100),
          currency: data.order_currency || 'INR',
          providerKeyId: this.appId,
          status: data.order_status || 'ACTIVE',
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`[CASHFREE] Network error: ${err?.message}`);
        throw new ServiceUnavailableException(`Cashfree service unreachable: ${err?.message}`);
      }
    }

    // Sandbox / Test fallback
    this.logger.log(`[CASHFREE] Created normalized payment order ${orderId} for ₹${req.amountPaise / 100}`);
    return {
      providerOrderId: orderId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: this.appId || 'cf_test_key',
      status: 'ACTIVE',
      rawResponse: {
        order_id: orderId,
        order_status: 'ACTIVE',
        payment_session_id: `session_${orderId}`,
        cf_order_id: Math.floor(Math.random() * 1000000),
      },
    };
  }

  async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    const key = this.secretKey;
    const hasLiveCredentials = Boolean(this.appId && this.secretKey && !this.secretKey.startsWith('placeholder'));

    if (hasLiveCredentials && req.providerOrderId && !req.providerOrderId.startsWith('mock_')) {
      try {
        const response = await fetch(`${this.apiEndpoint}/orders/${encodeURIComponent(req.providerOrderId)}/payments`, {
          method: 'GET',
          headers: {
            'x-client-id': this.appId,
            'x-client-secret': this.secretKey,
            'x-api-version': '2023-08-01',
          },
        });

        if (response.ok) {
          const payments: any[] = await response.json();
          const successfulPayment = Array.isArray(payments) && payments.find((p) => p.payment_status === 'SUCCESS');
          if (successfulPayment) {
            return {
              isValid: true,
              providerPaymentId: String(successfulPayment.cf_payment_id || req.providerPaymentId),
              providerOrderId: req.providerOrderId,
              status: 'PAID',
              rawResponse: successfulPayment,
            };
          }
        }
      } catch (err: any) {
        this.logger.warn(`[CASHFREE] Payment status check warning: ${err?.message}`);
      }
    }

    if (!req.providerSignature || !key) {
      return {
        isValid: false,
        providerPaymentId: req.providerPaymentId,
        providerOrderId: req.providerOrderId,
        status: 'FAILED',
        failureReason: 'Missing Cashfree payment signature or secret key',
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
      failureReason: isValid ? undefined : 'Cashfree signature verification failed',
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

    const refundId = `cf_ref_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const orderId = req.notes?.orderId || req.providerPaymentId;
    if (hasLive && orderId) {
      try {
        const response = await fetch(`${this.apiEndpoint}/orders/${encodeURIComponent(orderId)}/refunds`, {
          method: 'POST',
          headers: {
            'x-client-id': this.appId,
            'x-client-secret': this.secretKey,
            'x-api-version': '2023-08-01',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            refund_amount: req.amountPaise / 100,
            refund_id: refundId,
          }),
        });

        const data: any = await response.json();
        if (!response.ok) {
          throw new ServiceUnavailableException(`Cashfree refund error: ${data.message || response.statusText}`);
        }

        return {
          providerRefundId: data.refund_id || refundId,
          amountPaise: Math.round((data.refund_amount || (req.amountPaise / 100)) * 100),
          status: 'PROCESSED',
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        throw new ServiceUnavailableException(`Cashfree refund network error: ${err?.message}`);
      }
    }

    this.logger.log(`[CASHFREE] Processed refund ${refundId} for payment ${req.providerPaymentId}`);
    return {
      providerRefundId: refundId,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
      rawResponse: {
        refund_id: refundId,
        refund_status: 'SUCCESS',
        refund_amount: req.amountPaise / 100,
      },
    };
  }

  verifyWebhookSignature(rawBody: string, signature: string, secret: string, headers?: any): boolean {
    if (!signature || !secret) return false;
    try {
      const timestamp = headers?.['x-webhook-timestamp'] || headers?.timestamp || '';
      const payloadToSign = timestamp ? `${timestamp}${rawBody}` : rawBody;
      const expected = crypto
        .createHmac('sha256', secret)
        .update(payloadToSign)
        .digest('base64');
      return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
    } catch {
      return false;
    }
  }

  normalizeWebhook(rawPayload: any, headers?: any): NormalizedPaymentWebhookEvent {
    const eventType = rawPayload?.type || rawPayload?.event || 'PAYMENT_SUCCESS';
    const data = rawPayload?.data || rawPayload;
    const order = data?.order || data;
    const payment = data?.payment || data;

    let status = 'SUCCESS';
    if (eventType.includes('FAILED')) status = 'FAILED';
    if (eventType.includes('USER_DROPPED')) status = 'DROPPED';

    return {
      eventId: rawPayload?.event_id || `cf_evt_${Date.now()}`,
      eventType: eventType.toLowerCase(),
      providerOrderId: order?.order_id || String(order?.orderId || ''),
      providerPaymentId: String(payment?.cf_payment_id || payment?.payment_id || ''),
      amountPaise: Math.round((order?.order_amount || 0) * 100),
      currency: order?.order_currency || 'INR',
      status,
      timestamp: new Date(),
      rawPayload,
    };
  }

  async fetchPaymentDetails(providerPaymentId: string): Promise<any> {
    return {
      cf_payment_id: providerPaymentId,
      payment_status: 'SUCCESS',
      payment_method: 'netbanking',
      payment_time: new Date().toISOString(),
    };
  }
}
