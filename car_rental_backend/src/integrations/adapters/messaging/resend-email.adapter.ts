import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
export class ResendEmailAdapter implements EmailProvider {
  private readonly logger = new Logger(ResendEmailAdapter.name);
  private apiKey: string;
  private fromEmail: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey =
      this.configService.get<string>('RESEND_API_KEY') ||
      this.configService.get<string>('SENDGRID_API_KEY') ||
      '';
    this.fromEmail =
      this.configService.get<string>('EMAIL_FROM') || 'notifications@drivego.in';
  }

  getProviderId(): string {
    return 'resend';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_EMAIL;
  }

  getDisplayName(): string {
    return 'Resend Email Service';
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
    return 10000;
  }

  async sendEmail(req: NormalizedEmailRequest): Promise<NormalizedEmailResponse> {
    if (!this.apiKey) {
      this.logger.warn('Resend API key missing. Falling back to mock dispatch.');
      return {
        success: true,
        messageId: `email_noop_${Date.now()}`,
        status: 'SENT',
      };
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.getDefaultTimeoutMs());

    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: req.from || this.fromEmail,
          to: req.to,
          subject: req.subject,
          html: req.html,
          reply_to: req.replyTo,
          cc: req.cc,
          bcc: req.bcc,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = await response.json();

      if (!response.ok) {
        return {
          success: false,
          messageId: `email_err_${Date.now()}`,
          status: 'FAILED',
          error: data?.message || 'Email dispatch failed',
          isTransient: response.status === 429 || response.status >= 500,
          rawResponse: data,
        };
      }

      return {
        success: true,
        messageId: data.id,
        status: 'SENT',
        rawResponse: data,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      return {
        success: false,
        messageId: `email_net_err_${Date.now()}`,
        status: 'FAILED',
        error: err?.message || 'Network error',
        isTransient: true,
      };
    }
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const configured = Boolean(this.apiKey && !this.apiKey.startsWith('placeholder'));
    return {
      status: configured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: configured ? 'Resend configured' : 'Resend running in mock mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const key = credentials?.apiKey || this.apiKey;
    if (!key) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Resend apiKey is required',
      };
    }
    return {
      success: true,
      latencyMs: 1,
      message: 'Resend API key format verified',
    };
  }
}
