import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { CorporateAccountsService } from './corporate-accounts.service';
import { CorporateAccountsController } from './corporate-accounts.controller';

@Module({
  imports: [PrismaModule],
  controllers: [CorporateAccountsController],
  providers: [CorporateAccountsService],
  exports: [CorporateAccountsService],
})
export class CorporateModule {}
