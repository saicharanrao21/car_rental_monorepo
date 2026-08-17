import {
  Controller,
  Get,
  Query,
  Res,
  UseGuards,
  ParseIntPipe,
  BadRequestException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, BookingStatus } from '@prisma/client';
import { AdminRevenueService } from './admin-revenue.service';
import { DateRangeDto } from '../common/dto/date-range.dto';

@Controller('admin/revenue')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminRevenueController {
  constructor(private revenueService: AdminRevenueService) {}

  private validateDateRange(dto: DateRangeDto) {
    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException(
        'Invalid date format. Must be valid ISO strings.',
      );
    }
    if (start > end) {
      throw new BadRequestException(
        'startDate must be before or equal to endDate',
      );
    }
  }

  @Get('summary')
  async getSummary(
    @Query() query: DateRangeDto,
    @Query('city') city?: string,
  ) {
    this.validateDateRange(query);
    return this.revenueService.getRevenueSummary(query, city);
  }

  @Get('over-time')
  async getOverTime(
    @Query() query: DateRangeDto,
    @Query('city') city?: string,
  ) {
    this.validateDateRange(query);
    return this.revenueService.getRevenueOverTime(query, city);
  }

  @Get('by-city')
  async getByCity(@Query() query: DateRangeDto) {
    this.validateDateRange(query);
    return this.revenueService.getBookingsByCity(query);
  }

  @Get('by-trip-type')
  async getByTripType(@Query() query: DateRangeDto) {
    this.validateDateRange(query);
    return this.revenueService.getBookingsByTripType(query);
  }

  @Get('top-vendors')
  async getTopVendors(
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.revenueService.getTopVendorsByRevenue(limit ?? 10);
  }

  @Get('booking-stats')
  async getBookingStats(
    @Query() query: DateRangeDto,
    @Query('city') city?: string,
  ) {
    this.validateDateRange(query);
    return this.revenueService.getBookingLifecycleStats(query, city);
  }

  @Get('fleet-stats')
  async getFleetStats(@Query('city') city?: string) {
    return this.revenueService.getFleetUtilizationStats(city);
  }

  @Get('customer-stats')
  async getCustomerStats(@Query() query: DateRangeDto) {
    this.validateDateRange(query);
    return this.revenueService.getCustomerGrowthStats(query);
  }

  @Get('addon-stats')
  async getAddonStats(
    @Query() query: DateRangeDto,
    @Query('city') city?: string,
  ) {
    this.validateDateRange(query);
    return this.revenueService.getAddonAdoptionStats(query, city);
  }

  @Get('export/csv')
  async exportCsv(
    @Query() query: DateRangeDto,
    @Query('city') city?: string,
    @Query('status') status?: BookingStatus,
    @Res({ passthrough: true }) res?: any,
  ) {
    this.validateDateRange(query);
    const csvContent = await this.revenueService.exportRevenueCsv(query, city, status);

    if (res) {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="drivego_revenue_report_${query.startDate}_to_${query.endDate}.csv"`,
      );
    }
    return csvContent;
  }
}
