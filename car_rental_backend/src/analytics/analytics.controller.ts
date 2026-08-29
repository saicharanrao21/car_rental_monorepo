import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { TrackAnalyticsEventDto } from './dto/track-event.dto';
import { AnalyticsQueryDto } from './dto/analytics-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Controller('analytics')
export class AnalyticsController {
  constructor(
    private readonly analyticsService: AnalyticsService,
    private readonly prisma: PrismaService,
  ) {}

  private async getVendorId(userId: string): Promise<string> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new NotFoundException('Vendor profile not found for this user.');
    }
    return vendor.id;
  }

  // ── 1. Event Tracking (Client / Public / Non-blocking) ────────────────────

  @Post('track')
  @HttpCode(HttpStatus.OK)
  async trackEvent(@Body() dto: TrackAnalyticsEventDto) {
    return this.analyticsService.trackEvent(dto);
  }

  // ── 2. Admin Analytics & Control Tower Endpoints ──────────────────────────

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('overview')
  async getMarketplaceOverview(@Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getMarketplaceOverview(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('funnel')
  async getCustomerFunnel(@Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getCustomerFunnel(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('search')
  async getSearchIntelligence(@Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getSearchIntelligence(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('cities')
  async getCityIntelligence(@Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getCityIntelligence(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('vehicles')
  async getVehicleIntelligence(@Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getVehicleIntelligence(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('vendors/:id')
  async getVendorIntelligenceForAdmin(
    @Param('id') vendorId: string,
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analyticsService.getVendorIntelligence(vendorId, query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('customers/segmentation')
  async getCustomerSegmentation() {
    return this.analyticsService.getCustomerSegmentation();
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  @Get('health')
  async getMarketplaceHealthScore() {
    return this.analyticsService.getMarketplaceHealthScore();
  }

  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_READ)
  @Get('finance-reconciliation')
  async getFinancialAnalyticsComparison() {
    return this.analyticsService.getFinancialAnalyticsComparison();
  }

  // ── 3. Vendor Isolated Analytics ──────────────────────────────────────────

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('vendor/me')
  async getMyVendorIntelligence(@Req() req: any, @Query() query: AnalyticsQueryDto) {
    const vendorId = await this.getVendorId(req.user.userId || req.user.id);
    return this.analyticsService.getVendorIntelligence(vendorId, query);
  }
}
