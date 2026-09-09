import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { FleetAvailabilityService } from '../fleet/fleet-availability.service';
import { VehicleAllocationService } from '../fleet/vehicle-allocation.service';
import { RentalPricingResolutionService } from '../pricing/rental-pricing-resolution.service';
import { RentalOperationsService } from './rental-operations.service';
import { RentalAutomationService } from './rental-automation.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  SearchClassAvailabilityDto,
  CalculateRentalPricingDto,
  AllocateVehicleDto,
  ExecutePickupDto,
  ExecuteReturnDto,
  CreateRentalPricingRuleDto,
} from './dto/rental-core.dto';

@Controller('rental')
export class RentalCoreController {
  constructor(
    private readonly availabilityService: FleetAvailabilityService,
    private readonly allocationService: VehicleAllocationService,
    private readonly pricingResolution: RentalPricingResolutionService,
    private readonly operationsService: RentalOperationsService,
    private readonly automationService: RentalAutomationService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * 1. SEARCH CLASS AVAILABILITY
   * Searches available inventory by vehicle class across branches with turnaround buffers.
   */
  @Post('search-availability')
  async searchAvailability(@Body() dto: SearchClassAvailabilityDto) {
    return this.availabilityService.searchClassAvailability({
      vendorId: dto.vendorId,
      branchId: dto.branchId,
      city: dto.city,
      vehicleClass: dto.vehicleClass,
      startDate: new Date(dto.startDate),
      endDate: new Date(dto.endDate),
      minCapacity: dto.minCapacity,
      fuelType: dto.fuelType,
      turnaroundBufferMinutes: dto.turnaroundBufferMinutes,
    });
  }

  /**
   * 2. CALCULATE HIERARCHICAL RENTAL PRICING
   * Resolves effective pricing across PLATFORM -> VENDOR -> BRANCH -> VEHICLE_CLASS
   */
  @Post('pricing/calculate')
  async calculatePricing(@Body() dto: CalculateRentalPricingDto) {
    return this.pricingResolution.resolvePricing({
      vendorId: dto.vendorId,
      branchId: dto.branchId,
      returnBranchId: dto.returnBranchId,
      vehicleClass: dto.vehicleClass,
      carId: dto.carId,
      startDate: new Date(dto.startDate),
      endDate: new Date(dto.endDate),
      tripType: dto.tripType,
      distanceKm: dto.distanceKm,
      couponCode: dto.couponCode,
      couponDiscountAmount: dto.couponDiscountAmount,
      pickupFee: dto.pickupFee,
      returnFee: dto.returnFee,
    });
  }

  /**
   * 3. ALLOCATE / REASSIGN VEHICLE (Vendor, Admin)
   */
  @Post('allocations/:bookingId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN, Role.VENDOR)
  async allocateVehicle(
    @Req() req: any,
    @Param('bookingId') bookingId: string,
    @Body() dto: AllocateVehicleDto,
  ) {
    return this.allocationService.allocateVehicle({
      bookingId,
      targetCarId: dto.targetCarId,
      strategy: dto.strategy,
      reason: dto.reason,
      allocatedBy: req.user.userId,
      allocatedByRole: req.user.role as Role,
      allowUpgrade: dto.allowUpgrade,
    });
  }

  /**
   * 4. ALLOCATION AUDIT HISTORY
   */
  @Get('allocations/:bookingId/history')
  @UseGuards(JwtAuthGuard)
  async getAllocationHistory(@Param('bookingId') bookingId: string) {
    return this.allocationService.getAllocationHistory(bookingId);
  }

  /**
   * 5. DIGITAL PICKUP OPERATION (Vendor, Admin)
   */
  @Post('operations/pickup')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN, Role.VENDOR)
  async executePickup(@Req() req: any, @Body() dto: ExecutePickupDto) {
    return this.operationsService.executePickup({
      bookingId: dto.bookingId,
      actorId: req.user.userId,
      actorRole: req.user.role as Role,
      odometerReading: dto.odometerReading,
      fuelPercent: dto.fuelPercent,
      handoverOtpCode: dto.handoverOtpCode,
      inspectionPhotos: dto.inspectionPhotos,
      notes: dto.notes,
      skipOtpForAdmin: dto.skipOtpForAdmin,
    });
  }

  /**
   * 6. DIGITAL RETURN & DEPOSIT SETTLEMENT (Vendor, Admin)
   */
  @Post('operations/return')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN, Role.VENDOR)
  async executeReturn(@Req() req: any, @Body() dto: ExecuteReturnDto) {
    return this.operationsService.executeReturn({
      bookingId: dto.bookingId,
      actorId: req.user.userId,
      actorRole: req.user.role as Role,
      odometerReading: dto.odometerReading,
      fuelPercent: dto.fuelPercent,
      handoverOtpCode: dto.handoverOtpCode,
      inspectionPhotos: dto.inspectionPhotos,
      newDamagesNotes: dto.newDamagesNotes,
      damageEstimatedCost: dto.damageEstimatedCost,
      skipOtpForAdmin: dto.skipOtpForAdmin,
    });
  }

  /**
   * 7. LIST PRICING RULES (Admin, Vendor)
   */
  @Get('rules')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN, Role.VENDOR)
  async listPricingRules(@Query('vendorId') vendorId?: string) {
    return this.prisma.rentalPricingRule.findMany({
      where: {
        isActive: true,
        vendorId: vendorId || undefined,
      },
      orderBy: [{ scope: 'asc' }, { priority: 'desc' }],
    });
  }

  /**
   * 8. CREATE PRICING RULE (Admin Only)
   */
  @Post('rules')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async createPricingRule(@Body() dto: CreateRentalPricingRuleDto) {
    return this.prisma.rentalPricingRule.create({
      data: {
        scope: dto.scope,
        name: dto.name,
        description: dto.description,
        vendorId: dto.vendorId,
        branchId: dto.branchId,
        vehicleClass: dto.vehicleClass,
        carId: dto.carId,
        hourlyRateMultiplier: dto.hourlyRateMultiplier,
        dailyRate: dto.dailyRate,
        weeklyDiscountPct: dto.weeklyDiscountPct,
        monthlyDiscountPct: dto.monthlyDiscountPct,
        weekendMultiplier: dto.weekendMultiplier,
        peakSeasonMultiplier: dto.peakSeasonMultiplier,
        holidayMultiplier: dto.holidayMultiplier,
        extraKmRate: dto.extraKmRate,
        lateReturnHourlyFee: dto.lateReturnHourlyFee,
        securityDepositAmount: dto.securityDepositAmount,
        convenienceFee: dto.convenienceFee,
        oneWayBaseFee: dto.oneWayBaseFee,
        priority: dto.priority || 0,
        effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : null,
        effectiveTo: dto.effectiveTo ? new Date(dto.effectiveTo) : null,
      },
    });
  }

  /**
   * 9. TRIGGER AUTOMATION SWEEP (Admin Only)
   */
  @Post('automation/run')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async runAutomation() {
    const [quotes, unconfirmed, overdue, reminders] = await Promise.all([
      this.automationService.expireStaleQuotes(),
      this.automationService.expireUnconfirmedReservations(),
      this.automationService.detectOverdueReturns(),
      this.automationService.processPickupReminders(),
    ]);

    return {
      timestamp: new Date().toISOString(),
      results: [quotes, unconfirmed, overdue, reminders],
    };
  }
}
