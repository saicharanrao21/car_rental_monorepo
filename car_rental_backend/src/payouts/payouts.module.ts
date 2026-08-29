import { Module, forwardRef } from '@nestjs/common';
import { PayoutsService } from './payouts.service';
import { PayoutsController } from './payouts.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';
import { SystemConfigModule } from '../config-engine/system-config.module';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [
    PrismaModule,
    NotificationsModule,
    AdminModule,
    SystemConfigModule,
    forwardRef(() => WalletsModule),
  ],
  controllers: [PayoutsController],
  providers: [PayoutsService],
  exports: [PayoutsService],
})
export class PayoutsModule {}
