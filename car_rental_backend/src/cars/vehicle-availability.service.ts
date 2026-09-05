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
import { BookingLockService } from '../redis/booking-lock.service';
import { NotificationRealtimeService } from '../notifications/notification-realtime.service';
import {
  VehicleBlockType,
  VehicleHoldStatus,
  Role,
  BookingStatus,
  Prisma,
  VerificationStatus,
} from '@prisma/client';
import {
  VehicleAvailabilityResult,
  VehicleAvailabilityConflict,
  AvailabilityTimelineEntry,
} from './vehicle-availability.types';

@Injectable()
export class VehicleAvailabilityService {
  private readonly logger = new Logger(VehicleAvailabilityService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookingLockService: BookingLockService,
    @Optional() private readonly realtimeService?: NotificationRealtimeService,
  ) {}

  /**
   * Helper to check interval overlap between two intervals [S1, E1) and [S2, E2)
   * Two intervals overlap iff S1 < E2 AND E1 > S2.
   * Adjacent intervals (E1 == S2 or S1 == E2) do NOT overlap.
   */
  isIntervalOverlapping(start1: Date, end1: Date, start2: Date, end2: Date): boolean {
    return start1.getTime() < end2.getTime() && end1.getTime() > start2.getTime();
  }

  /**
   * 1. CHECK AVAILABILITY
   * Server-authoritative evaluation of whether a vehicle is bookable for a requested interval.
   */
  async checkAvailability(
    carId: string,
    startDate: Date,
    endDate: Date,
    options?: {
      excludeBookingId?: string;
      actorId?: string;
      hubId?: string;
    },
  ): Promise<VehicleAvailabilityResult> {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid date format for startDate or endDate.');
    }

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: {
        vendor: true,
        pickupHub: true,
      },
    });

    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    const conflicts: VehicleAvailabilityConflict[] = [];

    // Static Invariant 1: Physical / Listing availability
    if (!car.isAvailable) {
      return {
        available: false,
        carId,
        evaluatedInterval: {
          startDate: start.toISOString(),
          endDate: end.toISOString(),
        },
        reason: 'This vehicle is currently marked as unavailable or deactivated.',
        conflicts: [
          {
            type: 'BLOCK',
            startDate: start,
            endDate: end,
            reason: 'Vehicle listing is deactivated.',
          },
        ],
      };
    }

    // Static Invariant 2: Vendor Verification
    if (car.vendor?.verificationStatus !== VerificationStatus.VERIFIED) {
      return {
        available: false,
        carId,
        evaluatedInterval: {
          startDate: start.toISOString(),
          endDate: end.toISOString(),
        },
        reason: 'Vendor is not verified.',
        conflicts: [
          {
            type: 'BLOCK',
            startDate: start,
            endDate: end,
            reason: 'Vendor verification is pending or suspended.',
          },
        ],
      };
    }

    // Location Closure Invariant: If a hub is specified, verify no holiday/closure
    const hubIdToCheck = options?.hubId || car.pickupHubId;
    if (hubIdToCheck) {
      const locationExceptions = await this.prisma.locationException.findMany({
        where: {
          locationId: hubIdToCheck,
          isClosed: true,
          date: {
            gte: new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0),
            lte: new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59),
          },
        },
      });

      for (const exc of locationExceptions) {
        conflicts.push({
          type: 'LOCATION_CLOSURE',
          id: exc.id,
          startDate: exc.date,
          endDate: exc.date,
          reason: exc.reason || 'Location closure / holiday',
        });
      }
    }

    // Dynamic Invariant 3: Conflicting Active Bookings
    const bookingWhere: Prisma.BookingWhereInput = {
      carId,
      status: {
        in: [
          BookingStatus.PENDING,
          BookingStatus.CONFIRMED,
          BookingStatus.HANDOVER_READY,
          BookingStatus.ONGOING,
          BookingStatus.RETURN_PENDING,
        ],
      },
      startDate: { lt: end },
      endDate: { gt: start },
    };

    if (options?.excludeBookingId) {
      bookingWhere.id = { not: options.excludeBookingId };
    }

    const overlappingBookings = await this.prisma.booking.findMany({
      where: bookingWhere,
      select: {
        id: true,
        startDate: true,
        endDate: true,
        status: true,
      },
    });

    for (const b of overlappingBookings) {
      conflicts.push({
        type: 'BOOKING',
        id: b.id,
        startDate: b.startDate,
        endDate: b.endDate,
        status: b.status,
        reason: `Reserved by active booking ${b.id} (${b.status})`,
      });
    }

    // Dynamic Invariant 4: Operational Blocks & Maintenance Windows
    const overlappingBlocks = await this.prisma.vehicleBlock.findMany({
      where: {
        carId,
        startDate: { lt: end },
        endDate: { gt: start },
      },
    });

    for (const blk of overlappingBlocks) {
      conflicts.push({
        type: blk.blockType === VehicleBlockType.MAINTENANCE ? 'MAINTENANCE' : 'BLOCK',
        id: blk.id,
        startDate: blk.startDate,
        endDate: blk.endDate,
        reason: blk.reason || `Operational block (${blk.blockType})`,
      });
    }

    // Dynamic Invariant 5: Active Temporary Holds (by other users)
    const now = new Date();
    const overlappingHolds = await this.prisma.vehicleHold.findMany({
      where: {
        carId,
        status: VehicleHoldStatus.ACTIVE,
        expiresAt: { gt: now },
        startDate: { lt: end },
        endDate: { gt: start },
      },
    });

    for (const hold of overlappingHolds) {
      // If the hold was created by the same actor, it is not a conflict for them!
      if (options?.actorId && hold.customerId === options.actorId) {
        continue;
      }
      conflicts.push({
        type: 'HOLD',
        id: hold.id,
        startDate: hold.startDate,
        endDate: hold.endDate,
        reason: 'Vehicle is currently on temporary hold during checkout.',
      });
    }

    // Dynamic Invariant 6: Legacy Car.blockedDates
    if (car.blockedDates && car.blockedDates.length > 0) {
      const hasBlockedDate = car.blockedDates.some((bd) => {
        const bTime = bd.getTime();
        return bTime >= start.getTime() && bTime <= end.getTime();
      });

      if (hasBlockedDate) {
        conflicts.push({
          type: 'BLOCK',
          startDate: start,
          endDate: end,
          reason: 'Vehicle is marked blocked by fleet owner on requested dates.',
        });
      }
    }

    const available = conflicts.length === 0;

    return {
      available,
      carId,
      evaluatedInterval: {
        startDate: start.toISOString(),
        endDate: end.toISOString(),
      },
      reason: available ? undefined : conflicts.map((c) => c.reason).filter(Boolean).join('; '),
      conflicts,
    };
  }

  /**
   * 2. CREATE TEMPORARY HOLD
   * Places an idempotent, short-lived TTL hold on a vehicle during checkout.
   */
  async createHold(
    carId: string,
    customerId: string,
    startDate: Date,
    endDate: Date,
    ttlSeconds: number = 900,
    idempotencyKey?: string,
  ) {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    // 1. Idempotency Check: if key provided, return existing active hold
    if (idempotencyKey) {
      const existing = await this.prisma.vehicleHold.findUnique({
        where: { idempotencyKey },
      });
      if (existing && existing.status === VehicleHoldStatus.ACTIVE && existing.expiresAt > new Date()) {
        return existing;
      }
    }

    // 2. Acquire Redis Distributed Lock for Car
    const lockToken = await this.bookingLockService.acquireLock(carId);

    try {
      // 3. Re-verify availability inside lock
      const check = await this.checkAvailability(carId, start, end, {
        actorId: customerId,
      });

      if (!check.available) {
        throw new ConflictException(
          check.reason || 'Vehicle is not available for hold during requested dates.',
        );
      }

      const car = await this.prisma.car.findUnique({
        where: { id: carId },
        select: { vendorId: true },
      });

      if (!car) {
        throw new NotFoundException('Vehicle not found.');
      }

      const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

      // 4. Create VehicleHold record
      const hold = await this.prisma.vehicleHold.create({
        data: {
          carId,
          customerId,
          vendorId: car.vendorId,
          startDate: start,
          endDate: end,
          expiresAt,
          status: VehicleHoldStatus.ACTIVE,
          idempotencyKey,
        },
      });

      this.logger.log(`Created temporary hold ${hold.id} for car ${carId} by customer ${customerId}`);
      return hold;
    } finally {
      await this.bookingLockService.releaseLock(carId, lockToken);
    }
  }

  /**
   * 3. RELEASE HOLD
   */
  async releaseHold(holdId: string, customerId?: string): Promise<boolean> {
    const hold = await this.prisma.vehicleHold.findUnique({
      where: { id: holdId },
    });

    if (!hold) {
      return false;
    }

    if (customerId && hold.customerId !== customerId) {
      throw new ForbiddenException('You can only release your own vehicle holds.');
    }

    await this.prisma.vehicleHold.update({
      where: { id: holdId },
      data: {
        status: VehicleHoldStatus.RELEASED,
      },
    });

    return true;
  }

  /**
   * 4. EXPIRE HOLD
   */
  async expireHold(holdId: string): Promise<boolean> {
    await this.prisma.vehicleHold.updateMany({
      where: {
        id: holdId,
        status: VehicleHoldStatus.ACTIVE,
      },
      data: {
        status: VehicleHoldStatus.EXPIRED,
      },
    });
    return true;
  }

  /**
   * 5. CONVERT HOLD TO BOOKING
   * Marks all active holds for this customer on this vehicle as CONVERTED upon successful reservation.
   */
  async convertHoldToBooking(carId: string, customerId: string, tx?: Prisma.TransactionClient): Promise<void> {
    const client = tx || this.prisma;
    await client.vehicleHold.updateMany({
      where: {
        carId,
        customerId,
        status: VehicleHoldStatus.ACTIVE,
      },
      data: {
        status: VehicleHoldStatus.CONVERTED,
      },
    });
  }

  /**
   * 6. CREATE OPERATIONAL BLOCK / MAINTENANCE WINDOW
   */
  async blockVehicle(
    carId: string,
    vendorId: string,
    startDate: Date,
    endDate: Date,
    blockType: VehicleBlockType = VehicleBlockType.VENDOR_BLACKOUT,
    reason?: string,
    actorId: string = 'system',
    actorRole: Role = Role.VENDOR,
  ) {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    if (actorRole === Role.CUSTOMER) {
      throw new ForbiddenException('Customers are not authorized to block vehicles.');
    }

    const lockToken = await this.bookingLockService.acquireLock(carId);

    try {
      const car = await this.prisma.car.findUnique({
        where: { id: carId },
      });

      if (!car) {
        throw new NotFoundException('Vehicle not found.');
      }

      if (actorRole === Role.VENDOR && car.vendorId !== vendorId) {
        throw new ForbiddenException('You can only block vehicles belonging to your own fleet.');
      }

      // Check if existing active bookings conflict with the requested maintenance / block window
      const conflictingBookings = await this.prisma.booking.findMany({
        where: {
          carId,
          status: {
            in: [
              BookingStatus.PENDING,
              BookingStatus.CONFIRMED,
              BookingStatus.HANDOVER_READY,
              BookingStatus.ONGOING,
              BookingStatus.RETURN_PENDING,
            ],
          },
          startDate: { lt: end },
          endDate: { gt: start },
        },
      });

      if (conflictingBookings.length > 0) {
        throw new ConflictException(
          `Cannot block vehicle: Existing active booking (${conflictingBookings[0].id}) conflicts with requested dates.`,
        );
      }

      // Create the VehicleBlock record
      const block = await this.prisma.vehicleBlock.create({
        data: {
          carId,
          vendorId: car.vendorId,
          startDate: start,
          endDate: end,
          blockType,
          reason,
          actorId,
          actorRole,
        },
      });

      this.logger.log(`Created vehicle block ${block.id} (${blockType}) on car ${carId}`);

      // Emit realtime update to vendor if available
      if (this.realtimeService && car.vendorId) {
        const vendor = await this.prisma.vendor.findUnique({
          where: { id: car.vendorId },
          select: { userId: true },
        });
        if (vendor?.userId) {
          this.realtimeService.emitToUser(vendor.userId, 'notification', {
            eventType: 'VEHICLE_BLOCKED',
            carId,
            blockId: block.id,
            startDate: start.toISOString(),
            endDate: end.toISOString(),
          });
        }
      }

      return block;
    } finally {
      await this.bookingLockService.releaseLock(carId, lockToken);
    }
  }

  /**
   * 7. UNBLOCK VEHICLE / RELEASE MAINTENANCE WINDOW
   */
  async unblockVehicle(
    blockId: string,
    actorId: string,
    actorRole: Role,
    vendorId?: string,
  ): Promise<boolean> {
    const block = await this.prisma.vehicleBlock.findUnique({
      where: { id: blockId },
    });

    if (!block) {
      throw new NotFoundException(`Vehicle block with ID ${blockId} not found.`);
    }

    if (actorRole === Role.VENDOR && vendorId && block.vendorId !== vendorId) {
      throw new ForbiddenException('You can only remove blocks on your own fleet.');
    }

    await this.prisma.vehicleBlock.delete({
      where: { id: blockId },
    });

    this.logger.log(`Deleted vehicle block ${blockId} on car ${block.carId}`);
    return true;
  }

  /**
   * 8. GET VEHICLE AVAILABILITY TIMELINE
   * Constructs an authoritative chronological timeline of bookings, blocks, holds, and free intervals.
   */
  async getVehicleAvailabilityTimeline(
    carId: string,
    startDate: Date,
    endDate: Date,
  ): Promise<AvailabilityTimelineEntry[]> {
    const start = new Date(startDate);
    const end = new Date(endDate);

    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: {
        bookings: {
          where: {
            status: {
              in: [
                BookingStatus.PENDING,
                BookingStatus.CONFIRMED,
                BookingStatus.HANDOVER_READY,
                BookingStatus.ONGOING,
                BookingStatus.RETURN_PENDING,
              ],
            },
            startDate: { lt: end },
            endDate: { gt: start },
          },
          orderBy: { startDate: 'asc' },
        },
        blocks: {
          where: {
            startDate: { lt: end },
            endDate: { gt: start },
          },
          orderBy: { startDate: 'asc' },
        },
        holds: {
          where: {
            status: VehicleHoldStatus.ACTIVE,
            expiresAt: { gt: new Date() },
            startDate: { lt: end },
            endDate: { gt: start },
          },
          orderBy: { startDate: 'asc' },
        },
      },
    });

    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    const timeline: AvailabilityTimelineEntry[] = [];

    for (const b of car.bookings) {
      timeline.push({
        type: 'BOOKING',
        id: b.id,
        status: b.status,
        startDate: b.startDate.toISOString(),
        endDate: b.endDate.toISOString(),
        metadata: {
          customerId: b.customerId,
          totalFare: Number(b.totalFare),
        },
      });
    }

    for (const blk of car.blocks) {
      timeline.push({
        type: blk.blockType === VehicleBlockType.MAINTENANCE ? 'MAINTENANCE' : 'BLOCK',
        id: blk.id,
        status: blk.blockType,
        startDate: blk.startDate.toISOString(),
        endDate: blk.endDate.toISOString(),
        reason: blk.reason || undefined,
      });
    }

    for (const hold of car.holds) {
      timeline.push({
        type: 'HOLD',
        id: hold.id,
        status: hold.status,
        startDate: hold.startDate.toISOString(),
        endDate: hold.endDate.toISOString(),
        metadata: {
          expiresAt: hold.expiresAt.toISOString(),
        },
      });
    }

    // Sort timeline chronologically
    timeline.sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime());

    return timeline;
  }

  /**
   * 9. GET VEHICLE BLOCKS
   */
  async getBlocks(carId: string) {
    return this.prisma.vehicleBlock.findMany({
      where: { carId },
      orderBy: { startDate: 'asc' },
    });
  }
}

