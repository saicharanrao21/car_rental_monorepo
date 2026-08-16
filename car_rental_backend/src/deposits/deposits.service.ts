import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SecurityDepositStatus, Role, Prisma } from '@prisma/client';

@Injectable()
export class DepositsService {
  private readonly logger = new Logger(DepositsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
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
      throw new NotFoundException('Security deposit record not found.');
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
      throw new NotFoundException('Security deposit record not found.');
    }

    if (deposit.status !== SecurityDepositStatus.HELD) {
      throw new ConflictException(
        `Deposit cannot be settled in status: ${deposit.status}`,
      );
    }

    const deductDecimal = new Prisma.Decimal(deductAmount);
    if (deductDecimal.gt(deposit.amount)) {
      throw new BadRequestException(
        `Deduction amount (${deductAmount}) cannot exceed total deposit (${deposit.amount.toNumber()}).`,
      );
    }

    const remainingRefund = deposit.amount.sub(deductDecimal);
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
        deductedAmount: deductDecimal,
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

    this.auditLogService.log(
      adminUserId,
      'SECURITY_DEPOSIT_SETTLED_WITH_DEDUCTION',
      'SecurityDeposit',
      deposit.id,
      {
        bookingId,
        deductedAmount: deductDecimal.toNumber(),
        refundedAmount: remainingRefund.toNumber(),
        reason,
      },
    );

    return updated;
  }
}
