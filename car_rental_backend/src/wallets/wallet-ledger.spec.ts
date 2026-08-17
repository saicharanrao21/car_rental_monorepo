import { Test, TestingModule } from '@nestjs/testing';
import { WalletsService, MAX_SINGLE_DEPOSIT, MIN_SINGLE_DEPOSIT, MAX_WALLET_BALANCE_CAP } from './wallets.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ApmMonitoringService } from '../common/apm-monitoring.service';
import { WalletStatus, WalletBucketType, LedgerEntryType, LedgerDirection } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('WalletsService (Ledger & Financial Invariants)', () => {
  let service: WalletsService;
  let prisma: any;
  let auditLogService: any;
  let notificationsService: any;
  let apmMonitoringService: any;

  const mockWallet = {
    id: 'wlt_test_123',
    userId: 'usr_test_456',
    currency: 'INR',
    availableBalance: new Decimal(1000),
    lockedBalance: new Decimal(0),
    realBalance: new Decimal(800),
    promoBalance: new Decimal(200),
    status: WalletStatus.ACTIVE,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    prisma = {
      wallet: {
        findUnique: jest.fn().mockResolvedValue({ ...mockWallet }),
        create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'wlt_created', ...args.data })),
        update: jest.fn().mockImplementation((args) => Promise.resolve({ ...mockWallet, ...args.data })),
        findMany: jest.fn().mockResolvedValue([{ ...mockWallet }]),
      },
      walletLedgerEntry: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation((args) =>
          Promise.resolve({
            id: `led_${Date.now()}`,
            ...args.data,
          }),
        ),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
        groupBy: jest.fn().mockResolvedValue([
          { direction: LedgerDirection.CREDIT, _sum: { amount: new Decimal(1000) } },
          { direction: LedgerDirection.DEBIT, _sum: { amount: new Decimal(0) } },
        ]),
      },
      $queryRaw: jest.fn().mockResolvedValue([
        {
          id: mockWallet.id,
          availableBalance: mockWallet.availableBalance,
          lockedBalance: mockWallet.lockedBalance,
          realBalance: mockWallet.realBalance,
          promoBalance: mockWallet.promoBalance,
          status: mockWallet.status,
        },
      ]),
      $transaction: jest.fn().mockImplementation(async (cb) => cb(prisma)),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    apmMonitoringService = {
      captureFinancialInconsistency: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletsService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'RAZORPAY_USE_MOCK') return 'true';
              if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_mock';
              if (key === 'RAZORPAY_KEY_SECRET') return 'mock_secret';
              return null;
            }),
          },
        },
        { provide: AuditLogService, useValue: auditLogService },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: ApmMonitoringService, useValue: apmMonitoringService },
      ],
    }).compile();

    service = module.get<WalletsService>(WalletsService);
  });

  describe('Wallet Initialization & Retrieval', () => {
    it('should retrieve existing wallet for user', async () => {
      const wallet = await service.getOrCreateWallet('usr_test_456');
      expect(wallet).toBeDefined();
      expect(wallet.id).toBe('wlt_test_123');
      expect(wallet.availableBalance.toNumber()).toBe(1000);
    });

    it('should create new wallet if one does not exist', async () => {
      prisma.wallet.findUnique.mockResolvedValueOnce(null);
      const wallet = await service.getOrCreateWallet('usr_new_789');
      expect(prisma.wallet.create).toHaveBeenCalled();
      expect(wallet.id).toBe('wlt_created');
    });
  });

  describe('Credit Operations & Invariants', () => {
    it('should credit wallet real balance correctly with immutable ledger entry', async () => {
      const creditAmount = new Decimal(500);
      const entry = await service.creditWallet(
        mockWallet.id,
        creditAmount,
        LedgerEntryType.CUSTOMER_DEPOSIT,
        WalletBucketType.REAL_MONEY,
        'PAYMENT',
        'pay_123',
        'idemp_credit_1',
        'Deposit test',
      );

      expect(entry).toBeDefined();
      expect(entry.direction).toBe(LedgerDirection.CREDIT);
      expect(entry.amount.toNumber()).toBe(500);
      expect(entry.balanceAfter.toNumber()).toBe(1500);
      expect(prisma.wallet.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            availableBalance: new Decimal(1500),
            realBalance: new Decimal(1300),
          }),
        }),
      );
    });

    it('should credit promotional balance correctly', async () => {
      const promoAmount = new Decimal(250);
      const entry = await service.creditWallet(
        mockWallet.id,
        promoAmount,
        LedgerEntryType.REFERRAL_REWARD,
        WalletBucketType.PROMOTIONAL,
        'REFERRAL',
        'ref_123',
        'idemp_promo_1',
        'Referral bonus',
      );

      expect(entry.bucket).toBe(WalletBucketType.PROMOTIONAL);
      expect(entry.balanceAfter.toNumber()).toBe(1250);
      expect(prisma.wallet.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            availableBalance: new Decimal(1250),
            promoBalance: new Decimal(450),
          }),
        }),
      );
    });

    it('should enforce idempotency and not double-credit', async () => {
      const existing = {
        id: 'led_existing',
        idempotencyKey: 'idemp_duplicate',
        amount: new Decimal(500),
      };
      prisma.walletLedgerEntry.findUnique.mockResolvedValueOnce(existing);

      const res = await service.creditWallet(
        mockWallet.id,
        new Decimal(500),
        LedgerEntryType.CUSTOMER_DEPOSIT,
        WalletBucketType.REAL_MONEY,
        'PAYMENT',
        'pay_123',
        'idemp_duplicate',
        'Duplicate deposit',
      );

      expect(res.id).toBe('led_existing');
      expect(prisma.wallet.update).not.toHaveBeenCalled();
    });

    it('should reject non-positive credit amounts', async () => {
      await expect(
        service.creditWallet(
          mockWallet.id,
          new Decimal(0),
          LedgerEntryType.CUSTOMER_DEPOSIT,
          WalletBucketType.REAL_MONEY,
          'PAYMENT',
          'pay_123',
          'idemp_zero',
          'Zero credit',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject credits that exceed maximum wallet balance cap', async () => {
      await expect(
        service.creditWallet(
          mockWallet.id,
          new Decimal(MAX_WALLET_BALANCE_CAP + 1),
          LedgerEntryType.CUSTOMER_DEPOSIT,
          WalletBucketType.REAL_MONEY,
          'PAYMENT',
          'pay_123',
          'idemp_cap',
          'Cap breach',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Debit Operations & Bucket Consumption Order', () => {
    it('should debit promotional balance first before real cash', async () => {
      // Wallet has Available: 1000 (Promo: 200, Real: 800)
      // Debit 300 -> Should consume 200 Promo, then 100 Real
      const debitAmount = new Decimal(300);
      const entry = await service.debitWallet(
        mockWallet.id,
        debitAmount,
        LedgerEntryType.CHECKOUT_DEBIT,
        'BOOKING',
        'bk_123',
        'idemp_debit_1',
        'Booking checkout',
      );

      expect(entry).toBeDefined();
      expect(entry.direction).toBe(LedgerDirection.DEBIT);
      expect(entry.balanceAfter.toNumber()).toBe(700);

      expect(prisma.wallet.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            availableBalance: new Decimal(700),
            promoBalance: new Decimal(0),
            realBalance: new Decimal(700),
          }),
        }),
      );
    });

    it('should reject debit when requested amount exceeds available balance', async () => {
      await expect(
        service.debitWallet(
          mockWallet.id,
          new Decimal(1500),
          LedgerEntryType.CHECKOUT_DEBIT,
          'BOOKING',
          'bk_123',
          'idemp_overdraw',
          'Overdraw attempt',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should enforce idempotency on debit operations', async () => {
      const existingDebit = {
        id: 'led_debit_existing',
        idempotencyKey: 'idemp_debit_dup',
        amount: new Decimal(100),
      };
      prisma.walletLedgerEntry.findUnique.mockResolvedValueOnce(existingDebit);

      const res = await service.debitWallet(
        mockWallet.id,
        new Decimal(100),
        LedgerEntryType.CHECKOUT_DEBIT,
        'BOOKING',
        'bk_123',
        'idemp_debit_dup',
        'Duplicate checkout debit',
      );

      expect(res.id).toBe('led_debit_existing');
      expect(prisma.wallet.update).not.toHaveBeenCalled();
    });
  });

  describe('Deposit Orders & Limits', () => {
    it('should create deposit order within allowed range', async () => {
      const order = await service.createDepositOrder('usr_test_456', 1000);
      expect(order).toBeDefined();
      expect(order.amount).toBe(1000);
      expect(order.orderId).toContain('order_mock_wlt_');
    });

    it('should reject deposit below minimum limit (₹100)', async () => {
      await expect(
        service.createDepositOrder('usr_test_456', MIN_SINGLE_DEPOSIT - 1),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject deposit above single deposit maximum (₹50,000)', async () => {
      await expect(
        service.createDepositOrder('usr_test_456', MAX_SINGLE_DEPOSIT + 1),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Admin Manual Adjustments', () => {
    it('should process admin credit with mandatory reason and AuditLog', async () => {
      const res = await service.adminAdjustWallet('adm_123', {
        walletId: mockWallet.id,
        amount: 200,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL_MONEY,
        reason: 'Customer goodwill credit for delay',
      });

      expect(res.success).toBe(true);
      expect(auditLogService.log).toHaveBeenCalledWith(
        'adm_123',
        'WALLET_ADJUSTMENT_CREDIT',
        'Wallet',
        mockWallet.id,
        expect.objectContaining({
          reason: 'Customer goodwill credit for delay',
          amount: 200,
        }),
      );
    });
  });

  describe('Financial Reconciliation & Anomaly Detection', () => {
    it('should detect matching wallet and confirm valid status', async () => {
      const result = await service.reconcileWallet(mockWallet.id);
      expect(result.isMatched).toBe(true);
      expect(result.cachedAvailable).toBe(1000);
      expect(result.computedAvailable).toBe(1000);
      expect(result.status).toBe(WalletStatus.ACTIVE);
    });

    it('should detect ledger mismatch, freeze wallet, and report anomaly', async () => {
      // Simulate ledger aggregate reporting ₹500 while cached is ₹1000
      prisma.walletLedgerEntry.groupBy.mockResolvedValueOnce([
        { direction: LedgerDirection.CREDIT, _sum: { amount: new Decimal(500) } },
      ]);

      const result = await service.reconcileWallet(mockWallet.id);

      expect(result.isMatched).toBe(false);
      expect(prisma.wallet.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { status: WalletStatus.FROZEN },
        }),
      );
      expect(apmMonitoringService.captureFinancialInconsistency).toHaveBeenCalledWith(
        'WALLET_RECONCILIATION_MISMATCH',
        expect.objectContaining({
          severity: 'fatal',
        }),
      );
    });
  });
});
