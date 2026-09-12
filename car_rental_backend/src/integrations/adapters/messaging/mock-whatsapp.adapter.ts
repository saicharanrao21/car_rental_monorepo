import { Injectable, Logger } from '@nestjs/common';
import {
  WhatsAppProvider,
  WhatsAppCapability,
  NormalizedWhatsAppRequest,
  NormalizedWhatsAppResponse,
} from '../../contracts/messaging-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockWhatsAppAdapter implements WhatsAppProvider {
  private readonly logger = new Logger(MockWhatsAppAdapter.name);

  getProviderId(): string {
    return 'mock_whatsapp';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_WHATSAPP;
  }

  getDisplayName(): string {
    return 'Mock WhatsApp Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      WhatsAppCapability.SEND_TEMPLATE,
      WhatsAppCapability.SEND_TEXT,
      WhatsAppCapability.WEBHOOK_DELIVERY_STATUS,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 5000;
  }

  async sendTemplateMessage(req: NormalizedWhatsAppRequest): Promise<NormalizedWhatsAppResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockWhatsAppAdapter cannot be used in production.');
    }
    const mockId = `wamid.mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(`[WHATSAPP_MOCK] Dispatched template "${req.templateName}" to ${req.to} | ID: ${mockId}`);
    return {
      success: true,
      providerMessageId: mockId,
      status: 'ACCEPTED',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    if (process.env.NODE_ENV === 'production') {
      return {
        status: ProviderHealthStatus.UNAVAILABLE,
        latencyMs: 0,
        message: 'CRITICAL: Mock WhatsApp provider cannot be used in production.',
        lastChecked: new Date(),
      };
    }
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock WhatsApp Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    if (process.env.NODE_ENV === 'production') {
      return {
        success: false,
        latencyMs: 0,
        message: 'Mock WhatsApp cannot be tested or used in production.',
      };
    }
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock WhatsApp connection successful',
    };
  }
}
