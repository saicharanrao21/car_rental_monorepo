import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PayoutStatus, PaymentStatus, Prisma } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';

@Injectable()
export class PayoutsService {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async getVendorEarningsSummary(vendorId: string) {
    const vendorExists = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendorExists) {
      throw new NotFoundException('Vendor not found.');
    }

    // 1. Sum netToVendor for all COMPLETED bookings with verified PAID payment
    const completedBookings = await this.prisma.booking.findMany({
      where: {
        vendorId,
        status: 'COMPLETED',
        payment: { status: PaymentStatus.PAID },
      },
    });

    const totalEarnings = completedBookings.reduce(
      (sum, b) => sum.add(b.netToVendor),
      new Prisma.Decimal(0),
    );

    // 2. Sum amount for all PAID payouts
    const paidPayouts = await this.prisma.payout.findMany({
      where: { vendorId, status: PayoutStatus.PAID },
    });

    const totalPaid = paidPayouts.reduce(
      (sum, p) => sum.add(p.amount),
      new Prisma.Decimal(0),
    );

    // 3. Sum amount for all PENDING payouts (reserved funds)
    const pendingPayouts = await this.prisma.payout.findMany({
      where: { vendorId, status: PayoutStatus.PENDING },
    });

    const totalPending = pendingPayouts.reduce(
      (sum, p) => sum.add(p.amount),
      new Prisma.Decimal(0),
    );

    // 4. Compute balances
    const reservedTotal = totalPaid.add(totalPending);
    const availableBalance = totalEarnings.sub(reservedTotal);
    const outstandingBalance = totalEarnings.sub(totalPaid);

    // 5. Calculate thisMonth and lastMonth breakdowns
    const now = new Date();
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(
      now.getFullYear(),
      now.getMonth(),
      0,
      23,
      59,
      59,
      999,
    );

    const thisMonthBookings = completedBookings.filter(
      (b) => b.createdAt >= thisMonthStart,
    );
    const thisMonthEarnings = thisMonthBookings.reduce(
      (sum, b) => sum.add(b.netToVendor),
      new Prisma.Decimal(0),
    );

    const lastMonthBookings = completedBookings.filter(
      (b) => b.createdAt >= lastMonthStart && b.createdAt <= lastMonthEnd,
    );
    const lastMonthEarnings = lastMonthBookings.reduce(
      (sum, b) => sum.add(b.netToVendor),
      new Prisma.Decimal(0),
    );

    return {
      totalEarnings: totalEarnings.toNumber(),
      totalPaid: totalPaid.toNumber(),
      totalPending: totalPending.toNumber(),
      availableBalance: Math.max(0, availableBalance.toNumber()),
      outstandingBalance: Math.max(0, outstandingBalance.toNumber()),
      thisMonthEarnings: thisMonthEarnings.toNumber(),
      lastMonthEarnings: lastMonthEarnings.toNumber(),
    };
  }

  async getDailyEarnings(vendorId: string, days: number) {
    const vendorExists = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendorExists) {
      throw new NotFoundException('Vendor not found.');
    }

    const limitDate = new Date();
    limitDate.setDate(limitDate.getDate() - days);
    limitDate.setHours(0, 0, 0, 0);

    const bookings = await this.prisma.booking.findMany({
      where: {
        vendorId,
        status: 'COMPLETED',
        payment: { status: PaymentStatus.PAID },
        createdAt: { gte: limitDate },
      },
      orderBy: { createdAt: 'asc' },
    });

    // Generate date map for last 'days' days to ensure we have zero entries
    const dailyMap = new Map<string, number>();
    for (let i = 0; i <= days; i++) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      dailyMap.set(dateStr, 0);
    }

    // Populate with actual completed bookings
    for (const b of bookings) {
      const dateStr = b.createdAt.toISOString().split('T')[0];
      if (dailyMap.has(dateStr)) {
        const currentVal = dailyMap.get(dateStr) || 0;
        dailyMap.set(dateStr, currentVal + b.netToVendor.toNumber());
      }
    }

    // Convert map to sorted array list
    const result = Array.from(dailyMap.entries())
      .map(([date, amount]) => ({
        date,
        amount,
      }))
      .sort((a, b) => a.date.localeCompare(b.date));

    return result;
  }

  async createPayout(vendorId: string, amount: number, adminUserId?: string) {
    if (amount <= 0) {
      throw new BadRequestException('Payout amount must be greater than zero.');
    }

    return this.prisma.$transaction(async (tx) => {
      const vendor = await tx.vendor.findUnique({
        where: { id: vendorId },
      });
      if (!vendor) {
        throw new NotFoundException('Vendor not found');
      }

      // Tier 2 Concurrency: Acquire row lock on Vendor record to serialize concurrent payout creations
      await tx.$queryRaw`SELECT id FROM "Vendor" WHERE id = ${vendorId} FOR UPDATE`;

      // Calculate live available balance inside transaction
      const completed = await tx.booking.findMany({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
        },
      });
      const totalEarned = completed.reduce(
        (sum, b) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );

      const paid = await tx.payout.findMany({
        where: { vendorId, status: PayoutStatus.PAID },
      });
      const totalPaidAmount = paid.reduce(
        (sum, p) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      const pending = await tx.payout.findMany({
        where: { vendorId, status: PayoutStatus.PENDING },
      });
      const totalPendingAmount = pending.reduce(
        (sum, p) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      const available = totalEarned.sub(totalPaidAmount).sub(totalPendingAmount);

      const reqAmount = new Prisma.Decimal(amount);
      if (reqAmount.gt(available)) {
        throw new BadRequestException(
          `Requested payout amount (${amount}) exceeds vendor's available balance (${Math.max(0, available.toNumber())}). Reserved in pending payouts: ${totalPendingAmount.toNumber()}`,
        );
      }

      const payout = await tx.payout.create({
        data: {
          vendorId,
          amount: reqAmount,
          status: PayoutStatus.PENDING,
        },
      });

      if (adminUserId) {
        this.auditLogService.log(
          adminUserId,
          'PAYOUT_CREATED',
          'Payout',
          payout.id,
          { vendorId, amount: reqAmount.toNumber() },
        );
      }

      return payout;
    });
  }

  async markPayoutPaid(payoutId: string, adminNote?: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
    });
    if (!payout) {
      throw new NotFoundException('Payout record not found');
    }

    if (payout.status === PayoutStatus.PAID) {
      throw new BadRequestException('Payout is already marked as PAID');
    }

    if (adminNote) {
      this.logger.log(
        `Marking payout ${payoutId} as PAID. Admin Note: ${adminNote}`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: PayoutStatus.PAID,
        paidAt: new Date(),
      },
      include: {
        vendor: true,
      },
    });

    if (updated.vendor.userId) {
      this.notificationsService
        .notifyUser(
          updated.vendor.userId,
          'Payout Marked Paid',
          `Your payout of INR ${updated.amount} has been processed and marked as paid.`,
        )
        .catch((err) =>
          this.logger.error(
            'Failed to notify vendor of payout status change',
            err,
          ),
        );
    }

    return updated;
  }

  async getPayoutHistory(vendorId: string) {
    const vendorExists = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendorExists) {
      throw new NotFoundException('Vendor not found.');
    }

    return this.prisma.payout.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllPayouts(status?: PayoutStatus, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const where: any = {};

    if (status) {
      where.status = status;
    }

    const [total, data] = await Promise.all([
      this.prisma.payout.count({ where }),
      this.prisma.payout.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          vendor: {
            select: {
              id: true,
              businessName: true,
              ownerName: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(total / limit);

    return {
      data,
      total,
      page,
      totalPages,
    };
  }
}
