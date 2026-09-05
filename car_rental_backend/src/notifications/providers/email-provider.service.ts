import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface EmailSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
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

    try {
      // Direct REST call to Resend email API if configured
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
      });

      const data = await response.json();

      if (!response.ok) {
        this.logger.error(`Resend API error: ${JSON.stringify(data)}`);
        return {
          success: false,
          error: data.message || 'Email dispatch failed',
        };
      }

      return {
        success: true,
        messageId: data.id,
      };
    } catch (err: any) {
      this.logger.error(`Email dispatch error: ${err?.message}`, err?.stack);
      return {
        success: false,
        error: err?.message || 'Email request failed',
      };
    }
  }
}
