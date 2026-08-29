import {
  Controller,
  Get,
  Put,
  Param,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { SystemConfigService } from './system-config.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
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
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
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
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getConfigByKey(@Param('key') key: string) {
    return this.configService.getConfig(key);
  }

  @Put('admin/:key')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updateConfig(
    @Param('key') key: string,
    @Body() body: any,
    @Req() req: any,
  ) {
    const userId = req.user?.userId || req.user?.id;
    return this.configService.setConfig(key, body, userId);
  }
}
