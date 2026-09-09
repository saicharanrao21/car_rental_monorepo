import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MarketplaceSupplyService } from './marketplace-supply.service';
import { CarCategory, InventoryTransferStatus } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

@Injectable()
export class InventoryRebalancingService {
  private readonly logger = new Logger(InventoryRebalancingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly supplyService: MarketplaceSupplyService,
  ) {}

  /**
   * Evaluates inventory across branches and generates explainable transfer recommendations
   */
  async generateRebalancingRecommendations(city?: string): Promise<any[]> {
    const where: any = { isActive: true };
    if (city) where.city = city.toUpperCase();

    const branches = await this.prisma.pickupHub.findMany({
      where,
      select: { id: true, name: true, city: true },
    });

    if (branches.length < 2) {
      return [];
    }

    const branchMetrics = await Promise.all(
      branches.map((b) => this.supplyService.getBranchSupplyMetrics(b.id)),
    );

    const createdRecommendations: any[] = [];

    // Evaluate pair-wise branch category imbalances within same city
    for (const deficitBranch of branchMetrics) {
      if (!deficitBranch.classBreakdown) continue;
      for (const cat of Object.values(CarCategory)) {
        const dStats = deficitBranch.classBreakdown[cat];
        if (!dStats || dStats.status !== 'DEFICIT') continue;

        // Find candidate surplus branch in the same city
        const surplusBranch = branchMetrics.find(
          (b) =>
            b.branchId !== deficitBranch.branchId &&
            b.city.toUpperCase() === deficitBranch.city.toUpperCase() &&
            b.classBreakdown?.[cat]?.status === 'SURPLUS',
        );

        if (!surplusBranch) continue;

        const sStats = surplusBranch.classBreakdown[cat];
        if (!sStats) continue;

        const transferUnits = Math.min(
          dStats.demandScore - dStats.available,
          sStats.available - sStats.demandScore,
        );

        if (transferUnits <= 0) continue;

        const estimatedTransferCost = transferUnits * 500; // ₹500 flat logistics per vehicle
        const projectedRevenueGain = transferUnits * 2500; // Estimated ₹2,500/day per rented vehicle

        const rec = await this.prisma.inventoryTransferRecommendation.create({
          data: {
            sourceBranchId: surplusBranch.branchId,
            destinationBranchId: deficitBranch.branchId,
            vehicleClass: cat,
            recommendedUnits: transferUnits,
            reason: `${deficitBranch.branchName} has ${cat} deficit (${dStats.demandScore} demand vs ${dStats.available} available); ${surplusBranch.branchName} has surplus.`,
            sourceUtilization: surplusBranch.utilizationRate,
            destinationDemandScore: dStats.demandScore,
            projectedRevenueGain: new Decimal(projectedRevenueGain),
            estimatedTransferCost: new Decimal(estimatedTransferCost),
            confidence: 0.88,
            status: InventoryTransferStatus.PROPOSED,
          },
        });

        createdRecommendations.push(rec);
      }
    }

    this.logger.log(
      `[REBALANCING] Generated ${createdRecommendations.length} inventory transfer recommendations.`,
    );

    return createdRecommendations;
  }

  /**
   * Retrieves active transfer recommendations
   */
  async getRecommendations(status?: InventoryTransferStatus, branchId?: string) {
    const where: any = {};
    if (status) where.status = status;
    if (branchId) {
      where.OR = [{ sourceBranchId: branchId }, { destinationBranchId: branchId }];
    }

    return this.prisma.inventoryTransferRecommendation.findMany({
      where,
      include: {
        sourceBranch: { select: { id: true, name: true, city: true } },
        destinationBranch: { select: { id: true, name: true, city: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Approves an inventory transfer recommendation
   */
  async approveRecommendation(id: string, approvedBy: string) {
    const rec = await this.prisma.inventoryTransferRecommendation.findUnique({
      where: { id },
    });

    if (!rec) {
      throw new NotFoundException(`Recommendation #${id} not found.`);
    }

    if (rec.status !== InventoryTransferStatus.PROPOSED) {
      throw new BadRequestException(`Cannot approve recommendation in status '${rec.status}'.`);
    }

    return this.prisma.inventoryTransferRecommendation.update({
      where: { id },
      data: {
        status: InventoryTransferStatus.APPROVED,
        approvedBy,
      },
    });
  }

  /**
   * Marks transfer dispatched (in transit)
   */
  async dispatchTransfer(id: string) {
    return this.prisma.inventoryTransferRecommendation.update({
      where: { id },
      data: {
        status: InventoryTransferStatus.IN_TRANSIT,
        dispatchedAt: new Date(),
      },
    });
  }

  /**
   * Marks transfer completed
   */
  async completeTransfer(id: string) {
    return this.prisma.inventoryTransferRecommendation.update({
      where: { id },
      data: {
        status: InventoryTransferStatus.RECEIVED,
        completedAt: new Date(),
      },
    });
  }
}
