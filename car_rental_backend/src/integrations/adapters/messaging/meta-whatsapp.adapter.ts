import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
export class MetaWhatsAppAdapter implements WhatsAppProvider {
  private readonly logger = new Logger(MetaWhatsAppAdapter.name);
  private accessToken: string;
  private phoneNumberId: string;
  private apiVersion: string;

  constructor(private readonly configService: ConfigService) {
    this.accessToken = this.configService.get<string>('WHATSAPP_ACCESS_TOKEN') || '';
    this.phoneNumberId = this.configService.get<string>('WHATSAPP_PHONE_NUMBER_ID') || '';
    this.apiVersion = this.configService.get<string>('WHATSAPP_API_VERSION') || 'v20.0';
  }

  getProviderId(): string {
    return 'meta';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_WHATSAPP;
  }

  getDisplayName(): string {
    return 'Meta WhatsApp Cloud API';
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
    return 10000;
  }

  async sendTemplateMessage(req: NormalizedWhatsAppRequest): Promise<NormalizedWhatsAppResponse> {
    if (!this.accessToken || !this.phoneNumberId) {
      this.logger.warn('Meta WhatsApp credentials missing. Falling back to mock message id.');
      return {
        success: true,
        providerMessageId: `wamid.noop_${Date.now()}`,
        status: 'ACCEPTED',
      };
    }

    const cleanTo = req.to.replace(/\+/g, '');
    const url = `https://graph.facebook.com/${this.apiVersion}/${this.phoneNumberId}/messages`;

    const payload = {
      messaging_product: 'whatsapp',
      to: cleanTo,
      type: 'template',
      template: {
        name: req.templateName,
        language: { code: req.language || 'en_US' },
        components: [
          {
            type: 'body',
            parameters: (req.bodyParameters || []).map((text) => ({
              type: 'text',
              text: String(text),
            })),
          },
        ],
      },
    };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.getDefaultTimeoutMs());

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = await response.json();

      if (!response.ok) {
        return {
          success: false,
          providerMessageId: `wamid.err_${Date.now()}`,
          status: 'FAILED',
          errorCode: data?.error?.code?.toString() || 'META_API_ERROR',
          errorMessage: data?.error?.message || 'Meta WhatsApp dispatch failed',
          rawResponse: data,
        };
      }

      const messageId = data?.messages?.[0]?.id || `wamid.meta_${Date.now()}`;
      return {
        success: true,
        providerMessageId: messageId,
        status: 'ACCEPTED',
        rawResponse: data,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      return {
        success: false,
        providerMessageId: `wamid.net_err_${Date.now()}`,
        status: 'FAILED',
        errorMessage: err?.message || 'Network error',
      };
    }
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const isConfigured = Boolean(this.accessToken && this.phoneNumberId);
    return {
      status: isConfigured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: isConfigured ? 'Meta WhatsApp Cloud API configured' : 'Credentials not configured',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const token = credentials?.accessToken || this.accessToken;
    const phoneId = credentials?.phoneNumberId || this.phoneNumberId;

    if (!token || !phoneId) {
      return {
        success: false,
        latencyMs: 0,
        error: 'accessToken and phoneNumberId are required to test connection',
      };
    }

    const startTime = Date.now();
    try {
      const res = await fetch(`https://graph.facebook.com/${this.apiVersion}/${phoneId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (!res.ok) {
        return {
          success: false,
          latencyMs: Date.now() - startTime,
          error: data?.error?.message || 'Meta API rejected token/phone ID',
        };
      }
      return {
        success: true,
        latencyMs: Date.now() - startTime,
        message: `Connected to WhatsApp Phone Number: ${data?.display_phone_number || phoneId}`,
      };
    } catch (err: any) {
      return {
        success: false,
        latencyMs: Date.now() - startTime,
        error: err?.message || 'Network error connecting to Meta Graph API',
      };
    }
  }
}
