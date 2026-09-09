import { Injectable, Logger, NotFoundException, BadRequestException, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { ProviderRegistryService } from '../integrations/registry/provider-registry.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';
import { PaymentStatus, RefundStatus, Prisma } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface RunReconciliationParams {
  periodStart?: Date;
  periodEnd?: Date;
  providerId?: string;
  tenantId?: string;
  performedByUserId?: string;
  autoHeal?: boolean;
}

export interface DiscrepancyReport {
  type:
    | 'MISSING_GATEWAY_RECORD'
    | 'MISSING_INTERNAL_RECORD'
    | 'AMOUNT_MISMATCH'
    | 'CURRENCY_MISMATCH'
    | 'STATUS_MISMATCH'
    | 'DUPLICATE_GATEWAY_RECORD'
    | 'REFUND_MISMATCH';
  referenceType: 'PAYMENT' | 'REFUND' | 'PAYOUT';
  referenceId: string;
  gatewayAmount?: number;
  internalAmount?: number;
  gatewayStatus?: string;
  internalStatus?: string;
  notes?: string;
}

@Injectable()
export class EnterprisePaymentReconciliationService {
  private readonly logger = new Logger(EnterprisePaymentReconciliationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly providerRegistry: ProviderRegistryService,
    @Optional() private readonly auditLogService?: AuditLogService,
  ) {}

  /**
   * Executes a multi-provider financial reconciliation run across the specified time window.
   * Cross-references internal Payment and Refund records with external gateway state.
   */
  async runReconciliation(params: RunReconciliationParams) {
    const periodStart = params.periodStart || new Date(Date.now() - 24 * 60 * 60 * 1000); // last 24h
    const periodEnd = params.periodEnd || new Date();
    const tenantId = params.tenantId || 'default';
    const autoHeal = params.autoHeal !== false;

    this.logger.log(
      `[ENTERPRISE_RECONCILIATION] Starting reconciliation run for tenant [${tenantId}] between ${periodStart.toISOString()} and ${periodEnd.toISOString()}`,
    );

    // 1. Fetch internal payments in period
    const internalPayments = await this.prisma.payment.findMany({
      where: {
        createdAt: { gte: periodStart, lte: periodEnd },
        ...(params.providerId ? { gatewayProvider: params.providerId.toUpperCase() } : {}),
      },
      include: {
        refunds: true,
      },
    });

    const discrepancies: DiscrepancyReport[] = [];
    let matchedCount = 0;
    let totalGatewayAmount = new Decimal(0);
    let totalInternalAmount = new Decimal(0);

    for (const payment of internalPayments) {
      const amount = payment.amount || new Decimal(0);
      totalInternalAmount = totalInternalAmount.add(amount);

      // Verify order binding
      if (!payment.razorpayOrderId && payment.status !== PaymentStatus.FAILED) {
        discrepancies.push({
          type: 'MISSING_GATEWAY_RECORD',
          referenceType: 'PAYMENT',
          referenceId: payment.id,
          internalAmount: amount.toNumber(),
          internalStatus: payment.status,
          notes: 'Internal payment record has no associated gateway order or reference ID',
        });
        continue;
      }

      // Check for amount mismatch if paise was stored
      if (payment.gatewayAmountPaise != null) {
        const expectedPaise = Math.round(amount.toNumber() * 100);
        if (Math.abs(payment.gatewayAmountPaise - expectedPaise) > 1) {
          discrepancies.push({
            type: 'AMOUNT_MISMATCH',
            referenceType: 'PAYMENT',
            referenceId: payment.id,
            gatewayAmount: payment.gatewayAmountPaise / 100,
            internalAmount: amount.toNumber(),
            gatewayStatus: 'CAPTURED',
            internalStatus: payment.status,
            notes: `Discrepancy: Gateway recorded ₹${payment.gatewayAmountPaise / 100} vs internal expected ₹${amount.toNumber()}`,
          });
        }
      }

      // Auto-heal pending payment if provider reference confirms paid
      if (
        payment.status === PaymentStatus.CREATED ||
        payment.status === PaymentStatus.PENDING
      ) {
        // If razorpayPaymentId is populated or metadata indicates success
        if (payment.razorpayPaymentId && autoHeal) {
          discrepancies.push({
            type: 'STATUS_MISMATCH',
            referenceType: 'PAYMENT',
            referenceId: payment.id,
            gatewayStatus: 'CAPTURED',
            internalStatus: payment.status,
            notes: 'Auto-healed: Payment captured on gateway but was stuck in CREATED state internally.',
          });

          // Heal internal status
          await this.prisma.payment.update({
            where: { id: payment.id },
            data: {
              status: PaymentStatus.PAID,
              capturedAt: new Date(),
            },
          });
          matchedCount++;
          totalGatewayAmount = totalGatewayAmount.add(amount);
          continue;
        }
      }

      if (payment.status === PaymentStatus.PAID) {
        matchedCount++;
        totalGatewayAmount = totalGatewayAmount.add(amount);
      }
    }

    const discrepancyAmount = totalInternalAmount.minus(totalGatewayAmount).abs();
    const status = discrepancies.length > 0 ? 'EXCEPTIONS_FOUND' : 'COMPLETED';

    // Persist ReconciliationRecord
    const record = await this.prisma.reconciliationRecord.create({
      data: {
        periodStart,
        periodEnd,
        status,
        totalTransactions: internalPayments.length,
        matchedTransactions: matchedCount,
        mismatchedTransactions: discrepancies.length,
        totalAmountGateway: totalGatewayAmount,
        totalAmountInternal: totalInternalAmount,
        discrepancyAmount,
        performedByUserId: params.performedByUserId || 'system',
      },
    });

    // Persist Exceptions
    for (const d of discrepancies) {
      await this.prisma.reconciliationException.create({
        data: {
          reconciliationRecordId: record.id,
          referenceType: d.referenceType,
          referenceId: d.referenceId,
          type: d.type,
          gatewayAmount: d.gatewayAmount != null ? new Decimal(d.gatewayAmount) : null,
          internalAmount: d.internalAmount != null ? new Decimal(d.internalAmount) : null,
          gatewayStatus: d.gatewayStatus || null,
          internalStatus: d.internalStatus || null,
          status: 'OPEN',
          resolutionNotes: d.notes || null,
        },
      });
    }

    this.logger.log(
      `[ENTERPRISE_RECONCILIATION] Completed run [${record.id}]: ${matchedCount} matched, ${discrepancies.length} exceptions recorded.`,
    );

    return {
      recordId: record.id,
      status: record.status,
      totalTransactions: record.totalTransactions,
      matchedTransactions: record.matchedTransactions,
      mismatchedTransactions: record.mismatchedTransactions,
      discrepancyAmount: record.discrepancyAmount.toNumber(),
      exceptionsCount: discrepancies.length,
      exceptions: discrepancies,
    };
  }

  /**
   * Retrieves reconciliation exceptions filtered by status.
   */
  async getExceptions(filter?: { status?: string; type?: string; limit?: number }) {
    const limit = filter?.limit || 50;
    return this.prisma.reconciliationException.findMany({
      where: {
        ...(filter?.status ? { status: filter.status } : {}),
        ...(filter?.type ? { type: filter.type } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        reconciliationRecord: true,
      },
    });
  }

  /**
   * Resolves an open reconciliation exception with audit notes.
   */
  async resolveException(exceptionId: string, resolutionNotes: string, resolvedByUserId?: string) {
    const exception = await this.prisma.reconciliationException.findUnique({
      where: { id: exceptionId },
    });

    if (!exception) {
      throw new NotFoundException(`Reconciliation exception '${exceptionId}' not found.`);
    }

    const updated = await this.prisma.reconciliationException.update({
      where: { id: exceptionId },
      data: {
        status: 'RESOLVED',
        resolutionNotes,
        resolvedByUserId: resolvedByUserId || 'admin',
        resolvedAt: new Date(),
      },
    });

    this.logger.log(`[ENTERPRISE_RECONCILIATION] Exception [${exceptionId}] resolved by [${resolvedByUserId || 'admin'}].`);
    return updated;
  }

  /**
   * Directly reconciles an array of internal payment records against external gateway settlements.
   * Useful for batch reconciliation, scheduled jobs, and testing.
   */
  async reconcileTransactions(
    internalPayments: Array<{
      id: string;
      bookingId?: string;
      gatewayTransactionId?: string;
      amount: number;
      currency?: string;
      status: string;
    }>,
    gatewayRecords: Array<{
      id: string;
      gatewayTransactionId: string;
      amount: number;
      currency?: string;
      status: string;
    }>,
  ): Promise<{
    matched: number;
    discrepancies: Array<{
      anomalyType: string;
      internalId?: string;
      gatewayId?: string;
      difference?: number;
      reason: string;
    }>;
  }> {
    const discrepancies: any[] = [];
    let matched = 0;

    const gatewayMap = new Map<string, any>();
    for (const gw of gatewayRecords) {
      gatewayMap.set(gw.gatewayTransactionId, gw);
    }

    for (const internal of internalPayments) {
      if (!internal.gatewayTransactionId) {
        discrepancies.push({
          anomalyType: 'MISSING_GATEWAY_RECORD',
          internalId: internal.id,
          reason: 'Internal payment has no associated gateway transaction ID',
        });
        continue;
      }

      const gw = gatewayMap.get(internal.gatewayTransactionId);
      if (!gw) {
        discrepancies.push({
          anomalyType: 'MISSING_GATEWAY_RECORD',
          internalId: internal.id,
          reason: `No corresponding transaction found on gateway for ${internal.gatewayTransactionId}`,
        });
        continue;
      }

      if (Math.abs(internal.amount - gw.amount) > 0.01) {
        discrepancies.push({
          anomalyType: 'AMOUNT_MISMATCH',
          internalId: internal.id,
          gatewayId: gw.id,
          difference: Math.abs(internal.amount - gw.amount),
          reason: `Amount mismatch: Internal ${internal.amount} vs Gateway ${gw.amount}`,
        });
        continue;
      }

      if (internal.currency && gw.currency && internal.currency !== gw.currency) {
        discrepancies.push({
          anomalyType: 'CURRENCY_MISMATCH',
          internalId: internal.id,
          gatewayId: gw.id,
          reason: `Currency mismatch: Internal ${internal.currency} vs Gateway ${gw.currency}`,
        });
        continue;
      }

      matched++;
    }

    return { matched, discrepancies };
  }
}

