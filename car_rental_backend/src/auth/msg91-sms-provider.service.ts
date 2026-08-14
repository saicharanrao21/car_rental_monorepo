import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SmsProviderService } from './sms-provider.service';

@Injectable()
export class Msg91SmsProvider implements SmsProviderService {
  private readonly logger = new Logger(Msg91SmsProvider.name);
  private readonly authKey: string;
  private readonly templateId: string;
  private readonly senderId: string;
  private readonly apiUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.authKey = this.configService.get<string>('MSG91_AUTH_KEY') || '';
    this.templateId = this.configService.get<string>('MSG91_TEMPLATE_ID') || '';
    this.senderId =
      this.configService.get<string>('MSG91_SENDER_ID') || 'DRIVGO';
    this.apiUrl =
      this.configService.get<string>('MSG91_API_URL') ||
      'https://control.msg91.com/api/v5/otp';

    const isProduction =
      this.configService.get<string>('NODE_ENV') === 'production';
    if (isProduction && (!this.authKey || !this.templateId)) {
      throw new Error(
        'CRITICAL CONFIGURATION ERROR: MSG91_AUTH_KEY and MSG91_TEMPLATE_ID are required when using Msg91SmsProvider in production.',
      );
    }
  }

  /**
   * Normalizes mobile numbers for MSG91 by ensuring a country code prefix (defaults to 91 for Indian 10-digit numbers).
   */
  private formatMobileNumber(phone: string): string {
    // Strip non-digit characters
    const digitsOnly = phone.replace(/\D/g, '');

    // If standard 10-digit Indian mobile number, prefix with 91
    if (digitsOnly.length === 10) {
      return `91${digitsOnly}`;
    }

    return digitsOnly;
  }

  /**
   * Sends an OTP via the MSG91 Send OTP REST API.
   */
  async sendSms(to: string, message: string, otpCode?: string): Promise<void> {
    const mobile = this.formatMobileNumber(to);

    // Extract OTP if not explicitly passed
    let otp = otpCode;
    if (!otp) {
      const match = message.match(/\b\d{6}\b/);
      if (match) {
        otp = match[0];
      }
    }

    if (!otp) {
      throw new Error(
        'Cannot dispatch SMS OTP: OTP code is missing or unparseable.',
      );
    }

    const payload = {
      template_id: this.templateId,
      mobile,
      otp,
      sender: this.senderId,
    };

    const url = new URL(this.apiUrl);
    url.searchParams.set('template_id', this.templateId);
    url.searchParams.set('mobile', mobile);
    url.searchParams.set('authkey', this.authKey);
    url.searchParams.set('otp', otp);
    if (this.senderId) {
      url.searchParams.set('sender', this.senderId);
    }

    try {
      const response = await fetch(url.toString(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          authkey: this.authKey,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(8000), // 8 seconds timeout
      });

      const responseText = await response.text();
      let responseJson: any = null;
      try {
        responseJson = JSON.parse(responseText);
      } catch {
        // Response was not JSON
      }

      if (!response.ok) {
        this.logger.error(
          `MSG91 API error: HTTP status ${response.status} returned for mobile ${mobile.slice(-4).padStart(mobile.length, '*')}`,
        );
        throw new Error(`MSG91 gateway responded with HTTP ${response.status}`);
      }

      // Check MSG91 JSON response type
      if (responseJson && responseJson.type === 'error') {
        const errorMsg = responseJson.message || 'Unknown provider error';
        this.logger.error(
          `MSG91 delivery failure for mobile ${mobile.slice(-4).padStart(mobile.length, '*')}: ${errorMsg}`,
        );
        throw new Error(`MSG91 gateway rejected dispatch: ${errorMsg}`);
      }

      this.logger.log(
        `MSG91 OTP successfully dispatched to mobile ${mobile.slice(-4).padStart(mobile.length, '*')}`,
      );
    } catch (err: any) {
      if (err.name === 'TimeoutError' || err.name === 'AbortError') {
        this.logger.error('MSG91 API request timed out after 8 seconds');
        throw new Error('SMS Gateway request timed out. Please try again.');
      }

      // Re-throw gateway errors without exposing authKey or credentials
      if (err.message && !err.message.includes('MSG91')) {
        this.logger.error(`SMS network dispatch failure: ${err.message}`);
        throw new Error(
          'SMS Gateway network dispatch failure. Please try again.',
        );
      }

      throw err;
    }
  }
}
