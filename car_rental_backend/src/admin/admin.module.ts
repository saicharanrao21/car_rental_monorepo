import { Module, Global } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminRevenueService } from './admin-revenue.service';
import { AuditLogService } from './audit-log.service';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminRevenueController } from './admin-revenue.controller';
import { AdminCommissionController } from './admin-commission.controller';
import { AdminSettingsController } from './admin-settings.controller';
import { AdminAuditLogController } from './admin-audit-log.controller';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [AdminDashboardService, AdminRevenueService, AuditLogService],
  controllers: [
    AdminDashboardController,
    AdminRevenueController,
    AdminCommissionController,
    AdminSettingsController,
    AdminAuditLogController,
  ],
  exports: [AuditLogService],
})
export class AdminModule {}
