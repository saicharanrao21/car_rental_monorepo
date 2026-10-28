import {
  Controller,
  Get,
  Inject,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';
import { REDIS_CLIENT } from './redis/redis.module';
import Redis from 'ioredis';

@Controller()
export class AppController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  @Get()
  getRoot() {
    return {
      name: 'DriveGo Car Rental API',
      version: '1.0.0',
      status: 'online',
    };
  }

  @Get('health')
  async getHealth() {
    let dbLive = false;
    let redisLive = false;

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      dbLive = true;
    } catch (err) {
      console.error(
        'Database health check failed:',
        err instanceof Error ? err.message : err,
      );
    }

    try {
      const pingRes = await this.redis.ping();
      redisLive = pingRes === 'PONG';
    } catch (err) {
      console.error(
        'Redis health check failed:',
        err instanceof Error ? err.message : err,
      );
    }

    return {
      status: dbLive && redisLive ? 'ok' : dbLive ? 'degraded' : 'error',
      db: dbLive,
      redis: redisLive,
    };
  }

  @Get('health/live')
  getLiveness() {
    return {
      status: 'alive',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('health/ready')
  async getReadiness() {
    let dbLive = false;
    let redisLive = false;

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      dbLive = true;
    } catch (err) {
      console.error(
        'Readiness check: Database unavailable:',
        err instanceof Error ? err.message : err,
      );
    }

    try {
      const pingRes = await this.redis.ping();
      redisLive = pingRes === 'PONG';
    } catch (err) {
      console.error(
        'Readiness check: Redis unavailable:',
        err instanceof Error ? err.message : err,
      );
    }

    if (!dbLive) {
      throw new HttpException(
        {
          status: 'unready',
          reason: 'Database dependency is unavailable',
          db: false,
          redis: redisLive,
          timestamp: new Date().toISOString(),
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    return {
      status: 'ready',
      db: true,
      redis: redisLive,
      timestamp: new Date().toISOString(),
    };
  }
}
