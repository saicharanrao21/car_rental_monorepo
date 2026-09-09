import { Injectable, Logger } from '@nestjs/common';
import {
  EmailProvider,
  EmailCapability,
  NormalizedEmailRequest,
  NormalizedEmailResponse,
} from '../../contracts/messaging-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockEmailAdapter implements EmailProvider {
  private readonly logger = new Logger(MockEmailAdapter.name);

  getProviderId(): string {
    return 'mock_email';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_EMAIL;
  }

  getDisplayName(): string {
    return 'Mock Email Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      EmailCapability.SEND_TRANSACTIONAL,
      EmailCapability.SEND_HTML,
      EmailCapability.SEND_ATTACHMENT,
      EmailCapability.SEND_TEMPLATE,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 3000;
  }

  async sendEmail(req: NormalizedEmailRequest): Promise<NormalizedEmailResponse> {
    const mockId = `email_mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(`[EMAIL_MOCK] Dispatched email to ${req.to} | Subject: "${req.subject}" | ID: ${mockId}`);
    return {
      success: true,
      messageId: mockId,
      status: 'SENT',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Email Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock Email connection test successful',
    };
  }
}
