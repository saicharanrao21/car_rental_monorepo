import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, BookingStatus } from '@prisma/client';

export interface BranchSupplyMetrics {
  branchId: string;
  branchName: string;
  city: string;
  totalFleet: number;
  availableFleet: number;
  onRentFleet: number;
  maintenanceFleet: number;
  cleaningFleet: number;
  utilizationRate: number;
  classBreakdown: Record<
    CarCategory,
    {
      total: number;
      available: number;
      onRent: number;
      demandScore: number;
      status: 'DEFICIT' | 'BALANCED' | 'SURPLUS';
    }
  >;
}

@Injectable()
export class MarketplaceSupplyService {
  private readonly logger = new Logger(MarketplaceSupplyService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Computes comprehensive supply and utilization metrics for a given branch or city
   */
  async getBranchSupplyMetrics(branchId: string): Promise<BranchSupplyMetrics> {
    const branch = await this.prisma.pickupHub.findUnique({
      where: { id: branchId },
      include: { cars: true },
    });

    if (!branch) {
      throw new Error(`PickupHub #${branchId} not found.`);
    }

    const cars = branch.cars;
    const totalFleet = cars.length;

    let availableFleet = 0;
    let onRentFleet = 0;
    let maintenanceFleet = 0;
    let cleaningFleet = 0;

    const classStats: Record<string, { total: number; available: number; onRent: number }> = {};
    for (const cat of Object.values(CarCategory)) {
      classStats[cat] = { total: 0, available: 0, onRent: 0 };
    }

    for (const c of cars) {
      const cat = c.type;
      classStats[cat].total++;

      if (c.operationalStatus === 'ACTIVE' && c.isAvailable) {
        availableFleet++;
        classStats[cat].available++;
      } else if (c.operationalStatus === 'MAINTENANCE') {
        maintenanceFleet++;
      } else {
        onRentFleet++;
        classStats[cat].onRent++;
      }
    }

    // Check active bookings in next 24h to evaluate demand score per class
    const now = new Date();
    const next24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const upcomingBookings = await this.prisma.booking.findMany({
      where: {
        pickupHubId: branchId,
        status: { in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY, BookingStatus.PENDING] },
        startDate: { lte: next24h },
      },
    });

    const demandByClass: Record<string, number> = {};
    for (const b of upcomingBookings) {
      const cls = b.vehicleClass || 'SEDAN';
      demandByClass[cls] = (demandByClass[cls] || 0) + 1;
    }

    const classBreakdown: any = {};
    for (const cat of Object.values(CarCategory)) {
      const stats = classStats[cat];
      const demand = demandByClass[cat] || 0;
      const supply = stats.available;

      let status: 'DEFICIT' | 'BALANCED' | 'SURPLUS' = 'BALANCED';
      if (demand > supply) {
        status = 'DEFICIT';
      } else if (supply > demand + 3) {
        status = 'SURPLUS';
      }

      classBreakdown[cat] = {
        total: stats.total,
        available: stats.available,
        onRent: stats.onRent,
        demandScore: demand,
        status,
      };
    }

    const utilizationRate = totalFleet > 0 ? Math.round(((totalFleet - availableFleet) / totalFleet) * 100) / 100 : 0;

    return {
      branchId: branch.id,
      branchName: branch.name,
      city: branch.city,
      totalFleet,
      availableFleet,
      onRentFleet,
      maintenanceFleet,
      cleaningFleet,
      utilizationRate,
      classBreakdown,
    };
  }
}
