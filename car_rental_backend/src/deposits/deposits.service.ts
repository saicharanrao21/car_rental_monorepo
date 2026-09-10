import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Logger,
  Optional,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  SecurityDepositStatus,
  Role,
  Prisma,
  LedgerAccountType,
  LedgerEntrySide,
} from '@prisma/client';
import { LedgerCoreService } from '../finance/ledger-core.service';

@Injectable()
export class DepositsService {
  private readonly logger = new Logger(DepositsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
    @Optional()
    @Inject(forwardRef(() => LedgerCoreService))
    private readonly ledgerCore?: LedgerCoreService,
  ) {}

  /**
   * Automated worker running every hour to release security deposits for trips completed >= 24h ago with no active damage claims.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async autoReleaseEligibleDeposits() {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    try {
      const eligibleDeposits = await this.prisma.securityDeposit.findMany({
        where: {
          status: SecurityDepositStatus.HELD,
          booking: {
            status: 'COMPLETED',
            updatedAt: { lte: twentyFourHoursAgo },
            damageClaims: {
              none: {
                status: {
                  in: [
                    'SUBMITTED',
                    'UNDER_REVIEW',
                    'APPROVED',
                    'PARTIALLY_APPROVED',
                  ],
                },
              },
            },
          },
        },
        take: 20,
      });

      for (const deposit of eligibleDeposits) {
        try {
          await this.releaseDeposit(
            deposit.bookingId,
            undefined,
            'Automated 24-hour post-trip deposit release',
          );
          this.logger.log(
            `Auto-released deposit for booking ${deposit.bookingId}`,
          );
        } catch (err: any) {
          this.logger.error(
            `Auto-release failed for booking ${deposit.bookingId}: ${err.message}`,
          );
        }
      }
    } catch (err: any) {
      this.logger.warn(`Failed to query eligible auto-release deposits: ${err.message}`);
    }
  }


  /**
   * Retrieves security deposit record for a booking with RBAC checks.
   */
  async getDeposit(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        vendor: true,
        securityDeposit: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isSupport = requestingUser.role === Role.SUPPORT_AGENT;
    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor.userId === requestingUser.userId;

    if (!isAdmin && !isSupport && !isCustomer && !isVendor) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view this security deposit.',
      );
    }

    if (!booking.securityDeposit) {
      throw new NotFoundException(
        'No security deposit record found for this booking.',
      );
    }

    return booking.securityDeposit;
  }

  /**
   * Creates or records a security deposit as HELD once payment is confirmed.
   */
  async holdDeposit(
    bookingId: string,
    amount: number,
    razorpayPaymentId?: string,
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const amountDecimal = new Prisma.Decimal(amount);

    return this.prisma.securityDeposit.upsert({
      where: { bookingId },
      create: {
        bookingId,
        amount: amountDecimal,
        razorpayPaymentId,
        status: SecurityDepositStatus.HELD,
        heldAt: new Date(),
      },
      update: {
        amount: amountDecimal,
        razorpayPaymentId,
        status: SecurityDepositStatus.HELD,
        heldAt: new Date(),
      },
    });
  }

  /**
   * Releases full or remaining security deposit back to customer with atomic concurrency and recovery (SEC-P2-01).
   */
  async releaseDeposit(
    bookingId: string,
    adminUserId?: string,
    reason?: string,
  ) {
    const deposit = await this.prisma.securityDeposit.findUnique({
      where: { bookingId },
      include: { booking: true },
    });

    if (!deposit) {
      this.logger.warn(
        `releaseDeposit invoked for booking ${bookingId}, but no security deposit record exists. Skipping deposit release.`,
      );
      return null;
    }

    if (deposit.status !== SecurityDepositStatus.HELD) {
      throw new ConflictException(
        `Deposit cannot be released in status: ${deposit.status}`,
      );
    }

    const remainingToRefund = deposit.amount.sub(deposit.deductedAmount);

    if (remainingToRefund.lte(0)) {
      throw new BadRequestException(
        'No remaining deposit balance available to refund.',
      );
    }

    const targetStatus =
      deposit.deductedAmount.gt(0)
        ? SecurityDepositStatus.PARTIALLY_REFUNDED
        : SecurityDepositStatus.REFUNDED;

    // Atomic compare-and-swap state transition: prevents concurrent duplicate refund triggers
    const transitionResult = await this.prisma.securityDeposit.updateMany({
      where: {
        id: deposit.id,
        status: SecurityDepositStatus.HELD,
      },
      data: {
        status: targetStatus,
        releasedAt: new Date(),
      },
    });

    if (transitionResult.count === 0) {
      throw new ConflictException(
        'Security deposit release is already being processed or has completed concurrently.',
      );
    }

    const refundAmountInPaise = Math.round(remainingToRefund.toNumber() * 100);

    // Issue automated refund via Razorpay
    let razorpayRefundId: string | null = null;
    try {
      const refundRes = await this.paymentsService.refund(
        bookingId,
        refundAmountInPaise,
        reason || 'Security deposit release',
        'SECURITY_DEPOSIT_RELEASE',
      );
      razorpayRefundId = refundRes?.refundId || null;
    } catch (err: any) {
      this.logger.error(
        `Deposit release Razorpay refund failed: ${err.message}. Reverting deposit status to HELD for recovery.`,
      );
      // Revert to HELD so subsequent retry is possible
      await this.prisma.securityDeposit.update({
        where: { id: deposit.id },
        data: {
          status: SecurityDepositStatus.HELD,
          releasedAt: null,
        },
      });
      throw new BadRequestException(
        `Payment gateway refund failed: ${err.message}. Deposit status reverted for retry.`,
      );
    }

    const updated = await this.prisma.securityDeposit.update({
      where: { id: deposit.id },
      data: {
        refundedAmount: remainingToRefund,
        razorpayRefundId: razorpayRefundId || deposit.razorpayRefundId,
      },
    });

    if (this.ledgerCore && deposit.booking) {
      try {
        await this.ledgerCore.recordJournal({
          referenceType: 'SECURITY_DEPOSIT_RELEASE',
          referenceId: deposit.id,
          bookingId: deposit.bookingId,
          narration: `Security deposit refund for booking ${deposit.bookingId} (${reason || 'Standard release'})`,
          idempotencyKey: `jrn_dep_rel_${deposit.id}`,
          lines: [
            {
              accountType: LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW,
              accountEntityId: deposit.booking.customerId,
              side: LedgerEntrySide.DEBIT,
              amount: remainingToRefund,
              narration: `Escrow liability released on deposit refund for booking ${deposit.bookingId}`,
              bookingId: deposit.bookingId,
            },
            {
              accountType: LedgerAccountType.GATEWAY_CLEARING,
              accountEntityId: 'RAZORPAY',
              side: LedgerEntrySide.CREDIT,
              amount: remainingToRefund,
              narration: `Gateway refund clearing for released security deposit on booking ${deposit.bookingId}`,
              bookingId: deposit.bookingId,
            },
          ],
        });
      } catch (ledgerErr: any) {
        this.logger.error(`Failed to record deposit release ledger journal: ${ledgerErr.message}`);
      }
    }

    if (adminUserId) {
      this.auditLogService.log(
        adminUserId,
        'SECURITY_DEPOSIT_RELEASED',
        'SecurityDeposit',
        deposit.id,
        {
          bookingId,
          refundedAmount: remainingToRefund.toNumber(),
          deductedAmount: deposit.deductedAmount.toNumber(),
          reason,
        },
      );
    }

    if (deposit.booking.customerId) {
      this.notificationsService
        .notifyUser(
          deposit.booking.customerId,
          'Security Deposit Released',
          `Your security deposit of INR ${remainingToRefund} for booking ${bookingId} has been refunded to your original payment method.`,
        )
        .catch((err) =>
          this.logger.error('Failed to notify customer of deposit release', err),
        );
    }

    return updated;
  }

  /**
   * Deducts approved damage amount from deposit and releases any remaining balance with atomic concurrency and recovery (SEC-P2-01).
   */
  async settleDeduction(
    bookingId: string,
    deductAmount: number,
    adminUserId: string,
    reason: string,
  ) {
    const deposit = await this.prisma.securityDeposit.findUnique({
      where: { bookingId },
      include: { booking: true },
    });

    if (!deposit) {
      this.logger.warn(
        `settleDeduction invoked for booking ${bookingId}, but no security deposit record exists. Skipping deposit deduction.`,
      );
      return null;
    }

    if (deposit.status !== SecurityDepositStatus.HELD) {
      this.logger.warn(
        `Deposit for booking ${bookingId} cannot be settled in status: ${deposit.status}. Skipping deduction.`,
      );
      return deposit;
    }

    const deductDecimal = new Prisma.Decimal(deductAmount);
    const actualDeductDecimal = deductDecimal.gt(deposit.amount)
      ? deposit.amount
      : deductDecimal;

    const remainingRefund = deposit.amount.sub(actualDeductDecimal);
    const targetStatus = remainingRefund.gt(0)
      ? SecurityDepositStatus.PARTIALLY_REFUNDED
      : SecurityDepositStatus.FORFEITED;

    // Atomic compare-and-swap transition
    const transitionResult = await this.prisma.securityDeposit.updateMany({
      where: {
        id: deposit.id,
        status: SecurityDepositStatus.HELD,
      },
      data: {
        status: targetStatus,
        deductedAmount: actualDeductDecimal,
        releasedAt: new Date(),
      },
    });

    if (transitionResult.count === 0) {
      throw new ConflictException(
        'Security deposit settlement is already being processed or has completed concurrently.',
      );
    }

    let razorpayRefundId: string | null = null;

    if (remainingRefund.gt(0)) {
      const refundAmountInPaise = Math.round(remainingRefund.toNumber() * 100);
      try {
        const refundRes = await this.paymentsService.refund(
          bookingId,
          refundAmountInPaise,
          `Partial deposit release after damage settlement: ${reason}`,
          'DAMAGE_CLAIM_SETTLEMENT_REMAINDER',
        );
        razorpayRefundId = refundRes?.refundId || null;
      } catch (err: any) {
        this.logger.error(
          `Partial deposit release refund error: ${err.message}. Reverting status to HELD for recovery.`,
        );
        await this.prisma.securityDeposit.update({
          where: { id: deposit.id },
          data: {
            status: SecurityDepositStatus.HELD,
            deductedAmount: new Prisma.Decimal(0),
            releasedAt: null,
          },
        });
        throw new BadRequestException(
          `Payment gateway partial refund failed: ${err.message}. Deposit status reverted for retry.`,
        );
      }
    }

    const updated = await this.prisma.securityDeposit.update({
      where: { id: deposit.id },
      data: {
        refundedAmount: remainingRefund,
        razorpayRefundId: razorpayRefundId || deposit.razorpayRefundId,
      },
    });

    if (this.ledgerCore && deposit.booking) {
      try {
        const journalLines: any[] = [
          {
            accountType: LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW,
            accountEntityId: deposit.booking.customerId,
            side: LedgerEntrySide.DEBIT,
            amount: deposit.amount,
            narration: `Total escrow deposit settled after damage assessment for booking ${deposit.bookingId}`,
            bookingId: deposit.bookingId,
          },
        ];

        if (actualDeductDecimal.gt(0)) {
          journalLines.push({
            accountType: LedgerAccountType.VENDOR_PAYABLE,
            accountEntityId: deposit.booking.vendorId,
            side: LedgerEntrySide.CREDIT,
            amount: actualDeductDecimal,
            narration: `Damage compensation payable to host from security deposit for booking ${deposit.bookingId}: ${reason}`,
            bookingId: deposit.bookingId,
          });
        }

        if (remainingRefund.gt(0)) {
          journalLines.push({
            accountType: LedgerAccountType.GATEWAY_CLEARING,
            accountEntityId: 'RAZORPAY',
            side: LedgerEntrySide.CREDIT,
            amount: remainingRefund,
            narration: `Remaining security deposit refunded to customer for booking ${deposit.bookingId}`,
            bookingId: deposit.bookingId,
          });
        }

        await this.ledgerCore.recordJournal({
          referenceType: 'DAMAGE_DEDUCTION',
          referenceId: deposit.id,
          bookingId: deposit.bookingId,
          vendorId: deposit.booking.vendorId,
          narration: `Security deposit damage deduction settlement for booking ${deposit.bookingId} (${reason})`,
          idempotencyKey: `jrn_dep_deduct_${deposit.id}`,
          lines: journalLines,
        });
      } catch (ledgerErr: any) {
        this.logger.error(`Failed to record deposit deduction ledger journal: ${ledgerErr.message}`);
      }
    }

    this.auditLogService.log(
      adminUserId,
      'SECURITY_DEPOSIT_SETTLED_WITH_DEDUCTION',
      'SecurityDeposit',
      deposit.id,
      {
        bookingId,
        deductedAmount: actualDeductDecimal.toNumber(),
        totalClaimedAmount: deductAmount,
        refundedAmount: remainingRefund.toNumber(),
        reason,
      },
    );

    return updated;
  }
}
