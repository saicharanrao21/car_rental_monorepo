import { Controller, Get, Query, UseGuards, ParseIntPipe, BadRequestException } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
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
      throw new BadRequestException('Invalid date format. Must be valid ISO strings.');
    }
    if (start > end) {
      throw new BadRequestException('startDate must be before or equal to endDate');
    }
  }

  @Get('summary')
  async getSummary(@Query() query: DateRangeDto) {
    this.validateDateRange(query);
    return this.revenueService.getRevenueSummary(query);
  }

  @Get('over-time')
  async getOverTime(@Query() query: DateRangeDto) {
    this.validateDateRange(query);
    return this.revenueService.getRevenueOverTime(query);
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
  async getTopVendors(@Query('limit', new ParseIntPipe({ optional: true })) limit?: number) {
    return this.revenueService.getTopVendorsByRevenue(limit ?? 10);
  }
}
