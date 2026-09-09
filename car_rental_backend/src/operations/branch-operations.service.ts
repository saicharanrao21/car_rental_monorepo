import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FulfillmentOrchestratorService } from '../fulfillment/fulfillment-orchestrator.service';
import { MarketplaceSupplyService } from '../fleet/marketplace-supply.service';
import { BookingStatus, FulfillmentStage } from '@prisma/client';

export interface BranchOperationsDashboard {
  branchId: string;
  branchName: string;
  city: string;
  overview: {
    totalFleet: number;
    availableFleet: number;
    onRentFleet: number;
    utilizationRate: number;
    pickupsToday: number;
    returnsToday: number;
    overdueCount: number;
    pendingPreparationCount: number;
    pendingAllocationsCount: number;
  };
  queues: {
    pickupQueue: any[];
    returnQueue: any[];
    preparationQueue: any[];
    customerArrivalQueue: any[];
    overdueQueue: any[];
  };
  supplyBreakdown: any;
  incidents: {
    unresolvedSlaBreaches: any[];
    pendingSubstitutions: any[];
  };
  timestamp: string;
}

@Injectable()
export class BranchOperationsService {
  private readonly logger = new Logger(BranchOperationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fulfillmentOrchestrator: FulfillmentOrchestratorService,
    private readonly supplyService: MarketplaceSupplyService,
  ) {}

  /**
   * Generates a unified real-time branch operations dashboard
   */
  async getBranchDashboard(branchId: string, vendorId?: string): Promise<BranchOperationsDashboard> {
    const branch = await this.prisma.pickupHub.findUnique({
      where: { id: branchId },
    });

    if (!branch) {
      throw new NotFoundException(`Branch #${branchId} not found.`);
    }

    // 1. Fetch fulfillment queues
    const queueSummary = await this.fulfillmentOrchestrator.getBranchOperationalQueue(branchId, vendorId);

    // 2. Fetch fleet supply metrics
    const supplyMetrics = await this.supplyService.getBranchSupplyMetrics(branchId);

    // 3. Fetch SLA breaches for branch
    const slaBreaches = await this.prisma.slaBreachIncident.findMany({
      where: {
        branchId,
        status: 'OPEN',
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    // 4. Fetch pending substitutions
    const substitutions = await this.prisma.vehicleSubstitutionRecord.findMany({
      where: {
        booking: {
          OR: [{ pickupHubId: branchId }, { car: { pickupHubId: branchId } }],
        },
      },
      include: {
        originalCar: { select: { registrationNumber: true, make: true, model: true } },
        substitutedCar: { select: { registrationNumber: true, make: true, model: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    // Partition queues
    const items = queueSummary.items;
    const pickupQueue = items.filter(
      (i) => i.stage === FulfillmentStage.READY_FOR_PICKUP || i.stage === FulfillmentStage.CUSTOMER_CHECKED_IN,
    );
    const returnQueue = items.filter(
      (i) => i.stage === FulfillmentStage.ACTIVE_RENTAL || i.stage === FulfillmentStage.RETURN_INSPECTION_PENDING,
    );
    const preparationQueue = items.filter(
      (i) =>
        i.stage === FulfillmentStage.ALLOCATED ||
        i.stage === FulfillmentStage.PREPARATION_SCHEDULED ||
        i.stage === FulfillmentStage.PREPARATION_IN_PROGRESS ||
        i.stage === FulfillmentStage.CLEANING_COMPLETED ||
        i.stage === FulfillmentStage.INSPECTION_COMPLETED,
    );
    const customerArrivalQueue = items.filter((i) => i.customerArrived);
    const overdueQueue = items.filter((i) => i.overdueMinutes && i.overdueMinutes > 0);

    return {
      branchId: branch.id,
      branchName: branch.name,
      city: branch.city,
      overview: {
        totalFleet: supplyMetrics.totalFleet,
        availableFleet: supplyMetrics.availableFleet,
        onRentFleet: supplyMetrics.onRentFleet,
        utilizationRate: supplyMetrics.utilizationRate,
        pickupsToday: pickupQueue.length,
        returnsToday: returnQueue.length,
        overdueCount: overdueQueue.length,
        pendingPreparationCount: preparationQueue.length,
        pendingAllocationsCount: queueSummary.pendingAllocationCount,
      },
      queues: {
        pickupQueue,
        returnQueue,
        preparationQueue,
        customerArrivalQueue,
        overdueQueue,
      },
      supplyBreakdown: supplyMetrics.classBreakdown,
      incidents: {
        unresolvedSlaBreaches: slaBreaches,
        pendingSubstitutions: substitutions,
      },
      timestamp: new Date().toISOString(),
    };
  }
}
