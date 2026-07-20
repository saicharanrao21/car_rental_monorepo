import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminRevenueService } from './admin-revenue.service';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminRevenueController } from './admin-revenue.controller';

@Module({
  imports: [PrismaModule],
  providers: [AdminDashboardService, AdminRevenueService],
  controllers: [AdminDashboardController, AdminRevenueController],
})
export class AdminModule {}
