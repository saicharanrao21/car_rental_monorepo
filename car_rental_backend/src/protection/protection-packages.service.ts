import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ProtectionPlanCode, ProtectionPackage, Prisma } from '@prisma/client';
import { CreateProtectionPackageDto } from './dto/create-protection-package.dto';

@Injectable()
export class ProtectionPackagesService implements OnModuleInit {
  private readonly logger = new Logger(ProtectionPackagesService.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    await this.seedDefaultPackages();
  }

  /**
   * Seeds standard default baseline protection packages if none exist.
   */
  async seedDefaultPackages() {
    const count = await this.prisma.protectionPackage.count();
    if (count === 0) {
      this.logger.log('Seeding baseline DriveGo Protection Packages...');
      await this.prisma.protectionPackage.createMany({
        data: [
          {
            name: 'Basic Protection',
            code: ProtectionPlanCode.BASIC,
            description: 'Standard third-party liability with regular damage deductible.',
            dailyRate: new Prisma.Decimal(0),
            coverageSummary: [
              'Third-Party Property & Bodily Injury Liability',
              'Standard Platform roadside dispatch',
            ],
            deductibleAmount: new Prisma.Decimal(10000),
            maxCoverageAmount: new Prisma.Decimal(200000),
            exclusions: ['Interior upholstery tears', 'Key loss or misplacement', 'Drunk driving damage'],
            isActive: true,
            displayOrder: 1,
          },
          {
            name: 'Standard Peace-of-Mind',
            code: ProtectionPlanCode.STANDARD,
            description: 'Reduced customer deductible limit of ₹5,000 for accidental exterior dents.',
            dailyRate: new Prisma.Decimal(250),
            coverageSummary: [
              'Customer liability capped at ₹5,000',
              'Windshield, glass & mirror scratch cover',
              'Free flat tyre roadside assistance',
            ],
            deductibleAmount: new Prisma.Decimal(5000),
            maxCoverageAmount: new Prisma.Decimal(500000),
            exclusions: ['Off-road driving damage', 'Waterlogging / hydrolock'],
            isActive: true,
            displayOrder: 2,
          },
          {
            name: 'Premium Zero-Depreciation',
            code: ProtectionPlanCode.ZERO_DEP,
            description: 'Complete bumper-to-bumper exterior protection with ZERO damage deductible.',
            dailyRate: new Prisma.Decimal(500),
            coverageSummary: [
              '₹0 Customer Deductible for all exterior body damages',
              'Zero deposit deduction for accidental collisions',
              'Full bumper, glass, light, tyre & engine casing coverage',
              'Priority 24/7 Roadside Assistance dispatch',
            ],
            deductibleAmount: new Prisma.Decimal(0),
            maxCoverageAmount: new Prisma.Decimal(1000000),
            exclusions: ['Intentional vandalism', 'Intoxicated driving'],
            isActive: true,
            displayOrder: 3,
          },
        ],
      });
      this.logger.log('Default Protection Packages seeded successfully.');
    }
  }

  /**
   * Retrieves active protection packages available in a city.
   * If city-specific overrides exist, uses them; otherwise falls back to global (city: null).
   */
  async getActivePackages(city?: string): Promise<ProtectionPackage[]> {
    const packages = await this.prisma.protectionPackage.findMany({
      where: {
        isActive: true,
        OR: [{ city: city || null }, { city: null }],
      },
      orderBy: { displayOrder: 'asc' },
    });

    // Deduplicate: If city override exists for a code, prefer city over global
    const codeMap = new Map<ProtectionPlanCode, ProtectionPackage>();
    for (const pkg of packages) {
      if (!codeMap.has(pkg.code) || pkg.city !== null) {
        codeMap.set(pkg.code, pkg);
      }
    }

    return Array.from(codeMap.values()).sort(
      (a, b) => a.displayOrder - b.displayOrder,
    );
  }

  /**
   * Retrieves package by ID.
   */
  async getPackageById(id: string): Promise<ProtectionPackage> {
    const pkg = await this.prisma.protectionPackage.findUnique({
      where: { id },
    });
    if (!pkg) {
      throw new NotFoundException('Protection package not found.');
    }
    return pkg;
  }

  /**
   * Admin creates or configures a protection package.
   */
  async createPackage(
    dto: CreateProtectionPackageDto,
  ): Promise<ProtectionPackage> {
    return this.prisma.protectionPackage.create({
      data: {
        name: dto.name,
        code: dto.code,
        description: dto.description,
        dailyRate: new Prisma.Decimal(dto.dailyRate),
        coverageSummary: dto.coverageSummary,
        deductibleAmount: new Prisma.Decimal(dto.deductibleAmount),
        maxCoverageAmount: new Prisma.Decimal(dto.maxCoverageAmount),
        exclusions: dto.exclusions || [],
        termsUrl: dto.termsUrl || null,
        city: dto.city || null,
        isActive: dto.isActive !== undefined ? dto.isActive : true,
        displayOrder: dto.displayOrder || 0,
      },
    });
  }

  /**
   * Admin updates a package.
   */
  async updatePackage(
    id: string,
    dto: Partial<CreateProtectionPackageDto>,
  ): Promise<ProtectionPackage> {
    const pkg = await this.prisma.protectionPackage.findUnique({
      where: { id },
    });
    if (!pkg) {
      throw new NotFoundException('Protection package not found.');
    }

    return this.prisma.protectionPackage.update({
      where: { id },
      data: {
        name: dto.name,
        description: dto.description,
        dailyRate: dto.dailyRate !== undefined ? new Prisma.Decimal(dto.dailyRate) : undefined,
        coverageSummary: dto.coverageSummary,
        deductibleAmount: dto.deductibleAmount !== undefined ? new Prisma.Decimal(dto.deductibleAmount) : undefined,
        maxCoverageAmount: dto.maxCoverageAmount !== undefined ? new Prisma.Decimal(dto.maxCoverageAmount) : undefined,
        exclusions: dto.exclusions,
        termsUrl: dto.termsUrl,
        city: dto.city !== undefined ? dto.city : undefined,
        isActive: dto.isActive,
        displayOrder: dto.displayOrder,
      },
    });
  }
}
