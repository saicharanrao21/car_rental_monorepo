import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { CouponsService } from './coupons.service';
import { ValidateCouponDto } from './dto/validate-coupon.dto';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { UpdateCouponDto } from './dto/update-coupon.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { RateLimit } from '../common/decorators/rate-limit.decorator';

@Controller()
export class CouponsController {
  constructor(private readonly couponsService: CouponsService) {}

  // 1. CUSTOMER: Validate promo code
  @UseGuards(JwtAuthGuard)
  @RateLimit({ limit: 10, ttlSeconds: 60 })
  @Post('coupons/validate')
  async validateCoupon(@Req() req: any, @Body() dto: ValidateCouponDto) {
    return this.couponsService.validateCoupon(req.user.userId, dto);
  }

  // 2. CUSTOMER: Get available active coupons
  @UseGuards(JwtAuthGuard)
  @Get('coupons/available')
  async getAvailableCoupons(@Req() req: any, @Query('city') city?: string) {
    return this.couponsService.getAvailableCoupons(req.user.userId, city);
  }

  // 3. ADMIN: List all coupons
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Get('admin/coupons')
  async findAllAdmin() {
    return this.couponsService.findAllAdmin();
  }

  // 4. ADMIN: Create coupon
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Post('admin/coupons')
  async createCoupon(@Req() req: any, @Body() dto: CreateCouponDto) {
    return this.couponsService.createCoupon(dto, req.user.userId);
  }

  // 5. ADMIN: Update coupon
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('admin/coupons/:id')
  async updateCoupon(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateCouponDto,
  ) {
    return this.couponsService.updateCoupon(id, dto, req.user.userId);
  }

  // 6. ADMIN: Delete coupon
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Delete('admin/coupons/:id')
  async deleteCoupon(@Req() req: any, @Param('id') id: string) {
    return this.couponsService.deleteCoupon(id, req.user.userId);
  }

  // 7. ADMIN: Get coupon redemption history
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Get('admin/coupons/:id/usages')
  async getCouponUsages(
    @Param('id') id: string,
    @Query('skip') skip?: number,
    @Query('take') take?: number,
  ) {
    return this.couponsService.getCouponUsages(id, {
      skip: skip ? Number(skip) : 0,
      take: take ? Number(take) : 50,
    });
  }

  // 8. ADMIN: Toggle coupon status (active/inactive)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Post('admin/coupons/:id/toggle-status')
  async toggleCouponStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body('isActive') isActive: boolean,
  ) {
    return this.couponsService.toggleCouponStatus(
      id,
      Boolean(isActive),
      req.user.userId,
    );
  }

  // 9. ADMIN: Archive coupon
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Post('admin/coupons/:id/archive')
  async archiveCoupon(@Req() req: any, @Param('id') id: string) {
    return this.couponsService.archiveCoupon(id, req.user.userId);
  }
}
