import { Module } from '@nestjs/common';
import { EmergencyAssistanceService } from './emergency-assistance.service';
import { EmergencyAssistanceController } from './emergency-assistance.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CommonModule } from '../common/common.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [PrismaModule, NotificationsModule, CommonModule, AdminModule],
  controllers: [EmergencyAssistanceController],
  providers: [EmergencyAssistanceService],
  exports: [EmergencyAssistanceService],
})
export class EmergencyAssistanceModule {}
