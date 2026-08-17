import { Test, TestingModule } from '@nestjs/testing';
import { ProtectionPackagesService } from './protection-packages.service';
import { PrismaService } from '../prisma/prisma.service';
import { ProtectionPlanCode, Prisma } from '@prisma/client';

describe('ProtectionPackagesService', () => {
  let service: ProtectionPackagesService;
  let prisma: PrismaService;

  const mockPrisma = {
    protectionPackage: {
      count: jest.fn().mockResolvedValue(3),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProtectionPackagesService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<ProtectionPackagesService>(ProtectionPackagesService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getActivePackages', () => {
    it('should return packages and prefer city-specific overrides', async () => {
      mockPrisma.protectionPackage.findMany.mockResolvedValue([
        {
          id: 'pkg_basic_global',
          code: ProtectionPlanCode.BASIC,
          dailyRate: new Prisma.Decimal(0),
          city: null,
          displayOrder: 1,
        },
        {
          id: 'pkg_standard_global',
          code: ProtectionPlanCode.STANDARD,
          dailyRate: new Prisma.Decimal(250),
          city: null,
          displayOrder: 2,
        },
        {
          id: 'pkg_standard_mumbai',
          code: ProtectionPlanCode.STANDARD,
          dailyRate: new Prisma.Decimal(300),
          city: 'Mumbai',
          displayOrder: 2,
        },
      ]);

      const packages = await service.getActivePackages('Mumbai');

      expect(packages.length).toBe(2);
      const standardPkg = packages.find(
        (p) => p.code === ProtectionPlanCode.STANDARD,
      );
      expect(standardPkg?.id).toBe('pkg_standard_mumbai');
      expect(standardPkg?.dailyRate.toNumber()).toBe(300);
    });
  });
});
