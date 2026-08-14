import { Injectable, Inject, ConflictException } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.constants';
import { randomUUID } from 'crypto';

@Injectable()
export class BookingLockService {
  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  private getLockKey(carId: string): string {
    return `lock:car:${carId}`;
  }

  /**
   * Tries to acquire a distributed lock for creating a booking on a specific car.
   * Throws a 409 Conflict if the car is currently locked by a concurrent booking transaction.
   * Returns the lock token value to be used for safe release.
   */
  async acquireLock(carId: string, ttlMs: number = 10000): Promise<string> {
    const key = this.getLockKey(carId);
    const token = randomUUID();

    // NX - Only set if not exists, PX - Expiration in milliseconds
    const result = await this.redis.set(key, token, 'PX', ttlMs, 'NX');

    if (result !== 'OK') {
      throw new ConflictException(
        'This car is currently being booked by someone else, please try again.',
      );
    }

    return token;
  }

  /**
   * Releases the car booking lock safely using a Lua script to compare token value first.
   */
  async releaseLock(carId: string, token: string): Promise<boolean> {
    const key = this.getLockKey(carId);

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

  private getCancellationLockKey(bookingId: string): string {
    return `lock:cancel:booking:${bookingId}`;
  }

  /**
   * Tries to acquire a distributed lock for booking cancellation/refund flow.
   * Throws a 409 Conflict if the cancellation lock is already held.
   * Returns the lock token value to be used for safe release.
   */
  async acquireCancellationLock(
    bookingId: string,
    ttlMs: number = 10000,
  ): Promise<string> {
    const key = this.getCancellationLockKey(bookingId);
    const token = randomUUID();

    const result = await this.redis.set(key, token, 'PX', ttlMs, 'NX');

    if (result !== 'OK') {
      throw new ConflictException(
        'This booking is currently undergoing cancellation/refund processing. Please wait.',
      );
    }

    return token;
  }

  /**
   * Releases the cancellation lock safely using a Lua script to compare token value first.
   */
  async releaseCancellationLock(
    bookingId: string,
    token: string,
  ): Promise<boolean> {
    const key = this.getCancellationLockKey(bookingId);

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
