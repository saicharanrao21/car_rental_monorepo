import { Injectable, Logger, Optional } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { RateLimitConfig } from './runtime.types';
import { RedisCacheService } from '../../redis/redis-cache.service';

export interface RateLimitCheckResult {
  allowed: boolean;
  retryAfterMs?: number;
  reason?: string;
}

interface InFlightTracker {
  activeCount: number;
  requestsLastSecond: number[];
  requestsLastMinute: number[];
}

const DEFAULT_RATE_LIMIT_CONFIG: RateLimitConfig = {
  rps: 50,
  rpm: 1000,
  burstCapacity: 20,
  concurrencyLimit: 15,
};

@Injectable()
export class ProviderRateLimiterService {
  private readonly logger = new Logger(ProviderRateLimiterService.name);
  private readonly trackers = new Map<string, InFlightTracker>();
  private readonly configs = new Map<string, RateLimitConfig>();

  constructor(@Optional() private readonly redis?: RedisCacheService) {}

  private normalizeKey(arg1: string, arg2?: string): string {
    if (arg2) {
      return `${arg1}:${arg2}`.toLowerCase();
    }
    return arg1.toLowerCase();
  }

  private getTracker(key: string): InFlightTracker {
    let tracker = this.trackers.get(key);
    if (!tracker) {
      tracker = {
        activeCount: 0,
        requestsLastSecond: [],
        requestsLastMinute: [],
      };
      this.trackers.set(key, tracker);
    }
    return tracker;
  }

  public setProviderConfig(
    arg1: string,
    arg2OrConfig: any,
    config?: Partial<RateLimitConfig>,
  ): void {
    let key: string;
    let actualConfig: Partial<RateLimitConfig>;

    if (config) {
      key = `${arg1}:${arg2OrConfig}`.toLowerCase();
      actualConfig = config;
    } else {
      key = arg1.toLowerCase();
      actualConfig = arg2OrConfig;
    }

    const current = this.configs.get(key) || { ...DEFAULT_RATE_LIMIT_CONFIG };
    this.configs.set(key, { ...current, ...actualConfig });
  }

  private getConfig(key: string): RateLimitConfig {
    return this.configs.get(key.toLowerCase()) || DEFAULT_RATE_LIMIT_CONFIG;
  }

  /**
   * Checks whether a request is allowed according to token-bucket and RPM/RPS rate limits.
   */
  public isAllowed(providerId: string, vendorId?: string, capability?: string): boolean {
    const key = providerId.toLowerCase();
    const config = this.getConfig(key);
    const now = Date.now();
    const tracker = this.getTracker(key);

    // Filter expired timestamps
    tracker.requestsLastSecond = tracker.requestsLastSecond.filter((ts) => now - ts < 1000);
    tracker.requestsLastMinute = tracker.requestsLastMinute.filter((ts) => now - ts < 60000);

    const limit = config.rps || config.burstCapacity || 50;
    if (tracker.requestsLastSecond.length >= limit) {
      return false;
    }

    if (config.rpm && tracker.requestsLastMinute.length >= config.rpm) {
      return false;
    }

    // Record request timestamp
    tracker.requestsLastSecond.push(now);
    tracker.requestsLastMinute.push(now);
    return true;
  }

  /**
   * Acquires a concurrency execution slot for the provider.
   */
  public acquireConcurrency(providerId: string): boolean {
    const key = providerId.toLowerCase();
    const config = this.getConfig(key);
    const tracker = this.getTracker(key);

    const limit = config.concurrencyLimit || 15;
    if (tracker.activeCount >= limit) {
      return false;
    }

    tracker.activeCount++;
    return true;
  }

  /**
   * Releases a concurrency execution slot for the provider.
   */
  public releaseConcurrency(providerId: string): void {
    const key = providerId.toLowerCase();
    const tracker = this.trackers.get(key);
    if (tracker && tracker.activeCount > 0) {
      tracker.activeCount--;
    }
  }

  /**
   * Clears all tracking state and active concurrency counts.
   */
  public clearAll(): void {
    this.trackers.clear();
  }

  /**
   * Legacy acquire method supporting category and tenantId.
   */
  async acquire(
    category: IntegrationCategory,
    providerId: string,
    tenantId?: string,
  ): Promise<RateLimitCheckResult> {
    const allowed = this.isAllowed(providerId, tenantId);
    if (!allowed) {
      return {
        allowed: false,
        retryAfterMs: 200,
        reason: 'Rate limit exceeded',
      };
    }
    const concurrencyAllowed = this.acquireConcurrency(providerId);
    if (!concurrencyAllowed) {
      return {
        allowed: false,
        retryAfterMs: 100,
        reason: 'Concurrency limit reached',
      };
    }
    return { allowed: true };
  }

  /**
   * Legacy release method supporting category and tenantId.
   */
  release(category: IntegrationCategory, providerId: string, tenantId?: string): void {
    this.releaseConcurrency(providerId);
  }
}
