import { Test, TestingModule } from '@nestjs/testing';
import { SystemConfigController } from './system-config.controller';
import { SystemConfigService } from './system-config.service';
import { BadRequestException } from '@nestjs/common';

describe('Phase 27.2 — SystemConfig Controller Validation & Security Tests', () => {
  let controller: SystemConfigController;
  let mockService: any;

  beforeEach(async () => {
    mockService = {
      setConfig: jest.fn().mockImplementation((key, val) => Promise.resolve({ key, value: val })),
      getWalletConfig: jest.fn().mockResolvedValue({}),
      getReferralConfig: jest.fn().mockResolvedValue({}),
      getSearchRankingConfig: jest.fn().mockResolvedValue({}),
      getBookingPolicyConfig: jest.fn().mockResolvedValue({}),
      getFeatureFlags: jest.fn().mockResolvedValue({}),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SystemConfigController],
      providers: [{ provide: SystemConfigService, useValue: mockService }],
    }).compile();

    controller = module.get<SystemConfigController>(SystemConfigController);
  });

  describe('Validation on updateConfig', () => {
    it('rejects invalid wallet deposit cap bounds', async () => {
      // Below 500
      await expect(
        controller.updateConfig('wallet.rules', { maxSingleDeposit: 100 }, { user: { id: 'adm_1' } }),
      ).rejects.toThrow(BadRequestException);

      // Above 500,000
      await expect(
        controller.updateConfig('wallet.rules', { maxSingleDeposit: 1000000 }, { user: { id: 'adm_1' } }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects invalid search ranking multipliers', async () => {
      // Below 1.0
      await expect(
        controller.updateConfig('search.ranking', { sponsoredBoostMultiplier: 0.5 }, { user: { id: 'adm_1' } }),
      ).rejects.toThrow(BadRequestException);

      // Above 3.0
      await expect(
        controller.updateConfig('search.ranking', { sponsoredBoostMultiplier: 5.0 }, { user: { id: 'adm_1' } }),
      ).rejects.toThrow(BadRequestException);
    });

    it('accepts valid configuration update', async () => {
      const res = await controller.updateConfig(
        'wallet.rules',
        { maxSingleDeposit: 75000, maxWalletPaymentPercentage: 50 },
        { user: { id: 'adm_1' } },
      );

      expect(res).toBeDefined();
      expect(mockService.setConfig).toHaveBeenCalledWith(
        'wallet.rules',
        { maxSingleDeposit: 75000, maxWalletPaymentPercentage: 50 },
        'adm_1',
      );
    });
  });
});
