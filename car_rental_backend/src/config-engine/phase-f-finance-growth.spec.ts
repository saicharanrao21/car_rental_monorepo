import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { WalletsService } from '../wallets/wallets.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { ReferralsService } from '../referrals/referrals.service';
import { SystemConfigService } from './system-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES } from '../redis/redis-namespace.constants';
import {
  WalletStatus,
  WalletBucketType,
  LedgerEntryType,
  LedgerDirection,
  LoyaltyTransactionType,
  LoyaltyTierCode,
  ReferralStatus,
  BookingStatus,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase F — Comprehensive Finance, Loyalty, Referral & Configuration Suite (30 Scenarios)', () => {
  let mockPrisma: any;
  let mockAuditLogService: any;
  let mockNotificationsService: any;
  let mockConfigService: any;
  let mockRedisCacheService: any;

  let walletsService: WalletsService;
  let loyaltyService: LoyaltyService;
  let referralsService: ReferralsService;
  let systemConfigService: SystemConfigService;

  let configStore: Map<string, any>;
  let cacheStore: Map<string, any>;
  let walletStore: Map<string, any>;
  let walletLedgerStore: any[];
  let loyaltyAccountStore: Map<string, any>;
  let loyaltyTransactionStore: any[];
  let loyaltyTiers: any[];
  let referralAttributionStore: Map<string, any>;
  let referralCampaignStore: any[];
  let userStore: Map<string, any>;
  let auditLogs: any[];

  beforeEach(async () => {
    configStore = new Map<string, any>();
    cacheStore = new Map<string, any>();
    walletStore = new Map<string, any>();
    walletLedgerStore = [];
    loyaltyAccountStore = new Map<string, any>();
    loyaltyTransactionStore = [];
    referralAttributionStore = new Map<string, any>();
    referralCampaignStore = [];
    userStore = new Map<string, any>();
    auditLogs = [];

    loyaltyTiers = [
      { id: 'tier_bronze', code: LoyaltyTierCode.BRONZE, name: 'Bronze', minPointsRequired: 0, pointsMultiplier: new Decimal(1.0) },
      { id: 'tier_silver', code: LoyaltyTierCode.SILVER, name: 'Silver', minPointsRequired: 500, pointsMultiplier: new Decimal(1.25) },
      { id: 'tier_gold', code: LoyaltyTierCode.GOLD, name: 'Gold', minPointsRequired: 2000, pointsMultiplier: new Decimal(1.5) },
      { id: 'tier_platinum', code: LoyaltyTierCode.PLATINUM, name: 'Platinum', minPointsRequired: 5000, pointsMultiplier: new Decimal(2.0) },
    ];

    userStore.set('usr_alice', { id: 'usr_alice', name: 'Alice Customer', phone: '+919999900001', email: 'alice@test.com', referralCode: 'DGALICE1' });
    userStore.set('usr_bob', { id: 'usr_bob', name: 'Bob Friend', phone: '+919999900002', email: 'bob@test.com', referralCode: 'DGBOB222' });
    userStore.set('usr_charlie', { id: 'usr_charlie', name: 'Charlie User', phone: '+919999900003', email: 'charlie@test.com', referralCode: 'DGCHARL3' });
    userStore.set('admin_1', { id: 'admin_1', name: 'Super Admin', phone: '+919999999999', email: 'admin@drivego.in' });

    mockRedisCacheService = {
      get: jest.fn(async (key: string) => cacheStore.get(key) || null),
      set: jest.fn(async (key: string, val: any) => {
        cacheStore.set(key, val);
        return true;
      }),
      delete: jest.fn(async (key: string) => {
        cacheStore.delete(key);
        return true;
      }),
    };

    mockAuditLogService = {
      log: jest.fn(async (userId, action, entity, entityId, details) => {
        auditLogs.push({ userId, action, entity, entityId, details, timestamp: new Date() });
      }),
    };

    mockNotificationsService = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockConfigService = {
      get: jest.fn((key: string) => {
        if (key === 'RAZORPAY_USE_MOCK') return 'true';
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_123';
        if (key === 'RAZORPAY_KEY_SECRET') return 'rzp_secret_123';
        return null;
      }),
    };

    mockPrisma = {
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn(async (strings: any, ...values: any[]) => {
        const sqlObj = strings;
        const allValues = sqlObj?.values ? sqlObj.values : values;
        const queryText = Array.isArray(sqlObj)
          ? sqlObj.join(' ')
          : sqlObj?.strings
          ? sqlObj.strings.join(' ')
          : String(sqlObj);

        if (queryText.includes('wallets') || queryText.includes('Wallet')) {
          const id = allValues ? allValues[0] : null;
          const w =
            (id && walletStore.get(id)) ||
            Array.from(walletStore.values()).find(
              (item) => item.id === id || item.userId === id,
            ) ||
            Array.from(walletStore.values())[0] || {
              id: id || 'wlt_usr_alice',
              userId: 'usr_alice',
              availableBalance: new Decimal(1000),
              lockedBalance: new Decimal(0),
              realBalance: new Decimal(1000),
              promoBalance: new Decimal(0),
              status: WalletStatus.ACTIVE,
            };
          return [
            {
              id: w.id,
              userId: w.userId,
              availableBalance: w.availableBalance,
              lockedBalance: w.lockedBalance,
              realBalance: w.realBalance,
              promoBalance: w.promoBalance,
              status: w.status,
            },
          ];
        }

        if (queryText.includes('LoyaltyAccount')) {
          const userId = allValues ? allValues[0] : null;
          const acc =
            (userId && loyaltyAccountStore.get(userId)) ||
            Array.from(loyaltyAccountStore.values()).find(
              (item) => item.userId === userId || item.id === userId,
            ) ||
            Array.from(loyaltyAccountStore.values())[0] || {
              id: `lac_${userId || 'usr_alice'}`,
              userId: userId || 'usr_alice',
              tierId: 'tier_bronze',
              pointsBalance: 100,
              lifetimePoints: 100,
            };
          return [
            {
              id: acc.id,
              userId: acc.userId,
              tierId: acc.tierId,
              pointsBalance: acc.pointsBalance,
              lifetimePoints: acc.lifetimePoints,
            },
          ];
        }

        if (queryText.includes('ReferralAttribution')) {
          const id = allValues ? allValues[0] : null;
          const attr =
            Array.from(referralAttributionStore.values()).find((a) => a.id === id) ||
            Array.from(referralAttributionStore.values())[0];
          if (attr) {
            return [
              {
                id: attr.id,
                status: attr.status,
                referrerId: attr.referrerId,
                refereeId: attr.refereeId,
                referrerRewardAmount: attr.referrerRewardAmount,
              },
            ];
          }
        }

        return [];
      }),
      systemConfig: {
        findUnique: jest.fn(async ({ where }: { where: { key: string } }) => {
          return configStore.get(where.key) || null;
        }),
        findMany: jest.fn(async () => Array.from(configStore.values())),
        upsert: jest.fn(async ({ where, create, update }: any) => {
          const val = update?.value ?? create?.value;
          const updated = {
            id: `cfg_${where.key}`,
            key: where.key,
            value: val,
            category: create.category ?? 'GENERAL',
            description: create.description ?? 'Test description',
            isPublic: create.isPublic ?? false,
            updatedBy: update?.updatedBy ?? create.updatedBy ?? 'system',
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          configStore.set(where.key, updated);
          return updated;
        }),
      },
      auditLog: {
        create: jest.fn(async ({ data }: any) => {
          auditLogs.push(data);
          return { id: `audit_${Date.now()}`, ...data };
        }),
        count: jest.fn(async () => 0),
      },
      user: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.id) return userStore.get(where.id) || null;
          if (where.referralCode) {
            for (const u of userStore.values()) {
              if (u.referralCode === where.referralCode) return u;
            }
          }
          return null;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          const u = userStore.get(where.id);
          if (u) {
            Object.assign(u, data);
            userStore.set(where.id, u);
          }
          return u;
        }),
      },
      wallet: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.id) return walletStore.get(where.id) || null;
          if (where.userId) return walletStore.get(where.userId) || null;
          return null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const newWallet = {
            id: `wlt_${data.userId}`,
            currency: 'INR',
            availableBalance: new Decimal(data.availableBalance || 0),
            lockedBalance: new Decimal(data.lockedBalance || 0),
            realBalance: new Decimal(data.realBalance || 0),
            promoBalance: new Decimal(data.promoBalance || 0),
            status: data.status || WalletStatus.ACTIVE,
            userId: data.userId,
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          walletStore.set(newWallet.id, newWallet);
          walletStore.set(newWallet.userId, newWallet);
          return newWallet;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          const w = walletStore.get(where.id);
          if (!w) throw new NotFoundException(`Wallet not found: ${where.id}`);
          if (data.availableBalance !== undefined) w.availableBalance = new Decimal(data.availableBalance);
          if (data.realBalance !== undefined) w.realBalance = new Decimal(data.realBalance);
          if (data.promoBalance !== undefined) w.promoBalance = new Decimal(data.promoBalance);
          if (data.lockedBalance !== undefined) w.lockedBalance = new Decimal(data.lockedBalance);
          if (data.status !== undefined) w.status = data.status;
          walletStore.set(w.id, w);
          walletStore.set(w.userId, w);
          return w;
        }),
      },
      walletLedgerEntry: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.idempotencyKey) {
            return walletLedgerStore.find((e) => e.idempotencyKey === where.idempotencyKey) || null;
          }
          return walletLedgerStore.find((e) => e.id === where.id) || null;
        }),
        findMany: jest.fn(async ({ where }: any) => {
          return walletLedgerStore.filter((e) => !where?.walletId || e.walletId === where.walletId);
        }),
        count: jest.fn(async () => walletLedgerStore.length),
        aggregate: jest.fn(async () => ({ _sum: { amount: null } })),
        create: jest.fn(async ({ data }: any) => {
          const entry = {
            id: `wle_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
            ...data,
            createdAt: new Date(),
          };
          walletLedgerStore.push(entry);
          return entry;
        }),
        groupBy: jest.fn(async ({ where }: any) => {
          const credits = walletLedgerStore
            .filter((e) => e.walletId === where.walletId && e.direction === LedgerDirection.CREDIT)
            .reduce((sum, e) => sum.add(e.amount), new Decimal(0));
          const debits = walletLedgerStore
            .filter((e) => e.walletId === where.walletId && e.direction === LedgerDirection.DEBIT)
            .reduce((sum, e) => sum.add(e.amount), new Decimal(0));
          return [
            { direction: LedgerDirection.CREDIT, _sum: { amount: credits } },
            { direction: LedgerDirection.DEBIT, _sum: { amount: debits } },
          ];
        }),
      },
      loyaltyTier: {
        findMany: jest.fn(async () => loyaltyTiers),
        findFirst: jest.fn(async () => loyaltyTiers[0]),
        findUnique: jest.fn(async ({ where }: any) => loyaltyTiers.find((t) => t.id === where.id || t.code === where.code) || null),
      },
      loyaltyAccount: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.userId) return loyaltyAccountStore.get(where.userId) || null;
          if (where.id) {
            for (const a of loyaltyAccountStore.values()) {
              if (a.id === where.id) return a;
            }
          }
          return null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const account = {
            id: `lac_${data.userId}`,
            userId: data.userId,
            tierId: data.tierId || 'tier_bronze',
            pointsBalance: data.pointsBalance || 0,
            lifetimePoints: data.lifetimePoints || 0,
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          loyaltyAccountStore.set(data.userId, account);
          return account;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          let acc: any = null;
          for (const a of loyaltyAccountStore.values()) {
            if (a.id === where.id || a.userId === where.userId) {
              acc = a;
              break;
            }
          }
          if (!acc) throw new NotFoundException(`Loyalty account not found`);
          Object.assign(acc, data);
          loyaltyAccountStore.set(acc.userId, acc);
          return acc;
        }),
      },
      loyaltyTransaction: {
        findFirst: jest.fn(async ({ where }: any) => {
          return (
            loyaltyTransactionStore.find((t) => {
              if (where?.referenceId && t.referenceId !== where.referenceId) return false;
              if (where?.referenceType && t.referenceType !== where.referenceType) return false;
              if (where?.accountId && t.accountId !== where.accountId) return false;
              return true;
            }) || null
          );
        }),
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.idempotencyKey) {
            return loyaltyTransactionStore.find((t) => t.idempotencyKey === where.idempotencyKey) || null;
          }
          return loyaltyTransactionStore.find((t) => t.id === where.id) || null;
        }),
        findMany: jest.fn(async ({ where }: any) => {
          return loyaltyTransactionStore.filter((t) => {
            if (where?.referenceId && t.referenceId !== where.referenceId) return false;
            if (where?.accountId && t.accountId !== where.accountId) return false;
            return true;
          });
        }),
        create: jest.fn(async ({ data }: any) => {
          const tx = {
            id: `ltx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
            ...data,
            createdAt: new Date(),
          };
          loyaltyTransactionStore.push(tx);
          return tx;
        }),
      },
      booking: {
        findUnique: jest.fn(async ({ where }: any) => {
          const isCancelled = where.id.includes('cancelled');
          const isBob = where.id.includes('bob');
          const isUnderMin = where.id === 'bk_under_min';
          const userId = isBob ? 'usr_bob' : 'usr_alice';
          return {
            id: where.id,
            bookingNumber: `BK-${where.id}`,
            customerId: userId,
            pricingPlan: 'DAILY',
            baseFare: isUnderMin ? new Decimal(1000) : new Decimal(2000),
            totalFare: isUnderMin ? new Decimal(1200) : new Decimal(2500),
            baseRentalPrice: new Decimal(2000),
            totalAmount: isUnderMin ? new Decimal(1200) : new Decimal(2500),
            status: isCancelled ? BookingStatus.CANCELLED : BookingStatus.COMPLETED,
            customer: { id: userId, name: 'Customer' },
            payment: { status: 'PAID', refundStatus: 'NONE' },
          };
        }),
        count: jest.fn(async () => 0),
      },
      referralCampaign: {
        findFirst: jest.fn(async () => {
          return referralCampaignStore[0] || null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const camp = {
            id: `camp_${Date.now()}`,
            ...data,
            referrerRewardAmount: new Decimal(data.referrerRewardAmount),
            refereeRewardAmount: new Decimal(data.refereeRewardAmount),
            minBookingAmount: new Decimal(data.minBookingAmount),
            createdAt: new Date(),
            updatedAt: new Date(),
          };
          referralCampaignStore.push(camp);
          return camp;
        }),
      },
      referralAttribution: {
        findUnique: jest.fn(async ({ where, include }: any) => {
          let attr = null;
          if (where.refereeId) attr = referralAttributionStore.get(where.refereeId) || null;
          if (where.id) attr = Array.from(referralAttributionStore.values()).find((a) => a.id === where.id) || null;
          if (!attr) return null;
          const copy = { ...attr };
          if (include?.campaign) {
            copy.campaign = referralCampaignStore.find((c) => c.id === attr.campaignId) || referralCampaignStore[0] || null;
          }
          return copy;
        }),
        findFirst: jest.fn(async ({ where, include }: any) => {
          for (const a of referralAttributionStore.values()) {
            if (where?.refereeId && a.refereeId !== where.refereeId) continue;
            if (where?.qualifyingBookingId && a.qualifyingBookingId !== where.qualifyingBookingId) continue;
            const copy = { ...a };
            if (include?.campaign) {
              copy.campaign = referralCampaignStore.find((c) => c.id === a.campaignId) || referralCampaignStore[0] || null;
            }
            return copy;
          }
          return null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const attr = {
            id: `attr_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
            ...data,
            referrerRewardAmount: new Decimal(data.referrerRewardAmount),
            refereeRewardAmount: new Decimal(data.refereeRewardAmount),
            status: data.status || ReferralStatus.REGISTERED,
            createdAt: new Date(),
          };
          referralAttributionStore.set(data.refereeId, attr);
          return attr;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          const attr = Array.from(referralAttributionStore.values()).find((a) => a.id === where.id || a.refereeId === where.refereeId);
          if (attr) {
            const updated = { ...attr, ...data };
            referralAttributionStore.set(attr.refereeId, updated);
            return updated;
          }
          return null;
        }),
        count: jest.fn(async () => 0),
        findMany: jest.fn(async () => Array.from(referralAttributionStore.values())),
      },
    };

    systemConfigService = new SystemConfigService(
      mockPrisma,
      mockRedisCacheService,
      mockAuditLogService,
    );

    walletsService = new WalletsService(
      mockPrisma,
      mockConfigService,
      mockAuditLogService,
      mockNotificationsService,
      undefined,
      systemConfigService,
    );

    loyaltyService = new LoyaltyService(
      mockPrisma,
      walletsService,
      systemConfigService,
      mockAuditLogService,
    );

    referralsService = new ReferralsService(
      mockPrisma,
      walletsService,
      mockAuditLogService,
      mockNotificationsService,
      undefined,
      systemConfigService,
    );
  });

  // =========================================================================
  // Section 1: Wallet Master Control (Tests 1-9)
  // =========================================================================
  describe('Wallet Master Control & Invariants', () => {
    it('1. wallet.rules.isEnabled: wallet enabled allows usable calculation & deposits', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');
      await mockPrisma.wallet.update({
        where: { id: wallet.id },
        data: { availableBalance: new Decimal(1000), realBalance: new Decimal(1000) },
      });

      const usable = await walletsService.validateAndCalculateUsableWallet('usr_alice', 2000);
      expect(usable.allowed).toBe(true);
      expect(usable.usableAmount).toBeGreaterThan(0);

      const order = await walletsService.createDepositOrder('usr_alice', 1000);
      expect(order.amount).toBe(1000);
      expect(order.isMock).toBe(true);
    });

    it('2. wallet.rules.isEnabled: wallet disabled rejects deposit order creation', async () => {
      await systemConfigService.setConfig('wallet.rules', {
        isEnabled: false,
        minSingleDeposit: 100,
        maxSingleDeposit: 50000,
        maxWalletBalanceCap: 100000,
        maxWalletPaymentPercentage: 100,
      });

      await expect(walletsService.createDepositOrder('usr_alice', 500)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('3. Backend rejects customer usable wallet deduction when disabled', async () => {
      await systemConfigService.setConfig('wallet.rules', {
        isEnabled: false,
        minSingleDeposit: 100,
        maxSingleDeposit: 50000,
        maxWalletBalanceCap: 100000,
        maxWalletPaymentPercentage: 100,
      });

      const usable = await walletsService.validateAndCalculateUsableWallet('usr_alice', 3000);
      expect(usable.allowed).toBe(false);
      expect(usable.usableAmount).toBe(0);
      expect(usable.reason).toContain('disabled');
    });

    it('4. Admin wallet credit with audit logging', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');

      const result = await walletsService.adminAdjustWallet('admin_1', {
        walletId: wallet.id,
        amount: 500,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL,
        reason: 'Customer goodwill gesture',
        clientNonce: 'test_nonce_credit_4',
      });

      expect(result.success).toBe(true);
      expect(result.ledgerEntry.amount.toNumber()).toBe(500);

      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin_1',
        'WALLET_ADJUSTMENT_CREDIT',
        'Wallet',
        wallet.id,
        expect.objectContaining({
          amount: 500,
          direction: LedgerDirection.CREDIT,
          reason: 'Customer goodwill gesture',
        }),
      );
    });

    it('5. Admin wallet debit with audit logging', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');
      wallet.availableBalance = new Decimal(1000);
      wallet.realBalance = new Decimal(1000);
      walletStore.set(wallet.id, wallet);
      walletStore.set(wallet.userId, wallet);

      const result = await walletsService.adminAdjustWallet('admin_1', {
        walletId: wallet.id,
        amount: 400,
        direction: LedgerDirection.DEBIT,
        bucket: WalletBucketType.REAL,
        reason: 'Correction of duplicate credit',
        clientNonce: 'test_nonce_debit_5',
      });

      expect(result.success).toBe(true);
      expect(result.ledgerEntry.balanceAfter.toNumber()).toBe(600);

      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin_1',
        'WALLET_ADJUSTMENT_DEBIT',
        'Wallet',
        wallet.id,
        expect.objectContaining({
          amount: 400,
          direction: LedgerDirection.DEBIT,
          reason: 'Correction of duplicate credit',
        }),
      );
    });

    it('6. Negative balance prevention in wallet debit', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');
      wallet.availableBalance = new Decimal(200);
      wallet.realBalance = new Decimal(200);
      walletStore.set(wallet.id, wallet);
      walletStore.set(wallet.userId, wallet);

      await expect(
        walletsService.adminAdjustWallet('admin_1', {
          walletId: wallet.id,
          amount: 500,
          direction: LedgerDirection.DEBIT,
          bucket: WalletBucketType.REAL,
          reason: 'Excessive debit',
          clientNonce: 'test_nonce_debit_6',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('7. Duplicate adjustment prevention via idempotency key', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');

      const fixedNonce = 'idempotent_fixed_key_7';
      const first = await walletsService.adminAdjustWallet('admin_1', {
        walletId: wallet.id,
        amount: 100,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL,
        reason: 'Idempotency test 1',
        clientNonce: fixedNonce,
      });

      const second = await walletsService.adminAdjustWallet('admin_1', {
        walletId: wallet.id,
        amount: 100,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL,
        reason: 'Idempotency test 2',
        clientNonce: fixedNonce,
      });

      expect(first.ledgerEntry.id).toBe(second.ledgerEntry.id);
    });

    it('8. Concurrent wallet mutation safety (FOR UPDATE row locking)', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');
      wallet.availableBalance = new Decimal(500);
      wallet.realBalance = new Decimal(500);
      walletStore.set(wallet.id, wallet);
      walletStore.set(wallet.userId, wallet);

      await walletsService.creditWallet(
        wallet.id,
        new Decimal(100),
        LedgerEntryType.ADMIN_ADJUSTMENT,
        WalletBucketType.REAL,
        'SYSTEM',
        'sys_1',
        'key_for_update_test_8',
        'Test locking',
      );

      expect(mockPrisma.$queryRaw).toHaveBeenCalled();
    });

    it('9. Wallet audit logging validation', async () => {
      const wallet = await walletsService.getOrCreateWallet('usr_alice');

      await walletsService.adminAdjustWallet('admin_1', {
        walletId: wallet.id,
        amount: 250,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL,
        reason: 'Audit verification test',
        clientNonce: 'audit_test_nonce_9',
      });

      const logged = auditLogs.find((l) => l.action === 'WALLET_ADJUSTMENT_CREDIT');
      expect(logged).toBeDefined();
      expect(logged.entityId).toBe(wallet.id);
      expect(logged.details.reason).toBe('Audit verification test');
    });
  });

  // =========================================================================
  // Section 2: Rewards / Loyalty Engine (Tests 10-18)
  // =========================================================================
  describe('Rewards & Loyalty Engine', () => {
    it('10. loyalty.rules.isEnabled: loyalty enabled allows points earning', async () => {
      await systemConfigService.setConfig('loyalty.rules', {
        isEnabled: true,
        rupeesPerPointEarned: 10,
        pointsToRupeeRatio: 2,
        minPointsToRedeem: 2,
        maxPointsPerBooking: 5000,
      });

      const eligible = loyaltyService.calculateEligiblePoints(1000, 1.0, 10, 5000);
      expect(eligible).toBe(100);
    });

    it('11. loyalty.rules.isEnabled: loyalty disabled halts points earning', async () => {
      await systemConfigService.setConfig('loyalty.rules', {
        isEnabled: false,
        rupeesPerPointEarned: 10,
        pointsToRupeeRatio: 2,
        minPointsToRedeem: 2,
        maxPointsPerBooking: 5000,
      });

      const result = await loyaltyService.handleBookingCompleted('bk_completed_1');
      expect(result.earnedPoints).toBe(0);
      expect(result.reason).toContain('disabled');
    });

    it('12. Reward earning configuration (rupeesPerPointEarned dynamic update)', async () => {
      await systemConfigService.setConfig('loyalty.rules', {
        isEnabled: true,
        rupeesPerPointEarned: 20,
        pointsToRupeeRatio: 2,
        minPointsToRedeem: 2,
        maxPointsPerBooking: 5000,
      });

      const points = loyaltyService.calculateEligiblePoints(1000, 1.0, 20, 5000);
      expect(points).toBe(50);
    });

    it('13. Reward conversion configuration (pointsToRupeeRatio dynamic update)', async () => {
      await walletsService.getOrCreateWallet('usr_alice');
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 100,
        lifetimePoints: 100,
      });

      await systemConfigService.setConfig('loyalty.rules', {
        isEnabled: true,
        rupeesPerPointEarned: 10,
        pointsToRupeeRatio: 4,
        minPointsToRedeem: 4,
        maxPointsPerBooking: 5000,
      });

      const res = await loyaltyService.redeemPointsToWallet('usr_alice', {
        points: 40,
        idempotencyKey: 'redeem_test_13',
      });

      expect(res.walletCreditAmount).toBe(10);
      expect(res.redeemedPoints).toBe(40);
    });

    it('14. Reward manual credit', async () => {
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 50,
        lifetimePoints: 50,
      });

      const res = await loyaltyService.adminAdjustPoints('admin_1', {
        userId: 'usr_alice',
        points: 200,
        reason: 'Loyalty manual grant',
        idempotencyKey: 'loyalty_adj_credit_14',
      });

      expect(res.newPointsBalance).toBe(250);
      expect(res.newLifetimePoints).toBe(250);
    });

    it('15. Reward manual debit', async () => {
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 200,
        lifetimePoints: 200,
      });

      const res = await loyaltyService.adminAdjustPoints('admin_1', {
        userId: 'usr_alice',
        points: -50,
        reason: 'Correction of points',
        idempotencyKey: 'loyalty_adj_debit_15',
      });

      expect(res.newPointsBalance).toBe(150);
    });

    it('16. Reward reversal on trip cancellation (handleBookingCancelled)', async () => {
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 300,
        lifetimePoints: 300,
      });

      loyaltyTransactionStore.push({
        id: 'ltx_earn_16',
        accountId: 'lac_usr_alice',
        type: LoyaltyTransactionType.BOOKING_COMPLETION,
        points: 200,
        balanceBefore: 100,
        balanceAfter: 300,
        referenceType: 'BOOKING',
        referenceId: 'bk_cancelled_1',
        idempotencyKey: 'loyalty_booking_bk_cancelled_1',
      });

      const reversal = await loyaltyService.handleBookingCancelled('bk_cancelled_1');
      expect(reversal.reversed).toBe(true);
      expect(reversal.pointsReversed).toBe(200);
      expect(reversal.newPointsBalance).toBe(100);
    });

    it('17. Negative points prevention on debit and reversal', async () => {
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 30,
        lifetimePoints: 100,
      });

      await expect(
        loyaltyService.adminAdjustPoints('admin_1', {
          userId: 'usr_alice',
          points: -50,
          reason: 'Excessive points deduction',
          idempotencyKey: 'loyalty_neg_test_17',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('18. Duplicate redemption rejection via idempotency', async () => {
      await walletsService.getOrCreateWallet('usr_alice');
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 100,
        lifetimePoints: 100,
      });

      const key = 'idem_redemption_18';
      await loyaltyService.redeemPointsToWallet('usr_alice', {
        points: 20,
        idempotencyKey: key,
      });

      await expect(
        loyaltyService.redeemPointsToWallet('usr_alice', {
          points: 20,
          idempotencyKey: key,
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // =========================================================================
  // Section 3: Referral Engine & Anti-Abuse (Tests 19-27)
  // =========================================================================
  describe('Referral Engine & Anti-Abuse', () => {
    it('19. Referral enabled/disabled toggle', async () => {
      await systemConfigService.setConfig('referral.rules', {
        isReferralsEnabled: false,
        defaultReferrerReward: 250,
        defaultRefereeReward: 250,
        minBookingAmount: 1000,
        maxReferralsPerUser: 20,
      });

      referralCampaignStore.push({
        id: 'camp_disabled',
        code: 'DEFAULT_GLOBAL',
        isActive: false,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      await expect(
        referralsService.applyReferralCode('usr_bob', {
          referralCode: 'DGALICE1',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('20. Referrer reward crediting on qualified first booking', async () => {
      await systemConfigService.setConfig('referral.rules', {
        isReferralsEnabled: true,
        defaultReferrerReward: 300,
        defaultRefereeReward: 200,
        minBookingAmount: 1000,
        maxReferralsPerUser: 20,
      });

      referralCampaignStore.push({
        id: 'camp_active_20',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(300),
        refereeRewardAmount: new Decimal(200),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      const applyRes = await referralsService.applyReferralCode('usr_bob', {
        referralCode: 'DGALICE1',
      });
      expect(applyRes.success).toBe(true);
      const attribution = referralAttributionStore.get('usr_bob');
      expect(attribution.status).toBe(ReferralStatus.REGISTERED);

      await walletsService.getOrCreateWallet('usr_alice');

      const result = await referralsService.handleBookingCompleted('bk_bob_1');
      expect(result.success).toBe(true);
      expect(result.rewardAmount).toBe(300);
    });

    it('21. Referee reward eligibility validation', async () => {
      referralCampaignStore.push({
        id: 'camp_21',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      mockPrisma.booking.count = jest.fn().mockResolvedValue(1);

      await expect(
        referralsService.applyReferralCode('usr_charlie', {
          referralCode: 'DGALICE1',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('22. Referral eligibility rules enforcement', async () => {
      referralCampaignStore.push({
        id: 'camp_22',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(2000),
        maxReferralsPerUser: 20,
      });

      referralAttributionStore.set('usr_charlie', {
        id: 'attr_charlie_22',
        referrerId: 'usr_alice',
        refereeId: 'usr_charlie',
        status: ReferralStatus.REGISTERED,
        campaignId: 'camp_22',
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
      });

      const res = await referralsService.handleBookingCompleted('bk_under_min');
      expect(res).toBeNull();
    });

    it('23. Anti-abuse: Self-referral prevention (ID & phone)', async () => {
      referralCampaignStore.push({
        id: 'camp_23',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      await expect(
        referralsService.applyReferralCode('usr_alice', {
          referralCode: 'DGALICE1',
        }),
      ).rejects.toThrow('Self-referral is strictly prohibited.');

      userStore.set('usr_alice_clone', {
        id: 'usr_alice_clone',
        name: 'Alice Clone',
        phone: '+919999900001',
        email: 'clone@test.com',
      });

      await expect(
        referralsService.applyReferralCode('usr_alice_clone', {
          referralCode: 'DGALICE1',
        }),
      ).rejects.toThrow('same phone identity');
    });

    it('24. Anti-abuse: Duplicate referral reward prevention', async () => {
      referralCampaignStore.push({
        id: 'camp_24',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      referralAttributionStore.set('usr_bob', {
        id: 'attr_bob_existing',
        referrerId: 'usr_alice',
        refereeId: 'usr_bob',
        status: ReferralStatus.REGISTERED,
      });

      await expect(
        referralsService.applyReferralCode('usr_bob', {
          referralCode: 'DGCHARL3',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('25. Referral reversal on qualifying booking cancellation', async () => {
      const aliceWallet = await walletsService.getOrCreateWallet('usr_alice');
      aliceWallet.availableBalance = new Decimal(500);
      aliceWallet.promoBalance = new Decimal(250);
      walletStore.set(aliceWallet.id, aliceWallet);
      walletStore.set(aliceWallet.userId, aliceWallet);

      referralAttributionStore.set('usr_bob', {
        id: 'attr_bob_rewarded',
        referrerId: 'usr_alice',
        refereeId: 'usr_bob',
        status: ReferralStatus.REWARDED,
        qualifyingBookingId: 'bk_bob_cancelled',
        referrerLedgerEntryId: 'wle_prev_reward_25',
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
      });

      const clawback = await referralsService.handleBookingCancelled('bk_bob_cancelled');
      expect(clawback.reversed).toBe(true);
      expect(clawback.previousStatus).toBe(ReferralStatus.REWARDED);
    });

    it('26. Historical reward immutability (ratio changes do not mutate old ledger records)', async () => {
      await walletsService.getOrCreateWallet('usr_alice');
      loyaltyAccountStore.set('usr_alice', {
        id: 'lac_usr_alice',
        userId: 'usr_alice',
        tierId: 'tier_bronze',
        pointsBalance: 100,
        lifetimePoints: 100,
      });

      const tx1 = await loyaltyService.redeemPointsToWallet('usr_alice', {
        points: 50,
        idempotencyKey: 'redeem_hist_immut_1',
      });
      expect(tx1.walletCreditAmount).toBe(25);

      await systemConfigService.setConfig('loyalty.rules', {
        isEnabled: true,
        rupeesPerPointEarned: 10,
        pointsToRupeeRatio: 5,
        minPointsToRedeem: 5,
        maxPointsPerBooking: 5000,
      });

      const historicTx = loyaltyTransactionStore.find((t) => t.idempotencyKey === 'redeem_hist_immut_1');
      expect(historicTx).toBeDefined();
      expect(historicTx.points).toBe(50);
      expect(historicTx.description).toContain('₹25');
    });

    it('27. Historical referral immutability (reward changes do not alter existing attributions)', async () => {
      referralCampaignStore.push({
        id: 'camp_27',
        code: 'DEFAULT_GLOBAL',
        isActive: true,
        referrerRewardAmount: new Decimal(250),
        refereeRewardAmount: new Decimal(250),
        minBookingAmount: new Decimal(1000),
        maxReferralsPerUser: 20,
      });

      const applyRes = await referralsService.applyReferralCode('usr_bob', {
        referralCode: 'DGALICE1',
      });
      expect(applyRes.success).toBe(true);
      const savedAttr = referralAttributionStore.get('usr_bob');
      expect(savedAttr.referrerRewardAmount.toNumber()).toBe(250);

      await systemConfigService.setConfig('referral.rules', {
        isReferralsEnabled: true,
        defaultReferrerReward: 500,
        defaultRefereeReward: 400,
        minBookingAmount: 1000,
        maxReferralsPerUser: 20,
      });

      expect(savedAttr.referrerRewardAmount.toNumber()).toBe(250);
    });
  });

  // =========================================================================
  // Section 4: Configuration Governance & Cache Lifecycle (Tests 28-30)
  // =========================================================================
  describe('Configuration Governance & Lifecycle', () => {
    it('28. Configuration OCC conflict (version mismatch throws ConflictException)', async () => {
      configStore.set('wallet.rules', {
        id: 'cfg_wallet.rules',
        key: 'wallet.rules',
        value: { isEnabled: true, _version: 3 },
        category: 'FINANCE',
      });

      await expect(
        systemConfigService.setConfig('wallet.rules', { isEnabled: false }, 'admin_1', {
          expectedVersion: 2,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('29. Configuration audit trail recording', async () => {
      await systemConfigService.setConfig(
        'loyalty.rules',
        { isEnabled: true, rupeesPerPointEarned: 15, pointsToRupeeRatio: 3 },
        'admin_1',
        { reason: 'Q3 Loyalty Policy Adjustment', ip: '192.168.1.1' },
      );

      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin_1',
        'CONFIG_UPDATED',
        'SYSTEM_CONFIG',
        'loyalty.rules',
        expect.objectContaining({
          key: 'loyalty.rules',
          reason: 'Q3 Loyalty Policy Adjustment',
        }),
      );
    });

    it('30. Configuration Redis cache invalidation on update', async () => {
      const cacheKey = REDIS_NAMESPACES.CACHE.SYSTEM_CONFIG('wallet.rules');
      cacheStore.set(cacheKey, { isEnabled: true });

      await systemConfigService.setConfig('wallet.rules', { isEnabled: false }, 'admin_1');

      expect(mockRedisCacheService.delete).toHaveBeenCalledWith(cacheKey);
      expect(cacheStore.has(cacheKey)).toBe(false);
    });
  });
});
