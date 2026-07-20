import { 
  Controller, 
  Get, 
  Post, 
  Patch, 
  Body, 
  Param, 
  Query, 
  UseGuards, 
  Req, 
  NotFoundException,
  ParseIntPipe,
  HttpCode,
  HttpStatus
} from '@nestjs/common';
import { PayoutsService } from './payouts.service';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { MarkPaidDto } from './dto/mark-paid.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, PayoutStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Controller()
export class PayoutsController {
  constructor(
    private readonly payoutsService: PayoutsService,
    private readonly prisma: PrismaService,
  ) {}

  // Resolve Vendor ID from User ID helper
  private async getVendorId(userId: string): Promise<string> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new NotFoundException('Vendor profile not found for this user.');
    }
    return vendor.id;
  }

  // --- VENDOR Endpoints ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('vendors/me/earnings/summary')
  async getMyEarningsSummary(@Req() req: any) {
    const vendorId = await this.getVendorId(req.user.userId);
    return this.payoutsService.getVendorEarningsSummary(vendorId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('vendors/me/earnings/daily')
  async getMyDailyEarnings(
    @Req() req: any,
    @Query('days') days?: string,
  ) {
    const vendorId = await this.getVendorId(req.user.userId);
    const dayCount = days ? parseInt(days, 10) : 30;
    return this.payoutsService.getDailyEarnings(vendorId, dayCount);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('vendors/me/payouts')
  async getMyPayoutHistory(@Req() req: any) {
    const vendorId = await this.getVendorId(req.user.userId);
    return this.payoutsService.getPayoutHistory(vendorId);
  }

  // --- ADMIN Endpoints ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Get('admin/payouts')
  async getAllPayouts(
    @Query('status') status?: PayoutStatus,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pageNum = page ? parseInt(page, 10) : 1;
    const limitNum = limit ? parseInt(limit, 10) : 20;
    return this.payoutsService.getAllPayouts(status, pageNum, limitNum);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Get('admin/vendors/:id/earnings-summary')
  async getVendorEarningsSummaryForAdmin(@Param('id') vendorId: string) {
    return this.payoutsService.getVendorEarningsSummary(vendorId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Post('admin/payouts')
  @HttpCode(HttpStatus.CREATED)
  async createPayout(@Body() dto: CreatePayoutDto) {
    return this.payoutsService.createPayout(dto.vendorId, dto.amount);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('admin/payouts/:id/mark-paid')
  async markPayoutPaid(
    @Param('id') id: string,
    @Body() dto: MarkPaidDto,
  ) {
    return this.payoutsService.markPayoutPaid(id, dto.note);
  }
}
