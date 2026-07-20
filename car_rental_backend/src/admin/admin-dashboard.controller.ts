import { Controller, Get, Query, UseGuards, ParseIntPipe } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { AdminDashboardService } from './admin-dashboard.service';

@Controller('admin/dashboard')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminDashboardController {
  constructor(private dashboardService: AdminDashboardService) {}

  @Get('kpis')
  async getKpis() {
    return this.dashboardService.getKpis();
  }

  @Get('bookings-per-day')
  async getBookingsPerDay(@Query('days', new ParseIntPipe({ optional: true })) days?: number) {
    return this.dashboardService.getBookingsPerDay(days ?? 30);
  }

  @Get('revenue-per-city')
  async getRevenuePerCity(@Query('days', new ParseIntPipe({ optional: true })) days?: number) {
    return this.dashboardService.getRevenuePerCity(days ?? 30);
  }

  @Get('recent-bookings')
  async getRecentBookings(@Query('limit', new ParseIntPipe({ optional: true })) limit?: number) {
    return this.dashboardService.getRecentBookings(limit ?? 10);
  }

  @Get('pending-approvals')
  async getPendingApprovals() {
    return this.dashboardService.getPendingVendorApprovals();
  }

  @Get('top-vendors')
  async getTopVendors(@Query('limit', new ParseIntPipe({ optional: true })) limit?: number) {
    return this.dashboardService.getTopVendorsByBookings(limit ?? 5);
  }
}
