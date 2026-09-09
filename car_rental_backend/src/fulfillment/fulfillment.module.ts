import { Module, forwardRef } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { RedisModule } from '../redis/redis.module';
import { BookingsModule } from '../bookings/bookings.module';
import { FleetModule } from '../fleet/fleet.module';
import { FulfillmentOrchestratorService } from './fulfillment-orchestrator.service';
import { FulfillmentController } from './fulfillment.controller';

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    forwardRef(() => BookingsModule),
    forwardRef(() => FleetModule),
  ],
  controllers: [FulfillmentController],
  providers: [FulfillmentOrchestratorService],
  exports: [FulfillmentOrchestratorService],
})
export class FulfillmentModule {}
