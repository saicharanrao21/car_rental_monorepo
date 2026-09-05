import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface SmsSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  isTransient?: boolean;
}

export abstract class SmsProvider {
  abstract sendSms(phone: string, message: string): Promise<SmsSendResult>;
}

@Injectable()
export class MockSmsProvider implements SmsProvider {
  private readonly logger = new Logger(MockSmsProvider.name);

  async sendSms(phone: string, message: string): Promise<SmsSendResult> {
    const mockId = `sms_mock_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    this.logger.log(`[SMS-MOCK] Dispatched SMS to ${phone}: "${message}" | ID: ${mockId}`);
    return {
      success: true,
      messageId: mockId,
    };
  }
}

@Injectable()
export class TwilioSmsProvider implements SmsProvider {
  private readonly logger = new Logger(TwilioSmsProvider.name);
  private readonly accountSid: string;
  private readonly authToken: string;
  private readonly fromNumber: string;

  constructor(private readonly configService: ConfigService) {
    this.accountSid = this.configService.get<string>('TWILIO_ACCOUNT_SID') || '';
    this.authToken = this.configService.get<string>('TWILIO_AUTH_TOKEN') || '';
    this.fromNumber = this.configService.get<string>('TWILIO_PHONE_NUMBER') || '';
  }

  async sendSms(phone: string, message: string): Promise<SmsSendResult> {
    if (!this.accountSid || !this.authToken || !this.fromNumber) {
      this.logger.warn('Twilio credentials missing. Falling back to MockSmsProvider behavior.');
      const fallbackId = `sms_noop_${Date.now()}`;
      return { success: true, messageId: fallbackId };
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    try {
      const url = `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`;
      const body = new URLSearchParams({
        To: phone,
        From: this.fromNumber,
        Body: message,
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
        this.logger.error(`Twilio SMS API error: ${JSON.stringify(data)}`);
        const isTransient = response.status === 429 || response.status >= 500;
        return {
          success: false,
          error: data.message || 'Twilio SMS failed',
          isTransient,
        };
      }

      return {
        success: true,
        messageId: data.sid,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      const isAbort = err?.name === 'AbortError';
      const errMsg = isAbort ? 'Twilio request timed out after 10000ms' : (err?.message || 'Twilio request failed');
      this.logger.error(`Twilio network error: ${errMsg}`, err?.stack);
      return {
        success: false,
        error: errMsg,
        isTransient: true,
      };
    }
  }
}
