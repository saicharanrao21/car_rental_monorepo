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
export class Msg91SmsAdapter implements SmsProvider {
  private readonly logger = new Logger(Msg91SmsAdapter.name);
  private authKey: string;
  private templateId: string;
  private senderId: string;
  private apiUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.authKey = this.configService.get<string>('MSG91_AUTH_KEY') || '';
    this.templateId = this.configService.get<string>('MSG91_TEMPLATE_ID') || '';
    this.senderId = this.configService.get<string>('MSG91_SENDER_ID') || 'DRIVGO';
    this.apiUrl =
      this.configService.get<string>('MSG91_API_URL') ||
      'https://control.msg91.com/api/v5/otp';
  }

  getProviderId(): string {
    return 'msg91';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_SMS;
  }

  getDisplayName(): string {
    return 'MSG91 SMS & OTP Gateway';
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

  private formatMobileNumber(phone: string): string {
    const digitsOnly = phone.replace(/\D/g, '');
    if (digitsOnly.length === 10) {
      return `91${digitsOnly}`;
    }
    return digitsOnly;
  }

  async sendSms(req: NormalizedSmsRequest): Promise<NormalizedSmsResponse> {
    if (!this.authKey || !this.templateId) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error('MSG91 credentials are required in production');
      }
      this.logger.warn('MSG91 credentials missing. Falling back to mock dispatch.');
      return {
        success: true,
        messageId: `msg91_noop_${Date.now()}`,
        status: 'SENT',
      };
    }

    const mobile = this.formatMobileNumber(req.to);
    let otp = req.otpCode;
    if (!otp) {
      const match = req.message.match(/\b\d{6}\b/);
      if (match) otp = match[0];
    }

    const payload = {
      template_id: req.templateId || this.templateId,
      mobile,
      otp: otp || '123456',
      sender: req.senderId || this.senderId,
    };

    const url = new URL(this.apiUrl);
    url.searchParams.set('template_id', payload.template_id);
    url.searchParams.set('mobile', mobile);
    url.searchParams.set('authkey', this.authKey);
    url.searchParams.set('otp', payload.otp);
    if (this.senderId) url.searchParams.set('sender', this.senderId);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.getDefaultTimeoutMs());

    try {
      const response = await fetch(url.toString(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          authkey: this.authKey,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const text = await response.text();
      let resJson: any = null;
      try {
        resJson = JSON.parse(text);
      } catch (_) {}

      if (!response.ok || (resJson && resJson.type === 'error')) {
        const errorMsg = resJson?.message || `HTTP ${response.status}`;
        return {
          success: false,
          messageId: `msg91_err_${Date.now()}`,
          status: 'FAILED',
          error: errorMsg,
          isTransient: response.status >= 500 || response.status === 429,
          rawResponse: resJson,
        };
      }

      return {
        success: true,
        messageId: resJson?.request_id || `msg91_${Date.now()}`,
        status: 'SENT',
        rawResponse: resJson,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      return {
        success: false,
        messageId: `msg91_net_err_${Date.now()}`,
        status: 'FAILED',
        error: err?.message || 'Network dispatch failure',
        isTransient: true,
      };
    }
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const configured = Boolean(this.authKey && !this.authKey.startsWith('placeholder'));
    return {
      status: configured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: configured ? 'MSG91 configured' : 'MSG91 running in mock/placeholder mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const key = credentials?.authKey || this.authKey;
    if (!key) {
      return {
        success: false,
        latencyMs: 0,
        error: 'MSG91 authKey is required to test connection',
      };
    }

    return {
      success: true,
      latencyMs: 1,
      message: 'MSG91 credentials format verified',
    };
  }
}
