import { LedgerAccountType, LedgerEntrySide } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface JournalEntryLineInput {
  accountType: LedgerAccountType;
  accountEntityId?: string; // vendorId, customerId, or corporateAccountId
  side?: LedgerEntrySide;
  entrySide?: LedgerEntrySide;
  amount: Decimal | number | string;
  narration?: string;
  description?: string;
  bookingId?: string;
  paymentId?: string;
  payoutId?: string;
  metadata?: Record<string, any>;
}

export interface RecordJournalInput {
  journalId?: string;
  referenceType: string;
  referenceId: string;
  narration?: string;
  description?: string;
  lines?: JournalEntryLineInput[];
  entries?: JournalEntryLineInput[];
  idempotencyKey?: string;
  currency?: string;
  bookingId?: string;
  paymentId?: string;
  payoutId?: string;
  vendorId?: string;
}

export interface LedgerFilterDto {
  journalId?: string;
  accountType?: LedgerAccountType;
  accountEntityId?: string;
  bookingId?: string;
  paymentId?: string;
  payoutId?: string;
  referenceType?: string;
  referenceId?: string;
  startDate?: Date;
  endDate?: Date;
  page?: number;
  limit?: number;
}
