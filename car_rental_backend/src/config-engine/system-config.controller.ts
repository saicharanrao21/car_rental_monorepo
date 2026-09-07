import {
  Controller,
  Get,
  Put,
  Param,
  Body,
  Query,
  Headers,
  UseGuards,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { SystemConfigService } from './system-config.service';
import { SystemConfigValidator } from './system-config-validator';
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

  @Get('admin/detailed')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getAllDetailedConfigs() {
    return this.configService.getAllDetailedConfigs();
  }

  @Get('admin/detailed/:key')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getDetailedConfigByKey(@Param('key') key: string) {
    return this.configService.getDetailedConfig(key);
  }

  @Get('admin/:key/audit-history')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getConfigAuditHistory(
    @Param('key') key: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? parseInt(limit, 10) : 50;
    return this.configService.getConfigAuditHistory(key, isNaN(parsedLimit) ? 50 : parsedLimit);
  }

  @Get('admin/:key')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async getConfigByKey(@Param('key') key: string) {
    return this.configService.getConfig(key);
  }

  @Put('admin/batch')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async updateConfigsBatch(@Body() body: any, @Req() req: any) {
    const items = Array.isArray(body) ? body : body?.configs;
    if (!items || !Array.isArray(items)) {
      throw new BadRequestException('Batch update payload must contain a "configs" array.');
    }
    const userId = req.user?.userId || req.user?.id;
    return this.configService.batchSetConfigs(items, userId, body?.reason);
  }

  @Put('admin/:key')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async updateConfig(
    @Param('key') key: string,
    @Body() body: any,
    @Req() req: any,
    @Query('expectedVersion') queryVersion?: string,
    @Headers('if-match') headerVersion?: string,
  ) {
    if (!body || typeof body !== 'object') {
      throw new BadRequestException('Configuration payload must be an object.');
    }

    // Extract OCC metadata if encapsulated in body or parameters
    let expectedVersion: number | undefined;
    let reason: string | undefined;
    let payloadToValidate = body;

    if (queryVersion !== undefined) {
      const parsed = parseInt(queryVersion, 10);
      if (!isNaN(parsed)) expectedVersion = parsed;
    } else if (headerVersion !== undefined) {
      const parsed = parseInt(headerVersion.replace(/"/g, ''), 10);
      if (!isNaN(parsed)) expectedVersion = parsed;
    }

    if (body && typeof body === 'object' && !Array.isArray(body)) {
      if (body.expectedVersion !== undefined) {
        expectedVersion = Number(body.expectedVersion);
      }
      if (body.reason !== undefined) {
        reason = String(body.reason);
      }

      // If payload is wrapped under `value`, unwrap it
      if (body.value !== undefined) {
        payloadToValidate = body.value;
      } else if (body.expectedVersion !== undefined || body.reason !== undefined) {
        // Strip out control fields from actual configuration value
        const { expectedVersion: _, reason: __, ...cleaned } = body;
        payloadToValidate = cleaned;
      }
    }

    // Strict schema & semantic validation
    const validatedPayload = SystemConfigValidator.validate(key, payloadToValidate);

    const options: any = {};
    if (expectedVersion !== undefined) options.expectedVersion = expectedVersion;
    if (reason !== undefined) options.reason = reason;
    if (req?.ip !== undefined) options.ip = req.ip;

    const hasOptions = Object.keys(options).length > 0;
    const userId = req?.user?.userId || req?.user?.id;

    return hasOptions
      ? this.configService.setConfig(key, validatedPayload, userId, options)
      : this.configService.setConfig(key, validatedPayload, userId);
  }
}
