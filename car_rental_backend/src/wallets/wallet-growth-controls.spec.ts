import { WalletsService } from './wallets.service';
import { WalletStatus, WalletBucketType, LedgerEntryType, LedgerDirection } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException } from '@nestjs/common';

describe('WalletGrowthControls (Phase 27.4)', () => {
  let service: WalletsService;
  let mockPrisma: any;
  let mockConfigService: any;
  let mockAuditLogService: any;
  let mockNotificationsService: any;
  let mockSystemConfigService: any;

  beforeEach(() => {
    mockPrisma = {
      wallet: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      walletLedgerEntry: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: null } }),
        count: jest.fn().mockResolvedValue(0),
      },
      $transaction: jest.fn((cb) => cb(mockPrisma)),
    };

    mockConfigService = {
      get: jest.fn().mockReturnValue('mock_secret'),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockNotificationsService = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfigService = {
      getWalletConfig: jest.fn().mockResolvedValue({
        maxSingleDeposit: 50000,
        minSingleDeposit: 100,
        maxWalletBalanceCap: 100000,
        maxWalletPaymentPercentage: 30, // 30% max wallet usage per booking
        minBookingAmountForWalletUse: 500,
        maxPromoCreditPerBooking: 1000,
        maxDailyWalletUsage: 25000,
        isDepositsEnabled: true,
      }),
    };

    service = new WalletsService(
      mockPrisma,
      mockConfigService,
      mockAuditLogService,
      mockNotificationsService,
      undefined,
      mockSystemConfigService,
    );
  });

  describe('Admin Configurable Wallet Limits on Booking Checkout', () => {
    it('should cap wallet application to configured percentage (30% of ₹5,000 = ₹1,500)', async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({
        id: 'w1',
        userId: 'u1',
        availableBalance: new Decimal(4000),
        realBalance: new Decimal(3000),
        promoBalance: new Decimal(1000),
        status: WalletStatus.ACTIVE,
      });

      const result = await service.validateAndCalculateUsableWallet('u1', 5000);

      expect(result.allowed).toBe(true);
      expect(result.usableAmount).toBe(1500); // 30% of 5000
      expect(result.maxPercentageAllowed).toBe(30);
      expect(result.promoAmount).toBe(1000); // Promo up to maxPromoCreditPerBooking
      expect(result.realAmount).toBe(500);
    });

    it('should reject wallet application if booking amount is below minBookingAmountForWalletUse', async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({
        id: 'w1',
        userId: 'u1',
        availableBalance: new Decimal(2000),
        realBalance: new Decimal(2000),
        promoBalance: new Decimal(0),
        status: WalletStatus.ACTIVE,
      });

      const result = await service.validateAndCalculateUsableWallet('u1', 400); // Below ₹500

      expect(result.allowed).toBe(false);
      expect(result.usableAmount).toBe(0);
      expect(result.reason).toContain('Booking amount must be at least ₹500');
    });
  });

  describe('Promotional Credit Expiry Lifecycle', () => {
    it('should identify and expire outdated promotional credits idempotently', async () => {
      const pastDate = new Date(Date.now() - 86400000); // 1 day ago

      mockPrisma.walletLedgerEntry.findMany.mockResolvedValue([
        {
          id: 'entry-old-promo',
          walletId: 'w1',
          bucket: WalletBucketType.PROMOTIONAL,
          direction: LedgerDirection.CREDIT,
          amount: new Decimal(300),
          expiresAt: pastDate,
        },
      ]);

      mockPrisma.wallet.findUnique.mockResolvedValue({
        id: 'w1',
        availableBalance: new Decimal(1000),
        realBalance: new Decimal(700),
        promoBalance: new Decimal(300),
      });

      const expiredAmount = await service.cleanExpiredPromotionalCredits('w1');

      expect(expiredAmount.toNumber()).toBe(300);
      expect(mockPrisma.walletLedgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            type: LedgerEntryType.EXPIRATION,
            amount: new Decimal(300),
            bucket: WalletBucketType.PROMOTIONAL,
          }),
        }),
      );
      expect(mockPrisma.wallet.update).toHaveBeenCalledWith({
        where: { id: 'w1' },
        data: {
          availableBalance: new Decimal(700),
          promoBalance: new Decimal(0),
        },
      });
    });
  });
});
