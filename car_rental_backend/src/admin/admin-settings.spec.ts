import { Test, TestingModule } from '@nestjs/testing';
import { AdminSettingsController } from './admin-settings.controller';
import { AuditLogService } from './audit-log.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminSettings Suite', () => {
  let controller: AdminSettingsController;
  let prisma: any;
  let auditLogService: any;

  beforeEach(async () => {
    prisma = {
      platformSettings: {
        findUnique: jest.fn(),
        create: jest.fn(),
        upsert: jest.fn(),
      },
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminSettingsController],
      providers: [
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    controller = module.get<AdminSettingsController>(AdminSettingsController);
  });

  describe('getSettings', () => {
    it('returns existing singleton platform settings', async () => {
      const mockSettings = {
        id: 'singleton',
        platformName: 'DriveGo India',
        gstNumber: '36AAAAA0000A1Z5',
        supportEmail: 'ops@drivego.in',
        supportPhone: '+919988776655',
        appVersion: '2.1.0',
        enabledTripTypes: ['SELF_DRIVE'],
      };
      prisma.platformSettings.findUnique.mockResolvedValue(mockSettings);

      const result = await controller.getSettings();

      expect(result).toEqual(mockSettings);
      expect(prisma.platformSettings.findUnique).toHaveBeenCalledWith({ where: { id: 'singleton' } });
      expect(prisma.platformSettings.create).not.toHaveBeenCalled();
    });

    it('creates default singleton settings if none exists', async () => {
      prisma.platformSettings.findUnique.mockResolvedValue(null);
      const defaultSettings = {
        id: 'singleton',
        platformName: 'DriveGo',
        logoUrl: null,
        gstNumber: '27AAAAA1111A1Z1',
        supportEmail: 'support@drivego.in',
        supportPhone: '+919876543210',
        appVersion: '1.0.0',
      };
      prisma.platformSettings.create.mockResolvedValue(defaultSettings);

      const result = await controller.getSettings();

      expect(result).toEqual(defaultSettings);
      expect(prisma.platformSettings.create).toHaveBeenCalled();
    });
  });

  describe('updateSettings', () => {
    it('updates platform settings and logs auditable event', async () => {
      const updatedMock = {
        id: 'singleton',
        platformName: 'DriveGo Mobility',
        gstNumber: '36BBBBB2222B2Z6',
        supportEmail: 'care@drivego.in',
        supportPhone: '+919000111222',
        appVersion: '2.2.0',
        enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
      };
      prisma.platformSettings.upsert.mockResolvedValue(updatedMock);

      const req = { user: { userId: 'admin-super-1' } };
      const dto = {
        platformName: 'DriveGo Mobility',
        supportEmail: 'care@drivego.in',
      };

      const result = await controller.updateSettings(req, dto);

      expect(result).toEqual(updatedMock);
      expect(prisma.platformSettings.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'singleton' },
          update: expect.objectContaining({
            platformName: 'DriveGo Mobility',
            supportEmail: 'care@drivego.in',
          }),
        }),
      );
      expect(auditLogService.log).toHaveBeenCalledWith(
        'admin-super-1',
        'PLATFORM_SETTINGS_UPDATED',
        'PlatformSettings',
        'singleton',
        dto,
      );
    });
  });
});

