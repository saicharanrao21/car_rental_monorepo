import { Test, TestingModule } from '@nestjs/testing';
import { WalletsService, MAX_SINGLE_DEPOSIT, MIN_SINGLE_DEPOSIT } from './wallets.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BadRequestException } from '@nestjs/common';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase 27.2 — Wallets & SystemConfig Dynamic Rule Integration Tests', () => {
  let walletsService: WalletsService;
  let configService: SystemConfigService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      wallet: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'wlt_1',
          userId: 'user_1',
          availableBalance: new Decimal(1000),
          realBalance: new Decimal(1000),
          promoBalance: new Decimal(0),
        }),
      },
    };

    const mockSystemConfig = {
      getWalletConfig: jest.fn().mockResolvedValue({
        minSingleDeposit: 500,
        maxSingleDeposit: 75000,
        maxWalletBalanceCap: 200000,
        maxWalletPaymentPercentage: 80,
        isDepositsEnabled: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WalletsService,
        { provide: PrismaService, useValue: prisma },
        { provide: SystemConfigService, useValue: mockSystemConfig },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) => {
              if (key === 'RAZORPAY_USE_MOCK') return 'true';
              return 'test';
            },
          },
        },
        { provide: AuditLogService, useValue: { log: jest.fn() } },
        { provide: NotificationsService, useValue: { notifyUser: jest.fn() } },
      ],
    }).compile();

    walletsService = module.get<WalletsService>(WalletsService);
    configService = module.get<SystemConfigService>(SystemConfigService);
  });

  it('dynamically enforces customized deposit boundaries from SystemConfig', async () => {
    // Under custom minimum (500)
    await expect(walletsService.createDepositOrder('user_1', 200)).rejects.toThrow(
      BadRequestException,
    );

    // Over custom maximum (75000)
    await expect(walletsService.createDepositOrder('user_1', 80000)).rejects.toThrow(
      BadRequestException,
    );

    // Within bounds (10000)
    const order = await walletsService.createDepositOrder('user_1', 10000);
    expect(order.amount).toBe(10000);
    expect(order.isMock).toBe(true);
  });
});
