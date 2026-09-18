import { Injectable, Inject, ConflictException, ServiceUnavailableException, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.constants';
import { randomUUID } from 'crypto';

@Injectable()
export class BookingLockService {
  private readonly logger = new Logger(BookingLockService.name);

  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  private getLockKey(carId: string): string {
    return `lock:car:${carId}`;
  }

  /**
   * Tries to acquire a distributed lock for creating a booking on a specific car.
   * Throws a 409 Conflict if the car is currently locked by a concurrent booking transaction.
   * Fails closed with 503 Service Unavailable if the Redis coordinator is offline/degraded.
   * Returns the lock token value to be used for safe release.
   */
  async acquireLock(carId: string, ttlMs: number = 10000): Promise<string> {
    const key = this.getLockKey(carId);
    const token = randomUUID();

    try {
      // NX - Only set if not exists, PX - Expiration in milliseconds
      const result = await this.redis.set(key, token, 'PX', ttlMs, 'NX');

      if (result !== 'OK') {
        throw new ConflictException(
          'This car is currently being booked by someone else, please try again.',
        );
      }

      return token;
    } catch (err: any) {
      if (err instanceof ConflictException) throw err;
      this.logger.error(`Distributed booking lock failed: ${err.message}`, err.stack);
      // FAIL-CLOSED: Concurrency integrity guarantees that reservations halt when lock coordinator degrades
      throw new ServiceUnavailableException(
        'Reservation concurrency coordination service is temporarily unavailable. Please retry in a few moments.',
      );
    }
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
    ttlMs: number = 20000,
  ): Promise<string> {
    const key = this.getCancellationLockKey(bookingId);
    const token = randomUUID();

    try {
      const result = await this.redis.set(key, token, 'PX', ttlMs, 'NX');

      if (result !== 'OK') {
        throw new ConflictException(
          'This booking is currently undergoing cancellation/refund processing. Please wait.',
        );
      }

      return token;
    } catch (err: any) {
      if (err instanceof ConflictException) throw err;
      this.logger.error(`Cancellation lock failed: ${err.message}`, err.stack);
      throw new ServiceUnavailableException(
        'Cancellation lock coordination service is temporarily unavailable. Please retry in a few moments.',
      );
    }
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
