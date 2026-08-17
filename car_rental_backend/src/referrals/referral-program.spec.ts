import { Test, TestingModule } from '@nestjs/testing';
import { ReferralsService, DEFAULT_REFERRER_REWARD, DEFAULT_REFEREE_DISCOUNT } from './referrals.service';
import { PrismaService } from '../prisma/prisma.service';
import { WalletsService } from '../wallets/wallets.service';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ApmMonitoringService } from '../common/apm-monitoring.service';
import { ReferralStatus, BookingStatus, LedgerEntryType, WalletBucketType } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';

describe('ReferralsService (Referral Program Business Logic & Fraud Controls)', () => {
  let service: ReferralsService;
  let prisma: any;
  let walletsService: any;
  let auditLogService: any;
  let notificationsService: any;

  const mockReferrer = {
    id: 'usr_referrer_1',
    name: 'Alice Referrer',
    phone: '+919876500001',
    referralCode: 'DGALICE1',
    customerKyc: {
      licenceNumber: 'DL-IND-11112222',
    },
  };

  const mockReferee = {
    id: 'usr_referee_2',
    name: 'Bob Referee',
    phone: '+919876500002',
    referralCode: 'DGBOB002',
    customerKyc: {
      licenceNumber: 'DL-IND-33334444',
    },
  };

  const mockCampaign = {
    id: 'cmp_default',
    name: 'Standard Referral Program',
    code: 'DEFAULT_GLOBAL',
    referrerRewardAmount: new Decimal(250),
    refereeRewardAmount: new Decimal(250),
    minBookingAmount: new Decimal(1000),
    city: null,
    startDate: null,
    endDate: null,
    isActive: true,
    maxReferralsPerUser: 20,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn().mockImplementation((args) => {
          if (args.where.id === mockReferrer.id || args.where.referralCode === mockReferrer.referralCode) {
            return Promise.resolve({ ...mockReferrer });
          }
          if (args.where.id === mockReferee.id || args.where.referralCode === mockReferee.referralCode) {
            return Promise.resolve({ ...mockReferee });
          }
          return Promise.resolve(null);
        }),
        update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
      },
      referralCampaign: {
        findFirst: jest.fn().mockResolvedValue({ ...mockCampaign }),
        findUnique: jest.fn().mockResolvedValue({ ...mockCampaign }),
        create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'cmp_created', ...args.data })),
        update: jest.fn().mockImplementation((args) => Promise.resolve({ ...mockCampaign, ...args.data })),
        findMany: jest.fn().mockResolvedValue([{ ...mockCampaign, attributions: [] }]),
      },
      referralAttribution: {
        findUnique: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
        create: jest.fn().mockImplementation((args) =>
          Promise.resolve({
            id: 'attr_123',
            status: ReferralStatus.REGISTERED,
            ...args.data,
          }),
        ),
        update: jest.fn().mockImplementation((args) =>
          Promise.resolve({
            id: args.where.id,
            ...args.data,
          }),
        ),
      },
      booking: {
        count: jest.fn().mockResolvedValue(0),
        findUnique: jest.fn().mockResolvedValue(null),
      },
      $queryRaw: jest.fn().mockResolvedValue([
        {
          id: 'attr_123',
          status: ReferralStatus.REGISTERED,
          referrerId: mockReferrer.id,
          refereeId: mockReferee.id,
          referrerRewardAmount: new Decimal(250),
        },
      ]),
      $transaction: jest.fn().mockImplementation(async (cb) => cb(prisma)),
    };

    walletsService = {
      getOrCreateWallet: jest.fn().mockResolvedValue({ id: 'wlt_referrer_1', availableBalance: new Decimal(0) }),
      creditWallet: jest.fn().mockResolvedValue({
        id: 'led_ref_reward_1',
        amount: new Decimal(250),
        balanceAfter: new Decimal(250),
      }),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReferralsService,
        { provide: PrismaService, useValue: prisma },
        { provide: WalletsService, useValue: walletsService },
        { provide: AuditLogService, useValue: auditLogService },
        { provide: NotificationsService, useValue: notificationsService },
      ],
    }).compile();

    service = module.get<ReferralsService>(ReferralsService);
  });

  describe('1. Referral Code Generation', () => {
    it('should generate and persist unique non-sensitive referral code if missing', async () => {
      prisma.user.findUnique.mockResolvedValueOnce({
        id: 'usr_new',
        referralCode: null,
        name: 'New User',
      });

      const res = await service.getOrCreateUserReferralCode('usr_new');
      expect(res.referralCode).toBeDefined();
      expect(res.referralCode.startsWith('DG')).toBe(true);
      expect(res.shareUrl).toContain(res.referralCode);
      expect(prisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            referralCode: expect.any(String),
          }),
        }),
      );
    });
  });

  describe('2. Fraud Protections & Code Application', () => {
    it('should allow valid referral code attribution', async () => {
      const res = await service.applyReferralCode(mockReferee.id, {
        referralCode: 'DGALICE1',
      });

      expect(res.success).toBe(true);
      expect(res.discountAmount).toBe(250);
      expect(prisma.referralAttribution.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            referrerId: mockReferrer.id,
            refereeId: mockReferee.id,
            status: ReferralStatus.REGISTERED,
          }),
        }),
      );
    });

    it('should reject invalid non-existent referral code', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'INVALID99' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject self-referral', async () => {
      await expect(
        service.applyReferralCode(mockReferrer.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('Self-referral is strictly prohibited.');
    });

    it('should reject same phone number referral', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({ ...mockReferrer, phone: '+919999999999' })
        .mockResolvedValueOnce({ ...mockReferee, phone: '+919999999999' });

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('Referral code cannot be shared between the same phone identity.');
    });

    it('should reject same KYC / Driving License identity', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({
          ...mockReferrer,
          customerKyc: { licenceNumber: 'SAME-DL-999' },
        })
        .mockResolvedValueOnce({
          ...mockReferee,
          customerKyc: { licenceNumber: 'SAME-DL-999' },
        });

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('Referral code cannot be shared with the same verified KYC identity.');
    });

    it('should reject duplicate referee referral application', async () => {
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_prev',
        refereeId: mockReferee.id,
      });

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should reject referral if referee already has prior completed trips', async () => {
      prisma.booking.count.mockResolvedValueOnce(1); // 1 completed booking

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('Referral benefits are only applicable for first-time customers.');
    });

    it('should reject referral when campaign is inactive', async () => {
      prisma.referralCampaign.findFirst.mockResolvedValueOnce({
        ...mockCampaign,
        isActive: false,
      });

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('This referral campaign is currently inactive.');
    });

    it('should reject referral when campaign has expired', async () => {
      prisma.referralCampaign.findFirst.mockResolvedValueOnce({
        ...mockCampaign,
        endDate: new Date(Date.now() - 24 * 60 * 60 * 1000), // yesterday
      });

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('This referral campaign has expired.');
    });

    it('should enforce city-specific campaign restriction', async () => {
      prisma.referralCampaign.findFirst.mockResolvedValueOnce({
        ...mockCampaign,
        city: 'Mumbai',
      });

      await expect(
        service.applyReferralCode(mockReferee.id, {
          referralCode: 'DGALICE1',
          city: 'Delhi',
        }),
      ).rejects.toThrow('This referral campaign is only applicable in Mumbai.');
    });

    it('should enforce referrer maximum rewards limit cap (20)', async () => {
      prisma.referralAttribution.count.mockResolvedValueOnce(20); // reached cap

      await expect(
        service.applyReferralCode(mockReferee.id, { referralCode: 'DGALICE1' }),
      ).rejects.toThrow('Referrer has reached the maximum rewarded referrals limit (20)');
    });
  });

  describe('3. Authoritative Referee First-Booking Eligibility', () => {
    it('should confirm eligibility for registered referee with 0 completed trips', async () => {
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        status: ReferralStatus.REGISTERED,
        refereeRewardAmount: new Decimal(250),
        referralCodeUsed: 'DGALICE1',
        campaign: { minBookingAmount: new Decimal(1000) },
      });
      prisma.booking.count.mockResolvedValueOnce(0);

      const res = await service.getRefereeEligibility(mockReferee.id);
      expect(res.eligible).toBe(true);
      expect(res.discountAmount).toBe(250);
      expect(res.minBookingAmount).toBe(1000);
    });

    it('should deny eligibility if referee has already completed a trip', async () => {
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        status: ReferralStatus.REGISTERED,
        refereeRewardAmount: new Decimal(250),
        campaign: { minBookingAmount: new Decimal(1000) },
      });
      prisma.booking.count.mockResolvedValueOnce(1);

      const res = await service.getRefereeEligibility(mockReferee.id);
      expect(res.eligible).toBe(false);
    });
  });

  describe('4. Qualification Event & Referrer Reward', () => {
    const mockCompletedBooking = {
      id: 'bk_referee_first',
      customerId: mockReferee.id,
      status: BookingStatus.COMPLETED,
      totalFare: new Decimal(1500),
      customer: { id: mockReferee.id, name: 'Bob Referee' },
      payment: { status: 'PAID', refundStatus: 'NONE' },
    };

    it('should qualify and reward referrer with ₹250 wallet credit on first completed booking', async () => {
      prisma.booking.findUnique.mockResolvedValueOnce({ ...mockCompletedBooking });
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        referrerId: mockReferrer.id,
        refereeId: mockReferee.id,
        status: ReferralStatus.REGISTERED,
        referrerRewardAmount: new Decimal(250),
        campaign: { minBookingAmount: new Decimal(1000) },
      });

      const res = await service.handleBookingCompleted('bk_referee_first');

      expect(res).toBeDefined();
      expect(res?.success).toBe(true);
      expect(res?.rewardAmount).toBe(250);

      // Verify wallet credit called with deterministic key
      expect(walletsService.creditWallet).toHaveBeenCalledWith(
        'wlt_referrer_1',
        new Decimal(250),
        LedgerEntryType.REFERRAL_REWARD,
        WalletBucketType.PROMOTIONAL,
        'REFERRAL',
        'attr_123',
        'ref_reward_attr_123_referrer',
        expect.any(String),
        undefined,
        expect.any(Object),
        expect.anything(),
      );

      // Verify attribution updated to REWARDED
      expect(prisma.referralAttribution.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: ReferralStatus.REWARDED,
            referrerLedgerEntryId: 'led_ref_reward_1',
          }),
        }),
      );
    });

    it('should not reward if booking total fare is below ₹1,000', async () => {
      prisma.booking.findUnique.mockResolvedValueOnce({
        ...mockCompletedBooking,
        totalFare: new Decimal(800), // Below ₹1,000
      });
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        referrerId: mockReferrer.id,
        refereeId: mockReferee.id,
        status: ReferralStatus.REGISTERED,
        referrerRewardAmount: new Decimal(250),
        campaign: { minBookingAmount: new Decimal(1000) },
      });

      const res = await service.handleBookingCompleted('bk_referee_first');
      expect(res).toBeNull();
      expect(walletsService.creditWallet).not.toHaveBeenCalled();
    });

    it('should not reward if booking was refunded', async () => {
      prisma.booking.findUnique.mockResolvedValueOnce({
        ...mockCompletedBooking,
        payment: { status: 'PAID', refundStatus: 'FULL' }, // Refunded
      });
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        referrerId: mockReferrer.id,
        refereeId: mockReferee.id,
        status: ReferralStatus.REGISTERED,
      });

      const res = await service.handleBookingCompleted('bk_referee_first');
      expect(res).toBeNull();
      expect(walletsService.creditWallet).not.toHaveBeenCalled();
    });

    it('should enforce idempotency when completion event is called twice', async () => {
      prisma.booking.findUnique.mockResolvedValueOnce({ ...mockCompletedBooking });
      prisma.referralAttribution.findUnique.mockResolvedValueOnce({
        id: 'attr_123',
        status: ReferralStatus.REWARDED, // Already rewarded
      });

      const res = await service.handleBookingCompleted('bk_referee_first');
      expect(res).toEqual({ alreadyRewarded: true, attributionId: 'attr_123' });
      expect(walletsService.creditWallet).not.toHaveBeenCalled();
    });
  });

  describe('5. Admin Campaign Management & Audit Logging', () => {
    it('should create campaign with AuditLog entry', async () => {
      prisma.referralCampaign.findUnique.mockResolvedValueOnce(null);

      const campaign = await service.createAdminCampaign('adm_123', {
        name: 'Summer Referral Promo',
        code: 'SUMMER2026',
        referrerRewardAmount: 300,
        refereeRewardAmount: 300,
        minBookingAmount: 1200,
        city: 'Bangalore',
      });

      expect(campaign).toBeDefined();
      expect(auditLogService.log).toHaveBeenCalledWith(
        'adm_123',
        'CREATE_REFERRAL_CAMPAIGN',
        'ReferralCampaign',
        expect.any(String),
        expect.objectContaining({ code: 'SUMMER2026' }),
      );
    });

    it('should toggle campaign active status with AuditLog entry', async () => {
      const updated = await service.toggleAdminCampaign('adm_123', 'cmp_default');
      expect(updated.isActive).toBe(false);
      expect(auditLogService.log).toHaveBeenCalledWith(
        'adm_123',
        'TOGGLE_REFERRAL_CAMPAIGN',
        'ReferralCampaign',
        'cmp_default',
        expect.objectContaining({ newStatus: false }),
      );
    });
  });
});
