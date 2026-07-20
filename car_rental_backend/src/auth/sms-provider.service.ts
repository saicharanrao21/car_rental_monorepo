import { Injectable } from '@nestjs/common';

export abstract class SmsProviderService {
  abstract sendSms(to: string, message: string): Promise<void>;
}

@Injectable()
export class MockSmsProvider implements SmsProviderService {
  async sendSms(to: string, message: string): Promise<void> {
    // PRODUCTION INTEGRATION POINT:
    // To send real SMS via 2Factor, MSG91, Twilio, or another provider:
    // 1. Install Axios/HttpModule: `npm i @nestjs/axios`
    // 2. Import HttpService and inject it into constructor
    // 3. Make HTTP request to your provider api, e.g.:
    //    await this.httpService.axiosRef.post('https://api.msg91.com/otp', { to, message });
    // 4. Swap this provider in auth.module.ts imports/providers declarations.
    
    console.log(`[SMS-MOCK] Sending SMS to ${to}: ${message}`);
  }
}
