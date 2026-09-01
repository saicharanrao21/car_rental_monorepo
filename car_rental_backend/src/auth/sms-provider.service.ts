import { Injectable } from '@nestjs/common';
import { Msg91SmsProvider } from './msg91-sms-provider.service';

export abstract class SmsProviderService {
  abstract sendSms(
    to: string,
    message: string,
    otpCode?: string,
  ): Promise<void>;
}

import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class MockSmsProvider implements SmsProviderService {
  async sendSms(to: string, message: string, otpCode?: string): Promise<void> {
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[SMS-MOCK] Sending SMS to ${to}: ${message}`);
      if (otpCode) {
        try {
          const otpPath = path.resolve(process.cwd(), '.latest_otp.json');
          fs.writeFileSync(otpPath, JSON.stringify({ to, otpCode, time: Date.now() }));
        } catch (_) {}
      }
    }
  }
}

export { Msg91SmsProvider };
