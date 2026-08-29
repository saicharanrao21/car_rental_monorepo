import { Module } from '@nestjs/common';
import { GrowthService } from './growth.service';
import { GrowthController } from './growth.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { RedisModule } from '../redis/redis.module';
import { AdminModule } from '../admin/admin.module';
import { SystemConfigModule } from '../config-engine/system-config.module';

@Module({
  imports: [PrismaModule, RedisModule, AdminModule, SystemConfigModule],
  controllers: [GrowthController],
  providers: [GrowthService],
  exports: [GrowthService],
})
export class GrowthModule {}
