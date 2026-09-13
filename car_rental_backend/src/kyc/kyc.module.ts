import { Module, forwardRef } from '@nestjs/common';
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
import { UploadsModule } from '../uploads/uploads.module';
import { IntegrationsModule } from '../integrations/integrations.module';

@Module({
  imports: [
    PrismaModule,
    AdminModule,
    NotificationsModule,
    UploadsModule,
    forwardRef(() => IntegrationsModule),
  ],
  providers: [KycService, AdditionalDriversService],
  controllers: [
    KycController,
    AdditionalDriversController,
    AdminAdditionalDriversController,
  ],
  exports: [KycService, AdditionalDriversService],
})
export class KycModule {}
