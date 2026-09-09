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
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { BranchOperationsService } from './branch-operations.service';
import { SlaEscalationEngineService } from './sla-escalation.service';
import { InventoryRebalancingService } from '../fleet/inventory-rebalancing.service';
import { BookingStatus, Role, SlaSeverity } from '@prisma/client';
import { ResolveIncidentDto } from './dto/command-center.dto';

@Controller('api/v1/operations')
@UseGuards(JwtAuthGuard, RolesGuard)
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
  @Roles(Role.ADMIN)
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
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY] },
        },
      }),
      // Returns scheduled today
      this.prisma.booking.count({
        where: {
          endDate: { gte: startOfToday, lte: endOfToday },
          status: { in: [BookingStatus.ONGOING, BookingStatus.RETURN_PENDING] },
        },
      }),
      // Unallocated confirmed bookings
      this.prisma.booking.count({
        where: {
          status: BookingStatus.CONFIRMED,
          carId: '',
        },
      }),
      // Vehicles under maintenance
      this.prisma.car.count({
        where: { operationalStatus: 'MAINTENANCE' },
      }),
      // Active SLA breaches
      this.prisma.slaBreachIncident.count({
        where: { status: 'OPEN' },
      }),
      // Total vehicle substitutions executed
      this.prisma.vehicleSubstitutionRecord.count(),
      // Fleet stats
      this.prisma.car.count(),
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
  @Roles(Role.VENDOR, Role.ADMIN)
  async getVendorCommandCenter(@Request() req: any, @Query('vendorId') queryVendorId?: string) {
    let vendorId: string;
    if (req.user.role === Role.VENDOR) {
      if (!req.user.vendorId) {
        throw new ForbiddenException('Access denied: Vendor user profile has no associated vendor ID.');
      }
      if (queryVendorId && queryVendorId !== req.user.vendorId) {
        throw new ForbiddenException('Access denied: Cannot query metrics for another vendor.');
      }
      vendorId = req.user.vendorId;
    } else {
      vendorId = queryVendorId || '';
      if (!vendorId) {
        throw new ForbiddenException('Vendor ID query parameter is required for admin viewing.');
      }
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
  @Roles(Role.VENDOR, Role.ADMIN)
  async getBranchDashboard(
    @Param('branchId') branchId: string,
    @Request() req: any,
    @Query('vendorId') queryVendorId?: string,
  ) {
    const vendorId = req.user.role === Role.VENDOR ? (req.user.vendorId || queryVendorId) : queryVendorId;
    return this.branchOperations.getBranchDashboard(branchId, vendorId);
  }

  /**
   * 4. INVENTORY REBALANCING RECOMMENDATIONS:
   */
  @Get('rebalancing/recommendations')
  @Roles(Role.ADMIN)
  async getRebalancingRecommendations(
    @Query('city') city?: string,
    @Query('status') status?: any,
  ) {
    return this.rebalancingService.getRecommendations(status);
  }

  @Post('rebalancing/generate')
  @Roles(Role.ADMIN)
  async generateRebalancingRecommendations(@Body() body: any) {
    return this.rebalancingService.generateRebalancingRecommendations(body.city);
  }

  /**
   * 5. RUN SLA EVALUATION:
   */
  @Post('sla/evaluate')
  @Roles(Role.ADMIN)
  async evaluateSlas() {
    return this.slaEngine.evaluateAllSlas();
  }

  /**
   * 6. LIST SLA INCIDENTS:
   */
  @Get('sla/incidents')
  @Roles(Role.ADMIN, Role.VENDOR)
  async listIncidents(
    @Request() req: any,
    @Query('status') status?: string,
    @Query('severity') severity?: SlaSeverity,
    @Query('vendorId') queryVendorId?: string,
  ) {
    const vendorId = req.user.role === Role.VENDOR ? (req.user.vendorId || queryVendorId) : queryVendorId;
    return this.slaEngine.listIncidents({ status, severity, vendorId });
  }

  /**
   * 7. RESOLVE SLA INCIDENT:
   */
  @Post('sla/incidents/:id/resolve')
  @Roles(Role.ADMIN)
  async resolveIncident(
    @Param('id') id: string,
    @Body() dto: ResolveIncidentDto,
    @Request() req: any,
  ) {
    return this.slaEngine.resolveIncident(id, req.user.userId, dto.resolutionNotes);
  }
}
