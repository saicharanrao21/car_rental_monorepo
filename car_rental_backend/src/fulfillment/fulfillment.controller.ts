import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { FulfillmentOrchestratorService } from './fulfillment-orchestrator.service';
import { VehicleSubstitutionService } from '../fleet/vehicle-substitution.service';
import {
  StartPreparationDto,
  MarkCleanedDto,
  MarkInspectedDto,
  MarkReadyForPickupDto,
  CustomerArrivalDto,
  EvaluateSubstitutionDto,
  ExecuteSubstitutionDto,
} from './dto/fulfillment-requests.dto';

@Controller(['api/v1/fulfillment', 'fulfillment'])
@UseGuards(JwtAuthGuard, RolesGuard)
export class FulfillmentController {
  constructor(
    private readonly fulfillmentOrchestrator: FulfillmentOrchestratorService,
    private readonly substitutionService: VehicleSubstitutionService,
  ) {}

  @Post('preparation/start')
  @Roles(Role.VENDOR, Role.ADMIN)
  async startPreparation(@Body() body: StartPreparationDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.fulfillmentOrchestrator.startPreparation({
      bookingId: body.bookingId,
      assignedStaffId: body.assignedStaffId,
      notes: body.notes,
      actorId,
      actorRole,
    });
  }

  @Post('preparation/clean')
  @Roles(Role.VENDOR, Role.ADMIN)
  async markCleaned(@Body() body: MarkCleanedDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.fulfillmentOrchestrator.markCleaned({
      bookingId: body.bookingId,
      assignedStaffId: body.assignedStaffId,
      cleaningChecklist: body.cleaningChecklist,
      actorId,
      actorRole,
    });
  }

  @Post('preparation/inspect')
  @Roles(Role.VENDOR, Role.ADMIN)
  async markInspected(@Body() body: MarkInspectedDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.fulfillmentOrchestrator.markInspected({
      bookingId: body.bookingId,
      assignedStaffId: body.assignedStaffId,
      inspectionNotes: body.inspectionNotes,
      odometerReading: body.odometerReading,
      fuelPercent: body.fuelPercent,
      actorId,
      actorRole,
    });
  }

  @Post('preparation/ready')
  @Roles(Role.VENDOR, Role.ADMIN)
  async markReadyForPickup(@Body() body: MarkReadyForPickupDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.fulfillmentOrchestrator.markReadyForPickup({
      bookingId: body.bookingId,
      bayNumber: body.bayNumber,
      keyLocation: body.keyLocation,
      actorId,
      actorRole,
    });
  }

  @Post('customer-arrival')
  @Roles(Role.VENDOR, Role.ADMIN)
  async recordCustomerArrival(@Body() body: CustomerArrivalDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.fulfillmentOrchestrator.recordCustomerArrival({
      bookingId: body.bookingId,
      deskNumber: body.deskNumber,
      verifiedIdentity: body.verifiedIdentity,
      notes: body.notes,
      actorId,
      actorRole,
    });
  }

  @Post('substitute/evaluate')
  @Roles(Role.VENDOR, Role.ADMIN)
  async evaluateSubstitution(@Body() body: EvaluateSubstitutionDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.substitutionService.evaluateSubstitution({
      bookingId: body.bookingId,
      reason: body.reason,
      reasonDetails: body.reasonDetails,
      actorId,
      actorRole,
      allowUpgrade: true,
    });
  }

  @Post('substitute/execute')
  @Roles(Role.VENDOR, Role.ADMIN)
  async executeSubstitution(@Body() body: ExecuteSubstitutionDto, @Request() req: any) {
    const actorId = req.user.userId;
    const actorRole = req.user.role;

    return this.substitutionService.executeSubstitution({
      bookingId: body.bookingId,
      targetCarId: body.targetCarId,
      decision: body.decision,
      reason: body.reason,
      reasonDetails: body.reasonDetails,
      customerApproved: body.customerApproved,
      waivePriceDifference: body.waivePriceDifference,
      actorId,
      actorRole,
    });
  }

  @Get('booking/:bookingId')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN, Role.SUPPORT_AGENT)
  async getFulfillmentStatus(@Param('bookingId') bookingId: string, @Request() req: any) {
    const record = await this.fulfillmentOrchestrator.getFulfillmentRecord(bookingId);
    // Tenant check: if caller is vendor, ensure vendor owns the record
    if (req.user.role === Role.VENDOR && (!req.user.vendorId || record.vendorId !== req.user.vendorId)) {
      throw new ForbiddenException('Access denied: Record belongs to another vendor.');
    }
    // Customer check: if caller is customer, ensure customer owns the booking
    if (req.user.role === Role.CUSTOMER && record.booking?.customerId !== req.user.userId) {
      throw new ForbiddenException('Access denied: You can only access your own booking fulfillment.');
    }
    return record;
  }

  @Get('branch/:branchId/queue')
  @Roles(Role.VENDOR, Role.ADMIN)
  async getBranchQueue(
    @Param('branchId') branchId: string,
    @Request() req: any,
    @Query('vendorId') queryVendorId?: string,
  ) {
    let vendorId: string | undefined;
    if (req.user.role === Role.VENDOR) {
      if (!req.user.vendorId) {
        throw new ForbiddenException(
          'Access denied: Vendor user profile has no associated vendor ID.',
        );
      }
      if (queryVendorId && queryVendorId !== req.user.vendorId) {
        throw new ForbiddenException(
          'Access denied: Cannot query operational queue for another vendor.',
        );
      }
      vendorId = req.user.vendorId;
    } else {
      vendorId = queryVendorId;
    }
    return this.fulfillmentOrchestrator.getBranchOperationalQueue(branchId, vendorId);
  }
}
