import { Injectable, Inject, ConflictException } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.constants';
import { randomUUID } from 'crypto';

@Injectable()
export class BookingLockService {
  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  private getLockKey(carId: string, startDate: Date, endDate: Date): string {
    return `lock:car:${carId}:${startDate.toISOString()}:${endDate.toISOString()}`;
  }

  /**
   * Tries to acquire a lock for a car booking in a specific date range.
   * Throws a 409 Conflict if the lock is already held.
   * Returns the lock token value to be used for release.
   */
  async acquireLock(carId: string, startDate: Date, endDate: Date, ttlMs: number = 10000): Promise<string> {
    const key = this.getLockKey(carId, startDate, endDate);
    const token = randomUUID();

    // NX - Only set if not exists, PX - Expiration in milliseconds
    const result = await this.redis.set(key, token, 'PX', ttlMs, 'NX');

    if (result !== 'OK') {
      throw new ConflictException('This car is currently being booked by someone else, please try again.');
    }

    return token;
  }

  /**
   * Releases the lock safely using a Lua script to compare value first.
   */
  async releaseLock(carId: string, startDate: Date, endDate: Date, token: string): Promise<boolean> {
    const key = this.getLockKey(carId, startDate, endDate);
    
    const luaScript = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
      else
          return 0
      end
    `;

    const result = await this.redis.eval(luaScript, 1, key, token);
    return result === 1;
  }
}
