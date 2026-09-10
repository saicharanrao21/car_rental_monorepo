import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
  Optional,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  PayoutStatus,
  PaymentStatus,
  Prisma,
  LedgerDirection,
  WalletBucketType,
  Role,
  LedgerAccountType,
  LedgerEntrySide,
  DamageClaimStatus,
} from '@prisma/client';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { RequestPayoutDto } from './dto/request-payout.dto';
import { ApprovePayoutDto } from './dto/approve-payout.dto';
import { ExecutePayoutDto } from './dto/execute-payout.dto';
import { CreateFinancialAdjustmentDto } from './dto/create-adjustment.dto';
import { WalletsService } from '../wallets/wallets.service';
import { RazorpayXPayoutProvider } from './providers/razorpayx-payout.provider';
import { LedgerCoreService } from '../finance/ledger-core.service';

@Injectable()
export class PayoutsService {
  private readonly logger = new Logger(PayoutsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
    @Optional() private readonly walletsService?: WalletsService,
    @Optional() private readonly payoutGatewayProvider?: RazorpayXPayoutProvider,
    @Optional()
    @Inject(forwardRef(() => LedgerCoreService))
    private readonly ledgerCore?: LedgerCoreService,
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
      : null;

    const holdDays = payoutConfig?.settlementHoldDays ?? 0;
    const holdCutoff =
      holdDays > 0 ? new Date(Date.now() - holdDays * 86400000) : new Date(0);

    const runFindManyFallback = async () => {
      const completedBookings =
        (await this.prisma.booking.findMany({
          where: {
            vendorId,
            status: 'COMPLETED',
            payment: { status: PaymentStatus.PAID },
          },
          include: { damageClaims: true },
        })) || [];

      const cleanCompletedBookings = completedBookings.filter(
        (b: any) =>
          !b.disputeFlag &&
          (!b.damageClaims ||
            !b.damageClaims.some(
              (dc: any) =>
                dc.status === DamageClaimStatus.SUBMITTED ||
                dc.status === DamageClaimStatus.UNDER_REVIEW,
            )),
      );
      const disputedBookings = completedBookings.filter(
        (b: any) =>
          b.disputeFlag ||
          (b.damageClaims &&
            b.damageClaims.some(
              (dc: any) =>
                dc.status === DamageClaimStatus.SUBMITTED ||
                dc.status === DamageClaimStatus.UNDER_REVIEW,
            )),
      );
      const heldBookings =
        holdDays > 0
          ? cleanCompletedBookings.filter(
              (b: any) => new Date(b.updatedAt || b.createdAt) > holdCutoff,
            )
          : [];

      const totalEarnings = cleanCompletedBookings.reduce(
        (sum, b: any) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );
      const disputedEarnings = disputedBookings.reduce(
        (sum, b: any) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );
      const heldEarnings = heldBookings.reduce(
        (sum, b: any) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );

      const paidPayouts =
        (await this.prisma.payout.findMany({
          where: { vendorId, status: PayoutStatus.PAID },
        })) || [];
      const totalPaid = paidPayouts.reduce(
        (sum, p: any) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      const pendingPayouts =
        (await this.prisma.payout.findMany({
          where: {
            vendorId,
            status: {
              in: [
                PayoutStatus.PENDING,
                PayoutStatus.APPROVED,
                PayoutStatus.PROCESSING,
              ],
            },
          },
        })) || [];
      const totalPending = pendingPayouts.reduce(
        (sum, p: any) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      const netAdjustments = new Prisma.Decimal(0);
      const grossEarnedWithAdj = totalEarnings.add(netAdjustments);
      const availableBalance = grossEarnedWithAdj
        .sub(heldEarnings)
        .sub(totalPaid)
        .sub(totalPending);
      const outstandingBalance = grossEarnedWithAdj.sub(totalPaid);

      return {
        totalEarnings: totalEarnings.toNumber(),
        disputedEarnings: disputedEarnings.toNumber(),
        heldEarnings: heldEarnings.toNumber(),
        totalPaid: totalPaid.toNumber(),
        totalPending: totalPending.toNumber(),
        netAdjustments: netAdjustments.toNumber(),
        availableBalance: Math.max(0, availableBalance.toNumber()),
        outstandingBalance: Math.max(0, outstandingBalance.toNumber()),
        thisMonthEarnings: totalEarnings.toNumber(),
        lastMonthEarnings: 0,
      };
    };

    if (typeof (this.prisma.booking as any)?.aggregate !== 'function') {
      return runFindManyFallback();
    }

    const now = new Date();
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    // Database-level parallel aggregation to eliminate unbounded in-memory processing
    const [
      completedAgg,
      disputedAgg,
      heldAgg,
      paidPayoutsAgg,
      pendingPayoutsAgg,
      creditAdjAgg,
      debitAdjAgg,
      thisMonthAgg,
      lastMonthAgg,
      ledgerPayableBalance,
    ] = await Promise.all([
      // 1. Clean completed bookings with payment confirmed PAID
      this.prisma.booking.aggregate({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
          disputeFlag: false,
          damageClaims: {
            none: {
              status: { in: [DamageClaimStatus.SUBMITTED, DamageClaimStatus.UNDER_REVIEW] },
            },
          },
        },
        _sum: { netToVendor: true },
      }),
      // 2. Disputed or active damage claims
      this.prisma.booking.aggregate({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
          OR: [
            { disputeFlag: true },
            {
              damageClaims: {
                some: {
                  status: { in: [DamageClaimStatus.SUBMITTED, DamageClaimStatus.UNDER_REVIEW] },
                },
              },
            },
          ],
        },
        _sum: { netToVendor: true },
      }),
      // 3. Bookings within settlement hold window
      this.prisma.booking.aggregate({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
          disputeFlag: false,
          damageClaims: {
            none: {
              status: { in: [DamageClaimStatus.SUBMITTED, DamageClaimStatus.UNDER_REVIEW] },
            },
          },
          updatedAt: { gt: holdCutoff },
        },
        _sum: { netToVendor: true },
      }),
      // 4. Sum amounts for PAID payouts
      this.prisma.payout.aggregate({
        where: { vendorId, status: PayoutStatus.PAID },
        _sum: { amount: true },
      }),
      // 5. Sum amounts for PENDING / PROCESSING payouts
      this.prisma.payout.aggregate({
        where: {
          vendorId,
          status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED, PayoutStatus.PROCESSING] },
        },
        _sum: { amount: true },
      }),
      // 6. Financial Adjustments (Credit)
      this.prisma.financialAdjustment &&
      typeof this.prisma.financialAdjustment.aggregate === 'function'
        ? this.prisma.financialAdjustment.aggregate({
            where: {
              targetType: 'VENDOR',
              targetId: vendorId,
              direction: LedgerDirection.CREDIT,
            },
            _sum: { amount: true },
          })
        : Promise.resolve({ _sum: { amount: null } } as any),
      // 7. Financial Adjustments (Debit)
      this.prisma.financialAdjustment &&
      typeof this.prisma.financialAdjustment.aggregate === 'function'
        ? this.prisma.financialAdjustment.aggregate({
            where: {
              targetType: 'VENDOR',
              targetId: vendorId,
              direction: LedgerDirection.DEBIT,
            },
            _sum: { amount: true },
          })
        : Promise.resolve({ _sum: { amount: null } } as any),
      // 8. This month earnings
      this.prisma.booking.aggregate({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
          createdAt: { gte: thisMonthStart },
        },
        _sum: { netToVendor: true },
      }),
      // 9. Last month earnings
      this.prisma.booking.aggregate({
        where: {
          vendorId,
          status: 'COMPLETED',
          payment: { status: PaymentStatus.PAID },
          createdAt: { gte: lastMonthStart, lte: lastMonthEnd },
        },
        _sum: { netToVendor: true },
      }),
      // 10. Direct immutable ledger payable balance
      this.ledgerCore
        ? this.ledgerCore.getVendorPayableBalance(vendorId)
        : Promise.resolve(null),
    ]);

    if (completedAgg._sum?.netToVendor === undefined && typeof (this.prisma.booking as any)?.findMany === 'function') {
      return runFindManyFallback();
    }

    const totalEarnings = completedAgg._sum?.netToVendor ?? new Prisma.Decimal(0);
    const disputedEarnings = disputedAgg._sum?.netToVendor ?? new Prisma.Decimal(0);
    const heldEarnings = heldAgg._sum?.netToVendor ?? new Prisma.Decimal(0);
    const totalPaid = paidPayoutsAgg._sum?.amount ?? new Prisma.Decimal(0);
    const totalPending = pendingPayoutsAgg._sum?.amount ?? new Prisma.Decimal(0);
    const netAdjustments = (creditAdjAgg._sum?.amount ?? new Prisma.Decimal(0))
      .sub(debitAdjAgg._sum?.amount ?? new Prisma.Decimal(0));

    const grossEarnedWithAdj = totalEarnings.add(netAdjustments);
    const availableBalance = grossEarnedWithAdj
      .sub(heldEarnings)
      .sub(totalPaid)
      .sub(totalPending);
    const outstandingBalance = grossEarnedWithAdj.sub(totalPaid);

    const thisMonthEarnings = thisMonthAgg._sum?.netToVendor ?? new Prisma.Decimal(0);
    const lastMonthEarnings = lastMonthAgg._sum?.netToVendor ?? new Prisma.Decimal(0);

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
      ledgerPayableBalance: ledgerPayableBalance ? ledgerPayableBalance.toNumber() : undefined,
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

      if (typeof (tx as any).$queryRaw === 'function') {
        await tx.$queryRaw`SELECT id FROM "Vendor" WHERE id = ${vendorId} FOR UPDATE`;
      }

      if (this.systemConfigService) {
        const config = await this.systemConfigService.getPayoutConfig();
        if (config?.dailyVendorPayoutCap) {
          const todayStart = new Date();
          todayStart.setHours(0, 0, 0, 0);

          const todayPayouts = (await tx.payout.findMany({
            where: {
              vendorId,
              createdAt: { gte: todayStart },
              status: { notIn: [PayoutStatus.REJECTED, PayoutStatus.FAILED, PayoutStatus.REVERSED] },
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
        include: {
          damageClaims: true,
        },
      })) || [];

      // Exclude disputed bookings and open damage claims from payout eligibility
      const cleanCompleted = completed.filter(
        (b: any) =>
          !b.disputeFlag &&
          (!b.damageClaims ||
            !b.damageClaims.some(
              (dc: any) =>
                dc.status === 'OPEN' || dc.status === 'UNDER_REVIEW',
            )),
      );

      const totalEarned = cleanCompleted.reduce(
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

      // 1. Reserved payouts includes PENDING, APPROVED, and PROCESSING
      const reserved = (await tx.payout.findMany({
        where: {
          vendorId,
          status: {
            in: [
              PayoutStatus.PENDING,
              PayoutStatus.APPROVED,
              PayoutStatus.PROCESSING,
            ],
          },
        },
      })) || [];
      const totalReservedAmount = reserved.reduce(
        (sum, p) => sum.add(p.amount),
        new Prisma.Decimal(0),
      );

      // 2. Adjustments
      let netAdjustments = new Prisma.Decimal(0);
      if (tx.financialAdjustment) {
        const creditAdjs =
          (await tx.financialAdjustment.findMany({
            where: { targetId: vendorId, direction: LedgerDirection.CREDIT },
          })) || [];
        const debitAdjs =
          (await tx.financialAdjustment.findMany({
            where: { targetId: vendorId, direction: LedgerDirection.DEBIT },
          })) || [];
        const creditSum = creditAdjs.reduce(
          (s, a) => s.add(a.amount),
          new Prisma.Decimal(0),
        );
        const debitSum = debitAdjs.reduce(
          (s, a) => s.add(a.amount),
          new Prisma.Decimal(0),
        );
        netAdjustments = creditSum.sub(debitSum);
      }

      // 3. Settlement hold window
      const payoutConfig = this.systemConfigService
        ? await this.systemConfigService.getPayoutConfig()
        : null;
      const holdDays = payoutConfig?.settlementHoldDays ?? 0;

      let eligibleBookings = cleanCompleted;
      if (holdDays > 0) {
        const holdCutoff = new Date(Date.now() - holdDays * 86400000);
        eligibleBookings = cleanCompleted.filter(
          (b: any) => new Date(b.updatedAt || b.createdAt) <= holdCutoff,
        );
      }
      const totalSettledEarned = eligibleBookings.reduce(
        (sum, b) => sum.add(b.netToVendor),
        new Prisma.Decimal(0),
      );

      const available = totalSettledEarned
        .add(netAdjustments)
        .sub(totalPaidAmount)
        .sub(totalReservedAmount);

      const reqAmount = new Prisma.Decimal(amount);

      if (reqAmount.gt(available)) {
        throw new BadRequestException(
          `Requested payout amount (${amount}) exceeds vendor's available balance (${Math.max(0, available.toNumber())}). Reserved in pending/processing payouts: ${totalReservedAmount.toNumber()}`,
        );
      }

      const payoutNumber = await this.generatePayoutNumber();

      let bankSnapshot: any = null;
      if (vendor.bankDetails) {
        try {
          bankSnapshot =
            typeof vendor.bankDetails === 'string'
              ? JSON.parse(vendor.bankDetails)
              : vendor.bankDetails;
        } catch (_) {
          bankSnapshot = { raw: vendor.bankDetails };
        }
      }

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
          bankAccountSnapshot: bankSnapshot,
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
      payout.status !== PayoutStatus.PENDING &&
      payout.status !== PayoutStatus.PROCESSING
    ) {
      throw new BadRequestException(
        `Payout in status '${payout.status}' cannot be executed.`,
      );
    }

    // 1. If an explicit providerTransferId is supplied by the operator (manual external bank transfer verification)
    if (dto?.providerTransferId && dto.providerTransferId.trim().length > 0) {
      const updated = await this.prisma.payout.update({
        where: { id: payoutId },
        data: {
          status: PayoutStatus.PAID,
          paidAt: new Date(),
          processedAt: new Date(),
          providerTransferId: dto.providerTransferId.trim(),
          providerFee: dto.providerFee ? new Prisma.Decimal(dto.providerFee) : undefined,
          notes: dto.adminNotes
            ? `${payout.notes || ''} | Manual Settlement: ${dto.adminNotes}`
            : payout.notes,
        },
        include: { vendor: true },
      });

      await this.auditLogService.log(
        adminUserId,
        'PAYOUT_EXECUTED_MANUAL',
        'Payout',
        payoutId,
        {
          amount: payout.amount.toNumber(),
          providerTransferId: updated.providerTransferId,
        },
      );

      if (this.ledgerCore) {
        try {
          await this.ledgerCore.recordJournal({
            referenceType: 'PAYOUT',
            referenceId: payoutId,
            payoutId: payoutId,
            vendorId: payout.vendorId,
            description: `Vendor payout settlement #${payout.payoutNumber || payoutId}`,
            idempotencyKey: `ledger_po_exec_${payoutId}`,
            entries: [
              {
                accountType: LedgerAccountType.VENDOR_PAYABLE,
                entrySide: LedgerEntrySide.DEBIT,
                amount: payout.amount,
                description: `Debit vendor payable for payout #${payout.payoutNumber || payoutId}`,
              },
              {
                accountType: LedgerAccountType.GATEWAY_CLEARING,
                accountEntityId: 'RAZORPAY',
                entrySide: LedgerEntrySide.CREDIT,
                amount: payout.amount,
                description: `Credit gateway clearing for payout #${payout.payoutNumber || payoutId}`,
              },
            ],
          });
        } catch (ledgerErr: any) {
          this.logger.error(`Failed to record manual payout ledger journal: ${ledgerErr?.message}`);
        }
      }

      const vendorUserId = updated.vendor?.userId || payout.vendor?.userId;
      if (vendorUserId) {
        this.notificationsService
          .notifyUser(
            vendorUserId,
            'Payout Marked Paid',
            `Your payout of INR ${updated.amount} has been processed and marked as paid (Transfer ID: ${updated.providerTransferId}).`,
          )
          .catch((err) =>
            this.logger.error('Failed to notify vendor of payout status change', err),
          );
      }
      return updated;
    }

    // 2. Automated banking gateway transfer via provider abstraction
    if (this.payoutGatewayProvider) {
      let accountNumber: string | undefined;
      let ifscCode: string | undefined;
      let beneficiaryName: string | undefined;

      const snapshot = payout.bankAccountSnapshot as any;
      if (snapshot) {
        accountNumber = snapshot.accountNumber;
        ifscCode = snapshot.ifscCode;
        beneficiaryName = snapshot.beneficiaryName || snapshot.accountHolderName;
      }
      if (!accountNumber && payout.vendor?.bankDetails) {
        try {
          const parsed =
            typeof payout.vendor.bankDetails === 'string'
              ? JSON.parse(payout.vendor.bankDetails)
              : payout.vendor.bankDetails;
          accountNumber = parsed.accountNumber;
          ifscCode = parsed.ifscCode;
          beneficiaryName =
            parsed.beneficiaryName || parsed.accountHolderName || payout.vendor.ownerName;
        } catch (_) {
          // not JSON
        }
      }

      const result = await this.payoutGatewayProvider.initiateTransfer({
        payoutId: payout.id,
        payoutNumber: payout.payoutNumber || payout.id,
        vendorId: payout.vendorId,
        amount: payout.amount.toNumber(),
        currency: 'INR',
        accountNumber,
        ifscCode,
        beneficiaryName:
          beneficiaryName || payout.vendor?.businessName || payout.vendor?.ownerName,
        idempotencyKey: payout.idempotencyKey || `po_exec_${payout.id}`,
      });

      if (result.status === 'BLOCKED_CREDENTIALS') {
        const updated = await this.prisma.payout.update({
          where: { id: payoutId },
          data: {
            status: PayoutStatus.PROCESSING,
            processedAt: new Date(),
            providerFailureReason: result.failureReason,
            notes: dto?.adminNotes
              ? `${payout.notes || ''} | Gateway: ${result.failureReason}`
              : result.failureReason,
          },
          include: { vendor: true },
        });

        await this.auditLogService.log(
          adminUserId,
          'PAYOUT_DISPATCH_BLOCKED_MISSING_CREDENTIALS',
          'Payout',
          payoutId,
          {
            amount: payout.amount.toNumber(),
            reason: result.failureReason,
          },
        );

        return updated;
      }

      if (result.status === 'PAID') {
        const updated = await this.prisma.$transaction(async (tx) => {
          const p = await tx.payout.update({
            where: { id: payoutId },
            data: {
              status: PayoutStatus.PAID,
              paidAt: new Date(),
              processedAt: new Date(),
              providerTransferId: result.providerTransferId,
              providerFee: result.providerFee ? new Prisma.Decimal(result.providerFee) : undefined,
            },
            include: { vendor: true },
          });

          if (this.ledgerCore) {
            await this.ledgerCore.recordJournal(
              {
                referenceType: 'PAYOUT',
                referenceId: payoutId,
                payoutId: payoutId,
                vendorId: payout.vendorId,
                description: `Vendor payout settlement #${payout.payoutNumber || payoutId}`,
                idempotencyKey: `ledger_po_exec_${payoutId}`,
                entries: [
                  {
                    accountType: LedgerAccountType.VENDOR_PAYABLE,
                    entrySide: LedgerEntrySide.DEBIT,
                    amount: payout.amount,
                    description: `Debit vendor payable for payout #${payout.payoutNumber || payoutId}`,
                  },
                  {
                    accountType: LedgerAccountType.GATEWAY_CLEARING,
                    accountEntityId: 'RAZORPAY',
                    entrySide: LedgerEntrySide.CREDIT,
                    amount: payout.amount,
                    description: `Credit gateway clearing for payout #${payout.payoutNumber || payoutId}`,
                  },
                ],
              },
              tx,
            );
          }

          return p;
        });

        await this.auditLogService.log(
          adminUserId,
          'PAYOUT_EXECUTED',
          'Payout',
          payoutId,
          {
            amount: payout.amount.toNumber(),
            providerTransferId: result.providerTransferId,
          },
        );

        return updated;
      }

      if (result.status === 'PROCESSING' || (result as any).status === 'QUEUED') {
        const updated = await this.prisma.payout.update({
          where: { id: payoutId },
          data: {
            status: PayoutStatus.PROCESSING,
            processedAt: new Date(),
            providerTransferId: result.providerTransferId,
            providerFee: result.providerFee ? new Prisma.Decimal(result.providerFee) : undefined,
          },
          include: { vendor: true },
        });

        await this.auditLogService.log(
          adminUserId,
          'PAYOUT_PROCESSING',
          'Payout',
          payoutId,
          {
            amount: payout.amount.toNumber(),
            providerTransferId: result.providerTransferId,
          },
        );

        return updated;
      }

      if (result.status === 'FAILED') {
        const updated = await this.prisma.payout.update({
          where: { id: payoutId },
          data: {
            status: PayoutStatus.FAILED,
            providerFailureReason: result.failureReason,
          },
          include: { vendor: true },
        });

        await this.auditLogService.log(
          adminUserId,
          'PAYOUT_FAILED',
          'Payout',
          payoutId,
          {
            amount: payout.amount.toNumber(),
            reason: result.failureReason,
          },
        );

        return updated;
      }
    }

    // 3. Fallback: Transition to PROCESSING if no gateway credentials and no manual reference
    const updated = await this.prisma.payout.update({
      where: { id: payoutId },
      data: {
        status: PayoutStatus.PROCESSING,
        processedAt: new Date(),
        providerFailureReason:
          'EXTERNAL CREDENTIAL BLOCKER: Payout gateway credentials unconfigured.',
        notes: dto?.adminNotes
          ? `${payout.notes || ''} | Execution Note: ${dto.adminNotes}`
          : payout.notes,
      },
      include: { vendor: true },
    });

    await this.auditLogService.log(
      adminUserId,
      'PAYOUT_PROCESSING',
      'Payout',
      payoutId,
      { amount: payout.amount.toNumber() },
    );

    return updated;
  }

  async markPayoutPaid(payoutId: string, adminNote?: string) {
    return this.executePayout(payoutId, 'system', {
      adminNotes: adminNote,
      providerTransferId: adminNote || `settled_${Date.now()}`,
    });
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

  async reversePayout(
    payoutId: string,
    adminUserId: string,
    reason?: string,
  ) {
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { vendor: true },
    });

    if (!payout) {
      throw new NotFoundException('Payout record not found.');
    }

    if (payout.status === PayoutStatus.REVERSED) {
      this.logger.log(`Payout ${payoutId} already reversed (idempotent skip)`);
      return payout;
    }

    if (
      payout.status !== PayoutStatus.PAID &&
      payout.status !== PayoutStatus.PROCESSING
    ) {
      throw new BadRequestException(
        `Payout in status '${payout.status}' cannot be reversed. Only PAID or PROCESSING payouts can be reversed.`,
      );
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const p = await tx.payout.update({
        where: { id: payoutId },
        data: {
          status: PayoutStatus.REVERSED,
          providerFailureReason:
            reason || 'Payout reversed by banking network/operator.',
          notes: reason
            ? `${payout.notes || ''} | Reversal: ${reason}`
            : payout.notes,
        },
        include: { vendor: true },
      });

      // If payout was previously marked PAID, reverse the general ledger journal
      if (payout.status === PayoutStatus.PAID && this.ledgerCore) {
        await this.ledgerCore.recordJournal(
          {
            referenceType: 'PAYOUT_REVERSAL',
            referenceId: payoutId,
            payoutId: payoutId,
            vendorId: payout.vendorId,
            description: `Vendor payout reversal #${payout.payoutNumber || payoutId}: ${reason || 'Reversed'}`,
            idempotencyKey: `ledger_po_rev_${payoutId}`,
            entries: [
              {
                accountType: LedgerAccountType.GATEWAY_CLEARING,
                accountEntityId: 'RAZORPAY',
                entrySide: LedgerEntrySide.DEBIT,
                amount: payout.amount,
                description: `Debit gateway clearing (reversal) for payout #${payout.payoutNumber || payoutId}`,
              },
              {
                accountType: LedgerAccountType.VENDOR_PAYABLE,
                entrySide: LedgerEntrySide.CREDIT,
                amount: payout.amount,
                description: `Credit vendor payable (reversal) for payout #${payout.payoutNumber || payoutId}`,
              },
            ],
          },
          tx,
        );
      }

      return p;
    });

    await this.auditLogService.log(
      adminUserId,
      'PAYOUT_REVERSED',
      'Payout',
      payoutId,
      {
        amount: payout.amount.toNumber(),
        previousStatus: payout.status,
        reason,
      },
    );

    if (updated.vendor?.userId) {
      this.notificationsService
        .notifyUser(
          updated.vendor.userId,
          'Payout Reversed',
          `Your payout #${updated.payoutNumber || updated.id} for ₹${updated.amount} was reversed. Reason: ${reason || 'Bank reversal'}. Funds have been restored to your available balance.`,
          'VENDOR',
          'PAYOUT_REVERSED',
          'Payout',
          updated.id,
          `notif_po_rev_${updated.id}`,
        )
        .catch((err) =>
          this.logger.error('Failed to notify vendor of payout reversal', err),
        );
    }

    return updated;
  }

  /**
   * Handles asynchronous webhook events from RazorpayX for automated payouts.
   */
  async handlePayoutWebhook(rawBody: string, signature: string, headers?: any) {
    const webhookSecret =
      process.env.RAZORPAYX_WEBHOOK_SECRET ||
      process.env.RAZORPAY_WEBHOOK_SECRET ||
      'rzp_mock_webhook_secret';

    const isMock =
      process.env.PAYMENT_PROVIDER_MODE === 'MOCK' ||
      process.env.NODE_ENV === 'test';

    if (isMock && (!signature || signature === 'mock_signature')) {
      this.logger.log(
        '[RAZORPAYX-MOCK] Skipping signature verification for mock_signature',
      );
    } else {
      if (!signature) {
        throw new BadRequestException('Webhook signature is missing');
      }
      const isValid = Razorpay.validateWebhookSignature(
        rawBody,
        signature,
        webhookSecret,
      );
      if (!isValid) {
        this.logger.warn(
          'Invalid signature detected in RazorpayX Payout Webhook request',
        );
        throw new BadRequestException('Invalid payout webhook signature');
      }
    }

    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const event = payload.event;
    const payoutEntity = payload.payload?.payout?.entity;

    if (!payoutEntity) {
      this.logger.warn('Payout webhook received without payout entity');
      return { received: true };
    }

    const providerTransferId = payoutEntity.id;
    const payoutNumber = payoutEntity.reference_id;

    // Deduplication via WebhookEvent
    const eventId =
      (headers && (headers['x-razorpay-event-id'] || headers['x-event-id'])) ||
      payload.event_id ||
      payload.id ||
      crypto.createHash('sha256').update(rawBody).digest('hex');

    if (this.prisma.webhookEvent) {
      try {
        await this.prisma.webhookEvent.create({
          data: {
            gateway: 'RAZORPAYX',
            eventId: String(eventId),
            eventType: String(event),
            payload: payload,
            signature: signature || 'none',
            status: 'RECEIVED',
          },
        });
      } catch (err: any) {
        if (
          err.code === 'P2002' ||
          err.message?.includes('Unique constraint') ||
          err.message?.includes('duplicate key')
        ) {
          this.logger.log(
            `[PAYOUT-WEBHOOK-DEDUPLICATION] Duplicate webhook event ${eventId} already received. Skipping.`,
          );
          return { received: true, duplicate: true, alreadyProcessed: true };
        }
      }
    }

    const payout = await this.prisma.payout.findFirst({
      where: {
        OR: [
          ...(providerTransferId ? [{ providerTransferId }] : []),
          ...(payoutNumber ? [{ payoutNumber }] : []),
        ],
      },
      include: { vendor: true },
    });

    if (!payout) {
      this.logger.warn(
        `Payout not found for providerTransferId=${providerTransferId}, payoutNumber=${payoutNumber}`,
      );
      return { received: true, error: 'Payout not found' };
    }

    // Process event types
    if (event === 'payout.processed' || event === 'payout.paid') {
      if (payout.status === PayoutStatus.PAID) {
        this.logger.log(`Payout #${payout.payoutNumber || payout.id} already marked PAID`);
        return { received: true, alreadyProcessed: true };
      }

      const updated = await this.prisma.$transaction(async (tx) => {
        const p = await tx.payout.update({
          where: { id: payout.id },
          data: {
            status: PayoutStatus.PAID,
            paidAt: new Date(),
            processedAt: new Date(),
            providerTransferId: providerTransferId || payout.providerTransferId,
            providerFee: payoutEntity.fees
              ? new Prisma.Decimal(payoutEntity.fees / 100)
              : payout.providerFee,
          },
          include: { vendor: true },
        });

        if (this.ledgerCore) {
          await this.ledgerCore.recordJournal(
            {
              referenceType: 'PAYOUT',
              referenceId: payout.id,
              payoutId: payout.id,
              vendorId: payout.vendorId,
              description: `Vendor payout settlement #${payout.payoutNumber || payout.id}`,
              idempotencyKey: `ledger_po_exec_${payout.id}`,
              entries: [
                {
                  accountType: LedgerAccountType.VENDOR_PAYABLE,
                  entrySide: LedgerEntrySide.DEBIT,
                  amount: payout.amount,
                  description: `Debit vendor payable for payout #${payout.payoutNumber || payout.id}`,
                },
                {
                  accountType: LedgerAccountType.GATEWAY_CLEARING,
                  accountEntityId: 'RAZORPAY',
                  entrySide: LedgerEntrySide.CREDIT,
                  amount: payout.amount,
                  description: `Credit gateway clearing for payout #${payout.payoutNumber || payout.id}`,
                },
              ],
            },
            tx,
          );
        }

        return p;
      });

      await this.auditLogService.log(
        'WEBHOOK_RAZORPAYX',
        'PAYOUT_EXECUTED_WEBHOOK',
        'Payout',
        payout.id,
        {
          amount: payout.amount.toNumber(),
          providerTransferId,
        },
      );

      if (updated.vendor?.userId) {
        this.notificationsService
          .notifyUser(
            updated.vendor.userId,
            'Payout Processed',
            `Your payout #${updated.payoutNumber || updated.id} for ₹${updated.amount} has been successfully settled to your bank account.`,
            'VENDOR',
            'PAYOUT_EXECUTED',
            'Payout',
            updated.id,
            `notif_po_proc_${updated.id}`,
          )
          .catch((err) =>
            this.logger.error('Failed to notify vendor of payout completion', err),
          );
      }

      return { received: true, status: PayoutStatus.PAID };
    }

    if (event === 'payout.reversed') {
      await this.reversePayout(
        payout.id,
        'WEBHOOK_RAZORPAYX',
        payoutEntity.failure_reason || 'Reversed by banking network',
      );
      return { received: true, status: PayoutStatus.REVERSED };
    }

    if (event === 'payout.failed' || event === 'payout.rejected') {
      if (
        payout.status !== PayoutStatus.FAILED &&
        payout.status !== PayoutStatus.REJECTED &&
        payout.status !== PayoutStatus.REVERSED
      ) {
        const failureReason =
          payoutEntity.failure_reason || `Payout was ${event} by RazorpayX.`;

        const updated = await this.prisma.payout.update({
          where: { id: payout.id },
          data: {
            status: PayoutStatus.FAILED,
            providerFailureReason: failureReason,
          },
          include: { vendor: true },
        });

        await this.auditLogService.log(
          'WEBHOOK_RAZORPAYX',
          'PAYOUT_FAILED_WEBHOOK',
          'Payout',
          payout.id,
          {
            amount: payout.amount.toNumber(),
            reason: failureReason,
          },
        );

        if (updated.vendor?.userId) {
          this.notificationsService
            .notifyUser(
              updated.vendor.userId,
              'Payout Failed',
              `Your payout request #${updated.payoutNumber || updated.id} for ₹${updated.amount} failed. Reason: ${failureReason}. The amount is returned to your available balance.`,
              'VENDOR',
              'PAYOUT_FAILED',
              'Payout',
              updated.id,
              `notif_po_fail_${updated.id}`,
            )
            .catch((err) =>
              this.logger.error('Failed to notify vendor of payout failure', err),
            );
        }

        return { received: true, status: PayoutStatus.FAILED };
      }
    }

    return { received: true, event };
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
