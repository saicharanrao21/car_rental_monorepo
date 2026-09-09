import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  BadRequestException,
} from '@nestjs/common';
import { FulfillmentOrchestratorService } from './fulfillment-orchestrator.service';
import { VehicleSubstitutionService } from '../fleet/vehicle-substitution.service';
import {
  StartPreparationRequest,
  MarkCleanedRequest,
  MarkInspectedRequest,
  MarkReadyForPickupRequest,
  CustomerArrivalRequest,
} from './fulfillment-domain.types';
import { SubstitutionDecision, SubstitutionReason, Role } from '@prisma/client';

@Controller('api/v1/fulfillment')
export class FulfillmentController {
  constructor(
    private readonly fulfillmentOrchestrator: FulfillmentOrchestratorService,
    private readonly substitutionService: VehicleSubstitutionService,
  ) {}

  @Post('preparation/start')
  async startPreparation(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

    return this.fulfillmentOrchestrator.startPreparation({
      bookingId: body.bookingId,
      assignedStaffId: body.assignedStaffId,
      notes: body.notes,
      actorId,
      actorRole,
    });
  }

  @Post('preparation/clean')
  async markCleaned(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

    return this.fulfillmentOrchestrator.markCleaned({
      bookingId: body.bookingId,
      assignedStaffId: body.assignedStaffId,
      cleaningChecklist: body.cleaningChecklist,
      actorId,
      actorRole,
    });
  }

  @Post('preparation/inspect')
  async markInspected(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

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
  async markReadyForPickup(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

    return this.fulfillmentOrchestrator.markReadyForPickup({
      bookingId: body.bookingId,
      bayNumber: body.bayNumber,
      keyLocation: body.keyLocation,
      actorId,
      actorRole,
    });
  }

  @Post('customer-arrival')
  async recordCustomerArrival(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

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
  async evaluateSubstitution(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

    return this.substitutionService.evaluateSubstitution({
      bookingId: body.bookingId,
      reason: body.reason || SubstitutionReason.SCHEDULED_MAINTENANCE,
      reasonDetails: body.reasonDetails,
      actorId,
      actorRole,
      allowUpgrade: body.allowUpgrade !== false,
    });
  }

  @Post('substitute/execute')
  async executeSubstitution(@Body() body: any, @Request() req: any) {
    const actorId = req.user?.id || body.actorId || 'SYSTEM';
    const actorRole = req.user?.role || body.actorRole || Role.VENDOR;

    return this.substitutionService.executeSubstitution({
      bookingId: body.bookingId,
      targetCarId: body.targetCarId,
      decision: body.decision || SubstitutionDecision.AUTO_SUBSTITUTE,
      reason: body.reason || SubstitutionReason.SCHEDULED_MAINTENANCE,
      reasonDetails: body.reasonDetails,
      customerApproved: body.customerApproved,
      waivePriceDifference: body.waivePriceDifference,
      actorId,
      actorRole,
    });
  }

  @Get('booking/:bookingId')
  async getFulfillmentStatus(@Param('bookingId') bookingId: string) {
    return this.fulfillmentOrchestrator.getFulfillmentRecord(bookingId);
  }

  @Get('branch/:branchId/queue')
  async getBranchQueue(
    @Param('branchId') branchId: string,
    @Query('vendorId') vendorId?: string,
  ) {
    return this.fulfillmentOrchestrator.getBranchOperationalQueue(branchId, vendorId);
  }
}
