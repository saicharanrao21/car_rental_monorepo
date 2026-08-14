import { BookingLockService } from './booking-lock.service';
import { ConflictException } from '@nestjs/common';

describe('BookingLockService — Phase 3B Redis Cancellation Lock Tests', () => {
  let lockService: BookingLockService;
  let mockRedis: any;
  const store: Record<string, string> = {};

  beforeEach(() => {
    // Clear in-memory mock store
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

  const bookingId = 'booking_cancel_lock_123';

  it('Test 1: Two cancellation attempts for the same booking cannot simultaneously enter the critical section', async () => {
    // Attempt 1 acquires lock
    const token1 = await lockService.acquireCancellationLock(bookingId, 5000);
    expect(token1).toBeDefined();
    expect(mockRedis.set).toHaveBeenCalledWith(
      `lock:cancel:booking:${bookingId}`,
      expect.any(String),
      'PX',
      5000,
      'NX',
    );

    // Attempt 2 fails with 409 Conflict
    await expect(
      lockService.acquireCancellationLock(bookingId, 5000),
    ).rejects.toThrow(ConflictException);
  });

  it('Test 2: The lock is released after successful cancellation flow', async () => {
    const token = await lockService.acquireCancellationLock(bookingId, 5000);
    expect(store[`lock:cancel:booking:${bookingId}`]).toBe(token);

    // Release lock
    const released = await lockService.releaseCancellationLock(
      bookingId,
      token,
    );
    expect(released).toBe(true);
    expect(store[`lock:cancel:booking:${bookingId}`]).toBeUndefined();

    // Now a subsequent attempt can acquire the lock
    const token2 = await lockService.acquireCancellationLock(bookingId, 5000);
    expect(token2).toBeDefined();
  });

  it('Test 3: The lock is released when operation in try block throws', async () => {
    const token = await lockService.acquireCancellationLock(bookingId, 5000);
    expect(store[`lock:cancel:booking:${bookingId}`]).toBe(token);

    // Simulate flow with try/finally where Razorpay/DB throws
    try {
      throw new Error('Razorpay network error');
    } catch {
      // Caught
    } finally {
      await lockService.releaseCancellationLock(bookingId, token);
    }

    // Verify lock is freed
    expect(store[`lock:cancel:booking:${bookingId}`]).toBeUndefined();
    const tokenSubsequent = await lockService.acquireCancellationLock(
      bookingId,
      5000,
    );
    expect(tokenSubsequent).toBeDefined();
  });
});
