import { Test, TestingModule } from '@nestjs/testing';
import { RedisCacheService } from './redis-cache.service';
import { DistributedLockService } from './distributed-lock.service';
import { REDIS_CLIENT } from './redis.constants';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from './redis-namespace.constants';
import { ConflictException } from '@nestjs/common';

describe('Phase 27.1 — Redis Architecture & Distributed Locking Tests', () => {
  let cacheService: RedisCacheService;
  let lockService: DistributedLockService;
  let mockRedis: any;

  beforeEach(async () => {
    const storage = new Map<string, string>();

    mockRedis = {
      get: jest.fn(async (key: string) => storage.get(key) || null),
      set: jest.fn(
        async (
          key: string,
          val: string,
          modeOrPx?: string,
          ttl?: number,
          nx?: string,
        ) => {
          if (nx === 'NX' && storage.has(key)) {
            return null;
          }
          storage.set(key, val);
          return 'OK';
        },
      ),
      del: jest.fn(async (...keys: string[]) => {
        let count = 0;
        for (const k of keys) {
          if (storage.delete(k)) count++;
        }
        return count;
      }),
      scan: jest.fn(async (cursor: string, match: string, pattern: string) => {
        const matchingKeys = Array.from(storage.keys()).filter((k) =>
          k.startsWith(pattern.replace('*', '')),
        );
        return ['0', matchingKeys];
      }),
      eval: jest.fn(
        async (script: string, numKeys: number, key: string, token: string) => {
          if (storage.get(key) === token) {
            storage.delete(key);
            return 1;
          }
          return 0;
        },
      ),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisCacheService,
        DistributedLockService,
        { provide: REDIS_CLIENT, useValue: mockRedis },
      ],
    }).compile();

    cacheService = module.get<RedisCacheService>(RedisCacheService);
    lockService = module.get<DistributedLockService>(DistributedLockService);
  });

  describe('Redis Namespaces & Key Standardization', () => {
    it('generates consistent, standardized namespaced keys', () => {
      expect(REDIS_NAMESPACES.AUTH.OTP_RATE_LIMIT('9876543210')).toBe(
        'auth:otp:ratelimit:9876543210',
      );
      expect(REDIS_NAMESPACES.LOCK.CAR('car_123')).toBe('lock:car:car_123');
      expect(REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES()).toBe('cache:cities:all');
      expect(REDIS_NAMESPACES.CACHE.SYSTEM_CONFIG('wallet.rules')).toBe(
        'cache:config:wallet.rules',
      );
      expect(DEFAULT_CACHE_TTLS.MEDIUM_TERM).toBe(300);
    });
  });

  describe('RedisCacheService', () => {
    it('sets and gets typed objects successfully', async () => {
      const data = { city: 'Mumbai', activeCars: 42 };
      const key = 'cache:test:city';

      const setOk = await cacheService.set(key, data, 60);
      expect(setOk).toBe(true);

      const cached = await cacheService.get<typeof data>(key);
      expect(cached).toEqual(data);
    });

    it('returns null on cache miss', async () => {
      const missing = await cacheService.get('cache:nonexistent');
      expect(missing).toBeNull();
    });

    it('implements getOrSet cache-aside helper', async () => {
      const fetchFn = jest.fn(async () => ({ computedValue: 100 }));
      const key = 'cache:aside:test';

      // 1. Initial call executes fetchFn
      const first = await cacheService.getOrSet(key, fetchFn, 60);
      expect(first).toEqual({ computedValue: 100 });
      expect(fetchFn).toHaveBeenCalledTimes(1);

      // 2. Second call retrieves from cache without invoking fetchFn
      const second = await cacheService.getOrSet(key, fetchFn, 60);
      expect(second).toEqual({ computedValue: 100 });
      expect(fetchFn).toHaveBeenCalledTimes(1);
    });

    it('invalidates keys by pattern using SCAN', async () => {
      await cacheService.set('cache:search:cars:mumbai', { count: 10 });
      await cacheService.set('cache:search:cars:delhi', { count: 5 });
      await cacheService.set('cache:other:data', { val: 1 });

      const deleted = await cacheService.invalidatePattern('cache:search:cars:*');
      expect(deleted).toBe(2);

      const checkMumbai = await cacheService.get('cache:search:cars:mumbai');
      expect(checkMumbai).toBeNull();
      const checkOther = await cacheService.get('cache:other:data');
      expect(checkOther).not.toBeNull();
    });
  });

  describe('DistributedLockService', () => {
    it('acquires and releases distributed lock atomically', async () => {
      const lockKey = REDIS_NAMESPACES.LOCK.CAR('car_abc');

      const handle = await lockService.acquire(lockKey, 5000);
      expect(handle.resourceKey).toBe(lockKey);
      expect(handle.token).toBeDefined();

      const released = await lockService.release(handle);
      expect(released).toBe(true);
    });

    it('throws ConflictException on concurrent lock contention', async () => {
      const lockKey = REDIS_NAMESPACES.LOCK.CAR('car_busy');

      await lockService.acquire(lockKey, 5000);

      await expect(lockService.acquire(lockKey, 5000)).rejects.toThrow(
        ConflictException,
      );
    });

    it('executes action inside withLock and releases automatically', async () => {
      const lockKey = REDIS_NAMESPACES.LOCK.BOOKING('book_999');

      let executed = false;
      const result = await lockService.withLock(lockKey, async () => {
        executed = true;
        return 'success_payload';
      });

      expect(executed).toBe(true);
      expect(result).toBe('success_payload');

      // Lock should now be free for subsequent acquisition
      const newHandle = await lockService.acquire(lockKey, 5000);
      expect(newHandle).toBeDefined();
      await lockService.release(newHandle);
    });
  });
});
