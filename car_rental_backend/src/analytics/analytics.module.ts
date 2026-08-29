import { Module, forwardRef } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { AnalyticsController } from './analytics.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { RedisModule } from '../redis/redis.module';
import { SystemConfigModule } from '../config-engine/system-config.module';
import { QueuesModule } from '../queues/queues.module';

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    SystemConfigModule,
    forwardRef(() => QueuesModule),
  ],
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
  exports: [AnalyticsService],
})
export class AnalyticsModule {}
