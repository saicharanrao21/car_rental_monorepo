import { Controller, Get, Inject } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';
import { REDIS_CLIENT } from './redis/redis.module';
import Redis from 'ioredis';

@Controller()
export class AppController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  @Get('health')
  async getHealth() {
    let dbLive = false;
    let redisLive = false;

    try {
      // Ping Prisma database
      await this.prisma.$queryRaw`SELECT 1`;
      dbLive = true;
    } catch (err) {
      console.error('Database health check failed:', err);
    }

    try {
      // Ping Redis client
      const pingRes = await this.redis.ping();
      redisLive = pingRes === 'PONG';
    } catch (err) {
      console.error('Redis health check failed:', err);
    }

    return {
      status: dbLive && redisLive ? 'ok' : 'error',
      db: dbLive,
      redis: redisLive,
    };
  }
}
