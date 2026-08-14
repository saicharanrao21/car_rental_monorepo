import { Reflector } from '@nestjs/core';
import { HttpException, HttpStatus } from '@nestjs/common';
import { RateLimiterGuard } from './rate-limiter.guard';

describe('RateLimiterGuard (Phase 1)', () => {
  let guard: RateLimiterGuard;
  let reflector: Reflector;
  let mockRedis: any;

  beforeEach(() => {
    reflector = new Reflector();
    mockRedis = {
      store: new Map<string, number>(),
      incr: jest.fn().mockImplementation((key: string) => {
        const val = (mockRedis.store.get(key) || 0) + 1;
        mockRedis.store.set(key, val);
        return Promise.resolve(val);
      }),
      expire: jest.fn().mockResolvedValue(1),
      ttl: jest.fn().mockResolvedValue(55),
    };

    guard = new RateLimiterGuard(reflector, mockRedis);
  });

  function createMockContext(
    ip: string,
    method: string,
    path: string,
    rateLimitMeta?: any,
  ) {
    const req: any = {
      ip,
      method,
      path,
      headers: {},
      user: undefined,
    };
    const res: any = {
      setHeader: jest.fn(),
    };

    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(rateLimitMeta);

    return {
      switchToHttp: () => ({
        getRequest: () => req,
        getResponse: () => res,
      }),
      getHandler: () => ({}),
      getClass: () => ({}),
      res,
    };
  }

  it('should allow requests within configured rate limit', async () => {
    const ctx = createMockContext('192.168.1.1', 'POST', '/auth/otp/send', {
      limit: 3,
      ttlSeconds: 60,
    });

    // 1st request
    const canPass1 = await guard.canActivate(ctx as any);
    expect(canPass1).toBe(true);
    expect(ctx.res.setHeader).toHaveBeenCalledWith('X-RateLimit-Limit', '3');
    expect(ctx.res.setHeader).toHaveBeenCalledWith(
      'X-RateLimit-Remaining',
      '2',
    );

    // 2nd request
    const canPass2 = await guard.canActivate(ctx as any);
    expect(canPass2).toBe(true);
    expect(ctx.res.setHeader).toHaveBeenCalledWith(
      'X-RateLimit-Remaining',
      '1',
    );

    // 3rd request
    const canPass3 = await guard.canActivate(ctx as any);
    expect(canPass3).toBe(true);
    expect(ctx.res.setHeader).toHaveBeenCalledWith(
      'X-RateLimit-Remaining',
      '0',
    );
  });

  it('should throw HTTP 429 Too Many Requests when rate limit is exceeded', async () => {
    const ctx = createMockContext('192.168.1.50', 'POST', '/auth/otp/send', {
      limit: 2,
      ttlSeconds: 60,
    });

    await guard.canActivate(ctx as any); // 1st
    await guard.canActivate(ctx as any); // 2nd

    // 3rd request should fail
    await expect(guard.canActivate(ctx as any)).rejects.toThrow(HttpException);

    try {
      await guard.canActivate(ctx as any);
    } catch (err: any) {
      expect(err.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
      expect(err.getResponse()).toMatchObject({
        statusCode: HttpStatus.TOO_MANY_REQUESTS,
        message:
          'Too Many Requests. Rate limit exceeded, please try again later.',
      });
    }
  });

  it('should fail open if Redis throws unexpected connection error', async () => {
    mockRedis.incr.mockRejectedValueOnce(new Error('Redis connection lost'));

    const ctx = createMockContext('192.168.1.99', 'POST', '/auth/otp/send', {
      limit: 5,
      ttlSeconds: 60,
    });

    const result = await guard.canActivate(ctx as any);
    expect(result).toBe(true); // Fails open gracefully
  });
});
