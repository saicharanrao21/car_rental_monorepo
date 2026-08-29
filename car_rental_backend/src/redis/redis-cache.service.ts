import { Injectable, Inject, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.constants';

@Injectable()
export class RedisCacheService {
  private readonly logger = new Logger(RedisCacheService.name);

  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  /**
   * Retrieves a typed value from Redis cache.
   * Returns null on cache miss or deserialization failure.
   */
  async get<T>(key: string): Promise<T | null> {
    try {
      const raw = await this.redis.get(key);
      if (!raw) return null;
      return JSON.parse(raw) as T;
    } catch (err: any) {
      this.logger.warn(`Redis cache get error for key [${key}]: ${err?.message}`);
      return null;
    }
  }

  /**
   * Stores a typed value in Redis cache with an expiration in seconds.
   */
  async set<T>(key: string, value: T, ttlSeconds: number = 300): Promise<boolean> {
    try {
      const serialized = JSON.stringify(value);
      const res = await this.redis.set(key, serialized, 'EX', ttlSeconds);
      return res === 'OK';
    } catch (err: any) {
      this.logger.warn(`Redis cache set error for key [${key}]: ${err?.message}`);
      return false;
    }
  }

  /**
   * Deletes a specific cache key.
   */
  async delete(key: string): Promise<boolean> {
    try {
      const res = await this.redis.del(key);
      return res > 0;
    } catch (err: any) {
      this.logger.warn(`Redis cache del error for key [${key}]: ${err?.message}`);
      return false;
    }
  }

  /**
   * Invalids all keys matching a pattern (e.g. "cache:search:cars:*").
   * Uses SCAN for safe non-blocking iteration in production.
   */
  async invalidatePattern(pattern: string): Promise<number> {
    try {
      let cursor = '0';
      let deletedCount = 0;
      do {
        // SCAN with batch size 100 to prevent Redis event-loop blocking
        const [nextCursor, keys] = await this.redis.scan(
          cursor,
          'MATCH',
          pattern,
          'COUNT',
          100,
        );
        cursor = nextCursor;
        if (keys.length > 0) {
          const res = await this.redis.del(...keys);
          deletedCount += res;
        }
      } while (cursor !== '0');

      return deletedCount;
    } catch (err: any) {
      this.logger.warn(
        `Redis pattern invalidation error for [${pattern}]: ${err?.message}`,
      );
      return 0;
    }
  }

  /**
   * Helper for Cache-Aside pattern: returns cached value or computes and caches it.
   */
  async getOrSet<T>(
    key: string,
    fetchFn: () => Promise<T>,
    ttlSeconds: number = 300,
  ): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null && cached !== undefined) {
      return cached;
    }

    const fresh = await fetchFn();
    if (fresh !== null && fresh !== undefined) {
      await this.set(key, fresh, ttlSeconds);
    }
    return fresh;
  }
}
