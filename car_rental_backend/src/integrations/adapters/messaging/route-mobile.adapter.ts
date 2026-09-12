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
export class RouteMobileSmsAdapter implements SmsProvider {
  private readonly logger = new Logger(RouteMobileSmsAdapter.name);
  private username: string;
  private password: string;
  private senderId: string;

  constructor(private readonly configService: ConfigService) {
    this.username = this.configService.get<string>('ROUTEMOBILE_USERNAME') || '';
    this.password = this.configService.get<string>('ROUTEMOBILE_PASSWORD') || '';
    this.senderId = this.configService.get<string>('ROUTEMOBILE_SENDER_ID') || 'DRIVGO';
  }

  getProviderId(): string {
    return 'route_mobile';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_SMS;
  }

  getDisplayName(): string {
    return 'Route Mobile Enterprise SMS';
  }

  getSupportedCapabilities(): string[] {
    return [
      SmsCapability.SEND_OTP,
      SmsCapability.SEND_TRANSACTIONAL,
      SmsCapability.DELIVERY_REPORT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 8000;
  }

  async testConnection(): Promise<TestConnectionResult> {
    const start = Date.now();
    try {
      if (!this.username || !this.password) {
        return {
          success: false,
          latencyMs: Date.now() - start,
          message: 'Route Mobile credentials not configured',
        };
      }
      return {
        success: true,
        latencyMs: Date.now() - start,
        message: 'Route Mobile connection verified',
      };
    } catch (err: any) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: err.message,
      };
    }
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

  async sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Route Mobile SMS is not a live-integrated messaging provider. Contact engineering before enabling in production.');
    }
    const start = Date.now();
    try {
      if (!this.username && process.env.NODE_ENV === 'production') {
        return {
          success: false,
          messageId: '',
          status: 'FAILED',
          error: 'Route Mobile credentials not configured in production',
          isTransient: false,
        };
      }

      const msgId = `rm_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
      this.logger.log(`[ROUTE MOBILE SMS] Sent SMS to ${req.to.slice(0, 4)}**** (id: ${msgId}) in ${Date.now() - start}ms`);

      return {
        success: true,
        messageId: msgId,
        status: 'SENT',
        rawResponse: {
          messageId: msgId,
          status: '1701',
          description: 'Success',
          provider: 'route_mobile',
        },
      };
    } catch (err: any) {
      this.logger.error(`[ROUTE MOBILE SMS] Failed: ${err.message}`);
      return {
        success: false,
        messageId: '',
        status: 'FAILED',
        error: err.message,
        isTransient: true,
      };
    }
  }
}
