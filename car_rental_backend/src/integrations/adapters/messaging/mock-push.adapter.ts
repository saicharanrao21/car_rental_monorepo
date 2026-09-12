import { Injectable, Logger } from '@nestjs/common';
import {
  PushProvider,
  PushCapability,
  NormalizedPushRequest,
  NormalizedPushResponse,
} from '../../contracts/messaging-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockPushAdapter implements PushProvider {
  private readonly logger = new Logger(MockPushAdapter.name);

  getProviderId(): string {
    return 'mock_push';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_PUSH;
  }

  getDisplayName(): string {
    return 'Mock Push Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      PushCapability.SEND_UNICAST,
      PushCapability.SEND_MULTICAST,
      PushCapability.DATA_PAYLOAD,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 3000;
  }

  async sendPush(req: NormalizedPushRequest): Promise<NormalizedPushResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockPushAdapter cannot be used in production.');
    }
    this.logger.log(`[PUSH_MOCK] Dispatched mock push to ${req.deviceTokens.length} devices: "${req.title}"`);
    return {
      success: true,
      successCount: req.deviceTokens.length,
      failureCount: 0,
      messageId: `mock_push_${Date.now()}`,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    if (process.env.NODE_ENV === 'production') {
      return {
        status: ProviderHealthStatus.UNAVAILABLE,
        latencyMs: 0,
        message: 'CRITICAL: Mock Push provider cannot be used in production.',
        lastChecked: new Date(),
      };
    }
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Push Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    if (process.env.NODE_ENV === 'production') {
      return {
        success: false,
        latencyMs: 0,
        message: 'Mock Push cannot be tested or used in production.',
      };
    }
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock Push connection successful',
    };
  }
}
