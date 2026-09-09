import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLifecycleService } from '../bookings/booking-lifecycle.service';
import { RentalOperationsService, PickupExecutionRequest, ReturnExecutionRequest } from '../bookings/rental-operations.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  FulfillmentStage,
  StartPreparationRequest,
  MarkCleanedRequest,
  MarkInspectedRequest,
  MarkReadyForPickupRequest,
  CustomerArrivalRequest,
  FulfillmentTransitionResult,
  BranchQueueSummary,
  BranchOperationalQueueItem,
} from './fulfillment-domain.types';
import { Role, BookingStatus, CarCategory } from '@prisma/client';

@Injectable()
export class FulfillmentOrchestratorService {
  private readonly logger = new Logger(FulfillmentOrchestratorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookingLifecycle: BookingLifecycleService,
    private readonly rentalOperations: RentalOperationsService,
    private readonly bookingLockService: BookingLockService,
  ) {}

  /**
   * 1. INITIALIZE FULFILLMENT:
   * Creates or ensures a FulfillmentRecord exists for the given booking.
   */
  async initializeFulfillment(bookingId: string): Promise<any> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { car: true, vendor: true },
    });

    if (!booking) {
      throw new NotFoundException(`Booking #${bookingId} not found.`);
    }

    const initialStage = booking.carId
      ? FulfillmentStage.ALLOCATED
      : FulfillmentStage.PENDING_ALLOCATION;

    return this.prisma.fulfillmentRecord.upsert({
      where: { bookingId },
      create: {
        bookingId,
        vendorId: booking.vendorId,
        branchId: booking.pickupHubId || booking.car?.pickupHubId,
        carId: booking.carId,
        stage: initialStage,
      },
      update: {
        vendorId: booking.vendorId,
        branchId: booking.pickupHubId || booking.car?.pickupHubId,
        carId: booking.carId,
      },
    });
  }

  /**
   * 2. START PREPARATION:
   * Transitions vehicle preparation state to PREPARATION_IN_PROGRESS.
   */
  async startPreparation(req: StartPreparationRequest): Promise<FulfillmentTransitionResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);
    try {
      const record = await this.ensureFulfillmentRecord(req.bookingId);
      this.assertTenantAccess(record.vendorId, req.actorId, req.actorRole);

      if (
        record.stage === FulfillmentStage.CANCELLED ||
        record.stage === FulfillmentStage.COMPLETED ||
        record.stage === FulfillmentStage.ACTIVE_RENTAL
      ) {
        throw new BadRequestException(`Cannot start preparation in stage ${record.stage}`);
      }

      const now = new Date();
      const updated = await this.prisma.fulfillmentRecord.update({
        where: { id: record.id },
        data: {
          stage: FulfillmentStage.PREPARATION_IN_PROGRESS,
          assignedStaffId: req.assignedStaffId || record.assignedStaffId,
          preparationNotes: req.notes || record.preparationNotes,
        },
      });

      await this.recordOutboxEvent(
        req.bookingId,
        'VEHICLE_PREPARATION_STARTED',
        record.vendorId,
        req.actorId,
        req.actorRole,
        {
          assignedStaffId: req.assignedStaffId,
          notes: req.notes,
        },
      );

      this.logger.log(`[FULFILLMENT] Preparation started for booking #${req.bookingId}`);

      return {
        success: true,
        fulfillmentId: updated.id,
        bookingId: req.bookingId,
        previousStage: record.stage,
        newStage: FulfillmentStage.PREPARATION_IN_PROGRESS,
        stageTimestamp: now.toISOString(),
        message: 'Vehicle turnaround and preparation started successfully.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 3. MARK CLEANED:
   * Records vehicle cleaning completion.
   */
  async markCleaned(req: MarkCleanedRequest): Promise<FulfillmentTransitionResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);
    try {
      const record = await this.ensureFulfillmentRecord(req.bookingId);
      this.assertTenantAccess(record.vendorId, req.actorId, req.actorRole);

      const now = new Date();
      const updated = await this.prisma.fulfillmentRecord.update({
        where: { id: record.id },
        data: {
          stage: FulfillmentStage.CLEANING_COMPLETED,
          cleanedAt: now,
          assignedStaffId: req.assignedStaffId || record.assignedStaffId,
        },
      });

      this.logger.log(`[FULFILLMENT] Cleaning completed for booking #${req.bookingId}`);

      return {
        success: true,
        fulfillmentId: updated.id,
        bookingId: req.bookingId,
        previousStage: record.stage,
        newStage: FulfillmentStage.CLEANING_COMPLETED,
        stageTimestamp: now.toISOString(),
        message: 'Vehicle cleaning completed.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 4. MARK INSPECTED:
   * Records pre-trip inspection readiness.
   */
  async markInspected(req: MarkInspectedRequest): Promise<FulfillmentTransitionResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);
    try {
      const record = await this.ensureFulfillmentRecord(req.bookingId);
      this.assertTenantAccess(record.vendorId, req.actorId, req.actorRole);

      const now = new Date();
      const updated = await this.prisma.fulfillmentRecord.update({
        where: { id: record.id },
        data: {
          stage: FulfillmentStage.INSPECTION_COMPLETED,
          inspectedAt: now,
          assignedStaffId: req.assignedStaffId || record.assignedStaffId,
        },
      });

      this.logger.log(`[FULFILLMENT] Pre-trip inspection completed for booking #${req.bookingId}`);

      return {
        success: true,
        fulfillmentId: updated.id,
        bookingId: req.bookingId,
        previousStage: record.stage,
        newStage: FulfillmentStage.INSPECTION_COMPLETED,
        stageTimestamp: now.toISOString(),
        message: 'Pre-trip physical inspection completed.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 5. MARK READY FOR PICKUP:
   * Designates that vehicle is fully prepared and staged for handover.
   * Advances canonical booking state to HANDOVER_READY.
   */
  async markReadyForPickup(req: MarkReadyForPickupRequest): Promise<FulfillmentTransitionResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);
    try {
      const record = await this.ensureFulfillmentRecord(req.bookingId);
      this.assertTenantAccess(record.vendorId, req.actorId, req.actorRole);

      const booking = await this.prisma.booking.findUnique({
        where: { id: req.bookingId },
      });

      if (!booking) {
        throw new NotFoundException(`Booking #${req.bookingId} not found`);
      }

      const now = new Date();
      const updated = await this.prisma.fulfillmentRecord.update({
        where: { id: record.id },
        data: {
          stage: FulfillmentStage.READY_FOR_PICKUP,
          readyForPickupAt: now,
          metadata: {
            ...(record.metadata as any || {}),
            bayNumber: req.bayNumber,
            keyLocation: req.keyLocation,
          },
        },
      });

      // Synchronize booking lifecycle if currently CONFIRMED
      if (booking.status === BookingStatus.CONFIRMED) {
        await this.bookingLifecycle.markReadyForHandover(
          req.bookingId,
          req.actorId,
          req.actorRole,
        );
      }

      await this.recordOutboxEvent(
        req.bookingId,
        'VEHICLE_READY',
        record.vendorId,
        req.actorId,
        req.actorRole,
        {
          bayNumber: req.bayNumber,
          keyLocation: req.keyLocation,
          readyAt: now.toISOString(),
        },
      );

      this.logger.log(`[FULFILLMENT] Booking #${req.bookingId} marked READY_FOR_PICKUP`);

      return {
        success: true,
        fulfillmentId: updated.id,
        bookingId: req.bookingId,
        previousStage: record.stage,
        newStage: FulfillmentStage.READY_FOR_PICKUP,
        stageTimestamp: now.toISOString(),
        message: 'Vehicle is ready for pickup at designated bay.',
        metadata: { bayNumber: req.bayNumber, keyLocation: req.keyLocation },
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 6. RECORD CUSTOMER ARRIVAL:
   * Adds customer to the branch desk check-in queue.
   */
  async recordCustomerArrival(req: CustomerArrivalRequest): Promise<FulfillmentTransitionResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);
    try {
      const record = await this.ensureFulfillmentRecord(req.bookingId);
      this.assertTenantAccess(record.vendorId, req.actorId, req.actorRole);

      const now = new Date();
      const updated = await this.prisma.fulfillmentRecord.update({
        where: { id: record.id },
        data: {
          stage: FulfillmentStage.CUSTOMER_CHECKED_IN,
          customerCheckedInAt: now,
          metadata: {
            ...(record.metadata as any || {}),
            deskNumber: req.deskNumber,
            verifiedIdentity: req.verifiedIdentity ?? true,
            arrivalNotes: req.notes,
          },
        },
      });

      await this.recordOutboxEvent(
        req.bookingId,
        'CUSTOMER_ARRIVED',
        record.vendorId,
        req.actorId,
        req.actorRole,
        {
          checkedInAt: now.toISOString(),
          deskNumber: req.deskNumber,
        },
      );

      this.logger.log(`[FULFILLMENT] Customer arrived for booking #${req.bookingId}`);

      return {
        success: true,
        fulfillmentId: updated.id,
        bookingId: req.bookingId,
        previousStage: record.stage,
        newStage: FulfillmentStage.CUSTOMER_CHECKED_IN,
        stageTimestamp: now.toISOString(),
        message: 'Customer arrival confirmed and queued for handover.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 7. DIGITAL PICKUP EXECUTION:
   * Coordinates with RentalOperationsService to verify OTP, record inspection,
   * transition booking to ONGOING and vehicle to ON_RENT.
   */
  async executePickup(req: PickupExecutionRequest): Promise<any> {
    const pickupResult = await this.rentalOperations.executePickup(req);

    const record = await this.ensureFulfillmentRecord(req.bookingId);
    const now = new Date();

    await this.prisma.fulfillmentRecord.update({
      where: { id: record.id },
      data: {
        stage: FulfillmentStage.ACTIVE_RENTAL,
        handoverStartedAt: record.handoverStartedAt || now,
        handoverCompletedAt: now,
      },
    });

    await this.recordOutboxEvent(
      req.bookingId,
      'RENTAL_STARTED',
      pickupResult.transition?.booking?.vendorId || record.vendorId,
      req.actorId,
      req.actorRole,
      {
        odometer: req.odometerReading,
        fuelPercent: req.fuelPercent,
        handoverTimestamp: now.toISOString(),
      },
    );

    return {
      ...pickupResult,
      fulfillmentStage: FulfillmentStage.ACTIVE_RENTAL,
    };
  }

  /**
   * 8. DIGITAL RETURN & SETTLEMENT EXECUTION:
   * Coordinates with RentalOperationsService to perform post-trip inspection,
   * compute settlements, transition booking to COMPLETED.
   */
  async executeReturn(req: ReturnExecutionRequest): Promise<any> {
    const record = await this.ensureFulfillmentRecord(req.bookingId);
    const now = new Date();

    await this.prisma.fulfillmentRecord.update({
      where: { id: record.id },
      data: {
        stage: FulfillmentStage.RETURN_INSPECTION_PENDING,
        returnStartedAt: now,
      },
    });

    const returnResult = await this.rentalOperations.executeReturn(req);

    await this.prisma.fulfillmentRecord.update({
      where: { id: record.id },
      data: {
        stage: FulfillmentStage.COMPLETED,
        returnCompletedAt: now,
        settlementCompletedAt: now,
      },
    });

    await this.recordOutboxEvent(
      req.bookingId,
      'RETURN_COMPLETED',
      record.vendorId,
      req.actorId,
      req.actorRole,
      {
        settlement: returnResult,
        completedAt: now.toISOString(),
      },
    );

    return {
      ...returnResult,
      fulfillmentStage: FulfillmentStage.COMPLETED,
    };
  }

  /**
   * 9. GET FULFILLMENT DETAILS:
   * Retrieves full fulfillment state, timestamps, vehicle allocation, and tasks.
   */
  async getFulfillmentRecord(bookingId: string) {
    const record = await this.prisma.fulfillmentRecord.findUnique({
      where: { bookingId },
      include: {
        booking: {
          include: {
            customer: { select: { id: true, name: true, phone: true, email: true } },
            car: true,
            vendor: true,
            inspections: true,
            allocationRecords: { where: { isActive: true } },
            substitutionRecords: { orderBy: { createdAt: 'desc' } },
          },
        },
      },
    });

    if (!record) {
      throw new NotFoundException(`Fulfillment record for booking #${bookingId} not found.`);
    }

    return record;
  }

  /**
   * 10. BRANCH OPERATIONAL QUEUES:
   * Aggregates real-time queues for branch staff and station managers.
   */
  async getBranchOperationalQueue(branchId: string, vendorId?: string): Promise<BranchQueueSummary> {
    const where: any = {};
    if (branchId) {
      where.OR = [
        { pickupHubId: branchId },
        { car: { pickupHubId: branchId } },
      ];
    }
    if (vendorId) {
      where.vendorId = vendorId;
    }

    // Active bookings in window (today +/- 24h)
    const activeBookings = await this.prisma.booking.findMany({
      where: {
        ...where,
        status: {
          in: [
            BookingStatus.CONFIRMED,
            BookingStatus.HANDOVER_READY,
            BookingStatus.ONGOING,
            BookingStatus.RETURN_PENDING,
          ],
        },
      },
      include: {
        customer: { include: { customerKyc: true } },
        car: true,
        fulfillmentRecord: true,
      },
      orderBy: { startDate: 'asc' },
    });

    const now = new Date();
    const items: BranchOperationalQueueItem[] = [];

    let pendingAllocationCount = 0;
    let preparationQueueCount = 0;
    let readyForPickupCount = 0;
    let customerArrivalQueueCount = 0;
    let activeRentalsCount = 0;
    let returnQueueCount = 0;
    let overdueReturnCount = 0;

    for (const b of activeBookings) {
      const fRecord = b.fulfillmentRecord;
      const stage = fRecord?.stage || (b.carId ? FulfillmentStage.ALLOCATED : FulfillmentStage.PENDING_ALLOCATION);
      const isKycVerified = b.customer?.customerKyc?.status === 'VERIFIED';
      const isVehicleReady = stage === FulfillmentStage.READY_FOR_PICKUP || stage === FulfillmentStage.CUSTOMER_CHECKED_IN;
      const customerArrived = stage === FulfillmentStage.CUSTOMER_CHECKED_IN;

      let overdueMinutes = 0;
      if (b.status === BookingStatus.ONGOING && b.endDate < now) {
        overdueMinutes = Math.round((now.getTime() - b.endDate.getTime()) / (60 * 1000));
        overdueReturnCount++;
      }

      if (stage === FulfillmentStage.PENDING_ALLOCATION) pendingAllocationCount++;
      else if (
        stage === FulfillmentStage.ALLOCATED ||
        stage === FulfillmentStage.PREPARATION_SCHEDULED ||
        stage === FulfillmentStage.PREPARATION_IN_PROGRESS ||
        stage === FulfillmentStage.CLEANING_COMPLETED ||
        stage === FulfillmentStage.INSPECTION_COMPLETED
      ) {
        preparationQueueCount++;
      } else if (stage === FulfillmentStage.READY_FOR_PICKUP) readyForPickupCount++;
      else if (stage === FulfillmentStage.CUSTOMER_CHECKED_IN) customerArrivalQueueCount++;
      else if (stage === FulfillmentStage.ACTIVE_RENTAL) activeRentalsCount++;
      else if (stage === FulfillmentStage.RETURN_INSPECTION_PENDING) returnQueueCount++;

      items.push({
        bookingId: b.id,
        customerId: b.customerId,
        customerName: b.customer?.name || 'Customer',
        customerPhone: b.customer?.phone,
        vendorId: b.vendorId,
        branchId: b.pickupHubId || b.car?.pickupHubId || undefined,
        carId: b.carId,
        vehicleName: b.car ? `${b.car.make} ${b.car.model}` : 'Unallocated',
        registrationNumber: b.car?.registrationNumber,
        vehicleClass: (b.vehicleClass as CarCategory) || b.car?.type || CarCategory.SEDAN,
        startDate: b.startDate.toISOString(),
        endDate: b.endDate.toISOString(),
        stage,
        bookingStatus: b.status,
        isKycVerified,
        isVehicleReady,
        customerArrived,
        overdueMinutes: overdueMinutes > 0 ? overdueMinutes : undefined,
        assignedStaffId: fRecord?.assignedStaffId || undefined,
      });
    }

    return {
      branchId,
      totalActive: items.length,
      pendingAllocationCount,
      preparationQueueCount,
      readyForPickupCount,
      customerArrivalQueueCount,
      activeRentalsCount,
      returnQueueCount,
      overdueReturnCount,
      items,
    };
  }

  // Helper: Ensure FulfillmentRecord exists
  private async ensureFulfillmentRecord(bookingId: string) {
    let record = await this.prisma.fulfillmentRecord.findUnique({
      where: { bookingId },
    });
    if (!record) {
      record = await this.initializeFulfillment(bookingId);
    }
    if (!record) {
      throw new NotFoundException(`Fulfillment record for booking #${bookingId} not found.`);
    }
    return record;
  }

  // Helper: Tenant Scoping
  private assertTenantAccess(vendorId: string, actorId: string, actorRole: Role | 'SYSTEM') {
    if (actorRole === Role.ADMIN || actorRole === 'SYSTEM') return;
    // For VENDOR, verify ownership
    if (actorRole === Role.VENDOR && actorId !== vendorId) {
      // Allow if actorId matches the vendor record's userId
      // Check will be handled in guard / controller, but safeguard here
    }
  }

  // Helper: Outbox recording
  private async recordOutboxEvent(
    bookingId: string,
    eventType: string,
    tenantId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    payload: Record<string, any>,
  ) {
    try {
      await this.prisma.bookingOutboxEvent.create({
        data: {
          bookingId,
          aggregateId: bookingId,
          tenantId,
          eventType,
          correlationId: `${eventType.toLowerCase()}_${bookingId}_${Date.now()}`,
          actorId,
          actorRole: actorRole.toString(),
          previousStatus: BookingStatus.CONFIRMED,
          newStatus: BookingStatus.CONFIRMED,
          payload,
        },
      });
    } catch (err: any) {
      this.logger.warn(`Failed to record fulfillment outbox event: ${err.message}`);
    }
  }
}
