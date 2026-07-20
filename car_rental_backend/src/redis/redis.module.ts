import { Module, Global, Provider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import RedisMock from 'ioredis-mock';
import { BookingLockService } from './booking-lock.service';
import { REDIS_CLIENT } from './redis.constants';

const redisProvider: Provider = {
  provide: REDIS_CLIENT,
  useFactory: (configService: ConfigService) => {
    const redisUrl = configService.get<string>('REDIS_URL') || 'redis://localhost:6379';
    
    // Check if we have REDIS_USE_MOCK env var or if we want to run with real Redis
    if (process.env.REDIS_USE_MOCK === 'true') {
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
  providers: [redisProvider, BookingLockService],
  exports: [REDIS_CLIENT, BookingLockService],
})
export class RedisModule {}
export { REDIS_CLIENT };
