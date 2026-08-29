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
    const wallet = await this.configService.getWalletConfig();
    const referral = await this.configService.getReferralConfig();
    const search = await this.configService.getSearchRankingConfig();
    const booking = await this.configService.getBookingPolicyConfig();
    const flags = await this.configService.getFeatureFlags();

    return {
      wallet,
      referral,
      search,
      booking,
      flags,
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
    }

    const userId = req.user?.userId || req.user?.id;
    return this.configService.setConfig(key, body, userId);
  }
}
