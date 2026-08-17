import { Injectable, Logger, Inject, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { ApmMonitoringService } from '../common/apm-monitoring.service';
import { InvoicesService } from '../invoices/invoices.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import Redis from 'ioredis';
import Razorpay from 'razorpay';
import {
  BookingStatus,
  PaymentStatus,
  RefundStatus,
  Role,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { randomUUID } from 'crypto';

export interface ReconciliationReport {
  candidatesFound: number;
  processed: number;
  healed: number;
  skipped: number;
  errors: number;
}

@Injectable()
export class FinancialReconciliationService {
  private readonly logger = new Logger(FinancialReconciliationService.name);
  private razorpay: Razorpay | null = null;
  private readonly useMock: boolean;
  private readonly isEnabled: boolean;
  private readonly lookbackMinutes: number;
  private readonly staleHours: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    @Optional() private readonly apmMonitoringService?: ApmMonitoringService,
    @Optional() private readonly invoicesService?: InvoicesService,
  ) {
    this.useMock =
      this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';
    this.isEnabled =
      this.configService.get<string>('RECONCILIATION_ENABLED') !== 'false';
    this.lookbackMinutes = Number(
      this.configService.get<number>('RECONCILIATION_LOOKBACK_MINUTES') || 30,
    );
    this.staleHours = Number(
      this.configService.get<number>('STALE_PAYMENT_ORDER_HOURS') || 24,
    );

    const keyId = this.configService.get<string>('RAZORPAY_KEY_ID');
    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (keyId && keySecret && !this.useMock) {
      this.razorpay = new Razorpay({
        key_id: keyId,
        key_secret: keySecret,
      });
    }
  }

  /**
   * Scheduled cron job running every 15 minutes.
   */
  @Cron('*/15 * * * *')
  async handleScheduledReconciliation(): Promise<ReconciliationReport | null> {
    if (!this.isEnabled) {
      this.logger.debug(
        'Scheduled financial reconciliation is disabled via RECONCILIATION_ENABLED=false.',
      );
      return null;
    }

    const lockKey = 'lock:reconciliation:cron';
    const lockToken = randomUUID();
    const lockTtlMs = 10 * 60 * 1000; // 10 minutes

    // Acquire global distributed lock to prevent multi-instance concurrency
    const acquired = await this.redis.set(
      lockKey,
      lockToken,
      'PX',
      lockTtlMs,
      'NX',
    );
    if (acquired !== 'OK') {
      this.logger.debug(
        'Another reconciliation worker instance is currently running. Skipping execution.',
      );
      return null;
    }

    try {
      return await this.runReconciliationCycle();
    } finally {
      // Safe Lua script lock release
      const luaScript = `
        if redis.call("get", KEYS[1]) == ARGV[1] then
            return redis.call("del", KEYS[1])
        else
            return 0
        end
      `;
      await this.redis.eval(luaScript, 1, lockKey, lockToken).catch(() => {});
    }
  }

  /**
   * Executes a full reconciliation cycle across all 4 financial rules.
   */
  async runReconciliationCycle(): Promise<ReconciliationReport> {
    const report: ReconciliationReport = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    this.logger.log(
      `[RECONCILIATION_STARTED] Initiating automated financial reconciliation cycle (Lookback: ${this.lookbackMinutes}m, Stale threshold: ${this.staleHours}h)...`,
    );

    // Rule 1: Orphaned Refund Recovery
    await this.reconcileOrphanedRefunds(report);

    // Rule 2: Unconfirmed Paid Bookings
    await this.reconcileUnconfirmedPaidBookings(report);

    // Rule 3: Stale Payment Orders
    await this.reconcileStalePaymentOrders(report);

    // Rule 4: Financial State Inconsistencies
    await this.reconcileFinancialInconsistencies(report);

    // Rule 5: Wallet Ledger Integrity
    await this.reconcileAllWallets();

    this.logger.log(
      `[RECONCILIATION_COMPLETED] Financial reconciliation completed. Summary: Candidates=${report.candidatesFound}, Processed=${report.processed}, Healed=${report.healed}, Skipped=${report.skipped}, Errors=${report.errors}`,
    );

    return report;
  }

  /**
   * RULE 1 — ORPHANED REFUND RECOVERY
   * Detects: Payment = PAID, refundStatus = NONE, Booking = CONFIRMED,
   * but Razorpay already reports an existing processed or pending refund.
   */
  async reconcileOrphanedRefunds(report: ReconciliationReport): Promise<void> {
    const lookbackDate = new Date(
      Date.now() - this.lookbackMinutes * 60 * 1000,
    );

    const candidates = await this.prisma.payment.findMany({
      where: {
        status: PaymentStatus.PAID,
        refundStatus: RefundStatus.NONE,
        razorpayPaymentId: { not: null },
        booking: {
          status: BookingStatus.CONFIRMED,
        },
        updatedAt: { lte: lookbackDate },
      },
      include: { booking: true },
      take: 50,
      orderBy: { updatedAt: 'asc' },
    });

    report.candidatesFound += candidates.length;

    for (const payment of candidates) {
      report.processed++;
      const bookingId = payment.bookingId;
      const paymentId = payment.id;
      const razorpayPaymentId = payment.razorpayPaymentId!;

      const perRecordLockKey = `lock:reconcile:payment:${paymentId}`;
      const token = randomUUID();
      const acquired = await this.redis.set(
        perRecordLockKey,
        token,
        'PX',
        30000,
        'NX',
      );
      if (acquired !== 'OK') {
        report.skipped++;
        continue;
      }

      try {
        if (!this.razorpay || this.useMock) {
          report.skipped++;
          continue;
        }

        let refundsList: any;
        try {
          refundsList =
            await this.razorpay.payments.fetchMultipleRefund(razorpayPaymentId);
        } catch (gatewayErr: any) {
          this.logger.warn(
            `[RECONCILIATION_RAZORPAY_ERROR] Failed to fetch refunds for paymentId=${paymentId}, razorpayPaymentId=${razorpayPaymentId}: ${gatewayErr?.message || gatewayErr}`,
          );
          report.errors++;
          continue;
        }

        if (!refundsList || !refundsList.items || refundsList.items.length === 0) {
          // No gateway refund exists; state is consistent
          report.skipped++;
          continue;
        }

        // Find the valid matching refund item
        const validRefund = refundsList.items.find(
          (rf: any) =>
            (rf.status === 'processed' || rf.status === 'pending') &&
            rf.payment_id === razorpayPaymentId,
        );

        if (!validRefund) {
          report.skipped++;
          continue;
        }

        const refundRupees = new Decimal((validRefund.amount / 100).toFixed(2));
        const paymentRupees = payment.amount;

        // Ensure refund amount does not exceed payment amount
        if (refundRupees.gt(paymentRupees)) {
          this.logger.error(
            `[RECONCILIATION_INCONSISTENCY] Gateway refund ${validRefund.id} amount (${refundRupees}) exceeds payment amount (${paymentRupees}) for bookingId=${bookingId}! Skipping auto-heal.`,
          );
          report.errors++;
          continue;
        }

        this.logger.log(
          `[RECONCILIATION_ORPHAN_REFUND_FOUND] Discovered orphaned Razorpay refund ${validRefund.id} (status: ${validRefund.status}, amount: ₹${refundRupees}) for bookingId=${bookingId}, paymentId=${paymentId}`,
        );

        // Atomically heal the database state
        await this.prisma.$transaction(async (tx) => {
          await tx.payment.update({
            where: { id: paymentId },
            data: {
              status: PaymentStatus.REFUNDED,
              refundStatus:
                validRefund.status === 'processed'
                  ? RefundStatus.PROCESSED
                  : RefundStatus.PENDING,
              razorpayRefundId: validRefund.id,
              refundAmount: refundRupees,
            },
          });

          await tx.booking.update({
            where: { id: bookingId },
            data: {
              status: BookingStatus.CANCELLED,
              refundAmount: refundRupees,
              cancelledAt: new Date(validRefund.created_at * 1000),
              cancellationReason: 'Reconciled from existing gateway refund',
            },
          });
        });

        // Record Audit Log entry
        await this.recordReconciliationAuditLog({
          action: 'RECONCILIATION_AUTO_HEALED_REFUND',
          targetType: 'Payment',
          targetId: paymentId,
          metadata: {
            bookingId,
            paymentId,
            razorpayOrderId: payment.razorpayOrderId,
            razorpayPaymentId,
            razorpayRefundId: validRefund.id,
            refundAmount: refundRupees.toNumber(),
            refundStatus: validRefund.status,
            reason: 'Orphaned gateway refund auto-healed',
          },
        });

        this.logger.log(
          `[RECONCILIATION_REFUND_HEALED] Successfully healed orphaned refund for bookingId=${bookingId}, paymentId=${paymentId}, razorpayRefundId=${validRefund.id}`,
        );

        report.healed++;
      } catch (err: any) {
        this.logger.error(
          `[RECONCILIATION_DB_ERROR] Failed to heal orphaned refund for bookingId=${bookingId}, paymentId=${paymentId}:`,
          err,
        );
        report.errors++;
      } finally {
        await this.releaseRecordLock(perRecordLockKey, token);
      }
    }
  }

  /**
   * RULE 2 — UNCONFIRMED PAID BOOKINGS
   * Detects: Booking = PENDING, Payment = CREATED,
   * but Razorpay confirms the order/payment was captured.
   */
  async reconcileUnconfirmedPaidBookings(
    report: ReconciliationReport,
  ): Promise<void> {
    const lookbackDate = new Date(
      Date.now() - this.lookbackMinutes * 60 * 1000,
    );

    const candidates = await this.prisma.payment.findMany({
      where: {
        status: PaymentStatus.CREATED,
        razorpayOrderId: { not: null },
        booking: {
          status: BookingStatus.PENDING,
        },
        createdAt: { lte: lookbackDate },
      },
      include: { booking: { include: { securityDeposit: true } } },
      take: 50,
      orderBy: { createdAt: 'asc' },
    });

    report.candidatesFound += candidates.length;

    for (const payment of candidates) {
      report.processed++;
      const booking = payment.booking;
      const bookingId = booking.id;
      const paymentId = payment.id;
      const razorpayOrderId = payment.razorpayOrderId!;

      const perRecordLockKey = `lock:reconcile:booking:${bookingId}`;
      const token = randomUUID();
      const acquired = await this.redis.set(
        perRecordLockKey,
        token,
        'PX',
        30000,
        'NX',
      );
      if (acquired !== 'OK') {
        report.skipped++;
        continue;
      }

      try {
        if (!this.razorpay || this.useMock) {
          report.skipped++;
          continue;
        }

        let orderPayments: any;
        try {
          orderPayments =
            await this.razorpay.orders.fetchPayments(razorpayOrderId);
        } catch (gatewayErr: any) {
          this.logger.warn(
            `[RECONCILIATION_RAZORPAY_ERROR] Failed to fetch payments for orderId=${razorpayOrderId}: ${gatewayErr?.message || gatewayErr}`,
          );
          report.errors++;
          continue;
        }

        if (!orderPayments || !orderPayments.items || orderPayments.items.length === 0) {
          report.skipped++;
          continue;
        }

        // Find captured payment for this order
        const capturedPayment = orderPayments.items.find(
          (p: any) => p.status === 'captured' && p.order_id === razorpayOrderId,
        );

        if (!capturedPayment) {
          report.skipped++;
          continue;
        }

        // Validate currency
        if (capturedPayment.currency && capturedPayment.currency.toUpperCase() !== 'INR') {
          this.logger.error(
            `[RECONCILIATION_INCONSISTENCY] Currency mismatch for orderId=${razorpayOrderId}. Expected INR, got ${capturedPayment.currency}`,
          );
          report.errors++;
          continue;
        }

        // Validate expected amount exactly
        const totalExpected = booking.totalFare.add(
          booking.securityDeposit?.amount || new Decimal(0),
        );
        const expectedPaise = Math.round(totalExpected.toNumber() * 100);

        if (Number(capturedPayment.amount) !== expectedPaise) {
          this.logger.error(
            `[RECONCILIATION_INCONSISTENCY] Amount mismatch for orderId=${razorpayOrderId}: expected ${expectedPaise} paise, but found ${capturedPayment.amount} paise! Skipping auto-heal.`,
          );
          report.errors++;
          continue;
        }

        // Atomically confirm payment and booking
        await this.prisma.$transaction(async (tx) => {
          await tx.payment.update({
            where: { id: paymentId },
            data: {
              status: PaymentStatus.PAID,
              razorpayPaymentId: capturedPayment.id,
            },
          });

          // Process coupon redemption if couponId exists
          if (booking.couponId) {
            const existingUsage = await tx.couponUsage.findUnique({
              where: { bookingId: booking.id },
            });

            if (!existingUsage) {
              // Acquire pessimistic row-level lock on Coupon record to serialize concurrent auto-heals
              await tx.$queryRaw`
                SELECT id FROM "Coupon" WHERE id = ${booking.couponId} FOR UPDATE
              `;

              const couponRecord = await tx.coupon.findUnique({
                where: { id: booking.couponId },
              });

              if (couponRecord && couponRecord.isActive) {
                const perCustomerLimit = couponRecord.perCustomerLimit ?? 1;
                const customerUsageCount = await tx.couponUsage.count({
                  where: {
                    couponId: booking.couponId,
                    customerId: booking.customerId,
                  },
                });

                if (
                  (couponRecord.globalUsageLimit === null ||
                    couponRecord.usageCount < couponRecord.globalUsageLimit) &&
                  customerUsageCount < perCustomerLimit
                ) {
                  await tx.coupon.update({
                    where: { id: booking.couponId },
                    data: { usageCount: { increment: 1 } },
                  });

                  await tx.couponUsage.create({
                    data: {
                      couponId: booking.couponId,
                      customerId: booking.customerId,
                      bookingId: booking.id,
                      discountAmount: booking.discountAmount!,
                    },
                  });
                }
              }
            }
          }

          await tx.booking.update({
            where: { id: bookingId },
            data: {
              status: BookingStatus.CONFIRMED,
            },
          });

          if (this.invoicesService) {
            try {
              await this.invoicesService.generateInvoiceForBooking(bookingId, tx);
            } catch (invErr: any) {
              this.logger.warn(`Invoice generation during reconciliation: ${invErr.message}`);
            }
          }
        });

        // Notify customer
        this.notificationsService
          .notifyUser(
            booking.customerId,
            'Payment Confirmed',
            `Your payment of INR ${payment.amount} for booking ${bookingId} was reconciled and confirmed.`,
          )
          .catch(() => {});

        // Record Audit Log entry
        await this.recordReconciliationAuditLog({
          action: 'RECONCILIATION_AUTO_CONFIRMED_PAYMENT',
          targetType: 'Booking',
          targetId: bookingId,
          metadata: {
            bookingId,
            paymentId,
            razorpayOrderId,
            razorpayPaymentId: capturedPayment.id,
            amount: payment.amount.toNumber(),
            reason: 'Captured gateway payment auto-confirmed',
          },
        });

        this.logger.log(
          `[RECONCILIATION_PAYMENT_HEALED] Successfully confirmed payment and booking for bookingId=${bookingId}, paymentId=${paymentId}, razorpayPaymentId=${capturedPayment.id}`,
        );

        report.healed++;
      } catch (err: any) {
        this.logger.error(
          `[RECONCILIATION_DB_ERROR] Failed to reconcile payment for bookingId=${bookingId}:`,
          err,
        );
        report.errors++;
      } finally {
        await this.releaseRecordLock(perRecordLockKey, token);
      }
    }
  }

  /**
   * RULE 3 — STALE PAYMENT ORDER
   * Detects: Booking = PENDING, Payment = CREATED older than 24 hours without capture.
   * Marks Payment = FAILED (leaving booking for customer retry or safe expiry).
   */
  async reconcileStalePaymentOrders(report: ReconciliationReport): Promise<void> {
    const staleDate = new Date(
      Date.now() - this.staleHours * 60 * 60 * 1000,
    );

    const stalePayments = await this.prisma.payment.findMany({
      where: {
        status: PaymentStatus.CREATED,
        razorpayOrderId: { not: null },
        booking: {
          status: BookingStatus.PENDING,
        },
        createdAt: { lte: staleDate },
      },
      take: 50,
      orderBy: { createdAt: 'asc' },
    });

    report.candidatesFound += stalePayments.length;

    for (const payment of stalePayments) {
      report.processed++;
      const paymentId = payment.id;
      const razorpayOrderId = payment.razorpayOrderId!;

      const perRecordLockKey = `lock:reconcile:payment:${paymentId}`;
      const token = randomUUID();
      const acquired = await this.redis.set(
        perRecordLockKey,
        token,
        'PX',
        30000,
        'NX',
      );
      if (acquired !== 'OK') {
        report.skipped++;
        continue;
      }

      try {
        if (this.razorpay && !this.useMock) {
          try {
            const orderPayments: any =
              await this.razorpay.orders.fetchPayments(razorpayOrderId);
            if (
              orderPayments &&
              orderPayments.items &&
              orderPayments.items.some(
                (p: any) => p.status === 'captured' || p.status === 'authorized',
              )
            ) {
              // Captured payment exists; will be picked up by Rule 2
              report.skipped++;
              continue;
            }
          } catch {
            // Ignore API fetch error on stale check
          }
        }

        await this.prisma.payment.update({
          where: { id: paymentId },
          data: { status: PaymentStatus.FAILED },
        });

        await this.recordReconciliationAuditLog({
          action: 'RECONCILIATION_STALE_ORDER_EXPIRED',
          targetType: 'Payment',
          targetId: paymentId,
          metadata: {
            bookingId: payment.bookingId,
            paymentId,
            razorpayOrderId,
            reason: `Stale unpaid payment order expired after ${this.staleHours} hours`,
          },
        });

        this.logger.log(
          `[RECONCILIATION_STALE_ORDER] Expired stale unpaid payment order for bookingId=${payment.bookingId}, paymentId=${paymentId}`,
        );

        report.healed++;
      } catch (err: any) {
        this.logger.error(
          `[RECONCILIATION_DB_ERROR] Failed to expire stale payment order for paymentId=${paymentId}:`,
          err,
        );
        report.errors++;
      } finally {
        await this.releaseRecordLock(perRecordLockKey, token);
      }
    }
  }

  /**
   * RULE 4 — FINANCIAL STATE INCONSISTENCIES
   * Detects and classifies anomalous states. Heals deterministically safe cases;
   * logs and creates audit alerts for ambiguous discrepancies.
   */
  async reconcileFinancialInconsistencies(
    report: ReconciliationReport,
  ): Promise<void> {
    // Sub-rule 4A: Payment is REFUNDED with PROCESSED status, but Booking is still CONFIRMED
    const refundedConfirmed = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        payment: {
          status: PaymentStatus.REFUNDED,
          refundStatus: RefundStatus.PROCESSED,
        },
      },
      include: { payment: true },
      take: 50,
    });

    report.candidatesFound += refundedConfirmed.length;

    for (const booking of refundedConfirmed) {
      report.processed++;
      const payment = booking.payment!;
      try {
        await this.prisma.booking.update({
          where: { id: booking.id },
          data: {
            status: BookingStatus.CANCELLED,
            refundAmount: payment.refundAmount || new Decimal(0),
            cancelledAt: new Date(),
            cancellationReason: 'Reconciled: linked payment was already refunded',
          },
        });

        await this.recordReconciliationAuditLog({
          action: 'RECONCILIATION_HEALED_CONFIRMED_TO_CANCELLED',
          targetType: 'Booking',
          targetId: booking.id,
          metadata: {
            bookingId: booking.id,
            paymentId: payment.id,
            razorpayRefundId: payment.razorpayRefundId,
            refundAmount: payment.refundAmount?.toNumber(),
            reason: 'Booking set to CANCELLED because payment is already REFUNDED',
          },
        });

        this.logger.log(
          `[RECONCILIATION_REFUND_HEALED] Healed inconsistent CONFIRMED booking to CANCELLED for bookingId=${booking.id}, paymentId=${payment.id}`,
        );

        report.healed++;
      } catch (err: any) {
        this.logger.error(
          `[RECONCILIATION_DB_ERROR] Failed to heal booking ${booking.id}:`,
          err,
        );
        report.errors++;
      }
    }

    // Sub-rule 4B: Booking is CANCELLED, Payment is PAID, refund was expected, but no Razorpay refund ID
    const cancelledUnrefunded = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CANCELLED,
        refundAmount: { gt: new Decimal(0) },
        payment: {
          status: PaymentStatus.PAID,
          refundStatus: RefundStatus.NONE,
        },
      },
      include: { payment: true },
      take: 50,
    });

    report.candidatesFound += cancelledUnrefunded.length;

    for (const booking of cancelledUnrefunded) {
      report.processed++;
      const payment = booking.payment!;

      // Check if Razorpay actually had a refund
      if (payment.razorpayPaymentId && this.razorpay && !this.useMock) {
        try {
          const refundsList: any =
            await this.razorpay.payments.fetchMultipleRefund(
              payment.razorpayPaymentId,
            );
          const validRefund = refundsList?.items?.find(
            (rf: any) =>
              rf.status === 'processed' || rf.status === 'pending',
          );

          if (validRefund) {
            const refundRupees = new Decimal(
              (validRefund.amount / 100).toFixed(2),
            );
            await this.prisma.payment.update({
              where: { id: payment.id },
              data: {
                status: PaymentStatus.REFUNDED,
                refundStatus:
                  validRefund.status === 'processed'
                    ? RefundStatus.PROCESSED
                    : RefundStatus.PENDING,
                razorpayRefundId: validRefund.id,
                refundAmount: refundRupees,
              },
            });

            await this.recordReconciliationAuditLog({
              action: 'RECONCILIATION_AUTO_HEALED_REFUND',
              targetType: 'Payment',
              targetId: payment.id,
              metadata: {
                bookingId: booking.id,
                paymentId: payment.id,
                razorpayRefundId: validRefund.id,
                refundAmount: refundRupees.toNumber(),
                reason: 'Linked gateway refund to cancelled booking',
              },
            });

            this.logger.log(
              `[RECONCILIATION_REFUND_HEALED] Linked gateway refund ${validRefund.id} to cancelled bookingId=${booking.id}`,
            );

            report.healed++;
            continue;
          }
        } catch {
          // Gateway check failed
        }
      }

      // If no gateway refund exists, NEVER automatically issue a new refund.
      // Emit high-severity structured log and record AuditLog alert for manual investigation.
      this.logger.error(
        `[RECONCILIATION_INCONSISTENCY] CRITICAL: Booking ${booking.id} is CANCELLED with expected refund of INR ${booking.refundAmount}, but Payment ${payment.id} remains PAID and no gateway refund exists on Razorpay! Manual settlement review required.`,
      );

      await this.recordReconciliationAuditLog({
        action: 'RECONCILIATION_INCONSISTENCY_DETECTED',
        targetType: 'Booking',
        targetId: booking.id,
        metadata: {
          bookingId: booking.id,
          paymentId: payment.id,
          expectedRefund: booking.refundAmount?.toNumber(),
          severity: 'CRITICAL',
          discrepancy:
            'Booking cancelled with expected refund but payment is PAID without gateway refund',
        },
      });

      if (this.apmMonitoringService) {
        this.apmMonitoringService.captureFinancialInconsistency(
          `Booking ${booking.id} is CANCELLED with expected refund of INR ${booking.refundAmount}, but Payment ${payment.id} remains PAID and no gateway refund exists on Razorpay!`,
          {
            bookingId: booking.id,
            paymentId: payment.id,
            razorpayPaymentId: payment.razorpayPaymentId || undefined,
            expectedAmount: booking.refundAmount?.toNumber(),
            severity: 'fatal',
            extra: {
              status: booking.status,
              paymentStatus: payment.status,
              refundStatus: payment.refundStatus,
            },
          },
        );
      }

      report.errors++;
    }
  }

  /**
   * Helper to release a per-record Redis distributed lock safely.
   */
  private async releaseRecordLock(key: string, token: string): Promise<void> {
    const luaScript = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
      else
          return 0
      end
    `;
    await this.redis.eval(luaScript, 1, key, token).catch(() => {});
  }

  /**
   * Helper to record safe AuditLog entries using the first available Admin user.
   */
  private async recordReconciliationAuditLog(params: {
    action: string;
    targetType: string;
    targetId: string;
    metadata: any;
  }): Promise<void> {
    try {
      const admin = await this.prisma.user.findFirst({
        where: { role: Role.ADMIN },
        select: { id: true },
      });

      if (admin) {
        await this.auditLogService.log(
          admin.id,
          params.action,
          params.targetType,
          params.targetId,
          params.metadata,
        );
      }
    } catch (err) {
      this.logger.warn('Failed to record reconciliation audit log:', err);
    }
  }

  /**
   * RULE 5 — WALLET LEDGER INTEGRITY RECONCILIATION
   * Compares cached Wallet balances against authoritative ledger aggregates.
   * If any mismatch is found, freezes the wallet, logs an audit log, and alerts APM.
   */
  async reconcileAllWallets(): Promise<{ totalChecked: number; discrepanciesFound: number }> {
    const wallets = await this.prisma.wallet.findMany();
    let discrepanciesFound = 0;

    for (const wallet of wallets) {
      const aggregate = await this.prisma.walletLedgerEntry.groupBy({
        by: ['direction'],
        where: { walletId: wallet.id },
        _sum: { amount: true },
      });

      let totalCredits = new Decimal(0);
      let totalDebits = new Decimal(0);

      for (const row of aggregate) {
        if (row.direction === 'CREDIT') {
          totalCredits = row._sum.amount ? new Decimal(row._sum.amount) : new Decimal(0);
        } else if (row.direction === 'DEBIT') {
          totalDebits = row._sum.amount ? new Decimal(row._sum.amount) : new Decimal(0);
        }
      }

      const calculatedBalance = totalCredits.sub(totalDebits);
      const isMatched = wallet.availableBalance.equals(calculatedBalance);
      const isBucketSumMatched = wallet.realBalance.add(wallet.promoBalance).equals(wallet.availableBalance);

      if (!isMatched || !isBucketSumMatched) {
        discrepanciesFound++;
        this.logger.error(
          `CRITICAL WALLET RECONCILIATION MISMATCH: Wallet ${wallet.id} (User: ${wallet.userId}) Cached: ₹${wallet.availableBalance}, Computed: ₹${calculatedBalance}, Real: ₹${wallet.realBalance}, Promo: ₹${wallet.promoBalance}`,
        );

        await this.prisma.wallet.update({
          where: { id: wallet.id },
          data: { status: 'FROZEN' },
        });

        await this.recordReconciliationAuditLog({
          action: 'WALLET_RECONCILIATION_DISCREPANCY_FROZEN',
          targetType: 'Wallet',
          targetId: wallet.id,
          metadata: {
            cachedAvailable: wallet.availableBalance.toString(),
            computedAvailable: calculatedBalance.toString(),
            realBalance: wallet.realBalance.toString(),
            promoBalance: wallet.promoBalance.toString(),
          },
        });

        if (this.apmMonitoringService) {
          this.apmMonitoringService.captureFinancialInconsistency(
            'WALLET_LEDGER_MISMATCH',
            {
              severity: 'fatal',
              extra: {
                walletId: wallet.id,
                cached: wallet.availableBalance.toString(),
                computed: calculatedBalance.toString(),
              },
            },
          );
        }
      }
    }

    return { totalChecked: wallets.length, discrepanciesFound };
  }
}
