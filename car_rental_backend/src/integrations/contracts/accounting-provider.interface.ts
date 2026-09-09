import { BaseProvider } from './provider.interface';

export enum AccountingCapability {
  SYNC_INVOICE = 'SYNC_INVOICE',
  SYNC_CREDIT_NOTE = 'SYNC_CREDIT_NOTE',
  SYNC_PAYOUT = 'SYNC_PAYOUT',
  RECONCILE_ACCOUNTS = 'RECONCILE_ACCOUNTS',
}

export interface AccountingInvoiceItem {
  description: string;
  amount: number;
  taxRatePercent: number;
}

export interface NormalizedAccountingInvoice {
  invoiceNumber: string;
  bookingId: string;
  customerName: string;
  customerGstin?: string;
  totalAmount: number;
  items: AccountingInvoiceItem[];
  issuedAt: Date;
}

export interface NormalizedAccountingPayout {
  payoutId: string;
  vendorId: string;
  vendorName: string;
  amount: number;
  reference: string;
  processedAt: Date;
}

export interface AccountingProvider extends BaseProvider {
  syncInvoice(invoice: NormalizedAccountingInvoice): Promise<{ success: boolean; externalId?: string }>;
  syncPayout(payout: NormalizedAccountingPayout): Promise<{ success: boolean; externalId?: string }>;
}
