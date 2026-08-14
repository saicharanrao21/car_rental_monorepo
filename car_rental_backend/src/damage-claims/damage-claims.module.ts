import { Module } from '@nestjs/common';
import { DamageClaimsService } from './damage-claims.service';
import { DamageClaimsController } from './damage-claims.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { DepositsModule } from '../deposits/deposits.module';
import { UploadsModule } from '../uploads/uploads.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [
    PrismaModule,
    DepositsModule,
    UploadsModule,
    NotificationsModule,
    AdminModule,
  ],
  controllers: [DamageClaimsController],
  providers: [DamageClaimsService],
  exports: [DamageClaimsService],
})
export class DamageClaimsModule {}
