import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('settings')
export class PublicSettingsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('public')
  async getPublicSettings() {
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
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        },
      });
    }

    return {
      platformName: settings.platformName,
      supportEmail: settings.supportEmail,
      supportPhone: settings.supportPhone,
      enabledTripTypes: settings.enabledTripTypes,
    };
  }
}
