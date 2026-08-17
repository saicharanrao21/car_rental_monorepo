import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WhatsAppProviderSendResult } from './whatsapp.types';

export abstract class WhatsAppProvider {
  abstract sendMessage(
    to: string,
    templateName: string,
    language: string,
    bodyParameters: string[],
  ): Promise<WhatsAppProviderSendResult>;
}

@Injectable()
export class MockWhatsAppProvider implements WhatsAppProvider {
  private readonly logger = new Logger(MockWhatsAppProvider.name);

  async sendMessage(
    to: string,
    templateName: string,
    language: string,
    bodyParameters: string[],
  ): Promise<WhatsAppProviderSendResult> {
    const mockMessageId = `wamid.mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(
      `[WHATSAPP-MOCK] Sent template "${templateName}" (${language}) to ${to} with params [${bodyParameters.join(', ')}]. ID: ${mockMessageId}`,
    );

    return {
      providerMessageId: mockMessageId,
      status: 'ACCEPTED',
    };
  }
}

@Injectable()
export class MetaWhatsAppProvider implements WhatsAppProvider {
  private readonly logger = new Logger(MetaWhatsAppProvider.name);
  private readonly accessToken: string;
  private readonly phoneNumberId: string;
  private readonly apiVersion: string;

  constructor(private readonly configService: ConfigService) {
    this.accessToken = this.configService.get<string>('WHATSAPP_ACCESS_TOKEN') || '';
    this.phoneNumberId = this.configService.get<string>('WHATSAPP_PHONE_NUMBER_ID') || '';
    this.apiVersion = this.configService.get<string>('WHATSAPP_API_VERSION') || 'v20.0';
  }

  async sendMessage(
    to: string,
    templateName: string,
    language: string,
    bodyParameters: string[],
  ): Promise<WhatsAppProviderSendResult> {
    if (!this.accessToken || !this.phoneNumberId) {
      this.logger.warn('WhatsApp credentials missing. Falling back to mock response.');
      return {
        providerMessageId: `wamid.noop_${Date.now()}`,
        status: 'ACCEPTED',
      };
    }

    const cleanTo = to.replace(/\+/g, '');
    const url = `https://graph.facebook.com/${this.apiVersion}/${this.phoneNumberId}/messages`;

    const payload = {
      messaging_product: 'whatsapp',
      to: cleanTo,
      type: 'template',
      template: {
        name: templateName,
        language: { code: language },
        components: [
          {
            type: 'body',
            parameters: bodyParameters.map((text) => ({
              type: 'text',
              text: String(text),
            })),
          },
        ],
      },
    };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();

      if (!response.ok) {
        this.logger.error(`Meta WhatsApp API error: ${JSON.stringify(data)}`);
        return {
          providerMessageId: `wamid.err_${Date.now()}`,
          status: 'FAILED',
          errorCode: data?.error?.code?.toString() || 'META_API_ERROR',
          errorMessage: data?.error?.message || 'Failed to dispatch WhatsApp message',
        };
      }

      const messageId = data?.messages?.[0]?.id || `wamid.meta_${Date.now()}`;
      return {
        providerMessageId: messageId,
        status: 'ACCEPTED',
      };
    } catch (err: any) {
      this.logger.error(`Meta WhatsApp HTTP request failed: ${err.message}`, err.stack);
      return {
        providerMessageId: `wamid.net_err_${Date.now()}`,
        status: 'FAILED',
        errorCode: 'NETWORK_ERROR',
        errorMessage: err.message,
      };
    }
  }
}
