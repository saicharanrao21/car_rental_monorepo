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
  Headers,
  BadRequestException,
  NotFoundException,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { PayoutsService } from './payouts.service';
import { RequestPayoutDto } from './dto/request-payout.dto';
import { ApprovePayoutDto } from './dto/approve-payout.dto';
import { ExecutePayoutDto } from './dto/execute-payout.dto';
import { CreateFinancialAdjustmentDto } from './dto/create-adjustment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role, PayoutStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Controller()
export class PayoutsController {
  constructor(
    private readonly payoutsService: PayoutsService,
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

  // ── VENDOR ENDPOINTS ──────────────────────────────────────────────────────

  @Roles(Role.VENDOR)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Get('vendors/me/earnings/summary')
  async getMyEarningsSummary(@Req() req: any) {
    const vendorId = await this.getVendorId(req.user.userId || req.user.id);
    return this.payoutsService.getVendorEarningsSummary(vendorId);
  }

  @Roles(Role.VENDOR)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Get('vendors/me/earnings/daily')
  async getMyDailyEarnings(@Req() req: any, @Query('days') days?: string) {
    const vendorId = await this.getVendorId(req.user.userId || req.user.id);
    const dayCount = days ? parseInt(days, 10) : 30;
    return this.payoutsService.getDailyEarnings(vendorId, dayCount);
  }

  @Roles(Role.VENDOR)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Get('vendors/me/payouts')
  async getMyPayoutHistory(@Req() req: any) {
    const vendorId = await this.getVendorId(req.user.userId || req.user.id);
    return this.payoutsService.getPayoutHistory(vendorId);
  }

  @Roles(Role.VENDOR)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Post('vendors/me/payouts/request')
  @HttpCode(HttpStatus.CREATED)
  async requestPayout(@Req() req: any, @Body() dto: RequestPayoutDto) {
    const userId = req.user.userId || req.user.id;
    const vendorId = await this.getVendorId(userId);
    return this.payoutsService.requestPayout(vendorId, dto, userId);
  }

  // ── ADMIN FINANCE ENDPOINTS ───────────────────────────────────────────────

  @Get('admin/payouts')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_READ)
  async getAllPayouts(
    @Query('status') status?: PayoutStatus,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.payoutsService.getAllPayouts(status, page ?? 1, limit ?? 20);
  }

  @Get('admin/vendors/:id/earnings-summary')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_READ)
  async getVendorEarningsSummaryForAdmin(@Param('id') vendorId: string) {
    return this.payoutsService.getVendorEarningsSummary(vendorId);
  }

  @Post('admin/payouts/request')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_WRITE)
  @HttpCode(HttpStatus.CREATED)
  async createPayoutByAdmin(@Req() req: any, @Body() dto: RequestPayoutDto) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.requestPayout(dto.vendorId, dto, adminUserId);
  }

  @Post('admin/payouts/:id/approve')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.PAYOUT_APPROVE)
  async approvePayout(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: ApprovePayoutDto,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.approvePayout(id, adminUserId, dto);
  }

  @Post('admin/payouts/:id/execute')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.PAYOUT_EXECUTE)
  async executePayout(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: ExecutePayoutDto,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.executePayout(id, adminUserId, dto);
  }

  @Post('admin/payouts/:id/reverse')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.PAYOUT_APPROVE)
  async reversePayout(
    @Req() req: any,
    @Param('id') id: string,
    @Body('reason') reason?: string,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.reversePayout(id, adminUserId, reason);
  }

  @Post('admin/payouts/:id/reject')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.PAYOUT_APPROVE)
  async rejectPayout(
    @Req() req: any,
    @Param('id') id: string,
    @Body('reason') reason: string,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.rejectPayout(
      id,
      adminUserId,
      reason || 'Rejected by finance operator.',
    );
  }

  @Post('admin/finance/adjustments')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_ADJUSTMENT)
  @HttpCode(HttpStatus.CREATED)
  async createFinancialAdjustment(
    @Req() req: any,
    @Body() dto: CreateFinancialAdjustmentDto,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.payoutsService.createFinancialAdjustment(adminUserId, dto);
  }

  @Get('admin/finance/adjustments')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_READ)
  async getAllAdjustments(
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.payoutsService.getAllAdjustments(page ?? 1, limit ?? 20);
  }

  @Get('admin/finance/summary')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @RequirePermissions(AdminPermission.FINANCE_READ)
  async getFinancialSummary() {
    return this.payoutsService.getFinancialSummary();
  }

  // ── PUBLIC WEBHOOK ENDPOINT ───────────────────────────────────────────────

  @Post('payouts/webhook')
  @HttpCode(HttpStatus.OK)
  async handlePayoutWebhook(
    @Req() req: any,
    @Headers('x-razorpay-signature') signature: string,
  ) {
    const rawBody =
      req.rawBody ||
      (typeof req.body === 'string' ? req.body : JSON.stringify(req.body));

    if (
      !signature &&
      process.env.PAYMENT_PROVIDER_MODE !== 'MOCK' &&
      process.env.NODE_ENV !== 'test'
    ) {
      throw new BadRequestException('Webhook signature is missing');
    }

    return this.payoutsService.handlePayoutWebhook(
      rawBody,
      signature,
      req.headers,
    );
  }
}
