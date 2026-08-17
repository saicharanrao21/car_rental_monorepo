import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import {
  BookingStatus,
  LedgerEntryType,
  LoyaltyTierCode,
  LoyaltyTransactionType,
  PaymentStatus,
  Prisma,
  RefundStatus,
  WalletBucketType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { WalletsService } from '../wallets/wallets.service';
import { AdminAdjustLoyaltyDto } from './dto/admin-adjust-loyalty.dto';
import { RedeemPointsDto } from './dto/redeem-points.dto';

@Injectable()
export class LoyaltyService implements OnModuleInit {
  private readonly logger = new Logger(LoyaltyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly walletsService: WalletsService,
  ) {}

  async onModuleInit() {
    await this.ensureTiersExist();
  }

  /**
   * Idempotently seeds default loyalty tiers (Bronze, Silver, Gold, Platinum)
   */
  async ensureTiersExist(): Promise<void> {
    const defaultTiers = [
      {
        code: LoyaltyTierCode.BRONZE,
        name: 'Bronze',
        minPointsRequired: 0,
        pointsMultiplier: new Prisma.Decimal(1.0),
        cashbackPercent: new Prisma.Decimal(1.0),
        prioritySupport: false,
        freeCancellationCount: 0,
      },
      {
        code: LoyaltyTierCode.SILVER,
        name: 'Silver',
        minPointsRequired: 500,
        pointsMultiplier: new Prisma.Decimal(1.25),
        cashbackPercent: new Prisma.Decimal(1.25),
        prioritySupport: false,
        freeCancellationCount: 1,
      },
      {
        code: LoyaltyTierCode.GOLD,
        name: 'Gold',
        minPointsRequired: 2000,
        pointsMultiplier: new Prisma.Decimal(1.5),
        cashbackPercent: new Prisma.Decimal(1.5),
        prioritySupport: true,
        freeCancellationCount: 2,
      },
      {
        code: LoyaltyTierCode.PLATINUM,
        name: 'Platinum',
        minPointsRequired: 5000,
        pointsMultiplier: new Prisma.Decimal(2.0),
        cashbackPercent: new Prisma.Decimal(2.0),
        prioritySupport: true,
        freeCancellationCount: 5,
      },
    ];

    for (const tier of defaultTiers) {
      await this.prisma.loyaltyTier.upsert({
        where: { code: tier.code },
        update: {
          name: tier.name,
          minPointsRequired: tier.minPointsRequired,
          pointsMultiplier: tier.pointsMultiplier,
          cashbackPercent: tier.cashbackPercent,
          prioritySupport: tier.prioritySupport,
          freeCancellationCount: tier.freeCancellationCount,
        },
        create: tier,
      });
    }
    this.logger.log('Default loyalty tiers verified / seeded.');
  }

  /**
   * Retrieves or lazily creates a loyalty account for a user
   */
  async getOrCreateLoyaltyAccount(
    userId: string,
    txClient?: Prisma.TransactionClient,
  ) {
    const client = txClient || this.prisma;
    let account = await client.loyaltyAccount.findUnique({
      where: { userId },
      include: { tier: true },
    });

    if (!account) {
      let bronzeTier = await client.loyaltyTier.findUnique({
        where: { code: LoyaltyTierCode.BRONZE },
      });

      if (!bronzeTier) {
        await this.ensureTiersExist();
        bronzeTier = await client.loyaltyTier.findUnique({
          where: { code: LoyaltyTierCode.BRONZE },
        });
      }

      account = await client.loyaltyAccount.create({
        data: {
          userId,
          tierId: bronzeTier!.id,
          pointsBalance: 0,
          lifetimePoints: 0,
        },
        include: { tier: true },
      });
      this.logger.log(`Created default LoyaltyAccount for user ${userId}`);
    }

    return account;
  }

  /**
   * Retrieves customer loyalty account state with tier progression details
   */
  async getLoyaltyAccount(userId: string) {
    const account = await this.getOrCreateLoyaltyAccount(userId);
    const tiers = await this.prisma.loyaltyTier.findMany({
      orderBy: { minPointsRequired: 'asc' },
    });

    const currentTierIndex = tiers.findIndex((t) => t.id === account.tierId);
    const currentTier = tiers[currentTierIndex] || account.tier;
    const nextTier =
      currentTierIndex >= 0 && currentTierIndex < tiers.length - 1
        ? tiers[currentTierIndex + 1]
        : null;

    let pointsToNextTier = 0;
    let progressPercent = 100.0;

    if (nextTier) {
      pointsToNextTier = Math.max(
        0,
        nextTier.minPointsRequired - account.lifetimePoints,
      );
      const tierSpan =
        nextTier.minPointsRequired - currentTier.minPointsRequired;
      const pointsInTier =
        account.lifetimePoints - currentTier.minPointsRequired;
      progressPercent =
        tierSpan > 0
          ? Math.min(100.0, Math.max(0.0, (pointsInTier / tierSpan) * 100))
          : 100.0;
    }

    const walletEquivalent = Math.floor(account.pointsBalance / 2);

    return {
      id: account.id,
      userId: account.userId,
      tierCode: currentTier.code,
      tierName: currentTier.name,
      pointsMultiplier: Number(currentTier.pointsMultiplier),
      pointsBalance: account.pointsBalance,
      lifetimePoints: account.lifetimePoints,
      walletEquivalent,
      currentTier: {
        code: currentTier.code,
        name: currentTier.name,
        minPointsRequired: currentTier.minPointsRequired,
        pointsMultiplier: Number(currentTier.pointsMultiplier),
        prioritySupport: currentTier.prioritySupport,
        freeCancellationCount: currentTier.freeCancellationCount,
      },
      nextTier: nextTier
        ? {
            code: nextTier.code,
            name: nextTier.name,
            minPointsRequired: nextTier.minPointsRequired,
            pointsMultiplier: Number(nextTier.pointsMultiplier),
            pointsToNextTier,
            progressPercent: Math.round(progressPercent * 10) / 10,
          }
        : null,
      updatedAt: account.updatedAt,
    };
  }

  /**
   * Retrieves paginated transaction history for a user
   */
  async getLoyaltyTransactions(userId: string, page = 1, limit = 20) {
    const account = await this.getOrCreateLoyaltyAccount(userId);
    const skip = (page - 1) * limit;

    const [transactions, total] = await Promise.all([
      this.prisma.loyaltyTransaction.findMany({
        where: { accountId: account.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.loyaltyTransaction.count({
        where: { accountId: account.id },
      }),
    ]);

    return {
      transactions: transactions.map((t) => ({
        id: t.id,
        type: t.type,
        points: t.points,
        balanceBefore: t.balanceBefore,
        balanceAfter: t.balanceAfter,
        referenceType: t.referenceType,
        referenceId: t.referenceId,
        idempotencyKey: t.idempotencyKey,
        description: t.description,
        createdAt: t.createdAt,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Retrieves all available tiers
   */
  async getLoyaltyTiers() {
    const tiers = await this.prisma.loyaltyTier.findMany({
      orderBy: { minPointsRequired: 'asc' },
    });
    return tiers.map((t) => ({
      id: t.id,
      code: t.code,
      name: t.name,
      minPointsRequired: t.minPointsRequired,
      pointsMultiplier: Number(t.pointsMultiplier),
      cashbackPercent: Number(t.cashbackPercent),
      prioritySupport: t.prioritySupport,
      freeCancellationCount: t.freeCancellationCount,
    }));
  }

  /**
   * Pure calculation of eligible loyalty points:
   * basePoints = floor(eligibleBaseFare / 10)
   * finalPoints = floor(basePoints * tierMultiplier)
   */
  calculateEligiblePoints(
    eligibleBaseFare: number,
    tierMultiplier: number,
  ): number {
    if (!eligibleBaseFare || eligibleBaseFare <= 0) return 0;
    const basePoints = Math.floor(eligibleBaseFare / 10);
    const finalPoints = Math.floor(basePoints * tierMultiplier);
    return Math.max(0, finalPoints);
  }

  /**
   * Evaluates the appropriate tier for a given lifetime points balance
   */
  private determineTierForLifetimePoints(
    lifetimePoints: number,
    tiers: Array<{ id: string; code: LoyaltyTierCode; minPointsRequired: number }>,
  ) {
    const sorted = [...tiers].sort(
      (a, b) => b.minPointsRequired - a.minPointsRequired,
    );
    for (const tier of sorted) {
      if (lifetimePoints >= tier.minPointsRequired) {
        return tier;
      }
    }
    return sorted[sorted.length - 1];
  }

  /**
   * Handles booking completion event and credits loyalty points authoritatively
   */
  async handleBookingCompleted(bookingId: string) {
    const idempotencyKey = `loyalty_booking_${bookingId}`;

    const existingTx = await this.prisma.loyaltyTransaction.findUnique({
      where: { idempotencyKey },
    });
    if (existingTx) {
      this.logger.log(
        `Loyalty points already credited for booking ${bookingId} (idempotent no-op)`,
      );
      return {
        alreadyCredited: true,
        points: existingTx.points,
      };
    }

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true },
    });

    if (!booking) {
      this.logger.warn(
        `handleBookingCompleted: Booking ${bookingId} not found`,
      );
      return { earnedPoints: 0, reason: 'Booking not found' };
    }

    if (booking.status !== BookingStatus.COMPLETED) {
      this.logger.warn(
        `handleBookingCompleted: Booking ${bookingId} status is ${booking.status}, expected COMPLETED`,
      );
      return { earnedPoints: 0, reason: 'Booking not completed' };
    }

    if (
      !booking.payment ||
      booking.payment.status !== PaymentStatus.PAID ||
      booking.payment.refundStatus !== RefundStatus.NONE
    ) {
      this.logger.warn(
        `handleBookingCompleted: Booking ${bookingId} payment is invalid or refunded`,
      );
      return { earnedPoints: 0, reason: 'Booking payment not paid/valid' };
    }

    const eligibleBaseFare = Number(booking.baseFare) || 0;
    if (eligibleBaseFare <= 0) {
      this.logger.log(
        `handleBookingCompleted: Booking ${bookingId} base fare is 0, no points earned`,
      );
      return { earnedPoints: 0, reason: 'Base fare is 0' };
    }

    return await this.prisma.$transaction(async (tx) => {
      const doubleCheck = await tx.loyaltyTransaction.findUnique({
        where: { idempotencyKey },
      });
      if (doubleCheck) {
        return { alreadyCredited: true, points: doubleCheck.points };
      }

      await this.getOrCreateLoyaltyAccount(booking.customerId, tx);

      const lockedAccounts = await tx.$queryRaw<
        Array<{
          id: string;
          userId: string;
          tierId: string;
          pointsBalance: number;
          lifetimePoints: number;
        }>
      >`
        SELECT "id", "userId", "tierId", "pointsBalance", "lifetimePoints"
        FROM "LoyaltyAccount"
        WHERE "userId" = ${booking.customerId}
        FOR UPDATE
      `;

      if (!lockedAccounts || lockedAccounts.length === 0) {
        throw new NotFoundException(
          `Loyalty account lock failed for user ${booking.customerId}`,
        );
      }

      const account = lockedAccounts[0];
      const allTiers = await tx.loyaltyTier.findMany({
        orderBy: { minPointsRequired: 'asc' },
      });

      const currentTier =
        allTiers.find((t) => t.id === account.tierId) || allTiers[0];
      const multiplier = Number(currentTier.pointsMultiplier);

      const finalPoints = this.calculateEligiblePoints(
        eligibleBaseFare,
        multiplier,
      );
      if (finalPoints <= 0) {
        return { earnedPoints: 0 };
      }

      const newLifetimePoints = account.lifetimePoints + finalPoints;
      const newPointsBalance = account.pointsBalance + finalPoints;

      const upgradedTier = this.determineTierForLifetimePoints(
        newLifetimePoints,
        allTiers,
      );

      await tx.loyaltyAccount.update({
        where: { id: account.id },
        data: {
          pointsBalance: newPointsBalance,
          lifetimePoints: newLifetimePoints,
          tierId: upgradedTier.id,
        },
      });

      const loyaltyTx = await tx.loyaltyTransaction.create({
        data: {
          accountId: account.id,
          type: LoyaltyTransactionType.TRIP_COMPLETION_EARNED,
          points: finalPoints,
          balanceBefore: account.pointsBalance,
          balanceAfter: newPointsBalance,
          referenceType: 'BOOKING',
          referenceId: booking.id,
          idempotencyKey,
          description: `Earned ${finalPoints} points for completed rental (Base Fare: ₹${eligibleBaseFare.toFixed(2)})`,
        },
      });

      this.logger.log(
        `[LOYALTY] User ${booking.customerId} earned ${finalPoints} points (Tier: ${currentTier.code}, Multiplier: ${multiplier}x, Lifetime: ${newLifetimePoints})`,
      );

      return {
        earnedPoints: finalPoints,
        newPointsBalance,
        newLifetimePoints,
        tierCode: upgradedTier.code,
        transactionId: loyaltyTx.id,
      };
    });
  }

  /**
   * Redeems loyalty points to DriveGo Promotional Wallet Credit (2 points = ₹1)
   */
  async redeemPointsToWallet(userId: string, dto: RedeemPointsDto) {
    if (!dto.points || dto.points < 2 || !Number.isInteger(dto.points)) {
      throw new BadRequestException(
        'Points to redeem must be an integer of at least 2 points (2 points = ₹1)',
      );
    }

    const idempotencyKey =
      dto.idempotencyKey ||
      `loyalty_redeem_${userId}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    return await this.prisma.$transaction(async (tx) => {
      const existingTx = await tx.loyaltyTransaction.findUnique({
        where: { idempotencyKey },
      });
      if (existingTx) {
        throw new ConflictException(
          'Redemption request with this idempotency key was already processed',
        );
      }

      await this.getOrCreateLoyaltyAccount(userId, tx);

      const lockedAccounts = await tx.$queryRaw<
        Array<{
          id: string;
          userId: string;
          tierId: string;
          pointsBalance: number;
          lifetimePoints: number;
        }>
      >`
        SELECT "id", "userId", "tierId", "pointsBalance", "lifetimePoints"
        FROM "LoyaltyAccount"
        WHERE "userId" = ${userId}
        FOR UPDATE
      `;

      if (!lockedAccounts || lockedAccounts.length === 0) {
        throw new NotFoundException(`Loyalty account not found for user ${userId}`);
      }

      const account = lockedAccounts[0];

      if (account.pointsBalance < dto.points) {
        throw new BadRequestException(
          `Insufficient loyalty points. Available: ${account.pointsBalance}, Requested: ${dto.points}`,
        );
      }

      const walletCreditAmount = Math.floor(dto.points / 2);
      if (walletCreditAmount <= 0) {
        throw new BadRequestException('Redemption must yield at least ₹1 wallet credit');
      }

      const actualPointsRedeemed = walletCreditAmount * 2;
      const newPointsBalance = account.pointsBalance - actualPointsRedeemed;

      await tx.loyaltyAccount.update({
        where: { id: account.id },
        data: {
          pointsBalance: newPointsBalance,
        },
      });

      const loyaltyTx = await tx.loyaltyTransaction.create({
        data: {
          accountId: account.id,
          type: LoyaltyTransactionType.REDEMPTION_TO_WALLET,
          points: actualPointsRedeemed,
          balanceBefore: account.pointsBalance,
          balanceAfter: newPointsBalance,
          referenceType: 'WALLET',
          idempotencyKey,
          description: `Converted ${actualPointsRedeemed} points to ₹${walletCreditAmount} DriveGo Promotional Wallet balance`,
        },
      });

      const userWallet = await this.walletsService.getOrCreateWallet(userId, tx);

      const walletLedger = await this.walletsService.creditWallet(
        userWallet.id,
        new Prisma.Decimal(walletCreditAmount),
        LedgerEntryType.LOYALTY_CONVERSION,
        WalletBucketType.PROMOTIONAL,
        'LOYALTY',
        loyaltyTx.id,
        `wallet_loyalty_redeem_${loyaltyTx.id}`,
        `Loyalty points conversion: ${actualPointsRedeemed} points`,
        undefined,
        {
          loyaltyAccountId: account.id,
          loyaltyTransactionId: loyaltyTx.id,
          pointsRedeemed: actualPointsRedeemed,
        },
        tx,
      );

      this.logger.log(
        `[LOYALTY REDEEM] User ${userId} converted ${actualPointsRedeemed} points -> ₹${walletCreditAmount} wallet credit (New Points: ${newPointsBalance})`,
      );

      return {
        success: true,
        redeemedPoints: actualPointsRedeemed,
        walletCreditAmount,
        newPointsBalance,
        lifetimePoints: account.lifetimePoints,
        transactionId: loyaltyTx.id,
        walletLedgerEntryId: walletLedger.id,
      };
    });
  }

  /**
   * Admin: Summary metrics for platform loyalty performance and liabilities
   */
  async getAdminLoyaltySummary() {
    const tiers = await this.prisma.loyaltyTier.findMany({
      orderBy: { minPointsRequired: 'asc' },
    });

    const [totalAccounts, pointStats, tierCounts] = await Promise.all([
      this.prisma.loyaltyAccount.count(),
      this.prisma.loyaltyAccount.aggregate({
        _sum: {
          pointsBalance: true,
          lifetimePoints: true,
        },
      }),
      this.prisma.loyaltyAccount.groupBy({
        by: ['tierId'],
        _count: { id: true },
      }),
    ]);

    const totalAvailablePoints = pointStats._sum.pointsBalance || 0;
    const totalLifetimePoints = pointStats._sum.lifetimePoints || 0;
    const totalPointsRedeemed = Math.max(0, totalLifetimePoints - totalAvailablePoints);
    const outstandingLiabilityInr = Math.floor(totalAvailablePoints / 2);

    const tierBreakdown = tiers.map((tier) => {
      const match = tierCounts.find((tc) => tc.tierId === tier.id);
      return {
        code: tier.code,
        name: tier.name,
        minPoints: tier.minPointsRequired,
        multiplier: Number(tier.pointsMultiplier),
        accountCount: match ? match._count.id : 0,
      };
    });

    return {
      totalAccounts,
      totalLifetimePoints,
      totalAvailablePoints,
      totalPointsRedeemed,
      outstandingLiabilityInr,
      tierBreakdown,
    };
  }

  /**
   * Admin: Paginated list of loyalty accounts with customer info and search
   */
  async getAdminLoyaltyAccounts(
    search?: string,
    tierCode?: LoyaltyTierCode,
    page = 1,
    limit = 20,
  ) {
    const skip = (page - 1) * limit;
    const where: Prisma.LoyaltyAccountWhereInput = {};

    if (tierCode) {
      where.tier = { code: tierCode };
    }

    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.user = {
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { phone: { contains: q } },
          { email: { contains: q, mode: 'insensitive' } },
        ],
      };
    }

    const [accounts, total] = await Promise.all([
      this.prisma.loyaltyAccount.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              phone: true,
              email: true,
            },
          },
          tier: true,
        },
        orderBy: { lifetimePoints: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.loyaltyAccount.count({ where }),
    ]);

    return {
      accounts: accounts.map((acc) => ({
        id: acc.id,
        userId: acc.userId,
        userName: acc.user.name,
        userPhone: acc.user.phone,
        userEmail: acc.user.email,
        tierCode: acc.tier.code,
        tierName: acc.tier.name,
        pointsBalance: acc.pointsBalance,
        lifetimePoints: acc.lifetimePoints,
        walletEquivalent: Math.floor(acc.pointsBalance / 2),
        updatedAt: acc.updatedAt,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Admin: Manual point adjustment with audit logging
   */
  async adminAdjustPoints(adminUserId: string, dto: AdminAdjustLoyaltyDto) {
    if (dto.points === 0) {
      throw new BadRequestException('Adjustment points cannot be zero');
    }

    return await this.prisma.$transaction(async (tx) => {
      const existingTx = await tx.loyaltyTransaction.findUnique({
        where: { idempotencyKey: dto.idempotencyKey },
      });
      if (existingTx) {
        throw new ConflictException(
          'Adjustment with this idempotency key has already been processed',
        );
      }

      await this.getOrCreateLoyaltyAccount(dto.userId, tx);

      const lockedAccounts = await tx.$queryRaw<
        Array<{
          id: string;
          userId: string;
          tierId: string;
          pointsBalance: number;
          lifetimePoints: number;
        }>
      >`
        SELECT "id", "userId", "tierId", "pointsBalance", "lifetimePoints"
        FROM "LoyaltyAccount"
        WHERE "userId" = ${dto.userId}
        FOR UPDATE
      `;

      if (!lockedAccounts || lockedAccounts.length === 0) {
        throw new NotFoundException(`Loyalty account not found for user ${dto.userId}`);
      }

      const account = lockedAccounts[0];

      if (dto.points < 0 && account.pointsBalance + dto.points < 0) {
        throw new BadRequestException(
          `Deduction of ${Math.abs(dto.points)} points exceeds available balance ${account.pointsBalance}`,
        );
      }

      const newPointsBalance = account.pointsBalance + dto.points;
      const newLifetimePoints =
        dto.points > 0
          ? account.lifetimePoints + dto.points
          : account.lifetimePoints;

      const allTiers = await tx.loyaltyTier.findMany({
        orderBy: { minPointsRequired: 'asc' },
      });
      const newTier = this.determineTierForLifetimePoints(
        newLifetimePoints,
        allTiers,
      );

      await tx.loyaltyAccount.update({
        where: { id: account.id },
        data: {
          pointsBalance: newPointsBalance,
          lifetimePoints: newLifetimePoints,
          tierId: newTier.id,
        },
      });

      const loyaltyTx = await tx.loyaltyTransaction.create({
        data: {
          accountId: account.id,
          type: LoyaltyTransactionType.ADMIN_ADJUSTMENT,
          points: Math.abs(dto.points),
          balanceBefore: account.pointsBalance,
          balanceAfter: newPointsBalance,
          referenceType: 'ADMIN',
          referenceId: adminUserId,
          idempotencyKey: dto.idempotencyKey,
          description: `Admin adjustment: ${dto.reason}`,
        },
      });

      await tx.auditLog.create({
        data: {
          adminUserId,
          action: 'LOYALTY_POINT_ADJUSTMENT',
          targetType: 'LoyaltyAccount',
          targetId: account.id,
          metadata: {
            userId: dto.userId,
            pointsAdjusted: dto.points,
            balanceBefore: account.pointsBalance,
            balanceAfter: newPointsBalance,
            reason: dto.reason,
            idempotencyKey: dto.idempotencyKey,
          },
        },
      });

      this.logger.log(
        `[ADMIN LOYALTY ADJUST] Admin ${adminUserId} adjusted ${dto.points} pts for user ${dto.userId} (New Balance: ${newPointsBalance}, Reason: ${dto.reason})`,
      );

      return {
        success: true,
        pointsAdjusted: dto.points,
        newPointsBalance,
        newLifetimePoints,
        tierCode: newTier.code,
        transactionId: loyaltyTx.id,
      };
    });
  }
}
