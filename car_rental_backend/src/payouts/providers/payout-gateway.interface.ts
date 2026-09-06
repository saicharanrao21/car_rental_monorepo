export interface PayoutTransferRequest {
  payoutId: string;
  payoutNumber: string;
  vendorId: string;
  amount: number;
  currency: string;
  accountNumber?: string;
  ifscCode?: string;
  beneficiaryName?: string;
  idempotencyKey: string;
}

export interface PayoutTransferResponse {
  success: boolean;
  status: 'QUEUED' | 'PROCESSING' | 'PAID' | 'FAILED' | 'BLOCKED_CREDENTIALS';
  providerTransferId?: string;
  providerFee?: number;
  failureReason?: string;
  rawResponse?: any;
}

export interface IPayoutGatewayProvider {
  getProviderName(): string;
  isConfigured(): boolean;
  initiateTransfer(request: PayoutTransferRequest): Promise<PayoutTransferResponse>;
}
