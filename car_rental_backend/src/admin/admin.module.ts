import { Module, Global } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminRevenueService } from './admin-revenue.service';
import { AuditLogService } from './audit-log.service';
import { AdminExportService } from './admin-export.service';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminRevenueController } from './admin-revenue.controller';
import { AdminCommissionController } from './admin-commission.controller';
import { AdminSettingsController } from './admin-settings.controller';
import { AdminAuditLogController } from './admin-audit-log.controller';
import { PublicSettingsController } from './public-settings.controller';
import { AdminExportController } from './admin-export.controller';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [AdminDashboardService, AdminRevenueService, AuditLogService, AdminExportService],
  controllers: [
    AdminDashboardController,
    AdminRevenueController,
    AdminCommissionController,
    AdminSettingsController,
    AdminAuditLogController,
    PublicSettingsController,
    AdminExportController,
  ],
  exports: [AuditLogService, AdminExportService],
})
export class AdminModule {}
