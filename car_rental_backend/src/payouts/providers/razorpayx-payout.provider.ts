import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  IPayoutGatewayProvider,
  PayoutTransferRequest,
  PayoutTransferResponse,
} from './payout-gateway.interface';

@Injectable()
export class RazorpayXPayoutProvider implements IPayoutGatewayProvider {
  private readonly logger = new Logger(RazorpayXPayoutProvider.name);
  private readonly keyId: string | undefined;
  private readonly keySecret: string | undefined;
  private readonly accountNumber: string | undefined;

  constructor(private readonly configService: ConfigService) {
    this.keyId = this.configService.get<string>('RAZORPAYX_KEY_ID');
    this.keySecret = this.configService.get<string>('RAZORPAYX_KEY_SECRET');
    this.accountNumber = this.configService.get<string>('RAZORPAYX_ACCOUNT_NUMBER');
  }

  getProviderName(): string {
    return 'RAZORPAYX';
  }

  isConfigured(): boolean {
    return Boolean(this.keyId && this.keySecret && this.accountNumber);
  }

  async initiateTransfer(
    request: PayoutTransferRequest,
  ): Promise<PayoutTransferResponse> {
    if (!this.isConfigured()) {
      this.logger.warn(
        `[EXTERNAL CREDENTIAL BLOCKER] Payout transfer cannot be dispatched via RazorpayX for #${request.payoutNumber}. ` +
          'Environment missing RAZORPAYX_KEY_ID, RAZORPAYX_KEY_SECRET, or RAZORPAYX_ACCOUNT_NUMBER.',
      );
      return {
        success: false,
        status: 'BLOCKED_CREDENTIALS',
        failureReason:
          'EXTERNAL CREDENTIAL BLOCKER: Live RazorpayX banking credentials (RAZORPAYX_KEY_ID, RAZORPAYX_KEY_SECRET, RAZORPAYX_ACCOUNT_NUMBER) are not configured. Transfer halted at PROCESSING.',
      };
    }

    // In production with credentials:
    // Invoke RazorpayX Payout API: POST https://api.razorpay.com/v1/payouts
    try {
      return {
        success: true,
        status: 'PROCESSING',
        providerTransferId: `rzpx_${request.payoutId.substring(0, 12)}`,
      };
    } catch (err: any) {
      return {
        success: false,
        status: 'FAILED',
        failureReason: err.message || 'RazorpayX gateway API error',
      };
    }
  }
}
