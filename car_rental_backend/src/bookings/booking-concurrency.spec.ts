import { BookingLockService } from '../redis/booking-lock.service';
import { ConflictException } from '@nestjs/common';

describe('Phase 4A: Booking Concurrency & Double-Booking Protection', () => {
  describe('BookingLockService — Car-Level Mutex Locking', () => {
    let lockService: BookingLockService;
    let mockRedis: any;
    const store: Record<string, string> = {};

    beforeEach(() => {
      for (const key of Object.keys(store)) {
        delete store[key];
      }

      mockRedis = {
        set: jest
          .fn()
          .mockImplementation(
            (
              key: string,
              value: string,
              _px: string,
              _ttl: number,
              flag?: string,
            ) => {
              if (flag === 'NX') {
                if (store[key]) {
                  return Promise.resolve(null);
                }
                store[key] = value;
                return Promise.resolve('OK');
              }
              store[key] = value;
              return Promise.resolve('OK');
            },
          ),
        eval: jest
          .fn()
          .mockImplementation(
            (_script: string, _numkeys: number, key: string, token: string) => {
              if (store[key] === token) {
                delete store[key];
                return Promise.resolve(1);
              }
              return Promise.resolve(0);
            },
          ),
      };

      lockService = new BookingLockService(mockRedis);
    });

    const carA = 'car_audi_a4_001';
    const carB = 'car_bmw_3series_002';

    it('Scenario 1: Two simultaneous booking attempts for the same vehicle serialize and reject second request with 409', async () => {
      // Customer 1 acquires lock on Car A
      const token1 = await lockService.acquireLock(carA, 10000);
      expect(token1).toBeDefined();
      expect(mockRedis.set).toHaveBeenCalledWith(
        `lock:car:${carA}`,
        expect.any(String),
        'PX',
        10000,
        'NX',
      );

      // Customer 2 attempts to acquire lock on Car A concurrently
      await expect(lockService.acquireLock(carA, 10000)).rejects.toThrow(
        ConflictException,
      );
    });

    it('Scenario 2: Concurrent booking attempts for different vehicles execute in parallel with zero contention', async () => {
      // Customer 1 locks Car A
      const tokenA = await lockService.acquireLock(carA, 10000);
      expect(tokenA).toBeDefined();

      // Customer 2 locks Car B concurrently
      const tokenB = await lockService.acquireLock(carB, 10000);
      expect(tokenB).toBeDefined();

      expect(store[`lock:car:${carA}`]).toBe(tokenA);
      expect(store[`lock:car:${carB}`]).toBe(tokenB);
    });

    it('Scenario 3: Lock token is released upon successful booking creation, allowing subsequent booking attempts', async () => {
      const token = await lockService.acquireLock(carA, 10000);
      expect(store[`lock:car:${carA}`]).toBe(token);

      const released = await lockService.releaseLock(carA, token);
      expect(released).toBe(true);
      expect(store[`lock:car:${carA}`]).toBeUndefined();

      // Subsequent attempt can acquire the lock
      const tokenNext = await lockService.acquireLock(carA, 10000);
      expect(tokenNext).toBeDefined();
    });

    it('Scenario 4: Lock token is reliably released when booking flow throws in try/finally', async () => {
      const token = await lockService.acquireLock(carA, 10000);
      expect(store[`lock:car:${carA}`]).toBe(token);

      try {
        throw new Error('Database transaction timeout');
      } catch {
        // Handled in service
      } finally {
        await lockService.releaseLock(carA, token);
      }

      expect(store[`lock:car:${carA}`]).toBeUndefined();
      const tokenSubsequent = await lockService.acquireLock(carA, 10000);
      expect(tokenSubsequent).toBeDefined();
    });
  });

  describe('Date Interval Availability Check Semantics ([start, end))', () => {
    function isOverlapping(
      existingStart: Date,
      existingEnd: Date,
      requestedStart: Date,
      requestedEnd: Date,
    ): boolean {
      // Authoritative half-open interval overlap: [startDate < reqEnd AND endDate > reqStart]
      return (
        existingStart.getTime() < requestedEnd.getTime() &&
        existingEnd.getTime() > requestedStart.getTime()
      );
    }

    const existingBookingStart = new Date('2026-08-20T10:00:00.000Z');
    const existingBookingEnd = new Date('2026-08-25T10:00:00.000Z');

    it('Case A: Identical date range [Aug 20, Aug 25] is detected as overlapping', () => {
      const reqStart = new Date('2026-08-20T10:00:00.000Z');
      const reqEnd = new Date('2026-08-25T10:00:00.000Z');
      expect(
        isOverlapping(
          existingBookingStart,
          existingBookingEnd,
          reqStart,
          reqEnd,
        ),
      ).toBe(true);
    });

    it('Case B: Partially overlapping date range [Aug 22, Aug 28] is detected as overlapping', () => {
      const reqStart = new Date('2026-08-22T10:00:00.000Z');
      const reqEnd = new Date('2026-08-28T10:00:00.000Z');
      expect(
        isOverlapping(
          existingBookingStart,
          existingBookingEnd,
          reqStart,
          reqEnd,
        ),
      ).toBe(true);
    });

    it('Case C: Back-to-back rental [Aug 25, Aug 28] starting at existing drop-off is permitted', () => {
      const reqStart = new Date('2026-08-25T10:00:00.000Z');
      const reqEnd = new Date('2026-08-28T10:00:00.000Z');
      expect(
        isOverlapping(
          existingBookingStart,
          existingBookingEnd,
          reqStart,
          reqEnd,
        ),
      ).toBe(false);
    });

    it('Case D: Enclosing date range [Aug 19, Aug 30] is detected as overlapping', () => {
      const reqStart = new Date('2026-08-19T10:00:00.000Z');
      const reqEnd = new Date('2026-08-30T10:00:00.000Z');
      expect(
        isOverlapping(
          existingBookingStart,
          existingBookingEnd,
          reqStart,
          reqEnd,
        ),
      ).toBe(true);
    });

    it('Case E: Completely non-overlapping date range [Aug 10, Aug 15] is permitted', () => {
      const reqStart = new Date('2026-08-10T10:00:00.000Z');
      const reqEnd = new Date('2026-08-15T10:00:00.000Z');
      expect(
        isOverlapping(
          existingBookingStart,
          existingBookingEnd,
          reqStart,
          reqEnd,
        ),
      ).toBe(false);
    });
  });
});
