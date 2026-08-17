import { Module } from '@nestjs/common';
import { SupportTicketsService } from './support-tickets.service';
import { SupportTicketsController } from './support-tickets.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommonModule } from '../common/common.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [PrismaModule, NotificationsModule, CommonModule, AdminModule],
  controllers: [SupportTicketsController],
  providers: [SupportTicketsService],
  exports: [SupportTicketsService],
})
export class SupportTicketsModule {}
