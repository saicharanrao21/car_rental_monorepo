import { Module } from '@nestjs/common';
import { SupportedCitiesService } from './supported-cities.service';
import { SupportedCitiesController } from './supported-cities.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  imports: [PrismaModule, AdminModule],
  controllers: [SupportedCitiesController],
  providers: [SupportedCitiesService],
  exports: [SupportedCitiesService],
})
export class SupportedCitiesModule {}
