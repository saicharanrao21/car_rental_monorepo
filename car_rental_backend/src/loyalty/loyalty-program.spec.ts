import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  LedgerEntryType,
  LoyaltyTierCode,
  LoyaltyTransactionType,
  PaymentStatus,
  Prisma,
  RefundStatus,
  Role,
  WalletBucketType,
} from '@prisma/client';
import { LoyaltyService } from './loyalty.service';

describe('DriveGo Loyalty Program Specification (Feature 25)', () => {
  let service: LoyaltyService;
  let mockPrisma: any;
  let mockWalletsService: any;

  const mockTiers = [
    {
      id: 'tier_bronze',
      code: LoyaltyTierCode.BRONZE,
      name: 'Bronze',
      minPointsRequired: 0,
      pointsMultiplier: new Prisma.Decimal(1.0),
      cashbackPercent: new Prisma.Decimal(1.0),
      prioritySupport: false,
      freeCancellationCount: 0,
    },
    {
      id: 'tier_silver',
      code: LoyaltyTierCode.SILVER,
      name: 'Silver',
      minPointsRequired: 500,
      pointsMultiplier: new Prisma.Decimal(1.25),
      cashbackPercent: new Prisma.Decimal(1.25),
      prioritySupport: false,
      freeCancellationCount: 1,
    },
    {
      id: 'tier_gold',
      code: LoyaltyTierCode.GOLD,
      name: 'Gold',
      minPointsRequired: 2000,
      pointsMultiplier: new Prisma.Decimal(1.5),
      cashbackPercent: new Prisma.Decimal(1.5),
      prioritySupport: true,
      freeCancellationCount: 2,
    },
    {
      id: 'tier_platinum',
      code: LoyaltyTierCode.PLATINUM,
      name: 'Platinum',
      minPointsRequired: 5000,
      pointsMultiplier: new Prisma.Decimal(2.0),
      cashbackPercent: new Prisma.Decimal(2.0),
      prioritySupport: true,
      freeCancellationCount: 5,
    },
  ];

  beforeEach(() => {
    mockPrisma = {
      loyaltyTier: {
        upsert: jest.fn().mockImplementation((args) => Promise.resolve(args.create)),
        findMany: jest.fn().mockResolvedValue(mockTiers),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.code) return Promise.resolve(mockTiers.find((t) => t.code === where.code));
          if (where.id) return Promise.resolve(mockTiers.find((t) => t.id === where.id));
          return Promise.resolve(null);
        }),
      },
      loyaltyAccount: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        count: jest.fn().mockResolvedValue(100),
        findMany: jest.fn().mockResolvedValue([]),
        aggregate: jest.fn().mockResolvedValue({
          _sum: { pointsBalance: 25000, lifetimePoints: 75000 },
        }),
        groupBy: jest.fn().mockResolvedValue([
          { tierId: 'tier_bronze', _count: { id: 70 } },
          { tierId: 'tier_silver', _count: { id: 20 } },
          { tierId: 'tier_gold', _count: { id: 8 } },
          { tierId: 'tier_platinum', _count: { id: 2 } },
        ]),
      },
      loyaltyTransaction: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      booking: {
        findUnique: jest.fn(),
      },
      auditLog: {
        create: jest.fn().mockResolvedValue({ id: 'audit_123' }),
      },
      $queryRaw: jest.fn(),
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return await callback(mockPrisma);
      }),
    };

    mockWalletsService = {
      getOrCreateWallet: jest.fn().mockResolvedValue({ id: 'wallet_cust_1' }),
      creditWallet: jest.fn().mockResolvedValue({
        id: 'ledger_entry_123',
        walletId: 'wallet_cust_1',
        amount: new Prisma.Decimal(250),
        bucket: WalletBucketType.PROMOTIONAL,
        type: LedgerEntryType.LOYALTY_CONVERSION,
      }),
    };

    service = new LoyaltyService(mockPrisma as any, mockWalletsService as any);
  });

  describe('Point Calculation Formula & Rounding (1 pt per ₹10 base fare)', () => {
    it('1. Bronze multiplier (1.00x) calculates floor(baseFare / 10)', () => {
      expect(service.calculateEligiblePoints(1000, 1.0)).toBe(100);
      expect(service.calculateEligiblePoints(999, 1.0)).toBe(99);
      expect(service.calculateEligiblePoints(9, 1.0)).toBe(0);
      expect(service.calculateEligiblePoints(0, 1.0)).toBe(0);
    });

    it('2. Silver multiplier (1.25x) calculates floor(floor(baseFare / 10) * 1.25)', () => {
      // 1000 -> 100 base -> floor(100 * 1.25) = 125
      expect(service.calculateEligiblePoints(1000, 1.25)).toBe(125);
      // 999 -> 99 base -> floor(99 * 1.25) = 123
      expect(service.calculateEligiblePoints(999, 1.25)).toBe(123);
    });

    it('3. Gold multiplier (1.50x) calculates floor(floor(baseFare / 10) * 1.50)', () => {
      // 1000 -> 100 base -> floor(100 * 1.5) = 150
      expect(service.calculateEligiblePoints(1000, 1.5)).toBe(150);
      // 1550 -> 155 base -> floor(155 * 1.5) = 232
      expect(service.calculateEligiblePoints(1550, 1.5)).toBe(232);
    });

    it('4. Platinum multiplier (2.00x) calculates floor(floor(baseFare / 10) * 2.00)', () => {
      // 1000 -> 100 base -> floor(100 * 2.0) = 200
      expect(service.calculateEligiblePoints(1000, 2.0)).toBe(200);
      // 2500 -> 250 base -> floor(250 * 2.0) = 500
      expect(service.calculateEligiblePoints(2500, 2.0)).toBe(500);
    });

    it('5. Floor rounding prevents fractional loyalty points', () => {
      // ₹1,495 -> 149 base pts * 1.25 = 186.25 -> 186 pts
      expect(service.calculateEligiblePoints(1495, 1.25)).toBe(186);
    });
  });

  describe('Booking Completion Lifecycle Event Hook', () => {
    it('6. Successfully credits points on COMPLETED paid booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_101',
        customerId: 'user_cust_1',
        baseFare: new Prisma.Decimal(2000),
        totalFare: new Prisma.Decimal(2360),
        status: BookingStatus.COMPLETED,
        payment: {
          id: 'pay_101',
          status: PaymentStatus.PAID,
          refundStatus: RefundStatus.NONE,
        },
      });

      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_101',
        userId: 'user_cust_1',
        tierId: 'tier_bronze',
        pointsBalance: 100,
        lifetimePoints: 100,
        tier: mockTiers[0],
      });

      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_101',
          userId: 'user_cust_1',
          tierId: 'tier_bronze',
          pointsBalance: 100,
          lifetimePoints: 100,
        },
      ]);

      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_1' });
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});

      const result = await service.handleBookingCompleted('book_101');

      expect(result.earnedPoints).toBe(200); // 2000 / 10 = 200 * 1.0
      expect(result.newPointsBalance).toBe(300);
      expect(result.newLifetimePoints).toBe(300);
      expect(mockPrisma.loyaltyTransaction.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          type: LoyaltyTransactionType.TRIP_COMPLETION_EARNED,
          points: 200,
          idempotencyKey: 'loyalty_booking_book_101',
        }),
      });
    });

    it('7. Automatically upgrades tier when lifetime points cross threshold (Silver >= 500)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_upgrade',
        customerId: 'user_cust_upgrade',
        baseFare: new Prisma.Decimal(4000), // 400 pts
        status: BookingStatus.COMPLETED,
        payment: { status: PaymentStatus.PAID, refundStatus: RefundStatus.NONE },
      });

      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_upgrade',
          userId: 'user_cust_upgrade',
          tierId: 'tier_bronze',
          pointsBalance: 200,
          lifetimePoints: 200, // 200 + 400 = 600 pts -> SILVER
        },
      ]);

      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_upgrade',
        userId: 'user_cust_upgrade',
        tierId: 'tier_bronze',
        tier: mockTiers[0],
      });

      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_upgrade' });
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});

      const result = await service.handleBookingCompleted('book_upgrade');

      expect(result.earnedPoints).toBe(400);
      expect(result.newLifetimePoints).toBe(600);
      expect(result.tierCode).toBe(LoyaltyTierCode.SILVER);
      expect(mockPrisma.loyaltyAccount.update).toHaveBeenCalledWith({
        where: { id: 'acc_upgrade' },
        data: expect.objectContaining({
          tierId: 'tier_silver',
        }),
      });
    });

    it('8. Duplicate completion event is idempotent and does not award points twice', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue({
        id: 'ltx_existing',
        points: 200,
        idempotencyKey: 'loyalty_booking_book_dup',
      });

      const result = await service.handleBookingCompleted('book_dup');

      expect(result.alreadyCredited).toBe(true);
      expect(result.points).toBe(200);
      expect(mockPrisma.loyaltyAccount.update).not.toHaveBeenCalled();
    });

    it('9. Non-COMPLETED booking earns zero points', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_ongoing',
        status: BookingStatus.ONGOING,
        baseFare: new Prisma.Decimal(2000),
        payment: { status: PaymentStatus.PAID, refundStatus: RefundStatus.NONE },
      });
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);

      const result = await service.handleBookingCompleted('book_ongoing');
      expect(result.earnedPoints).toBe(0);
      expect(result.reason).toBe('Booking not completed');
    });

    it('10. Cancelled booking earns zero points', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_cancelled',
        status: BookingStatus.CANCELLED,
        baseFare: new Prisma.Decimal(2000),
        payment: { status: PaymentStatus.REFUNDED, refundStatus: RefundStatus.PROCESSED },
      });
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);

      const result = await service.handleBookingCompleted('book_cancelled');
      expect(result.earnedPoints).toBe(0);
    });

    it('11. Refunded booking earns zero points', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_refunded',
        status: BookingStatus.COMPLETED,
        baseFare: new Prisma.Decimal(2000),
        payment: { status: PaymentStatus.PAID, refundStatus: RefundStatus.PROCESSED },
      });
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);

      const result = await service.handleBookingCompleted('book_refunded');
      expect(result.earnedPoints).toBe(0);
    });

    it('12. Unpaid booking earns zero points', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_unpaid',
        status: BookingStatus.COMPLETED,
        baseFare: new Prisma.Decimal(2000),
        payment: { status: PaymentStatus.FAILED, refundStatus: RefundStatus.NONE },
      });
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);

      const result = await service.handleBookingCompleted('book_unpaid');
      expect(result.earnedPoints).toBe(0);
    });

    it('13. Excludes GST, security deposits, delivery fees, and insurance from points', async () => {
      // Authoritative baseFare = 1500, totalFare = 6000 (includes 3000 deposit + 270 GST + 500 insurance + 730 fees)
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_fare_breakdown',
        customerId: 'user_cust_1',
        baseFare: new Prisma.Decimal(1500),
        totalFare: new Prisma.Decimal(6000),
        status: BookingStatus.COMPLETED,
        payment: { status: PaymentStatus.PAID, refundStatus: RefundStatus.NONE },
      });

      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_1',
          userId: 'user_cust_1',
          tierId: 'tier_bronze',
          pointsBalance: 0,
          lifetimePoints: 0,
        },
      ]);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_1',
        userId: 'user_cust_1',
        tier: mockTiers[0],
      });
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_fare' });
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});

      const result = await service.handleBookingCompleted('book_fare_breakdown');

      // 1500 / 10 = 150 points (NOT 6000 / 10 = 600)
      expect(result.earnedPoints).toBe(150);
    });

    it('14. Excludes referral discount from points (only rental base fare is used)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_ref_discount',
        customerId: 'user_cust_1',
        baseFare: new Prisma.Decimal(1200),
        totalFare: new Prisma.Decimal(1166), // 1200 - 250 referral + 216 GST
        status: BookingStatus.COMPLETED,
        payment: { status: PaymentStatus.PAID, refundStatus: RefundStatus.NONE },
      });

      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_1',
          userId: 'user_cust_1',
          tierId: 'tier_bronze',
          pointsBalance: 0,
          lifetimePoints: 0,
        },
      ]);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_1',
        userId: 'user_cust_1',
        tier: mockTiers[0],
      });
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_ref' });
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});

      const result = await service.handleBookingCompleted('book_ref_discount');
      expect(result.earnedPoints).toBe(120); // 1200 / 10 = 120
    });
  });

  describe('Wallet Redemption Integration (2 points = ₹1)', () => {
    it('15. Converts 500 points into exactly ₹250 promotional wallet credit', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_redeem',
        userId: 'user_cust_1',
        pointsBalance: 1000,
        lifetimePoints: 2500, // Gold member
        tier: mockTiers[2],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_redeem',
          userId: 'user_cust_1',
          tierId: 'tier_gold',
          pointsBalance: 1000,
          lifetimePoints: 2500,
        },
      ]);
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_redeem_1' });

      const result = await service.redeemPointsToWallet('user_cust_1', {
        points: 500,
      });

      expect(result.success).toBe(true);
      expect(result.redeemedPoints).toBe(500);
      expect(result.walletCreditAmount).toBe(250);
      expect(result.newPointsBalance).toBe(500);
      expect(result.lifetimePoints).toBe(2500); // LIFETIME POINTS PRESERVED!

      expect(mockWalletsService.creditWallet).toHaveBeenCalledWith(
        'wallet_cust_1',
        new Prisma.Decimal(250),
        LedgerEntryType.LOYALTY_CONVERSION,
        WalletBucketType.PROMOTIONAL,
        'LOYALTY',
        'ltx_redeem_1',
        'wallet_loyalty_redeem_ltx_redeem_1',
        'Loyalty points conversion: 500 points',
        undefined,
        expect.objectContaining({
          loyaltyAccountId: 'acc_redeem',
          pointsRedeemed: 500,
        }),
        expect.anything(),
      );
    });

    it('16. Preserves user tier upon redemption (no downgrade after spending points)', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_gold',
        userId: 'user_gold',
        pointsBalance: 2000,
        lifetimePoints: 2500, // GOLD
        tier: mockTiers[2],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_gold',
          userId: 'user_gold',
          tierId: 'tier_gold',
          pointsBalance: 2000,
          lifetimePoints: 2500,
        },
      ]);
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_gold_redeem' });

      const result = await service.redeemPointsToWallet('user_gold', {
        points: 1500, // available drops from 2000 to 500
      });

      expect(result.newPointsBalance).toBe(500);
      expect(result.lifetimePoints).toBe(2500);
      // Verify tierId is NOT modified to a lower tier
      expect(mockPrisma.loyaltyAccount.update).toHaveBeenCalledWith({
        where: { id: 'acc_gold' },
        data: {
          pointsBalance: 500,
        },
      });
    });

    it('17. Handles odd-point redemption safely (e.g. 501 points -> 500 redeemed for ₹250, 1 remains)', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_odd',
        userId: 'user_odd',
        pointsBalance: 501,
        lifetimePoints: 501,
        tier: mockTiers[1],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_odd',
          userId: 'user_odd',
          tierId: 'tier_silver',
          pointsBalance: 501,
          lifetimePoints: 501,
        },
      ]);
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_odd' });

      const result = await service.redeemPointsToWallet('user_odd', {
        points: 501,
      });

      expect(result.redeemedPoints).toBe(500);
      expect(result.walletCreditAmount).toBe(250);
      expect(result.newPointsBalance).toBe(1); // 501 - 500 = 1
    });

    it('18. Rejects redemption if requested points exceed available balance', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_poor',
        userId: 'user_poor',
        pointsBalance: 100,
        lifetimePoints: 100,
        tier: mockTiers[0],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_poor',
          userId: 'user_poor',
          tierId: 'tier_bronze',
          pointsBalance: 100,
          lifetimePoints: 100,
        },
      ]);

      await expect(
        service.redeemPointsToWallet('user_poor', { points: 500 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('19. Rejects redemption of less than 2 points', async () => {
      await expect(
        service.redeemPointsToWallet('user_cust_1', { points: 1 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('20. Duplicate redemption idempotency key is rejected with ConflictException', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue({
        id: 'ltx_duplicate',
      });

      await expect(
        service.redeemPointsToWallet('user_cust_1', {
          points: 500,
          idempotencyKey: 'idemp_duplicate_123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('21. Atomic rollback when wallet credit fails (points remain un-deducted)', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_fail',
        userId: 'user_fail',
        pointsBalance: 1000,
        lifetimePoints: 1000,
        tier: mockTiers[1],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_fail',
          userId: 'user_fail',
          tierId: 'tier_silver',
          pointsBalance: 1000,
          lifetimePoints: 1000,
        },
      ]);
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_fail' });

      mockWalletsService.creditWallet.mockRejectedValue(
        new Error('Wallet ledger write error'),
      );

      await expect(
        service.redeemPointsToWallet('user_fail', { points: 500 }),
      ).rejects.toThrow('Wallet ledger write error');
    });
  });

  describe('Admin Operations & Governance', () => {
    it('22. Admin can manually credit points with mandatory audit logging', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_target',
        userId: 'user_target',
        pointsBalance: 200,
        lifetimePoints: 200,
        tier: mockTiers[0],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_target',
          userId: 'user_target',
          tierId: 'tier_bronze',
          pointsBalance: 200,
          lifetimePoints: 200,
        },
      ]);
      mockPrisma.loyaltyAccount.update.mockResolvedValue({});
      mockPrisma.loyaltyTransaction.create.mockResolvedValue({ id: 'ltx_adj_1' });

      const result = await service.adminAdjustPoints('admin_super', {
        userId: 'user_target',
        points: 300,
        reason: 'Compensation for verified support ticket #TK-1002',
        idempotencyKey: 'adj_key_1002',
      });

      expect(result.success).toBe(true);
      expect(result.newPointsBalance).toBe(500);
      expect(result.newLifetimePoints).toBe(500);
      expect(result.tierCode).toBe(LoyaltyTierCode.SILVER); // Automatically upgraded
      expect(mockPrisma.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          adminUserId: 'admin_super',
          action: 'LOYALTY_POINT_ADJUSTMENT',
          targetType: 'LoyaltyAccount',
        }),
      });
    });

    it('23. Admin cannot adjust points to negative balance', async () => {
      mockPrisma.loyaltyTransaction.findUnique.mockResolvedValue(null);
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_target',
        userId: 'user_target',
        pointsBalance: 100,
        lifetimePoints: 100,
        tier: mockTiers[0],
      });
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          id: 'acc_target',
          userId: 'user_target',
          tierId: 'tier_bronze',
          pointsBalance: 100,
          lifetimePoints: 100,
        },
      ]);

      await expect(
        service.adminAdjustPoints('admin_super', {
          userId: 'user_target',
          points: -200,
          reason: 'Penalty deduction',
          idempotencyKey: 'adj_fail_negative',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('24. Admin summary accurately reports outstanding liability and tier distribution', async () => {
      const summary = await service.getAdminLoyaltySummary();

      expect(summary.totalAccounts).toBe(100);
      expect(summary.totalLifetimePoints).toBe(75000);
      expect(summary.totalAvailablePoints).toBe(25000);
      expect(summary.totalPointsRedeemed).toBe(50000);
      expect(summary.outstandingLiabilityInr).toBe(12500); // 25,000 / 2 = ₹12,500
      expect(summary.tierBreakdown).toHaveLength(4);
    });
  });

  describe('Customer Progress & Tier Progression', () => {
    it('25. getLoyaltyAccount returns accurate progress percentage to next tier', async () => {
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_prog',
        userId: 'user_prog',
        tierId: 'tier_bronze',
        pointsBalance: 250,
        lifetimePoints: 250, // 250 / 500 = 50% to Silver
        tier: mockTiers[0],
        updatedAt: new Date(),
      });

      const account = await service.getLoyaltyAccount('user_prog');

      expect(account.tierCode).toBe(LoyaltyTierCode.BRONZE);
      expect(account.pointsBalance).toBe(250);
      expect(account.walletEquivalent).toBe(125); // ₹125
      expect(account.nextTier).toBeDefined();
      expect(account.nextTier?.code).toBe(LoyaltyTierCode.SILVER);
      expect(account.nextTier?.pointsToNextTier).toBe(250);
      expect(account.nextTier?.progressPercent).toBe(50.0);
    });

    it('26. Platinum tier shows 100% progress and nextTier as null', async () => {
      mockPrisma.loyaltyAccount.findUnique.mockResolvedValue({
        id: 'acc_plat',
        userId: 'user_plat',
        tierId: 'tier_platinum',
        pointsBalance: 8000,
        lifetimePoints: 8000,
        tier: mockTiers[3],
        updatedAt: new Date(),
      });

      const account = await service.getLoyaltyAccount('user_plat');

      expect(account.tierCode).toBe(LoyaltyTierCode.PLATINUM);
      expect(account.nextTier).toBeNull();
    });
  });
});
