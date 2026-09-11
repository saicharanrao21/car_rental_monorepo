import { Injectable } from '@nestjs/common';
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
export class MockPaymentAdapter implements PaymentProvider {
  getProviderId(): string {
    return 'mock_payment';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }

  getDisplayName(): string {
    return 'Mock Payment Provider (Dev & Testing)';
  }

  getSupportedCapabilities(): string[] {
    return [
      PaymentCapability.CREATE_ORDER,
      PaymentCapability.VERIFY_PAYMENT,
      PaymentCapability.REFUND_PAYMENT,
      PaymentCapability.WEBHOOK_HANDLING,
      PaymentCapability.SPLIT_PAYMENT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 5000;
  }

  async createOrder(req: NormalizedPaymentOrderRequest): Promise<NormalizedPaymentOrderResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockPaymentAdapter cannot be used in production.');
    }
    const orderId = `order_mock_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    return {
      providerOrderId: orderId,
      amountPaise: req.amountPaise,
      currency: req.currency || 'INR',
      providerKeyId: 'rzp_test_mock',
      status: 'created',
    };
  }

  async verifyPayment(req: NormalizedPaymentVerifyRequest): Promise<NormalizedPaymentVerifyResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockPaymentAdapter cannot verify payments in production.');
    }
    const isValid = req.providerSignature === 'mock_signature' || req.providerSignature.length > 0;
    return {
      isValid,
      providerPaymentId: req.providerPaymentId || `pay_mock_${Date.now()}`,
      providerOrderId: req.providerOrderId,
      status: isValid ? 'PAID' : 'FAILED',
    };
  }

  async refund(req: NormalizedRefundRequest): Promise<NormalizedRefundResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockPaymentAdapter cannot process refunds in production.');
    }
    return {
      providerRefundId: `rfnd_mock_${Date.now()}`,
      amountPaise: req.amountPaise,
      status: 'PROCESSED',
    };
  }

  verifyWebhookSignature(): boolean {
    if (process.env.NODE_ENV === 'production') {
      return false;
    }
    return true;
  }

  normalizeWebhook(rawPayload: any): NormalizedPaymentWebhookEvent {
    return {
      eventId: `mock_evt_${Date.now()}`,
      eventType: rawPayload?.event || 'payment.captured',
      providerPaymentId: rawPayload?.payment_id || `pay_mock_${Date.now()}`,
      providerOrderId: rawPayload?.order_id || `order_mock_${Date.now()}`,
      amountPaise: rawPayload?.amount || 100000,
      currency: 'INR',
      status: 'CAPTURED',
      timestamp: new Date(),
      rawPayload,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Payment Provider is always healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock payment test connection successful',
    };
  }
}
