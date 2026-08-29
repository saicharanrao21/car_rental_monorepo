import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import {
  DEFAULT_SYSTEM_CONFIGS,
  WalletConfig,
  ReferralConfig,
  SearchRankingConfig,
  BookingPolicyConfig,
  GrowthCampaignConfig,
  NotificationConfig,
  SupportSlaConfig,
  PayoutConfig,
  ReconciliationConfig,
  AnalyticsConfig,
  PlatformFeatureFlags,
} from './system-config.interface';

@Injectable()
export class SystemConfigService {
  private readonly logger = new Logger(SystemConfigService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
  ) {}

  /**
   * Gets a typed configuration value with 3-tier fallback:
   * 1. Redis Cache -> 2. PostgreSQL DB -> 3. Hardcoded Safe Defaults
   */
  async getConfig<T>(key: string): Promise<T> {
    const cacheKey = REDIS_NAMESPACES.CACHE.SYSTEM_CONFIG(key);

    // 1. Try Cache
    const cached = await this.cacheService.get<T>(cacheKey);
    if (cached !== null && cached !== undefined) {
      return cached;
    }

    // 2. Try DB
    try {
      const record = await this.prisma.systemConfig.findUnique({
        where: { key },
      });

      if (record && record.value) {
        const val = record.value as unknown as T;
        await this.cacheService.set(cacheKey, val, DEFAULT_CACHE_TTLS.MEDIUM_TERM);
        return val;
      }
    } catch (err: any) {
      this.logger.warn(`Failed reading SystemConfig from DB for [${key}]: ${err?.message}`);
    }

    // 3. Fallback to default
    const fallback = DEFAULT_SYSTEM_CONFIGS[key];
    if (fallback) {
      return fallback.value as T;
    }

    throw new NotFoundException(`Configuration key [${key}] not found.`);
  }

  /**
   * Sets or updates a configuration value, updates DB, invalidates cache, and records audit trail.
   */
  async setConfig(
    key: string,
    value: any,
    updatedByUserId?: string,
  ): Promise<any> {
    const defaultMeta = DEFAULT_SYSTEM_CONFIGS[key] || {
      category: 'GENERAL',
      description: 'Dynamic configuration parameter',
      isPublic: false,
    };

    const record = await this.prisma.systemConfig.upsert({
      where: { key },
      create: {
        key,
        value,
        category: defaultMeta.category,
        description: defaultMeta.description,
        isPublic: defaultMeta.isPublic,
        updatedBy: updatedByUserId || 'system',
      },
      update: {
        value,
        updatedBy: updatedByUserId || 'system',
      },
    });

    // Invalidate Cache
    const cacheKey = REDIS_NAMESPACES.CACHE.SYSTEM_CONFIG(key);
    await this.cacheService.delete(cacheKey);

    this.logger.log(
      `[CONFIG_UPDATED] Key: ${key} by ${updatedByUserId || 'system'}`,
    );

    return record;
  }

  /**
   * Retrieves all public feature flags and client-facing configurations.
   */
  async getPublicConfigs(): Promise<Record<string, any>> {
    const publicKeys = Object.keys(DEFAULT_SYSTEM_CONFIGS).filter(
      (k) => DEFAULT_SYSTEM_CONFIGS[k].isPublic,
    );

    const result: Record<string, any> = {};
    for (const key of publicKeys) {
      result[key] = await this.getConfig(key);
    }
    return result;
  }

  // Typed Convenience Getters
  async getWalletConfig(): Promise<WalletConfig> {
    return this.getConfig<WalletConfig>('wallet.rules');
  }

  async getReferralConfig(): Promise<ReferralConfig> {
    return this.getConfig<ReferralConfig>('referral.rules');
  }

  async getSearchRankingConfig(): Promise<SearchRankingConfig> {
    return this.getConfig<SearchRankingConfig>('search.ranking');
  }

  async getBookingPolicyConfig(): Promise<BookingPolicyConfig> {
    return this.getConfig<BookingPolicyConfig>('booking.policies');
  }

  async getGrowthCampaignConfig(): Promise<GrowthCampaignConfig> {
    return this.getConfig<GrowthCampaignConfig>('growth.campaigns');
  }

  async getNotificationConfig(): Promise<NotificationConfig> {
    return this.getConfig<NotificationConfig>('notification.orchestration');
  }

  async getSupportSlaConfig(): Promise<SupportSlaConfig> {
    return this.getConfig<SupportSlaConfig>('support.sla');
  }

  async getPayoutConfig(): Promise<PayoutConfig> {
    return this.getConfig<PayoutConfig>('payout.rules');
  }

  async getReconciliationConfig(): Promise<ReconciliationConfig> {
    return this.getConfig<ReconciliationConfig>('reconciliation.rules');
  }

  async getAnalyticsConfig(): Promise<AnalyticsConfig> {
    return this.getConfig<AnalyticsConfig>('analytics.governance');
  }

  async getFeatureFlags(): Promise<PlatformFeatureFlags> {
    return this.getConfig<PlatformFeatureFlags>('platform.feature_flags');
  }
}
