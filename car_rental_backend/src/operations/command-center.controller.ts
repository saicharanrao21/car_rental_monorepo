import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  UseGuards,
  Request,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BranchOperationsService } from './branch-operations.service';
import { SlaEscalationEngineService } from './sla-escalation.service';
import { InventoryRebalancingService } from '../fleet/inventory-rebalancing.service';
import { BookingStatus, Role, FulfillmentStage } from '@prisma/client';

@Controller('api/v1/operations')
export class CommandCenterController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly branchOperations: BranchOperationsService,
    private readonly slaEngine: SlaEscalationEngineService,
    private readonly rebalancingService: InventoryRebalancingService,
  ) {}

  /**
   * 1. ADMIN COMMAND CENTER:
   * Aggregates enterprise-wide real-time operational health
   */
  @Get('admin/command-center')
  async getAdminCommandCenter(@Request() req: any) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);

    const [
      bookingsToday,
      activeRentals,
      pickupsToday,
      returnsToday,
      unallocatedCount,
      maintenanceVehicles,
      slaBreachesCount,
      substitutionsCount,
      totalCars,
      activeCars,
    ] = await Promise.all([
      // Bookings created today
      this.prisma.booking.count({
        where: { createdAt: { gte: startOfToday, lte: endOfToday } },
      }),
      // Active rentals
      this.prisma.booking.count({
        where: { status: BookingStatus.ONGOING },
      }),
      // Pickups scheduled today
      this.prisma.booking.count({
        where: {
          startDate: { gte: startOfToday, lte: endOfToday },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY, BookingStatus.ONGOING] },
        },
      }),
      // Returns scheduled today
      this.prisma.booking.count({
        where: {
          endDate: { gte: startOfToday, lte: endOfToday },
          status: { in: [BookingStatus.ONGOING, BookingStatus.RETURN_PENDING, BookingStatus.COMPLETED] },
        },
      }),
      // Unallocated bookings
      this.prisma.booking.count({
        where: {
          status: BookingStatus.CONFIRMED,
          allocationStatus: 'PENDING_ALLOCATION',
        },
      }),
      // Maintenance / unavailable cars
      this.prisma.car.count({
        where: { operationalStatus: 'MAINTENANCE' },
      }),
      // Open SLA breaches
      this.prisma.slaBreachIncident.count({
        where: { status: 'OPEN' },
      }),
      // Substitution incidents
      this.prisma.vehicleSubstitutionRecord.count({
        where: { createdAt: { gte: startOfToday } },
      }),
      // Total fleet
      this.prisma.car.count(),
      // Active fleet
      this.prisma.car.count({
        where: { operationalStatus: 'ACTIVE', isAvailable: true },
      }),
    ]);

    // Overdue rentals
    const now = new Date();
    const overdueRentals = await this.prisma.booking.count({
      where: {
        status: BookingStatus.ONGOING,
        endDate: { lt: now },
      },
    });

    const fleetUtilization =
      totalCars > 0 ? Math.round(((totalCars - activeCars) / totalCars) * 100) / 100 : 0;

    return {
      timestamp: now.toISOString(),
      overview: {
        bookingsToday,
        pickupsToday,
        returnsToday,
        activeRentals,
        overdueRentals,
        unallocatedCount,
        maintenanceVehicles,
        slaBreachesCount,
        substitutionsCount,
        totalFleet: totalCars,
        availableFleet: activeCars,
        fleetUtilization,
      },
    };
  }

  /**
   * 2. VENDOR OPERATIONS CENTER:
   * Multi-tenant isolated operational dashboard for vendor staff
   */
  @Get('vendor/command-center')
  async getVendorCommandCenter(@Query('vendorId') vendorId: string, @Request() req: any) {
    if (!vendorId) {
      throw new ForbiddenException('Vendor ID is required.');
    }

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [vendorBookingsToday, activeRentals, totalVendorCars, availableVendorCars, openSlaCount] =
      await Promise.all([
        this.prisma.booking.count({
          where: {
            vendorId,
            createdAt: { gte: startOfToday },
          },
        }),
        this.prisma.booking.count({
          where: {
            vendorId,
            status: BookingStatus.ONGOING,
          },
        }),
        this.prisma.car.count({ where: { vendorId } }),
        this.prisma.car.count({ where: { vendorId, operationalStatus: 'ACTIVE', isAvailable: true } }),
        this.prisma.slaBreachIncident.count({ where: { vendorId, status: 'OPEN' } }),
      ]);

    const utilization =
      totalVendorCars > 0
        ? Math.round(((totalVendorCars - availableVendorCars) / totalVendorCars) * 100) / 100
        : 0;

    return {
      vendorId,
      overview: {
        vendorBookingsToday,
        activeRentals,
        totalVendorCars,
        availableVendorCars,
        utilization,
        openSlaCount,
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * 3. SMART BRANCH DASHBOARD:
   * Returns operational queues, vehicle readiness, and bottlenecks for a specific branch
   */
  @Get('branch/:branchId/dashboard')
  async getBranchDashboard(
    @Param('branchId') branchId: string,
    @Query('vendorId') vendorId?: string,
  ) {
    return this.branchOperations.getBranchDashboard(branchId, vendorId);
  }

  /**
   * 4. INVENTORY REBALANCING RECOMMENDATIONS:
   */
  @Get('rebalancing/recommendations')
  async getRebalancingRecommendations(
    @Query('city') city?: string,
    @Query('status') status?: any,
  ) {
    return this.rebalancingService.getRecommendations(status);
  }

  @Post('rebalancing/generate')
  async generateRebalancingRecommendations(@Body() body: any) {
    return this.rebalancingService.generateRebalancingRecommendations(body.city);
  }

  /**
   * 5. RUN SLA EVALUATION:
   */
  @Post('sla/evaluate')
  async evaluateSlas() {
    return this.slaEngine.evaluateAllSlas();
  }
}
