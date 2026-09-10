import {
  Injectable,
  Logger,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  LedgerAccountType,
  LedgerEntrySide,
  PlatformLedgerEntry,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { UnbalancedJournalException } from './exceptions/unbalanced-journal.exception';
import {
  JournalEntryLineInput,
  RecordJournalInput,
  LedgerFilterDto,
} from './dto/ledger-core.dto';
import * as crypto from 'crypto';

@Injectable()
export class LedgerCoreService {
  private readonly logger = new Logger(LedgerCoreService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Records a balanced double-entry journal atomically.
   * Mathematical invariant: SUM(DEBITS) === SUM(CREDITS)
   */
  async recordJournal(
    input: RecordJournalInput,
    tx?: Prisma.TransactionClient,
  ): Promise<{
    journalId: string;
    entries: PlatformLedgerEntry[];
    isDuplicate?: boolean;
  }> {
    const prismaClient = tx || this.prisma;
    const rawLines = input.lines || input.entries || [];
    const narration = input.narration || input.description || `${input.referenceType} journal`;
    const { referenceType, referenceId, idempotencyKey, bookingId, paymentId, payoutId, vendorId } = input;

    if (!rawLines || rawLines.length < 2) {
      throw new BadRequestException(
        'A double-entry journal must have at least two entry lines (at least one debit and one credit).',
      );
    }

    // 1. Check idempotency if key provided
    if (idempotencyKey) {
      const existing = await prismaClient.platformLedgerEntry.findFirst({
        where: { idempotencyKey },
      });
      if (existing) {
        this.logger.debug(
          `Idempotent duplicate journal detected for key ${idempotencyKey}. Skipping duplicate insert.`,
        );
        const existingEntries = await prismaClient.platformLedgerEntry.findMany({
          where: { journalId: existing.journalId },
          orderBy: { postedAt: 'asc' },
        });
        return {
          journalId: existing.journalId,
          entries: existingEntries,
          isDuplicate: true,
        };
      }
    }

    // 2. Validate line amounts and calculate total debits and credits
    let totalDebit = new Decimal(0);
    let totalCredit = new Decimal(0);

    const parsedLines: Array<{
      accountType: LedgerAccountType;
      accountEntityId?: string;
      side: LedgerEntrySide;
      amount: Decimal;
      narration: string;
      bookingId?: string;
      paymentId?: string;
      payoutId?: string;
      metadata?: Record<string, any>;
    }> = [];

    for (const line of rawLines) {
      const amount = new Decimal(line.amount);
      if (amount.lte(0)) {
        throw new BadRequestException(
          `Ledger entry amount must be strictly positive. Received ₹${amount.toString()} for account ${line.accountType}.`,
        );
      }

      const side = line.side || line.entrySide;
      if (side === LedgerEntrySide.DEBIT) {
        totalDebit = totalDebit.add(amount);
      } else if (side === LedgerEntrySide.CREDIT) {
        totalCredit = totalCredit.add(amount);
      } else {
        throw new BadRequestException(`Invalid ledger entry side: ${side}`);
      }

      parsedLines.push({
        accountType: line.accountType,
        accountEntityId: line.accountEntityId || vendorId,
        side,
        amount,
        narration: line.narration || line.description || narration,
        bookingId: line.bookingId || bookingId,
        paymentId: line.paymentId || paymentId,
        payoutId: line.payoutId || payoutId,
        metadata: line.metadata,
      });
    }

    // 3. Mathematical enforcement: SUM(DEBITS) === SUM(CREDITS)
    if (!totalDebit.equals(totalCredit)) {
      throw new UnbalancedJournalException(
        totalDebit.toFixed(2),
        totalCredit.toFixed(2),
        input.journalId,
      );
    }

    const journalId =
      input.journalId ||
      `jrn_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const currency = input.currency || 'INR';

    // 4. Persist all lines atomically in database
    const executePersistence = async (pTx: Prisma.TransactionClient) => {
      const createdEntries: PlatformLedgerEntry[] = [];

      for (let i = 0; i < parsedLines.length; i++) {
        const line = parsedLines[i];
        const lineIdempotencyKey = idempotencyKey
          ? (i === 0 ? idempotencyKey : `${idempotencyKey}_line_${i}`)
          : undefined;

        const entry = await pTx.platformLedgerEntry.create({
          data: {
            journalId,
            accountType: line.accountType,
            accountEntityId: line.accountEntityId,
            side: line.side,
            amount: line.amount,
            currency,
            bookingId: line.bookingId,
            paymentId: line.paymentId,
            payoutId: line.payoutId,
            referenceType,
            referenceId,
            narration: line.narration,
            metadata: line.metadata ? (line.metadata as any) : undefined,
            idempotencyKey: lineIdempotencyKey,
          },
        });
        createdEntries.push(entry);
      }

      return createdEntries;
    };

    const entries = tx
      ? await executePersistence(tx)
      : await this.prisma.$transaction(executePersistence);

    this.logger.log(
      `Recorded balanced journal ${journalId} [${referenceType}:${referenceId}] with ${entries.length} lines. Total: ₹${totalDebit.toFixed(2)}`,
    );

    return { journalId, entries };
  }

  /**
   * Computes the net balance for a specific ledger account.
   * Accounting principles:
   * - Asset / Clearing accounts: Balance = SUM(DEBIT) - SUM(CREDIT)
   * - Liability / Escrow / Revenue accounts: Balance = SUM(CREDIT) - SUM(DEBIT)
   */
  async getAccountBalance(
    accountType: LedgerAccountType,
    accountEntityId?: string,
    tx?: Prisma.TransactionClient,
  ): Promise<Decimal> {
    const prismaClient = tx || this.prisma;

    const whereClause: Prisma.PlatformLedgerEntryWhereInput = {
      accountType,
      ...(accountEntityId !== undefined ? { accountEntityId } : {}),
    };

    const entries = await prismaClient.platformLedgerEntry.findMany({
      where: whereClause,
      select: {
        side: true,
        amount: true,
      },
    });

    let debits = new Decimal(0);
    let credits = new Decimal(0);

    for (const entry of entries) {
      if (entry.side === LedgerEntrySide.DEBIT) {
        debits = debits.add(entry.amount);
      } else {
        credits = credits.add(entry.amount);
      }
    }

    // Determine normal balance direction
    const isAssetAccount =
      accountType === LedgerAccountType.GATEWAY_CLEARING ||
      accountType === LedgerAccountType.CORPORATE_RECEIVABLE;

    return isAssetAccount ? debits.sub(credits) : credits.sub(debits);
  }

  /**
   * Retrieves net vendor payable balance derived from settled ledger entries.
   */
  async getVendorPayableBalance(
    vendorId: string,
    tx?: Prisma.TransactionClient,
  ): Promise<Decimal> {
    return this.getAccountBalance(
      LedgerAccountType.VENDOR_PAYABLE,
      vendorId,
      tx,
    );
  }

  /**
   * Retrieves platform commission revenue for a given date range.
   */
  async getPlatformCommissionRevenue(
    params?: { startDate?: Date; endDate?: Date },
    tx?: Prisma.TransactionClient,
  ): Promise<Decimal> {
    const prismaClient = tx || this.prisma;
    const whereClause: Prisma.PlatformLedgerEntryWhereInput = {
      accountType: LedgerAccountType.PLATFORM_COMMISSION_REVENUE,
      ...(params?.startDate || params?.endDate
        ? {
            postedAt: {
              ...(params.startDate ? { gte: params.startDate } : {}),
              ...(params.endDate ? { lte: params.endDate } : {}),
            },
          }
        : {}),
    };

    const entries = await prismaClient.platformLedgerEntry.findMany({
      where: whereClause,
      select: { side: true, amount: true },
    });

    let debits = new Decimal(0);
    let credits = new Decimal(0);

    for (const e of entries) {
      if (e.side === LedgerEntrySide.DEBIT) {
        debits = debits.add(e.amount);
      } else {
        credits = credits.add(e.amount);
      }
    }

    return credits.sub(debits);
  }

  /**
   * Retrieves total outstanding GST tax liability.
   */
  async getTaxLiabilityBalance(
    params?: { startDate?: Date; endDate?: Date },
    tx?: Prisma.TransactionClient,
  ): Promise<Decimal> {
    const prismaClient = tx || this.prisma;
    const whereClause: Prisma.PlatformLedgerEntryWhereInput = {
      accountType: LedgerAccountType.TAX_GST_LIABILITY,
      ...(params?.startDate || params?.endDate
        ? {
            postedAt: {
              ...(params.startDate ? { gte: params.startDate } : {}),
              ...(params.endDate ? { lte: params.endDate } : {}),
            },
          }
        : {}),
    };

    const entries = await prismaClient.platformLedgerEntry.findMany({
      where: whereClause,
      select: { side: true, amount: true },
    });

    let debits = new Decimal(0);
    let credits = new Decimal(0);

    for (const e of entries) {
      if (e.side === LedgerEntrySide.DEBIT) {
        debits = debits.add(e.amount);
      } else {
        credits = credits.add(e.amount);
      }
    }

    return credits.sub(debits);
  }

  /**
   * Paginated retrieval of platform ledger entries.
   */
  async getLedgerEntries(filter: LedgerFilterDto) {
    const {
      journalId,
      accountType,
      accountEntityId,
      bookingId,
      paymentId,
      payoutId,
      referenceType,
      referenceId,
      startDate,
      endDate,
      page = 1,
      limit = 20,
    } = filter;

    const where: Prisma.PlatformLedgerEntryWhereInput = {
      ...(journalId ? { journalId } : {}),
      ...(accountType ? { accountType } : {}),
      ...(accountEntityId ? { accountEntityId } : {}),
      ...(bookingId ? { bookingId } : {}),
      ...(paymentId ? { paymentId } : {}),
      ...(payoutId ? { payoutId } : {}),
      ...(referenceType ? { referenceType } : {}),
      ...(referenceId ? { referenceId } : {}),
      ...(startDate || endDate
        ? {
            postedAt: {
              ...(startDate ? { gte: startDate } : {}),
              ...(endDate ? { lte: endDate } : {}),
            },
          }
        : {}),
    };

    const skip = (page - 1) * limit;

    const [entries, total] = await Promise.all([
      this.prisma.platformLedgerEntry.findMany({
        where,
        skip,
        take: limit,
        orderBy: { postedAt: 'desc' },
        include: {
          booking: {
            select: { id: true, status: true, totalFare: true, carId: true },
          },
          payment: { select: { id: true, status: true, amount: true } },
          payout: { select: { id: true, status: true, amount: true } },
        },
      }),
      this.prisma.platformLedgerEntry.count({ where }),
    ]);

    return {
      data: entries,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Audits the entire platform ledger to ensure every journal satisfies net zero.
   */
  async verifyLedgerIntegrity(): Promise<{
    totalJournals: number;
    balancedJournals: number;
    unbalancedJournals: string[];
    isAudited: boolean;
  }> {
    const entries = await this.prisma.platformLedgerEntry.findMany({
      select: { journalId: true, side: true, amount: true },
    });

    const journalSums = new Map<string, Decimal>();

    for (const entry of entries) {
      const current = journalSums.get(entry.journalId) || new Decimal(0);
      const delta =
        entry.side === LedgerEntrySide.DEBIT
          ? new Decimal(entry.amount)
          : new Decimal(entry.amount).negated();
      journalSums.set(entry.journalId, current.add(delta));
    }

    const unbalanced: string[] = [];

    for (const [jid, sum] of journalSums.entries()) {
      if (!sum.equals(0)) {
        unbalanced.push(jid);
      }
    }

    return {
      totalJournals: journalSums.size,
      balancedJournals: journalSums.size - unbalanced.length,
      unbalancedJournals: unbalanced,
      isAudited: true,
    };
  }
}
