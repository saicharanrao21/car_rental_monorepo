import {
  Controller,
  Get,
  Put,
  Param,
  Body,
  UseGuards,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { SystemConfigService } from './system-config.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';

@Controller('config')
export class SystemConfigController {
  constructor(private readonly configService: SystemConfigService) {}

  @Get('public')
  async getPublicConfigs() {
    return this.configService.getPublicConfigs();
  }

  @Get('flags')
  async getFeatureFlags() {
    return this.configService.getFeatureFlags();
  }

  @Get('admin/all')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getAllAdminConfigs() {
    const wallet = await this.configService.getWalletConfig().catch(() => null);
    const referral = await this.configService.getReferralConfig().catch(() => null);
    const search = await this.configService.getSearchRankingConfig().catch(() => null);
    const booking = await this.configService.getBookingPolicyConfig().catch(() => null);
    const flags = await this.configService.getFeatureFlags().catch(() => null);
    const tax = await this.configService.getTaxConfig().catch(() => null);
    const quote = await this.configService.getQuoteConfig().catch(() => null);
    const durationDiscounts = await this.configService.getDurationDiscountsConfig().catch(() => null);
    const cancellationMatrix = await this.configService.getCancellationMatrixConfig().catch(() => null);
    const commission = await this.configService.getCommissionConfig().catch(() => null);
    const depositDefaults = await this.configService.getDepositDefaultsConfig().catch(() => null);

    return {
      wallet,
      referral,
      search,
      booking,
      flags,
      tax,
      quote,
      durationDiscounts,
      cancellationMatrix,
      commission,
      depositDefaults,
    };
  }

  @Get('admin/:key')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getConfigByKey(@Param('key') key: string) {
    return this.configService.getConfig(key);
  }

  @Put('admin/:key')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async updateConfig(
    @Param('key') key: string,
    @Body() body: any,
    @Req() req: any,
  ) {
    if (!body || typeof body !== 'object') {
      throw new BadRequestException('Configuration payload must be an object.');
    }

    // Strict validation on dynamic business rules
    if (key === 'wallet.rules') {
      if (body.maxSingleDeposit !== undefined) {
        if (Number(body.maxSingleDeposit) < 500 || Number(body.maxSingleDeposit) > 500000) {
          throw new BadRequestException('maxSingleDeposit must be between ₹500 and ₹500,000.');
        }
      }
      if (body.maxWalletPaymentPercentage !== undefined) {
        if (Number(body.maxWalletPaymentPercentage) < 5 || Number(body.maxWalletPaymentPercentage) > 100) {
          throw new BadRequestException('maxWalletPaymentPercentage must be between 5% and 100%.');
        }
      }
    } else if (key === 'search.ranking') {
      if (body.sponsoredBoostMultiplier !== undefined) {
        if (Number(body.sponsoredBoostMultiplier) < 1.0 || Number(body.sponsoredBoostMultiplier) > 3.0) {
          throw new BadRequestException('sponsoredBoostMultiplier must be between 1.0x and 3.0x.');
        }
      }
      if (body.featuredBoostMultiplier !== undefined) {
        if (Number(body.featuredBoostMultiplier) < 1.0 || Number(body.featuredBoostMultiplier) > 3.0) {
          throw new BadRequestException('featuredBoostMultiplier must be between 1.0x and 3.0x.');
        }
      }
    } else if (key === 'pricing.tax') {
      if (body.gstRate === undefined || typeof body.gstRate !== 'number' || isNaN(body.gstRate) || body.gstRate < 0 || body.gstRate > 100) {
        throw new BadRequestException('gstRate must be a number between 0% and 100%.');
      }
    } else if (key === 'pricing.quote') {
      if (body.validityMinutes === undefined || typeof body.validityMinutes !== 'number' || isNaN(body.validityMinutes) || body.validityMinutes < 1 || body.validityMinutes > 1440) {
        throw new BadRequestException('validityMinutes must be a number between 1 and 1440 minutes.');
      }
    } else if (key === 'pricing.duration_discounts') {
      const tiers = Array.isArray(body) ? body : body.tiers;
      if (!Array.isArray(tiers)) {
        throw new BadRequestException('pricing.duration_discounts must be an array of discount tiers.');
      }
      for (const tier of tiers) {
        if (typeof tier.minDays !== 'number' || tier.minDays < 1 || typeof tier.discountPercent !== 'number' || tier.discountPercent < 0 || tier.discountPercent > 100) {
          throw new BadRequestException('Each duration discount tier must contain valid minDays (>= 1) and discountPercent (0-100).');
        }
      }
    } else if (key === 'booking.cancellation_matrix') {
      const tiers = Array.isArray(body) ? body : body.tiers;
      if (!Array.isArray(tiers)) {
        throw new BadRequestException('booking.cancellation_matrix must contain a tiers array.');
      }
      for (const tier of tiers) {
        if (typeof tier.minHoursBeforePickup !== 'number' || tier.minHoursBeforePickup < 0 || typeof tier.feePercent !== 'number' || tier.feePercent < 0 || tier.feePercent > 100) {
          throw new BadRequestException('Each cancellation tier must have valid minHoursBeforePickup (>= 0) and feePercent (0-100).');
        }
      }
      if (body.afterStartFeePercent !== undefined && (typeof body.afterStartFeePercent !== 'number' || body.afterStartFeePercent < 0 || body.afterStartFeePercent > 100)) {
        throw new BadRequestException('afterStartFeePercent must be a number between 0 and 100.');
      }
    } else if (key === 'pricing.commission') {
      const rate = body.defaultPercent ?? body.defaultRate ?? body.defaultCommissionPercent;
      if (rate === undefined || typeof rate !== 'number' || isNaN(rate) || rate < 0 || rate > 100) {
        throw new BadRequestException('defaultPercent must be a number between 0% and 100%.');
      }
    } else if (key === 'deposits.defaults') {
      if (typeof body !== 'object') {
        throw new BadRequestException('deposits.defaults must be a category-to-amount map.');
      }
      for (const [category, amount] of Object.entries(body)) {
        if (typeof amount !== 'number' || isNaN(amount) || amount < 0) {
          throw new BadRequestException(`Invalid deposit amount for category ${category}. Must be a non-negative number.`);
        }
      }
    }

    const userId = req.user?.userId || req.user?.id;
    return this.configService.setConfig(key, body, userId);
  }
}
