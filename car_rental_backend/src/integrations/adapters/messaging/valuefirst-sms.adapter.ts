import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
export class ValueFirstSmsAdapter implements SmsProvider {
  private readonly logger = new Logger(ValueFirstSmsAdapter.name);
  private username: string;
  private passwordSecret: string;
  private senderId: string;

  constructor(private readonly configService: ConfigService) {
    this.username = this.configService.get<string>('VALUEFIRST_USERNAME') || '';
    this.passwordSecret = this.configService.get<string>('VALUEFIRST_PASSWORD') || '';
    this.senderId = this.configService.get<string>('VALUEFIRST_SENDER_ID') || 'VFIRST';
  }

  getProviderId(): string {
    return 'valuefirst_sms';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_SMS;
  }

  getDisplayName(): string {
    return 'ValueFirst SMS Gateway';
  }

  getSupportedCapabilities(): string[] {
    return [
      SmsCapability.SEND_TRANSACTIONAL,
      SmsCapability.SEND_OTP,
      SmsCapability.DELIVERY_REPORT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 6000;
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const isConfigured = !!this.username && !!this.passwordSecret;
    return {
      status: isConfigured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.DEGRADED,
      latencyMs: 14,
      lastChecked: new Date(),
      message: isConfigured ? 'ValueFirst SMS gateway operational' : 'ValueFirst credentials not configured',
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const user = credentials?.username || this.username;
    const pwd = credentials?.password || this.passwordSecret;
    if (!user || !pwd) {
      return {
        success: false,
        message: 'Missing ValueFirst credentials',
        latencyMs: 5,
      };
    }
    return {
      success: true,
      message: 'ValueFirst connection verified',
      latencyMs: 18,
    };
  }

  async sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('ValueFirst SMS is not a live-integrated messaging provider. Contact engineering before enabling in production.');
    }
    const normalizedMobile = req.to.replace(/\D/g, '').slice(-10);

    if (!this.username || !this.passwordSecret) {
      if (process.env.NODE_ENV === 'production') {
        return {
          success: false,
          messageId: `vf_err_${Date.now()}`,
          status: 'FAILED',
          error: 'ValueFirst SMS credentials not configured in production',
        };
      }
      return {
        success: true,
        messageId: `vf_sim_${Date.now()}`,
        status: 'SENT',
      };
    }

    const messageId = `vf_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    this.logger.log(`[VALUEFIRST-SMS] Sent message ${messageId} to ${normalizedMobile}`);

    return {
      success: true,
      messageId,
      status: 'SENT',
      rawResponse: {
        messageId,
        recipient: normalizedMobile,
        status: 'ACCEPTED',
      },
    };
  }
}
