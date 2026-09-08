import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigValidator } from './system-config-validator';
import {
  DEFAULT_SYSTEM_CONFIGS,
  DetailedConfigResult,
  SetConfigOptions,
  ConfigUpdateItem,
  BatchConfigUpdateResult,
  ConfigAuditHistoryItem,
  WalletConfig,
  LoyaltyConfig,
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
  TaxConfig,
  QuoteConfig,
  DurationDiscountTier,
  CancellationMatrixConfig,
  CommissionConfig,
  DepositDefaultsConfig,
  VendorOnboardingRulesConfig,
  FleetOperationsRulesConfig,
} from './system-config.interface';

@Injectable()
export class SystemConfigService {
  private readonly logger = new Logger(SystemConfigService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly auditLogService?: AuditLogService,
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

      if (record && record.value !== null && record.value !== undefined) {
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
   * Resolves detailed configuration with canonical source distinction:
   * Returns whether value is explicitly configured in DB or running on defaults,
   * along with version, metadata, and exposure level.
   */
  async getDetailedConfig<T = any>(key: string): Promise<DetailedConfigResult<T>> {
    const defaultMeta = DEFAULT_SYSTEM_CONFIGS[key];

    let record: any = null;
    try {
      record = await this.prisma.systemConfig.findUnique({
        where: { key },
      });
    } catch (err: any) {
      this.logger.warn(`Failed reading SystemConfig from DB for [${key}]: ${err?.message}`);
    }

    if (record && record.value !== null && record.value !== undefined) {
      const version = await this.getConfigVersion(key, record);
      let effectiveValue = record.value;
      if (
        effectiveValue &&
        typeof effectiveValue === 'object' &&
        !Array.isArray(effectiveValue) &&
        '_version' in effectiveValue
      ) {
        const { _version, ...cleanValue } = effectiveValue;
        effectiveValue = cleanValue;
      }

      return {
        key: record.key,
        effectiveValue: effectiveValue as T,
        source: 'DATABASE',
        isExplicitlyConfigured: true,
        version,
        updatedAt: record.updatedAt || null,
        updatedBy: record.updatedBy || null,
        category: record.category,
        description: record.description || null,
        isPublic: record.isPublic,
      };
    }

    if (defaultMeta) {
      return {
        key,
        effectiveValue: defaultMeta.value as T,
        source: 'DEFAULT_FALLBACK',
        isExplicitlyConfigured: false,
        version: 1,
        updatedAt: null,
        updatedBy: null,
        category: defaultMeta.category,
        description: defaultMeta.description || null,
        isPublic: defaultMeta.isPublic,
      };
    }

    throw new NotFoundException(`Configuration key [${key}] not found.`);
  }

  /**
   * Retrieves all known platform configurations with their detailed resolution states.
   */
  async getAllDetailedConfigs(): Promise<DetailedConfigResult[]> {
    const keys = Object.keys(DEFAULT_SYSTEM_CONFIGS);
    const results: DetailedConfigResult[] = [];
    for (const key of keys) {
      results.push(await this.getDetailedConfig(key));
    }
    return results;
  }

  /**
   * Sets or updates a configuration value with:
   * - Strict optimistic concurrency control (OCC)
   * - Immutable audit trail creation (previous vs new values)
   * - Atomic cache invalidation
   */
  async setConfig(
    key: string,
    value: any,
    updatedByUserId?: string,
    options?: SetConfigOptions,
  ): Promise<any> {
    const existing = await this.prisma.systemConfig
      .findUnique({
        where: { key },
      })
      .catch(() => null);

    const currentVersion = await this.getConfigVersion(key, existing);

    // Optimistic Concurrency Control
    if (options?.expectedVersion !== undefined && options.expectedVersion !== null) {
      if (existing && currentVersion !== options.expectedVersion) {
        throw new ConflictException(
          `Configuration key [${key}] has been modified by another administrator (version mismatch: expected v${options.expectedVersion}, current is v${currentVersion}). Please reload before updating.`,
        );
      }
    }

    const defaultMeta = DEFAULT_SYSTEM_CONFIGS[key] || {
      category: 'GENERAL',
      description: 'Dynamic configuration parameter',
      isPublic: false,
    };

    let previousValue = defaultMeta.value ?? null;
    if (existing && existing.value !== null && existing.value !== undefined) {
      if (
        typeof existing.value === 'object' &&
        !Array.isArray(existing.value) &&
        '_version' in existing.value
      ) {
        const { _version, ...clean } = existing.value;
        previousValue = clean;
      } else {
        previousValue = existing.value;
      }
    }

    const newVersion = currentVersion + 1;

    // Persist version metadata directly on object payloads
    let persistedValue = value;
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      persistedValue = { ...value, _version: newVersion };
    }

    const record = await this.prisma.systemConfig.upsert({
      where: { key },
      create: {
        key,
        value: persistedValue,
        category: defaultMeta.category,
        description: defaultMeta.description,
        isPublic: defaultMeta.isPublic,
        updatedBy: updatedByUserId || 'system',
      },
      update: {
        value: persistedValue,
        updatedBy: updatedByUserId || 'system',
      },
    });

    // Invalidate Cache
    const cacheKey = REDIS_NAMESPACES.CACHE.SYSTEM_CONFIG(key);
    await this.cacheService.delete(cacheKey);

    // Record immutable audit log
    await this.recordAudit(
      key,
      previousValue,
      value,
      updatedByUserId || 'system',
      newVersion,
      options?.reason,
      options?.ip,
    );

    this.logger.log(
      `[CONFIG_UPDATED] Key: ${key} (v${newVersion}) by ${updatedByUserId || 'system'}`,
    );

    return record;
  }

  /**
   * Safely updates multiple configuration keys in an atomic sequence:
   * Validates all items and checks concurrency up-front before mutating.
   */
  async batchSetConfigs(
    items: ConfigUpdateItem[],
    userId?: string,
    reason?: string,
  ): Promise<BatchConfigUpdateResult> {
    if (!Array.isArray(items) || items.length === 0) {
      throw new BadRequestException('Batch update requires a non-empty array of configuration items.');
    }

    // 1. Up-front schema & semantic validation
    for (const item of items) {
      if (!item || typeof item !== 'object' || !item.key) {
        throw new BadRequestException('Each item in batch configs must contain a valid "key".');
      }
      SystemConfigValidator.validate(item.key, item.value);
    }

    // 2. Up-front concurrency validation
    for (const item of items) {
      if (item.expectedVersion !== undefined && item.expectedVersion !== null) {
        const existing = await this.prisma.systemConfig
          .findUnique({ where: { key: item.key } })
          .catch(() => null);
        const currentVersion = await this.getConfigVersion(item.key, existing);
        if (existing && currentVersion !== item.expectedVersion) {
          throw new ConflictException(
            `Concurrency conflict on [${item.key}]: expected v${item.expectedVersion}, but current is v${currentVersion}. Batch update aborted.`,
          );
        }
      }
    }

    // 3. Apply updates
    const updatedKeys: string[] = [];
    for (const item of items) {
      await this.setConfig(item.key, item.value, userId, {
        expectedVersion: item.expectedVersion,
        reason: reason || 'Batch configuration update',
      });
      updatedKeys.push(item.key);
    }

    return {
      success: true,
      updatedCount: updatedKeys.length,
      updatedKeys,
    };
  }

  /**
   * Retrieves audit log history for a specific configuration key.
   */
  async getConfigAuditHistory(key: string, limit = 50): Promise<ConfigAuditHistoryItem[]> {
    if (!this.prisma || !this.prisma.auditLog) {
      return [];
    }

    try {
      const logs = await this.prisma.auditLog.findMany({
        where: {
          targetType: 'SYSTEM_CONFIG',
          targetId: key,
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
        include: {
          adminUser: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true,
            },
          },
        },
      });

      return logs.map((log: any) => {
        const meta = (log.metadata as any) || {};
        return {
          id: log.id,
          action: log.action,
          key: log.targetId,
          previousValue: meta.previousValue ?? null,
          newValue: meta.newValue ?? null,
          adminUserId: log.adminUserId,
          adminUser: log.adminUser || null,
          version: meta.version ?? undefined,
          reason: meta.reason ?? undefined,
          timestamp: log.createdAt,
        };
      });
    } catch (err: any) {
      this.logger.warn(`Failed querying audit logs for [${key}]: ${err?.message}`);
      return [];
    }
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

  // Version resolution helper
  private async getConfigVersion(key: string, record?: any): Promise<number> {
    if (
      record &&
      record.value &&
      typeof record.value === 'object' &&
      !Array.isArray(record.value) &&
      typeof record.value._version === 'number'
    ) {
      return record.value._version;
    }

    // Monotonic counter via indexed audit logs count
    try {
      if (this.prisma && this.prisma.auditLog && typeof this.prisma.auditLog.count === 'function') {
        const count = await this.prisma.auditLog.count({
          where: { targetType: 'SYSTEM_CONFIG', targetId: key },
        });
        return count + 1;
      }
    } catch (err: any) {
      this.logger.warn(`Failed counting audit logs for version: ${err?.message}`);
    }

    return 1;
  }

  // Audit recording helper
  private async recordAudit(
    key: string,
    previousValue: any,
    newValue: any,
    userId: string,
    version: number,
    reason?: string,
    ip?: string,
  ): Promise<void> {
    const metadata = {
      key,
      previousValue,
      newValue,
      version,
      timestamp: new Date().toISOString(),
      reason,
      ip,
    };

    if (this.auditLogService) {
      try {
        await this.auditLogService.log(
          userId,
          'CONFIG_UPDATED',
          'SYSTEM_CONFIG',
          key,
          metadata,
        );
        return;
      } catch (err: any) {
        this.logger.warn(`AuditLogService failed, falling back to direct Prisma log: ${err?.message}`);
      }
    }

    try {
      if (this.prisma && this.prisma.auditLog) {
        let targetAdminId = userId;
        try {
          if (this.prisma.user) {
            const user = await this.prisma.user.findUnique({
              where: { id: userId },
              select: { id: true },
            });
            if (!user) {
              const anyAdmin = await this.prisma.user.findFirst({
                where: { role: 'ADMIN' },
                select: { id: true },
              });
              if (anyAdmin) targetAdminId = anyAdmin.id;
            }
          }
        } catch (_) {}

        await this.prisma.auditLog.create({
          data: {
            adminUserId: targetAdminId,
            action: 'CONFIG_UPDATED',
            targetType: 'SYSTEM_CONFIG',
            targetId: key,
            metadata,
          },
        });
      }
    } catch (err: any) {
      this.logger.warn(`Failed recording audit log for ${key}: ${err?.message}`);
    }
  }

  // Typed Convenience Getters
  async getWalletConfig(): Promise<WalletConfig> {
    return this.getConfig<WalletConfig>('wallet.rules');
  }

  async getLoyaltyConfig(): Promise<LoyaltyConfig> {
    return this.getConfig<LoyaltyConfig>('loyalty.rules');
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

  async getTaxConfig(): Promise<TaxConfig> {
    return this.getConfig<TaxConfig>('pricing.tax');
  }

  async getQuoteConfig(): Promise<QuoteConfig> {
    return this.getConfig<QuoteConfig>('pricing.quote');
  }

  async getDurationDiscountsConfig(): Promise<DurationDiscountTier[]> {
    const raw = await this.getConfig<any>('pricing.duration_discounts');
    if (Array.isArray(raw)) return raw;
    if (raw && Array.isArray(raw.tiers)) return raw.tiers;
    return [];
  }

  async getCancellationMatrixConfig(): Promise<CancellationMatrixConfig> {
    return this.getConfig<CancellationMatrixConfig>('booking.cancellation_matrix');
  }

  async getCommissionConfig(): Promise<CommissionConfig> {
    return this.getConfig<CommissionConfig>('pricing.commission');
  }

  async getDepositDefaultsConfig(): Promise<DepositDefaultsConfig> {
    return this.getConfig<DepositDefaultsConfig>('deposits.defaults');
  }

  async getVendorOnboardingConfig(): Promise<VendorOnboardingRulesConfig> {
    return this.getConfig<VendorOnboardingRulesConfig>('vendor.onboarding.rules');
  }

  async getFleetOperationsConfig(): Promise<FleetOperationsRulesConfig> {
    return this.getConfig<FleetOperationsRulesConfig>('fleet.operations.rules');
  }
}
