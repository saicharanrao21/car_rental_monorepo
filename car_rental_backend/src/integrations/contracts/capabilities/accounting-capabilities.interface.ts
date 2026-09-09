export enum AccountingCapability {
  CREATE_INVOICE = 'CREATE_INVOICE',
  UPDATE_INVOICE = 'UPDATE_INVOICE',
  CANCEL_INVOICE = 'CANCEL_INVOICE',
  SYNC_CUSTOMER = 'SYNC_CUSTOMER',
  SYNC_PAYMENT = 'SYNC_PAYMENT',
  SYNC_EXPENSE = 'SYNC_EXPENSE',
  RECONCILE = 'RECONCILE',
  TAX_CALCULATION = 'TAX_CALCULATION',
  EXPORT_LEDGER = 'EXPORT_LEDGER',
}

export interface InvoiceLineItem {
  name: string;
  description?: string;
  rate: number;
  quantity: number;
  taxRatePercent: number;
  taxAmount: number;
  totalAmount: number;
}

export interface InvoicePayload {
  customerId: string;
  customerName: string;
  customerEmail: string;
  customerPhone?: string;
  customerGstin?: string;
  invoiceNumber?: string;
  bookingId: string;
  date: string;
  dueDate: string;
  currency: string;
  lineItems: InvoiceLineItem[];
  subtotal: number;
  taxTotal: number;
  discountTotal?: number;
  grandTotal: number;
}

export interface SyncCustomerPayload {
  customerId: string;
  name: string;
  email: string;
  phone?: string;
  gstin?: string;
  billingAddress?: {
    address: string;
    city: string;
    state: string;
    zip: string;
    country: string;
  };
}

export interface SyncPaymentPayload {
  invoiceId: string;
  amount: number;
  paymentMode: 'UPI' | 'CARD' | 'NET_BANKING' | 'WALLET' | 'CASH';
  referenceNumber: string;
  paymentDate: string;
}

export interface TaxCalculationPayload {
  amount: number;
  sourceStateCode: string;
  destinationStateCode: string;
  hsnSacCode?: string;
}

export interface TaxCalculationResult {
  cgstRate: number;
  cgstAmount: number;
  sgstRate: number;
  sgstAmount: number;
  igstRate: number;
  igstAmount: number;
  totalTax: number;
  isInterstate: boolean;
}

export interface AccountingResult {
  success: boolean;
  externalId: string;
  invoiceNumber?: string;
  status: 'DRAFT' | 'SENT' | 'PAID' | 'VOID' | 'SYNCED' | 'FAILED';
  pdfUrl?: string;
  provider: string;
  raw?: any;
}
