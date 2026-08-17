import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { FraudService } from './fraud.service';
import { AdminFraudController } from './admin-fraud.controller';

@Module({
  imports: [PrismaModule],
  controllers: [AdminFraudController],
  providers: [FraudService],
  exports: [FraudService],
})
export class FraudModule {}
