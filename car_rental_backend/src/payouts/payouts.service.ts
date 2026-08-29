import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  PayoutStatus,
  PaymentStatus,
  Prisma,
  LedgerDirection,
  WalletBucketType,
  Role,
} from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { RequestPayoutDto } from './dto/request-payout.dto';
import { ApprovePayoutDto } from './dto/approve-payout.dto';
import { ExecutePayoutDto } from './dto/execute-payout.dto';
import { CreateFinancialAdjustmentDto } from './dto/create-adjustment.dto';
import { WalletsService } from '../wallets/wallets.service';

@Injectable()
export class PayoutsService {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
    @Optional() private readonly walletsService?: WalletsService,
  ) {}

  private async generatePayoutNumber(): Promise<string> {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const prefix = `PO-${year}-${month}-`;

    const count = this.prisma.payout.count
      ? await this.prisma.payout.count({
          where: {
            payoutNumber: { startsWith: prefix },
          },
        })
      : 0;

    const safeCount = typeof count === 'number' && !isNaN(count) ? count : 0;
    return `${prefix}${String(safeCount + 1).padStart(5, '0')}`;
  }

  private async generateAdjustmentNumber(): Promise<string> {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const prefix = `ADJ-${year}-${month}-`;

    const count = this.prisma.financialAdjustment?.count
      ? await this.prisma.financialAdjustment.count({
          where: {
            adjustmentNumber: { startsWith: prefix },
          },
        })
      : 0;

    const safeCount = typeof count === 'number' && !isNaN(count) ? count : 0;
    return `${prefix}${String(safeCount + 1).padStart(5, '0')}`;
  }

  async getVendorEarningsSummary(vendorId: string) {
    const vendorExists = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendorExists) {
      throw new NotFoundException('Vendor not found.');
    }

    const payoutConfig = this.systemConfigService
      ? await this.systemConfigService.getPayoutConfig()
      : { settlementHoldDays: 2 };

    const holdCutoff = new Date(
      Date.now() - (payoutConfig?.settlementHoldDays || 2) * 86400000,
    );

    // 1. Fetch completed bookings with verified PAID payment
    const completedBookings = (await this.prisma.booking.findMany({
      where: {
        vendorId,
        status: 'COMPLETED',
        payment: { status: PaymentStatus.PAID },
      },
    })) || [];

    const totalEarnings = completedBookings.reduce(
      (sum, b) => sum.add(b.netToVendor),
      new Prisma.Decimal(0),
    );

    // 2. Identify bookings within settlement hold window
    const heldBookings = completedBookings.filter(
      (b) => b.updatedAt && b.updatedAt > holdCutoff,
    );
    const heldEarnings = heldBookings.reduce(
      (sum, b) => sum.add(b.netToVendor),
      new Prisma.Decimal(0),
    );

    // 3. Sum amounts for PAID and PENDING payouts
    const paidPayouts = (await this.prisma.payout.findMany({
      where: { vendorId, status: PayoutStatus.PAID },
    })) || [];

    const pendingPayouts = (await this.prisma.payout.findMany({
      where: {
        vendorId,
        status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED, PayoutStatus.PROCESSING] },
      },
    })) || [];

    const totalPaid = paidPayouts.reduce(
      (sum, p) => sum.add(p.amount),
      new Prisma.Decimal(0),
    );

    const totalPending = pendingPayouts.reduce(
      (sum, p) => sum.add(p.amount),
      new Prisma.Decimal(0),
    );

    // 4. Financial Adjustments for vendor
    const adjustments = this.prisma.financialAdjustment?.findMany
      ? (await this.prisma.financialAdjustment.findMany({
          where: { targetType: 'VENDOR', targetId: vendorId },
        })) || []
      : [];

    const netAdjustments = adjustments.reduce((sum, adj) => {
      return adj.direction === LedgerDirection.CREDIT
        ? sum.add(adj.amount)
        : sum.sub(adj.amount);
    }, new Prisma.Decimal(0));

    // 5. Compute available and outstanding balances
    const grossEarnedWithAdj = totalEarnings.add(netAdjustments);
    const availableBalance = grossEarnedWithAdj
      .sub(heldEarnings)
      .sub(totalPaid)
      .sub(totalPending);
    const outstandingBalance = grossEarnedWithAdj.sub(totalPaid);

    // 6. Monthly breakdowns
    const now = new Date();
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    const thisMonthBookings = completedBookings.filter((b) => b.createdAt >= thisMonthStart);
    const thisMonthEarnings = thisMonthBookings.reduce((sum, b) => sum.add(b.netToVendor), new Prisma.Decimal(0));

    const lastMonthBookings = completedBookings.filter(
      (b) => b.createdAt >= lastMonthStart && b.createdAt <= lastMonthEnd,
    );
    const lastMonthEarnings = lastMonthBookings.reduce((sum, b) => sum.add(b.netToVendor), new Prisma.Decimal(0));

    return {
      totalEarnings: totalEarnings.toNumber(),
      heldEarnings: heldEarnings.toNumber(),
      totalPaid: totalPaid.toNumber(),
      totalPending: totalPending.toNumber(),
      netAdjustments: netAdjustments.toNumber(),
      availableBalance: Math.max(0, availableBalance.toNumber()),
      outstandingBalance: Math.max(0, outstandingBalance.toNumber()),
      thisMonthEarnings: thisMonthEarnings.toNumber(),
      lastMonthEarnings: lastMonthEarnings.toNumber(),
    };
  }

  async getDailyEarnings(vendorId: string, days = 30) {
    const vendorExists = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendorExists) {
      throw new NotFoundException('Vendor not found.');
    }

    const limitDate = new Date();
    limitDate.setDate(limitDate.getDate() - days);
    limitDate.setHours(0, 0, 0, 0);

    const bookings = (await this.prisma.booking.findMany({
      where: {
        vendorId,
        status: 'COMPLETED',
        payment: { status: PaymentStatus.PAID },
        createdAt: { gte: limitDate },
      },
      orderBy: { createdAt: 'asc' },
    })) || [];

    const dailyMap = new Map<string, number>();
    for (let i = 0; i <= days; i++) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      dailyMap.set(dateStr, 0);
    }

    for (const b of bookings) {
      const dateStr = b.createdAt.toISOString().split('T')[0];
      if (dailyMap.has(dateStr)) {
        const currentVal = dailyMap.get(dateStr) || 0;
        dailyMap.set(dateStr, currentVal + b.netToVendor.toNumber());
      }
    }

    return Array.from(dailyMap.entries())
      .map(([date, amount]) => ({ date, amount }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async requestPayout(
    vendorId: string,
    dto: RequestPayoutDto,
    initiatedByUserId?: string,
  ) {
    const amount = Number(dto.amount);
    if (amount <= 0 || isNaN(amount)) {
      throw new BadRequestException('Payout amount must be greater than zero.');
    }

    if (dto.idempotencyKey) {
      const existing = await this.prisma.payout.findUnique({
        where: { idempotencyKey: dto.idempotencyKey },
      });
      if (existing) {
        this.logger.log(`[PAYOUT IDEMPOTENT HIT] Key: ${dto.idempotencyKey}`);
        return existing;
      }
    }

    if (this.systemConfigService) {
      const config = await this.systemConfigService.getPayoutConfig();
      if (config?.minPayoutAmount && amount < config.minPayoutAmount) {
        throw new BadRequestException(
          `Minimum payout amount is ₹${config.minPayoutAmount}.`,
        );
      }
      if (config?.maxSinglePayoutAmount && amount > config.maxSinglePayoutAmount) {
        throw new BadRequestException(
          `Maximum single payout amount is ₹${config.maxSinglePayoutAmount}.`,
        );
      }
    }

    return this.prisma.$transaction(async (tx) => {
      const vendor = await tx.vendor.findUnique({
        where: { id: vendorId },
      });
      if (!vendor) {
        throw new NotFoundException('Vendor not found');
      }

      await tx.$queryRaw`SELECT id FROM "Vendor" WHERE id = ${vendorId} FOR UPDATE`;

      if (this.systemConfigService) {
        const config = await this.systemConfigService.getPayoutConfig();
        if (config?.dailyVendorPayoutCap) {
          const todayStart = new Date();
          todayStart.setHours(0, 0, 0, 0);

          const todayPayouts = (await tx.payout.findMany({
            where: {
              vendorId,
              createdAt: { gte: todayStart },
              status: { notIn: [PayoutStatus.REJECTED, PayoutStatus.FAILED] },
            },
          })) || [];

          const todaySum = todayPayouts.reduce(
            (sum, p) => sum.add(p.amount),
            new Prisma.Decimal(0),
          );

          if (todaySum.add(amount).gt(config.dailyVendorPayoutCap)) {
            throw new BadRequestException(
              `Daily payout limit of ₹${config.dailyVendorPayoutCap} exceeded. Already requested/paid today: ₹${todaySum.toNumber()}.`,
            );
          }
        }
      }

      const completed = (await tx.booking.findMany({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
        },
      })) || [];
      const totalEarned = completed.reduce(
        (sum, b) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );

      const paid = (await tx.payout.findMany({
        where: { vendorId, status: PayoutStatus.PAID },
      })) || [];
      const totalPaidAmount = paid.reduce(
        (sum, p) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      const pending = (await tx.payout.findMany({
        where: { vendorId, status: PayoutStatus.PENDING },
      })) || [];
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

      const payoutNumber = await this.generatePayoutNumber();

      const payout = await tx.payout.create({
        data: {
          payoutNumber,
          vendorId,
          amount: reqAmount,
          netAmount: reqAmount,
          status: PayoutStatus.PENDING,
          idempotencyKey: dto.idempotencyKey,
          initiatedByUserId,
          notes: dto.notes,
        },
      });

      if (initiatedByUserId && payout?.id) {
        await this.auditLogService.log(
          initiatedByUserId,
          'PAYOUT_CREATED',
          'Payout',
          payout.id,
          { vendorId, amount: reqAmount.toNumber() },
        );
      }

      if (vendor?.userId && payout?.id) {
        await this.notificationsService.notifyUser(
          vendor.userId,
          'Payout Requested',
          `Your payout request #${payoutNumber} for ₹${amount} has been received.`,
          'VENDOR',
          'PAYOUT_REQUESTED',
          'Payout',
          payout.id,
          `notif_po_req_${payout.id}`,
        );
      }

      return payout;
    });
  }

  async createPayout(vendorId: string, amount: number, adminUserId?: string) {
    return this.requestPayout(vendorId, { vendorId, amount }, adminUserId);
  }

  async approvePayout(payoutId: string, adminUserId: string, dto?: ApprovePayoutDto) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { vendor: true },
    });

    if (!payout) {
      throw new NotFoundException('Payout record not found.');
    }

    if (payout.status !== PayoutStatus.PENDING) {
      throw new BadRequestException(
        `Payout in status '${payout.status}' cannot be approved. Only PENDING payouts can be approved.`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: PayoutStatus.APPROVED,
        approvedByUserId: adminUserId,
        approvedAt: new Date(),
        notes: dto?.adminNotes ? `${payout.notes || ''} | Approval: ${dto.adminNotes}` : payout.notes,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'PAYOUT_APPROVED',
      'Payout',
      payoutId,
      { amount: payout.amount.toNumber(), adminNotes: dto?.adminNotes },
    );

    if (payout.vendor?.userId) {
      await this.notificationsService.notifyUser(
        payout.vendor.userId,
        'Payout Approved',
        `Your payout #${payout.payoutNumber || payout.id} for ₹${payout.amount} has been approved for processing.`,
        'VENDOR',
        'PAYOUT_APPROVED',
        'Payout',
        payout.id,
        `notif_po_app_${payout.id}`,
      );
    }

    return updated;
  }

  async executePayout(
    payoutId: string,
    adminUserId: string,
    dto?: ExecutePayoutDto,
  ) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { vendor: true },
    });

    if (!payout) {
      throw new NotFoundException('Payout record not found.');
    }

    if (payout.status === PayoutStatus.PAID) {
      throw new BadRequestException('Payout is already marked as PAID');
    }

    if (
      payout.status !== PayoutStatus.APPROVED &&
      payout.status !== PayoutStatus.PENDING
    ) {
      throw new BadRequestException(
        `Payout in status '${payout.status}' cannot be executed.`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: PayoutStatus.PAID,
        paidAt: new Date(),
        processedAt: new Date(),
        providerTransferId: dto?.providerTransferId || `manual_tx_${Date.now()}`,
        providerFee: dto?.providerFee ? new Prisma.Decimal(dto.providerFee) : undefined,
        notes: dto?.adminNotes ? `${payout.notes || ''} | Execution: ${dto.adminNotes}` : payout.notes,
      },
      include: {
        vendor: true,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'PAYOUT_EXECUTED',
      'Payout',
      payoutId,
      {
        amount: payout.amount.toNumber(),
        providerTransferId: updated.providerTransferId,
      },
    );

    const vendorUserId = updated.vendor?.userId || payout.vendor?.userId;
    if (vendorUserId) {
      this.notificationsService
        .notifyUser(
          vendorUserId,
          'Payout Marked Paid',
          `Your payout of INR ${updated.amount} has been processed and marked as paid.`,
        )
        .catch((err) =>
          this.logger.error('Failed to notify vendor of payout status change', err),
        );
    }

    return updated;
  }

  async markPayoutPaid(payoutId: string, adminNote?: string) {
    return this.executePayout(payoutId, 'system', { adminNotes: adminNote });
  }

  async rejectPayout(payoutId: string, adminUserId: string, reason: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { vendor: true },
    });

    if (!payout) {
      throw new NotFoundException('Payout record not found.');
    }

    if (
      payout.status !== PayoutStatus.PENDING &&
      payout.status !== PayoutStatus.APPROVED
    ) {
      throw new BadRequestException(
        `Payout in status '${payout.status}' cannot be rejected.`,
      );
    }

    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: PayoutStatus.REJECTED,
        providerFailureReason: reason,
        notes: `${payout.notes || ''} | Rejection Reason: ${reason}`,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'PAYOUT_REJECTED',
      'Payout',
      payoutId,
      { amount: payout.amount.toNumber(), reason },
    );

    if (payout.vendor?.userId) {
      await this.notificationsService.notifyUser(
        payout.vendor.userId,
        'Payout Request Rejected',
        `Your payout request #${payout.payoutNumber || payout.id} was rejected. Reason: ${reason}`,
        'VENDOR',
        'PAYOUT_REJECTED',
        'Payout',
        payout.id,
        `notif_po_rej_${payout.id}`,
      );
    }

    return updated;
  }

  async createFinancialAdjustment(
    adminUserId: string,
    dto: CreateFinancialAdjustmentDto,
  ) {
    const existing = await this.prisma.financialAdjustment.findUnique({
      where: { idempotencyKey: dto.idempotencyKey },
    });
    if (existing) {
      this.logger.log(`[ADJUSTMENT IDEMPOTENT HIT] Key: ${dto.idempotencyKey}`);
      return existing;
    }

    const amount = new Prisma.Decimal(dto.amount);
    const adjustmentNumber = await this.generateAdjustmentNumber();

    const adjustment = await this.prisma.$transaction(async (tx) => {
      const adj = await tx.financialAdjustment.create({
        data: {
          adjustmentNumber,
          targetType: dto.targetType,
          targetId: dto.targetId,
          amount,
          direction: dto.direction,
          reason: dto.reason,
          category: dto.category,
          referenceId: dto.referenceId,
          approvedByUserId: adminUserId,
          idempotencyKey: dto.idempotencyKey,
          metadata: dto.metadata || Prisma.JsonNull,
        },
      });

      if (dto.targetType === 'CUSTOMER_WALLET' && this.walletsService) {
        await this.walletsService.adminAdjustWallet(
          adminUserId,
          {
            walletId: dto.targetId,
            amount: dto.amount,
            direction: dto.direction,
            bucket: WalletBucketType.REAL_MONEY,
            reason: `[${adjustmentNumber}] ${dto.reason}`,
            clientNonce: dto.idempotencyKey,
          },
        );
      }

      await this.auditLogService.log(
        adminUserId,
        'FINANCIAL_ADJUSTMENT_CREATED',
        'FinancialAdjustment',
        adj.id,
        {
          adjustmentNumber,
          targetType: dto.targetType,
          targetId: dto.targetId,
          amount: amount.toNumber(),
          direction: dto.direction,
        },
      );

      return adj;
    });

    return adjustment;
  }

  async getFinancialSummary() {
    const [
      totalGmvRaw,
      totalCommissionsRaw,
      totalPaidPayoutsRaw,
      totalPendingPayoutsRaw,
      totalHeldDepositsRaw,
      walletLiabilitiesRaw,
    ] = await Promise.all([
      this.prisma.payment.aggregate({
        where: { status: PaymentStatus.PAID },
        _sum: { amount: true },
      }),
      this.prisma.booking.aggregate({
        where: { payment: { status: PaymentStatus.PAID } },
        _sum: { platformFee: true },
      }),
      this.prisma.payout.aggregate({
        where: { status: PayoutStatus.PAID },
        _sum: { amount: true },
      }),
      this.prisma.payout.aggregate({
        where: { status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED] } },
        _sum: { amount: true },
      }),
      this.prisma.securityDeposit.aggregate({
        where: { status: 'HELD' },
        _sum: { amount: true },
      }),
      this.prisma.wallet.aggregate({
        _sum: { realBalance: true, promoBalance: true },
      }),
    ]);

    return {
      grossMerchandiseValue: totalGmvRaw._sum?.amount?.toNumber() || 0,
      platformCommissions: totalCommissionsRaw._sum?.platformFee?.toNumber() || 0,
      vendorPayoutsPaid: totalPaidPayoutsRaw._sum?.amount?.toNumber() || 0,
      vendorPayoutsPending: totalPendingPayoutsRaw._sum?.amount?.toNumber() || 0,
      securityDepositsHeld: totalHeldDepositsRaw._sum?.amount?.toNumber() || 0,
      customerWalletLiabilities:
        (walletLiabilitiesRaw._sum?.realBalance?.toNumber() || 0) +
        (walletLiabilitiesRaw._sum?.promoBalance?.toNumber() || 0),
    };
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

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getAllAdjustments(page = 1, limit = 20) {
    const skip = (page - 1) * limit;

    const [total, data] = await Promise.all([
      this.prisma.financialAdjustment.count(),
      this.prisma.financialAdjustment.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          approvedByUser: { select: { id: true, name: true, email: true } },
        },
      }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }
}
