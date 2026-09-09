import { Injectable, Logger, Optional } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { IntegrationExecutionResult } from './runtime.types';
import { RedisCacheService } from '../../redis/redis-cache.service';

interface CachedEntry {
  result: IntegrationExecutionResult;
  timestamp: number;
}

@Injectable()
export class IntegrationIdempotencyService {
  private readonly logger = new Logger(IntegrationIdempotencyService.name);
  private readonly memoryCache = new Map<string, CachedEntry>();
  private readonly activeLocks = new Set<string>();
  private readonly DEFAULT_TTL_MS = 86400000; // 24 hours

  constructor(@Optional() private readonly redis?: RedisCacheService) {}

  private getCompositeKey(
    category: IntegrationCategory,
    capability: string,
    idempotencyKey: string,
    tenantId?: string,
  ): string {
    return `idemp:${category}:${capability}:${tenantId || 'global'}:${idempotencyKey}`.toLowerCase();
  }

  /**
   * Retrieves a previously cached idempotent execution result if exists.
   */
  async getCachedResult<T = any>(
    category: IntegrationCategory,
    capability: string,
    idempotencyKey?: string,
    tenantId?: string,
  ): Promise<IntegrationExecutionResult<T> | null> {
    if (!idempotencyKey) return null;

    const key = this.getCompositeKey(category, capability, idempotencyKey, tenantId);

    // 1. Check local cache
    const cached = this.memoryCache.get(key);
    if (cached) {
      if (Date.now() - cached.timestamp < this.DEFAULT_TTL_MS) {
        this.logger.log(`[IDEMPOTENCY] Replaying cached response for key: ${idempotencyKey}`);
        return cached.result as IntegrationExecutionResult<T>;
      } else {
        this.memoryCache.delete(key);
      }
    }

    // 2. Check Redis if configured
    if (this.redis) {
      try {
        const val = await this.redis.get<IntegrationExecutionResult<T>>(key);
        if (val) {
          return val;
        }
      } catch (err) {
        this.logger.warn(`Redis lookup failed for idempotency key ${idempotencyKey}: ${err}`);
      }
    }

    return null;
  }

  /**
   * Stores execution result for future idempotent replays.
   */
  async storeResult(
    category: IntegrationCategory,
    capability: string,
    idempotencyKey: string,
    result: IntegrationExecutionResult,
    tenantId?: string,
  ): Promise<void> {
    if (!idempotencyKey) return;

    const key = this.getCompositeKey(category, capability, idempotencyKey, tenantId);

    this.memoryCache.set(key, {
      result,
      timestamp: Date.now(),
    });

    if (this.redis) {
      try {
        await this.redis.set(key, result, Math.floor(this.DEFAULT_TTL_MS / 1000));
      } catch (_) {}
    }
  }

  /**
   * Acquires an execution lock for in-flight deduplication.
   */
  acquireLock(
    category: IntegrationCategory,
    capability: string,
    idempotencyKey: string,
    tenantId?: string,
  ): boolean {
    const key = this.getCompositeKey(category, capability, idempotencyKey, tenantId);
    if (this.activeLocks.has(key)) {
      return false; // Already locked in-flight
    }
    this.activeLocks.add(key);
    return true;
  }

  /**
   * Releases an in-flight execution lock.
   */
  releaseLock(
    category: IntegrationCategory,
    capability: string,
    idempotencyKey: string,
    tenantId?: string,
  ): void {
    const key = this.getCompositeKey(category, capability, idempotencyKey, tenantId);
    this.activeLocks.delete(key);
  }

  /**
   * Checks idempotency by key directly.
   */
  async checkIdempotency<T = any>(key: string): Promise<T | null> {
    const entry = this.memoryCache.get(key.toLowerCase());
    if (entry) {
      if (Date.now() - entry.timestamp < this.DEFAULT_TTL_MS) {
        return (entry.result as any)?.data ?? (entry.result as any);
      }
      this.memoryCache.delete(key.toLowerCase());
    }
    return null;
  }

  /**
   * Records success data against an idempotency key directly.
   */
  async recordSuccess(key: string, data: any): Promise<void> {
    this.memoryCache.set(key.toLowerCase(), {
      result: data,
      timestamp: Date.now(),
    });
  }

  async acquire(key: string, payload?: any): Promise<{ isNew: boolean; cachedResult?: any }> {
    const cached = await this.checkIdempotency(key);
    if (cached) {
      return { isNew: false, cachedResult: cached };
    }
    return { isNew: true };
  }

  async complete(key: string, result: any): Promise<void> {
    await this.recordSuccess(key, result);
  }

  /**
   * Clears all cached idempotency results and active locks.
   */
  clear(): void {
    this.memoryCache.clear();
    this.activeLocks.clear();
  }
}
