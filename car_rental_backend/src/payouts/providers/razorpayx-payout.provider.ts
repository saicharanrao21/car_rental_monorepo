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
  private readonly apiUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.keyId = this.configService.get<string>('RAZORPAYX_KEY_ID');
    this.keySecret = this.configService.get<string>('RAZORPAYX_KEY_SECRET');
    this.accountNumber = this.configService.get<string>('RAZORPAYX_ACCOUNT_NUMBER');
    this.apiUrl =
      this.configService.get<string>('RAZORPAYX_API_URL') ||
      'https://api.razorpay.com/v1/payouts';
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

    if (!request.accountNumber || !request.ifscCode) {
      this.logger.warn(
        `[RAZORPAYX_PAYOUT_ERROR] Missing beneficiary account number or IFSC code for payout #${request.payoutNumber}.`,
      );
      return {
        success: false,
        status: 'FAILED',
        failureReason:
          'Beneficiary bank account details missing: both account number and IFSC code are required.',
      };
    }

    const beneficiaryName =
      request.beneficiaryName?.trim() || `Vendor-${request.vendorId.substring(0, 8)}`;
    const amountInPaise = Math.round(request.amount * 100);

    const payload = {
      account_number: this.accountNumber,
      fund_account: {
        account_type: 'bank_account',
        bank_account: {
          name: beneficiaryName,
          ifsc: request.ifscCode.toUpperCase().trim(),
          account_number: request.accountNumber.trim(),
        },
        contact: {
          name: beneficiaryName,
          type: 'vendor',
          reference_id: request.vendorId,
        },
      },
      amount: amountInPaise,
      currency: request.currency || 'INR',
      mode: 'NEFT',
      purpose: 'payout',
      queue_if_low_balance: true,
      reference_id: request.payoutNumber,
      narration: 'DriveGo Vendor Payout',
    };

    const authHeader = `Basic ${Buffer.from(
      `${this.keyId}:${this.keySecret}`,
    ).toString('base64')}`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    try {
      this.logger.log(
        `[RAZORPAYX_DISPATCH] Dispatching payout #${request.payoutNumber} for amount ₹${request.amount} to IFSC ${request.ifscCode.substring(0, 4)}****`,
      );

      const response = await fetch(this.apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: authHeader,
          'X-Payout-Idempotency': request.idempotencyKey,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeout);

      const data = await response.json().catch(() => null);

      if (!response.ok) {
        const errorMessage =
          data?.error?.description ||
          data?.error?.reason ||
          `RazorpayX HTTP ${response.status} error`;

        this.logger.error(
          `[RAZORPAYX_ERROR] Payout #${request.payoutNumber} failed with status ${response.status}: ${errorMessage}`,
        );

        return {
          success: false,
          status: 'FAILED',
          failureReason: errorMessage,
          rawResponse: data,
        };
      }

      if (!data || !data.id) {
        return {
          success: false,
          status: 'FAILED',
          failureReason: 'Invalid response from RazorpayX: Missing payout ID.',
          rawResponse: data,
        };
      }

      const providerTransferId = data.id;
      const providerFee = data.fees ? data.fees / 100 : undefined;
      const rzpxStatus = (data.status || '').toLowerCase();

      this.logger.log(
        `[RAZORPAYX_RESPONSE] Payout #${request.payoutNumber} responded with ID ${providerTransferId}, status: ${rzpxStatus}`,
      );

      if (rzpxStatus === 'processed') {
        return {
          success: true,
          status: 'PAID',
          providerTransferId,
          providerFee,
          rawResponse: data,
        };
      }

      if (
        rzpxStatus === 'processing' ||
        rzpxStatus === 'queued' ||
        rzpxStatus === 'pending'
      ) {
        return {
          success: true,
          status: 'PROCESSING',
          providerTransferId,
          providerFee,
          rawResponse: data,
        };
      }

      if (rzpxStatus === 'rejected' || rzpxStatus === 'cancelled') {
        return {
          success: false,
          status: 'FAILED',
          providerTransferId,
          failureReason:
            data.failure_reason || `Payout was ${rzpxStatus} by RazorpayX.`,
          rawResponse: data,
        };
      }

      if (rzpxStatus === 'reversed') {
        return {
          success: false,
          status: 'FAILED',
          providerTransferId,
          failureReason: 'Payout reversed by banking network.',
          rawResponse: data,
        };
      }

      // Default for unknown status
      return {
        success: true,
        status: 'PROCESSING',
        providerTransferId,
        providerFee,
        rawResponse: data,
      };
    } catch (err: any) {
      clearTimeout(timeout);
      const isAbort = err.name === 'AbortError';
      const failureReason = isAbort
        ? 'RazorpayX gateway API request timed out after 15s'
        : err.message || 'RazorpayX gateway communication error';

      this.logger.error(
        `[RAZORPAYX_NETWORK_ERROR] Payout #${request.payoutNumber} exception: ${failureReason}`,
      );

      return {
        success: false,
        status: 'FAILED',
        failureReason,
      };
    }
  }
}
