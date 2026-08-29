import { Test, TestingModule } from '@nestjs/testing';
import { ReferralsService } from './referrals.service';
import { WalletsService } from '../wallets/wallets.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase 27.2 — Referrals & SystemConfig Dynamic Rule Integration Tests', () => {
  let referralsService: ReferralsService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      referralCampaign: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'camp_1', ...data })),
      },
    };

    const mockSystemConfig = {
      getReferralConfig: jest.fn().mockResolvedValue({
        defaultReferrerReward: 500,
        defaultRefereeReward: 300,
        minBookingAmount: 1500,
        maxReferralsPerUser: 50,
        isReferralsEnabled: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReferralsService,
        { provide: PrismaService, useValue: prisma },
        { provide: SystemConfigService, useValue: mockSystemConfig },
        { provide: WalletsService, useValue: {} },
        { provide: AuditLogService, useValue: { log: jest.fn() } },
        { provide: NotificationsService, useValue: { notifyUser: jest.fn() } },
      ],
    }).compile();

    referralsService = module.get<ReferralsService>(ReferralsService);
  });

  it('initializes default referral campaign using dynamic values from SystemConfig', async () => {
    const campaign = await referralsService.getOrCreateDefaultCampaign();

    expect(campaign.referrerRewardAmount).toEqual(new Decimal(500));
    expect(campaign.refereeRewardAmount).toEqual(new Decimal(300));
    expect(campaign.minBookingAmount).toEqual(new Decimal(1500));
    expect(campaign.maxReferralsPerUser).toBe(50);
  });
});
