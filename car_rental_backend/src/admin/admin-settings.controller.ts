import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin/settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminSettingsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getSettings() {
    let settings = await this.prisma.platformSettings.findUnique({
      where: { id: 'singleton' },
    });

    if (!settings) {
      settings = await this.prisma.platformSettings.create({
        data: {
          id: 'singleton',
          platformName: 'DriveGo',
          logoUrl: null,
          gstNumber: '27AAAAA1111A1Z1',
          supportEmail: 'support@drivego.in',
          supportPhone: '+919876543210',
          appVersion: '1.0.0',
        },
      });
    }

    return settings;
  }

  @Patch()
  async updateSettings(
    @Body() dto: {
      platformName?: string;
      logoUrl?: string;
      gstNumber?: string;
      supportEmail?: string;
      supportPhone?: string;
      appVersion?: string;
    },
  ) {
    const data: any = {};
    if (dto.platformName !== undefined) data.platformName = dto.platformName;
    if (dto.logoUrl !== undefined) data.logoUrl = dto.logoUrl;
    if (dto.gstNumber !== undefined) data.gstNumber = dto.gstNumber;
    if (dto.supportEmail !== undefined) data.supportEmail = dto.supportEmail;
    if (dto.supportPhone !== undefined) data.supportPhone = dto.supportPhone;
    if (dto.appVersion !== undefined) data.appVersion = dto.appVersion;

    const settings = await this.prisma.platformSettings.upsert({
      where: { id: 'singleton' },
      update: data,
      create: {
        id: 'singleton',
        platformName: dto.platformName ?? 'DriveGo',
        logoUrl: dto.logoUrl ?? null,
        gstNumber: dto.gstNumber ?? '27AAAAA1111A1Z1',
        supportEmail: dto.supportEmail ?? 'support@drivego.in',
        supportPhone: dto.supportPhone ?? '+919876543210',
        appVersion: dto.appVersion ?? '1.0.0',
      },
    });

    return settings;
  }
}
