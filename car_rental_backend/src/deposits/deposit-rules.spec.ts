import { Test, TestingModule } from '@nestjs/testing';
import {
  DepositRulesService,
  DEFAULT_DEPOSIT_AMOUNTS,
} from './deposit-rules.service';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, Prisma } from '@prisma/client';

describe('DepositRulesService (Phase 3)', () => {
  let service: DepositRulesService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      depositRule: {
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DepositRulesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<DepositRulesService>(DepositRulesService);
  });

  describe('getDepositAmount', () => {
    it('returns city-specific rule if configured and active', async () => {
      prisma.depositRule.findFirst.mockResolvedValueOnce({
        id: 'rule_1',
        carCategory: CarCategory.SUV,
        city: 'Mumbai',
        depositAmount: new Prisma.Decimal(7500),
        isActive: true,
      });

      const amount = await service.getDepositAmount(CarCategory.SUV, 'Mumbai');
      expect(amount).toBe(7500);
      expect(prisma.depositRule.findFirst).toHaveBeenCalledWith({
        where: {
          carCategory: CarCategory.SUV,
          city: { equals: 'Mumbai', mode: 'insensitive' },
          isActive: true,
        },
      });
    });

    it('falls back to category global rule if city rule does not exist', async () => {
      prisma.depositRule.findFirst
        .mockResolvedValueOnce(null) // No city rule
        .mockResolvedValueOnce({
          id: 'rule_global',
          carCategory: CarCategory.LUXURY,
          city: null,
          depositAmount: new Prisma.Decimal(15000),
          isActive: true,
        });

      const amount = await service.getDepositAmount(
        CarCategory.LUXURY,
        'Delhi',
      );
      expect(amount).toBe(15000);
    });

    it('falls back to category default constant if no database rules exist', async () => {
      prisma.depositRule.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      const amount = await service.getDepositAmount(
        CarCategory.HATCHBACK,
        'Pune',
      );
      expect(amount).toBe(DEFAULT_DEPOSIT_AMOUNTS[CarCategory.HATCHBACK]);
      expect(amount).toBe(3000);
    });
  });

  describe('upsertRule', () => {
    it('creates new rule if none exists for category and city', async () => {
      prisma.depositRule.findFirst.mockResolvedValue(null);
      prisma.depositRule.create.mockResolvedValue({
        id: 'new_rule',
        carCategory: CarCategory.SEDAN,
        city: 'Mumbai',
        depositAmount: new Prisma.Decimal(6000),
        isActive: true,
      });

      const res = await service.upsertRule(CarCategory.SEDAN, 6000, 'Mumbai');
      expect(res.id).toBe('new_rule');
      expect(prisma.depositRule.create).toHaveBeenCalled();
    });

    it('updates existing rule if already configured', async () => {
      prisma.depositRule.findFirst.mockResolvedValue({
        id: 'existing_rule',
        carCategory: CarCategory.SEDAN,
        city: 'Mumbai',
      });
      prisma.depositRule.update.mockResolvedValue({
        id: 'existing_rule',
        depositAmount: new Prisma.Decimal(7000),
      });

      const res = await service.upsertRule(CarCategory.SEDAN, 7000, 'Mumbai');
      expect(prisma.depositRule.update).toHaveBeenCalledWith({
        where: { id: 'existing_rule' },
        data: {
          depositAmount: new Prisma.Decimal(7000),
          isActive: true,
        },
      });
    });
  });
});
