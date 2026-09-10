import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PaymentsModule } from '../payments/payments.module';
import { CorporateAccountsService } from './corporate-accounts.service';
import { CorporateAccountsController } from './corporate-accounts.controller';

@Module({
  imports: [PrismaModule, PaymentsModule],
  controllers: [CorporateAccountsController],
  providers: [CorporateAccountsService],
  exports: [CorporateAccountsService],
})
export class CorporateModule {}
