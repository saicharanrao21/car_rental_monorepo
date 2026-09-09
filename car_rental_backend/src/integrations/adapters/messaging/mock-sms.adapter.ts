import { Injectable, Logger } from '@nestjs/common';
import {
  SmsProvider,
  SmsCapability,
  NormalizedSmsRequest,
  NormalizedSmsResponse,
} from '../../contracts/messaging-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockSmsAdapter implements SmsProvider {
  private readonly logger = new Logger(MockSmsAdapter.name);

  getProviderId(): string {
    return 'mock_sms';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_SMS;
  }

  getDisplayName(): string {
    return 'Mock SMS Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      SmsCapability.SEND_OTP,
      SmsCapability.SEND_TRANSACTIONAL,
      SmsCapability.SEND_PROMOTIONAL,
      SmsCapability.DELIVERY_REPORT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 3000;
  }

  async sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse> {
    const mockId = `sms_mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(`[SMS_MOCK] Sent SMS to ${req.to}: "${req.message}" | ID: ${mockId}`);
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
      message: 'Mock SMS Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock SMS connection test successful',
    };
  }
}
