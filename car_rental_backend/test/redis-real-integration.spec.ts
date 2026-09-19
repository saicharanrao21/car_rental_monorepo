import { Test, TestingModule } from '@nestjs/testing';
import { ConfigModule } from '@nestjs/config';
import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import Redis from 'ioredis';
import { BookingLockService } from '../src/redis/booking-lock.service';
import { DistributedLockService } from '../src/redis/distributed-lock.service';
import { RedisCacheService } from '../src/redis/redis-cache.service';
import { REDIS_CLIENT } from '../src/redis/redis.constants';
import { RedisModule } from '../src/redis/redis.module';

describe('Real Redis 8.x Integration Suite (Non-Mock Concurrency Proof)', () => {
  let moduleRef: TestingModule;
  let redisClient: Redis;
  let bookingLockService: BookingLockService;
  let distributedLockService: DistributedLockService;
  let cacheService: RedisCacheService;

  const REAL_REDIS_URL = process.env.REDIS_URL || 'redis://127.0.0.1:6379';

  beforeAll(async () => {
    // Explicitly enforce REAL Redis - fail immediately if REDIS_USE_MOCK is set to true
    process.env.REDIS_USE_MOCK = 'false';
    process.env.REDIS_URL = REAL_REDIS_URL;

    moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          load: [
            () => ({
              REDIS_URL: REAL_REDIS_URL,
              REDIS_USE_MOCK: 'false',
              NODE_ENV: 'test',
            }),
          ],
        }),
        RedisModule,
      ],
    }).compile();

    redisClient = moduleRef.get<Redis>(REDIS_CLIENT);
    bookingLockService = moduleRef.get<BookingLockService>(BookingLockService);
    distributedLockService = moduleRef.get<DistributedLockService>(DistributedLockService);
    cacheService = moduleRef.get<RedisCacheService>(RedisCacheService);
  });

  afterAll(async () => {
    if (redisClient) {
      await redisClient.quit();
    }
    if (moduleRef) {
      await moduleRef.close();
    }
  });

  beforeEach(async () => {
    // Flush test keys before each scenario
    const keys = await redisClient.keys('lock:*');
    if (keys.length > 0) {
      await redisClient.del(...keys);
    }
    const cacheKeys = await redisClient.keys('cache:*');
    if (cacheKeys.length > 0) {
      await redisClient.del(...cacheKeys);
    }
  });

  it('PROVE ENVIRONMENT: Real Redis wire protocol verification (version, ping, no ioredis-mock)', async () => {
    const pingRes = await redisClient.ping();
    expect(pingRes).toBe('PONG');

    const info = await redisClient.info();
    expect(info).toContain('redis_version');
    // Verify it is a genuine Redis server (not ioredis-mock which returns empty or simulated info)
    const versionMatch = info.match(/redis_version:([0-9.]+)/);
    expect(versionMatch).not.toBeNull();
    const version = versionMatch![1];
    console.log(`[REAL REDIS INTEGRATION] Verified genuine Redis server version: ${version}`);
    expect(parseFloat(version)).toBeGreaterThanOrEqual(5.0);
  });

  it('SCENARIO A: acquireLock succeeds once on unlocked car and returns valid UUID token', async () => {
    const carId = `car_test_${Date.now()}`;
    const token = await bookingLockService.acquireLock(carId, 5000);

    expect(typeof token).toBe('string');
    expect(token.length).toBeGreaterThan(20);

    const storedValue = await redisClient.get(`lock:car:${carId}`);
    expect(storedValue).toBe(token);

    const ttl = await redisClient.pttl(`lock:car:${carId}`);
    expect(ttl).toBeGreaterThan(0);
    expect(ttl).toBeLessThanOrEqual(5000);
  });

  it('SCENARIO B: concurrent acquireLock on the same car rejects the second caller with 409 ConflictException', async () => {
    const carId = `car_test_${Date.now()}`;
    const token1 = await bookingLockService.acquireLock(carId, 5000);
    expect(token1).toBeDefined();

    await expect(bookingLockService.acquireLock(carId, 5000)).rejects.toThrow(
      ConflictException,
    );
  });

  it('SCENARIO C: correct token release succeeds and removes key from Redis', async () => {
    const carId = `car_test_${Date.now()}`;
    const token = await bookingLockService.acquireLock(carId, 5000);

    const released = await bookingLockService.releaseLock(carId, token);
    expect(released).toBe(true);

    const exists = await redisClient.exists(`lock:car:${carId}`);
    expect(exists).toBe(0);
  });

  it('SCENARIO D: wrong token release fails (returns false) and preserves the existing lock', async () => {
    const carId = `car_test_${Date.now()}`;
    const validToken = await bookingLockService.acquireLock(carId, 5000);

    const released = await bookingLockService.releaseLock(carId, 'invalid-fake-token-uuid');
    expect(released).toBe(false);

    // Lock must remain in place with original token
    const stored = await redisClient.get(`lock:car:${carId}`);
    expect(stored).toBe(validToken);
  });

  it('SCENARIO E & F: TTL expires automatically and lock becomes acquirable after expiry without manual release', async () => {
    const carId = `car_ttl_${Date.now()}`;
    const shortTtlMs = 300; // 300ms
    const token1 = await bookingLockService.acquireLock(carId, shortTtlMs);
    expect(token1).toBeDefined();

    // Immediately before expiry, acquire must fail
    await expect(bookingLockService.acquireLock(carId, 5000)).rejects.toThrow(
      ConflictException,
    );

    // Wait for TTL to expire
    await new Promise((resolve) => setTimeout(resolve, 400));

    // Lock must have expired in Redis
    const exists = await redisClient.exists(`lock:car:${carId}`);
    expect(exists).toBe(0);

    // New caller can now acquire cleanly
    const token2 = await bookingLockService.acquireLock(carId, 5000);
    expect(token2).toBeDefined();
    expect(token2).not.toBe(token1);
  });

  it('SCENARIO G: stale lock holder cannot delete a newer lock acquired by another caller', async () => {
    const carId = `car_stale_${Date.now()}`;
    const token1 = await bookingLockService.acquireLock(carId, 250);

    // Wait for token1 to expire
    await new Promise((resolve) => setTimeout(resolve, 350));

    // Caller 2 acquires new lock with token2
    const token2 = await bookingLockService.acquireLock(carId, 5000);
    expect(token2).not.toBe(token1);

    // Stale caller 1 attempts release using old token1
    const releaseResult = await bookingLockService.releaseLock(carId, token1);
    expect(releaseResult).toBe(false);

    // Caller 2's lock must still be active
    const currentToken = await redisClient.get(`lock:car:${carId}`);
    expect(currentToken).toBe(token2);
  });

  it('SCENARIO H: Redis outage / unreachability produces 503 fail-closed behavior, not 409 or bypass', async () => {
    // Instantiate an offline Redis client pointing to an unopen port
    const offlineRedis = new Redis('redis://127.0.0.1:6399', {
      maxRetriesPerRequest: 0,
      connectTimeout: 200,
      retryStrategy: () => null, // do not reconnect
      lazyConnect: true,
    });
    const brokenService = new BookingLockService(offlineRedis);

    await expect(brokenService.acquireLock('car_offline_test', 5000)).rejects.toThrow(
      ServiceUnavailableException,
    );

    offlineRedis.disconnect();
  });

  it('SCENARIO I: High-concurrency race condition — 10 concurrent requests, exactly 1 acquires lock, 9 fail with 409', async () => {
    const carId = `car_race_${Date.now()}`;
    const concurrency = 10;
    const attempts = Array.from({ length: concurrency }, () =>
      bookingLockService
        .acquireLock(carId, 10000)
        .then((token) => ({ success: true, token, error: null }))
        .catch((err) => ({ success: false, token: null, error: err })),
    );

    const results = await Promise.all(attempts);
    const successes = results.filter((r) => r.success);
    const conflicts = results.filter(
      (r) => !r.success && r.error instanceof ConflictException,
    );

    expect(successes.length).toBe(1);
    expect(conflicts.length).toBe(concurrency - 1);

    // Clean up
    await bookingLockService.releaseLock(carId, successes[0].token!);
  });

  it('SCENARIO J: cancellation lock behaves atomically (acquire, reject concurrent, release)', async () => {
    const bookingId = `booking_cancel_${Date.now()}`;
    const token = await bookingLockService.acquireCancellationLock(bookingId, 5000);
    expect(token).toBeDefined();

    // Concurrent cancellation lock must be rejected
    await expect(
      bookingLockService.acquireCancellationLock(bookingId, 5000),
    ).rejects.toThrow(ConflictException);

    // Release cancellation lock
    const released = await bookingLockService.releaseCancellationLock(bookingId, token);
    expect(released).toBe(true);

    // Now re-acquirable
    const token2 = await bookingLockService.acquireCancellationLock(bookingId, 5000);
    expect(token2).toBeDefined();
    await bookingLockService.releaseCancellationLock(bookingId, token2);
  });

  it('SCENARIO K: DistributedLockService withLock executes critical section and guarantees release', async () => {
    const resourceKey = `lock:custom_resource_${Date.now()}`;
    let executed = false;

    await distributedLockService.withLock(
      resourceKey,
      async () => {
        executed = true;
        // Inside critical section, key must exist in Redis
        const exists = await redisClient.exists(resourceKey);
        expect(exists).toBe(1);
        return 'DONE';
      },
      5000,
    );

    expect(executed).toBe(true);
    // After execution, lock must be released
    const existsAfter = await redisClient.exists(resourceKey);
    expect(existsAfter).toBe(0);
  });

  it('SCENARIO L: RedisCacheService set, get, and TTL expiration on real Redis', async () => {
    const cacheKey = `cache:test_key_${Date.now()}`;
    const testPayload = { foo: 'bar', timestamp: Date.now(), items: [1, 2, 3] };

    await cacheService.set(cacheKey, testPayload, 2); // 2 second TTL
    const fetched = await cacheService.get<typeof testPayload>(cacheKey);
    expect(fetched).toEqual(testPayload);

    // Wait for expiration
    await new Promise((resolve) => setTimeout(resolve, 2200));
    const expired = await cacheService.get(cacheKey);
    expect(expired).toBeNull();
  });
});
