import { Injectable, Inject, Logger, ConflictException } from '@nestjs/common';
import Redis from 'ioredis';
import { randomUUID } from 'crypto';
import { REDIS_CLIENT } from './redis.constants';
import { REDIS_NAMESPACES } from './redis-namespace.constants';

export interface LockHandle {
  resourceKey: string;
  token: string;
  expiresAt: number;
}

@Injectable()
export class DistributedLockService {
  private readonly logger = new Logger(DistributedLockService.name);

  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  /**
   * Attempts to acquire an atomic distributed lock on a resource.
   * @param resourceKey Full redis key for the lock
   * @param ttlMs Time-to-live in milliseconds
   * @param errorMessage Custom exception message if lock acquisition fails
   */
  async acquire(
    resourceKey: string,
    ttlMs: number = 10000,
    errorMessage: string = 'Resource is currently locked by another concurrent process. Please try again.',
  ): Promise<LockHandle> {
    const token = randomUUID();
    const result = await this.redis.set(resourceKey, token, 'PX', ttlMs, 'NX');

    if (result !== 'OK') {
      this.logger.warn(`Failed to acquire distributed lock for [${resourceKey}]`);
      throw new ConflictException(errorMessage);
    }

    return {
      resourceKey,
      token,
      expiresAt: Date.now() + ttlMs,
    };
  }

  /**
   * Safely releases a distributed lock using an atomic Lua script to ensure
   * only the original lock holder can release it.
   */
  async release(handle: LockHandle): Promise<boolean> {
    const luaScript = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
      else
          return 0
      end
    `;

    try {
      const result = await this.redis.eval(
        luaScript,
        1,
        handle.resourceKey,
        handle.token,
      );
      return result === 1;
    } catch (err: any) {
      this.logger.error(
        `Error releasing lock for [${handle.resourceKey}]: ${err?.message}`,
      );
      return false;
    }
  }

  /**
   * Executes a critical section wrapped in a distributed lock, guaranteeing release on completion or failure.
   */
  async withLock<T>(
    resourceKey: string,
    action: () => Promise<T>,
    ttlMs: number = 10000,
    errorMessage?: string,
  ): Promise<T> {
    const handle = await this.acquire(resourceKey, ttlMs, errorMessage);
    try {
      return await action();
    } finally {
      await this.release(handle);
    }
  }
}
