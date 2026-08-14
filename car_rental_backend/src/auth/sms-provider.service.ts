import { Injectable } from '@nestjs/common';
import { Msg91SmsProvider } from './msg91-sms-provider.service';

export abstract class SmsProviderService {
  abstract sendSms(
    to: string,
    message: string,
    otpCode?: string,
  ): Promise<void>;
}

@Injectable()
export class MockSmsProvider implements SmsProviderService {
  async sendSms(to: string, message: string, _otpCode?: string): Promise<void> {
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[SMS-MOCK] Sending SMS to ${to}: ${message}`);
    }
  }
}

export { Msg91SmsProvider };
