import { Injectable, Logger } from '@nestjs/common';
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
export class TwilioSmsAdapter implements SmsProvider {
  private readonly logger = new Logger(TwilioSmsAdapter.name);
  private accountSid: string;
  private authToken: string;
  private fromNumber: string;

  constructor(private readonly configService: ConfigService) {
    this.accountSid = this.configService.get<string>('TWILIO_ACCOUNT_SID') || '';
    this.authToken = this.configService.get<string>('TWILIO_AUTH_TOKEN') || '';
    this.fromNumber = this.configService.get<string>('TWILIO_PHONE_NUMBER') || '';
  }

  getProviderId(): string {
    return 'twilio';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_SMS;
  }

  getDisplayName(): string {
    return 'Twilio Programmable SMS';
  }

  getSupportedCapabilities(): string[] {
    return [
      SmsCapability.SEND_TRANSACTIONAL,
      SmsCapability.SEND_OTP,
      SmsCapability.SEND_PROMOTIONAL,
      SmsCapability.DELIVERY_REPORT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 10000;
  }

  async sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse> {
    if (!this.accountSid || !this.authToken || !this.fromNumber) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error('CRITICAL SECURITY ERROR: Twilio SMS credentials missing in production.');
      }
      this.logger.warn('Twilio credentials missing. Falling back to mock response.');
      return {
        success: true,
        messageId: `twilio_noop_${Date.now()}`,
        status: 'SENT',
      };
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.getDefaultTimeoutMs());

    try {
      const url = `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`;
      const body = new URLSearchParams({
        To: req.to,
        From: this.fromNumber,
        Body: req.message,
      });

      const auth = Buffer.from(`${this.accountSid}:${this.authToken}`).toString('base64');
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = await response.json();

      if (!response.ok) {
        return {
          success: false,
          messageId: `twilio_err_${Date.now()}`,
          status: 'FAILED',
          error: data?.message || 'Twilio SMS failed',
          isTransient: response.status === 429 || response.status >= 500,
          rawResponse: data,
        };
      }

      return {
        success: true,
        messageId: data.sid,
        status: 'SENT',
        rawResponse: data,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      return {
        success: false,
        messageId: `twilio_net_err_${Date.now()}`,
        status: 'FAILED',
        error: err?.message || 'Twilio request failed',
        isTransient: true,
      };
    }
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const configured = Boolean(this.accountSid && this.authToken);
    return {
      status: configured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: configured ? 'Twilio configured' : 'Twilio running in mock/unconfigured mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const sid = credentials?.accountSid || this.accountSid;
    const token = credentials?.authToken || this.authToken;

    if (!sid || !token) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Twilio accountSid and authToken required',
      };
    }

    const startTime = Date.now();
    try {
      const auth = Buffer.from(`${sid}:${token}`).toString('base64');
      const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}.json`, {
        headers: { Authorization: `Basic ${auth}` },
      });
      const data = await res.json();
      if (!res.ok) {
        return {
          success: false,
          latencyMs: Date.now() - startTime,
          error: data?.message || 'Twilio authentication failed',
        };
      }
      return {
        success: true,
        latencyMs: Date.now() - startTime,
        message: `Connected to Twilio Account: ${data?.friendly_name || sid}`,
      };
    } catch (err: any) {
      return {
        success: false,
        latencyMs: Date.now() - startTime,
        error: err?.message || 'Network error connecting to Twilio',
      };
    }
  }
}
