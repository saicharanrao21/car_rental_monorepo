import { Module } from '@nestjs/common';
import { ReferralsService } from './referrals.service';
import { ReferralsController } from './referrals.controller';
import { AdminReferralsController } from './admin-referrals.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { WalletsModule } from '../wallets/wallets.module';
import { AdminModule } from '../admin/admin.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommonModule } from '../common/common.module';

@Module({
  imports: [
    PrismaModule,
    WalletsModule,
    AdminModule,
    NotificationsModule,
    CommonModule,
  ],
  controllers: [ReferralsController, AdminReferralsController],
  providers: [ReferralsService],
  exports: [ReferralsService],
})
export class ReferralsModule {}
