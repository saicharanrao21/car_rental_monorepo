import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';
import { KycService } from './kyc.service';
import { KycController } from './kyc.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdditionalDriversService } from './additional-drivers.service';
import {
  AdditionalDriversController,
  AdminAdditionalDriversController,
} from './additional-drivers.controller';

@Module({
  imports: [PrismaModule, AdminModule, NotificationsModule],
  providers: [KycService, AdditionalDriversService],
  controllers: [
    KycController,
    AdditionalDriversController,
    AdminAdditionalDriversController,
  ],
  exports: [KycService, AdditionalDriversService],
})
export class KycModule {}
