import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface EmailSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  isTransient?: boolean;
}

export abstract class EmailProvider {
  abstract sendEmail(to: string, subject: string, html: string): Promise<EmailSendResult>;
}

@Injectable()
export class MockEmailProvider implements EmailProvider {
  private readonly logger = new Logger(MockEmailProvider.name);

  async sendEmail(to: string, subject: string, html: string): Promise<EmailSendResult> {
    const mockId = `email_mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(`[EMAIL-MOCK] Dispatched Email to ${to} | Subject: "${subject}" | ID: ${mockId}`);
    return {
      success: true,
      messageId: mockId,
    };
  }
}

@Injectable()
export class SmtpEmailProvider implements EmailProvider {
  private readonly logger = new Logger(SmtpEmailProvider.name);
  private readonly apiKey: string;
  private readonly fromEmail: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('RESEND_API_KEY') || this.configService.get<string>('SENDGRID_API_KEY') || '';
    this.fromEmail = this.configService.get<string>('EMAIL_FROM') || 'notifications@drivego.in';
  }

  async sendEmail(to: string, subject: string, html: string): Promise<EmailSendResult> {
    if (!this.apiKey) {
      this.logger.warn('Email provider API key missing. Falling back to MockEmailProvider behavior.');
      const fallbackId = `email_noop_${Date.now()}`;
      return { success: true, messageId: fallbackId };
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: this.fromEmail,
          to,
          subject,
          html,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = await response.json();

      if (!response.ok) {
        this.logger.error(`Resend API error: ${JSON.stringify(data)}`);
        const isTransient = response.status === 429 || response.status >= 500;
        return {
          success: false,
          error: data.message || 'Email dispatch failed',
          isTransient,
        };
      }

      return {
        success: true,
        messageId: data.id,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      const isAbort = err?.name === 'AbortError';
      const errMsg = isAbort ? 'Email request timed out after 10000ms' : (err?.message || 'Email request failed');
      this.logger.error(`Email dispatch error: ${errMsg}`, err?.stack);
      return {
        success: false,
        error: errMsg,
        isTransient: true,
      };
    }
  }
}
