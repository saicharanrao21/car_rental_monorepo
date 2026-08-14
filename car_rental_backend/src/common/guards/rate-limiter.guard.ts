import {
  Injectable,
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Inject,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Reflector } from '@nestjs/core';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../../redis/redis.constants';
import {
  RATE_LIMIT_KEY,
  RateLimitOptions,
} from '../decorators/rate-limit.decorator';

@Injectable()
export class RateLimiterGuard implements CanActivate {
  private readonly logger = new Logger(RateLimiterGuard.name);

  constructor(
    private readonly reflector: Reflector,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const rateLimitOptions = this.reflector.getAllAndOverride<RateLimitOptions>(
      RATE_LIMIT_KEY,
      [context.getHandler(), context.getClass()],
    );

    // Default rate limit: 100 requests per 60s if not explicitly configured on handler/controller
    const limit = rateLimitOptions?.limit ?? 100;
    const ttlSeconds = rateLimitOptions?.ttlSeconds ?? 60;

    const req = context
      .switchToHttp()
      .getRequest<Request & { user?: { userId?: string } }>();
    const res = context.switchToHttp().getResponse<Response>();

    // Determine client identifier: authenticated userId or client IP
    const clientIp =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      req.socket?.remoteAddress ||
      'unknown-ip';

    const userId = req.user?.userId;
    const identifier = userId ? `user:${userId}` : `ip:${clientIp}`;
    const endpoint = `${req.method}:${req.baseUrl || ''}${req.path || ''}`;
    const key = `ratelimit:${identifier}:${endpoint}`;

    try {
      const current = await this.redis.incr(key);
      if (current === 1) {
        await this.redis.expire(key, ttlSeconds);
      }

      const remaining = Math.max(0, limit - current);
      const ttl = await this.redis.ttl(key);

      // Set standard RateLimit headers if response object is available
      if (res && res.setHeader) {
        res.setHeader('X-RateLimit-Limit', limit.toString());
        res.setHeader('X-RateLimit-Remaining', remaining.toString());
        res.setHeader(
          'X-RateLimit-Reset',
          ttl > 0 ? ttl.toString() : ttlSeconds.toString(),
        );
      }

      if (current > limit) {
        if (res && res.setHeader) {
          res.setHeader(
            'Retry-After',
            ttl > 0 ? ttl.toString() : ttlSeconds.toString(),
          );
        }
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            message:
              'Too Many Requests. Rate limit exceeded, please try again later.',
            retryAfterSeconds: ttl > 0 ? ttl : ttlSeconds,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      return true;
    } catch (err) {
      if (err instanceof HttpException) {
        throw err;
      }
      const errorMsg = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Rate limiter Redis error: ${errorMsg}. Failing open.`);
      return true;
    }
  }
}
