import { Module, Global, Provider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import RedisMock from 'ioredis-mock';
import { BookingLockService } from './booking-lock.service';
import { RedisCacheService } from './redis-cache.service';
import { DistributedLockService } from './distributed-lock.service';
import { REDIS_CLIENT } from './redis.constants';

const redisProvider: Provider = {
  provide: REDIS_CLIENT,
  useFactory: (configService: ConfigService) => {
    const redisUrl =
      configService.get<string>('REDIS_URL') || 'redis://localhost:6379';

    // Check if we have REDIS_USE_MOCK env var or if we want to run with real Redis
    if (process.env.REDIS_USE_MOCK === 'true') {
      if (configService.get<string>('NODE_ENV') === 'production') {
        throw new Error(
          'CRITICAL SECURITY CONFIGURATION ERROR: REDIS_USE_MOCK is set to true, but NODE_ENV is production! Running in-memory mock Redis in production is forbidden.',
        );
      }
      console.log('Using ioredis-mock for local development environment');
      return new RedisMock();
    }

    console.log(`Connecting to real Redis instance at: ${redisUrl}`);
    const client = new Redis(redisUrl, {
      maxRetriesPerRequest: null,
      enableReadyCheck: true,
    });

    client.on('error', (err) => {
      console.error('Redis Client Error:', err);
    });

    return client;
  },
  inject: [ConfigService],
};

@Global()
@Module({
  providers: [
    redisProvider,
    BookingLockService,
    RedisCacheService,
    DistributedLockService,
  ],
  exports: [
    REDIS_CLIENT,
    BookingLockService,
    RedisCacheService,
    DistributedLockService,
  ],
})
export class RedisModule {}
export { REDIS_CLIENT };
export * from './redis-namespace.constants';
export * from './redis-cache.service';
export * from './distributed-lock.service';
