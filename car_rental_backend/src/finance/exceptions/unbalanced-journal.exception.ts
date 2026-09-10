import { BadRequestException } from '@nestjs/common';

export class UnbalancedJournalException extends BadRequestException {
  constructor(totalDebit: string, totalCredit: string, journalId?: string) {
    super(
      `Ledger invariant violation: Total Debits (₹${totalDebit}) does not equal Total Credits (₹${totalCredit})${
        journalId ? ` for journal ${journalId}` : ''
      }. Double-entry requires net zero balance.`,
    );
  }
}
