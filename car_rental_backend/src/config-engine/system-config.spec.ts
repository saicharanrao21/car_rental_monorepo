import { Test, TestingModule } from '@nestjs/testing';
import { SystemConfigService } from './system-config.service';
import { SystemConfigController } from './system-config.controller';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { DEFAULT_SYSTEM_CONFIGS } from './system-config.interface';

describe('Phase 27.1 — System Configuration & Feature Flags Tests', () => {
  let service: SystemConfigService;
  let controller: SystemConfigController;
  let mockPrisma: any;
  let mockCache: any;
  let dbStore: Map<string, any>;

  beforeEach(async () => {
    dbStore = new Map<string, any>();

    mockPrisma = {
      systemConfig: {
        findUnique: jest.fn(async ({ where }: { where: { key: string } }) => {
          const val = dbStore.get(where.key);
          if (!val) return null;
          return { key: where.key, value: val };
        }),
        upsert: jest.fn(
          async ({
            where,
            create,
            update,
          }: {
            where: { key: string };
            create: any;
            update: any;
          }) => {
            const val = update.value ?? create.value;
            dbStore.set(where.key, val);
            return { key: where.key, value: val };
          },
        ),
      },
    };

    const cacheStore = new Map<string, any>();
    mockCache = {
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

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SystemConfigController],
      providers: [
        SystemConfigService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
      ],
    }).compile();

    service = module.get<SystemConfigService>(SystemConfigService);
    controller = module.get<SystemConfigController>(SystemConfigController);
  });

  describe('3-Tier Configuration Fallback', () => {
    it('returns default fallback when neither cache nor DB has custom config', async () => {
      const walletConfig = await service.getWalletConfig();
      expect(walletConfig.maxSingleDeposit).toBe(50000);
      expect(walletConfig.isDepositsEnabled).toBe(true);
      expect(walletConfig.maxWalletPaymentPercentage).toBe(100);
    });

    it('retrieves from DB and caches for subsequent reads', async () => {
      dbStore.set('wallet.rules', {
        maxSingleDeposit: 75000,
        minSingleDeposit: 50,
        maxWalletBalanceCap: 200000,
        maxWalletPaymentPercentage: 50,
        isDepositsEnabled: true,
      });

      const config = await service.getWalletConfig();
      expect(config.maxSingleDeposit).toBe(75000);
      expect(config.maxWalletPaymentPercentage).toBe(50);
      expect(mockCache.set).toHaveBeenCalled();
    });

    it('updates config in DB and invalidates cache', async () => {
      await service.setConfig(
        'wallet.rules',
        {
          maxSingleDeposit: 100000,
          minSingleDeposit: 100,
          maxWalletBalanceCap: 250000,
          maxWalletPaymentPercentage: 100,
          isDepositsEnabled: true,
        },
        'admin_user_1',
      );

      expect(mockCache.delete).toHaveBeenCalled();
      const updated = await service.getWalletConfig();
      expect(updated.maxSingleDeposit).toBe(100000);
    });
  });

  describe('Typed Getters & Feature Flags', () => {
    it('returns valid ReferralConfig', async () => {
      const referral = await service.getReferralConfig();
      expect(referral.defaultReferrerReward).toBe(250);
      expect(referral.isReferralsEnabled).toBe(true);
    });

    it('returns valid SearchRankingConfig', async () => {
      const ranking = await service.getSearchRankingConfig();
      expect(ranking.relevanceWeight).toBe(0.35);
      expect(ranking.distanceWeight).toBe(0.35);
      expect(ranking.sponsoredBoostMultiplier).toBe(1.25);
    });

    it('returns public configs and feature flags via controller', async () => {
      const publicFlags = await controller.getPublicConfigs();
      expect(publicFlags['wallet.rules']).toBeDefined();
      expect(publicFlags['platform.feature_flags']).toBeDefined();

      const flags = await controller.getFeatureFlags();
      expect(flags.enableDoorstepDelivery).toBe(true);
      expect(flags.enableSplitPayments).toBe(true);
    });
  });
});
