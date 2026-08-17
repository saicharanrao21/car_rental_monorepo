import { Module } from '@nestjs/common';
import { WalletsService } from './wallets.service';
import { WalletsController } from './wallets.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommonModule } from '../common/common.module';

@Module({
  imports: [PrismaModule, AdminModule, NotificationsModule, CommonModule],
  controllers: [WalletsController],
  providers: [WalletsService],
  exports: [WalletsService],
})
export class WalletsModule {}
