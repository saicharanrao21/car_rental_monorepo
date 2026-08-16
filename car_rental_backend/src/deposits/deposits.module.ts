import { Module } from '@nestjs/common';
import { DepositsService } from './deposits.service';
import { DepositRulesService } from './deposit-rules.service';
import { DepositsController } from './deposits.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { PaymentsModule } from '../payments/payments.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [PrismaModule, PaymentsModule, NotificationsModule, AdminModule],
  controllers: [DepositsController],
  providers: [DepositsService, DepositRulesService],
  exports: [DepositsService, DepositRulesService],
})
export class DepositsModule {}

