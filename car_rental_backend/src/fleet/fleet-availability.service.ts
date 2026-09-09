import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import {
  FleetOperationalState,
  FleetAvailabilityExplanation,
  VehicleClass,
} from './fleet-domain.types';

export interface AvailabilityInterval {
  startDate: Date;
  endDate: Date;
}

export interface AvailabilityEvaluationOptions {
  excludeBookingId?: string;
  bufferMinutes?: number; // Turnaround buffer time (default: 60 mins)
  includeAlternatives?: boolean;
}

@Injectable()
export class FleetAvailabilityService {
  private readonly logger = new Logger(FleetAvailabilityService.name);
  private static readonly DEFAULT_TURNAROUND_BUFFER_MINUTES = 60;

  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycleService: FleetLifecycleService,
  ) {}

  /**
   * Evaluates whether a vehicle is available for a given time window.
   */
  async isVehicleAvailable(
    carId: string,
    interval: AvailabilityInterval,
    options?: AvailabilityEvaluationOptions,
  ): Promise<boolean> {
    const explanation = await this.explainAvailability(carId, interval, options);
    return explanation.isAvailable;
  }

  /**
   * Computes an explainable, server-authoritative availability status with reasons and alternatives.
   */
  async explainAvailability(
    carId: string,
    interval?: AvailabilityInterval,
    options?: AvailabilityEvaluationOptions,
  ): Promise<FleetAvailabilityExplanation> {
    const bufferMinutes = options?.bufferMinutes ?? FleetAvailabilityService.DEFAULT_TURNAROUND_BUFFER_MINUTES;

    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: {
        pickupHub: true,
        blocks: true,
        holds: true,
      },
    });

    if (!car) {
      throw new NotFoundException(`Vehicle ${carId} not found`);
    }

    const state = await this.lifecycleService.getVehicleState(carId);
    const blockingFactors: Array<{
      type: 'RENTAL' | 'RESERVATION' | 'MAINTENANCE' | 'COMPLIANCE' | 'CLEANING' | 'GPS_OFFLINE';
      details: string;
      blockedUntil?: string;
    }> = [];

    // 1. Static Lifecycle State Checks
    if (state === FleetOperationalState.COMPLIANCE_BLOCKED) {
      blockingFactors.push({
        type: 'COMPLIANCE',
        details: 'Mandatory vehicle documents (Insurance/Fitness/PUC) expired or suspended.',
      });
    }

    if (state === FleetOperationalState.MAINTENANCE) {
      const returnDate = car.expectedReturnDate?.toISOString() || new Date(Date.now() + 86400000).toISOString();
      const reason = this.lifecycleService.getVehicleStateReason(carId) || car.maintenanceReason || 'Scheduled routine maintenance or repair in progress.';
      blockingFactors.push({
        type: 'MAINTENANCE',
        details: reason,
        blockedUntil: returnDate,
      });
    }

    if (state === FleetOperationalState.CLEANING) {
      const cleaningDone = new Date(Date.now() + 45 * 60000).toISOString();
      blockingFactors.push({
        type: 'CLEANING',
        details: 'Post-rental turnaround cleaning and sanitization in progress.',
        blockedUntil: cleaningDone,
      });
    }

    if (state === FleetOperationalState.GPS_OFFLINE) {
      blockingFactors.push({
        type: 'GPS_OFFLINE',
        details: 'Telematics signal heartbeat lost. Commercial dispatch temporarily suspended.',
      });
    }

    if (state === FleetOperationalState.ON_RENT) {
      const rentalUntil = car.expectedReturnDate?.toISOString() || new Date(Date.now() + 3600000 * 4).toISOString();
      blockingFactors.push({
        type: 'RENTAL',
        details: 'Vehicle is currently active on customer rental trip.',
        blockedUntil: rentalUntil,
      });
    }

    // 2. Interval Conflict Checks (if evaluated for a specific timeframe)
    let nextAvailableTime: string | undefined;

    if (interval) {
      const start = new Date(interval.startDate);
      const end = new Date(interval.endDate);

      // Add turnaround buffer to start and end
      const bufferMs = bufferMinutes * 60 * 1000;
      const bufferedStart = new Date(start.getTime() - bufferMs);
      const bufferedEnd = new Date(end.getTime() + bufferMs);

      // Check active or confirmed bookings
      const conflictingBookings = await this.prisma.booking.findMany({
        where: {
          carId,
          id: options?.excludeBookingId ? { not: options.excludeBookingId } : undefined,
          status: { in: ['CONFIRMED', 'HANDOVER_READY', 'ONGOING', 'RETURN_PENDING'] },
          startDate: { lt: bufferedEnd },
          endDate: { gt: bufferedStart },
        },
        orderBy: { endDate: 'desc' },
      });

      if (conflictingBookings.length > 0) {
        const latestBooking = conflictingBookings[0];
        const bufferedReturn = new Date(latestBooking.endDate.getTime() + bufferMs).toISOString();
        blockingFactors.push({
          type: 'RESERVATION',
          details: `Reserved for Booking #${latestBooking.id.substring(0, 8)} with ${bufferMinutes}m turnaround buffer.`,
          blockedUntil: bufferedReturn,
        });
        nextAvailableTime = bufferedReturn;
      }

      // Check vendor blackout blocks
      const conflictingBlocks = car.blocks.filter(
        (b) => b.startDate < bufferedEnd && b.endDate > bufferedStart,
      );
      if (conflictingBlocks.length > 0) {
        const block = conflictingBlocks[0];
        blockingFactors.push({
          type: 'MAINTENANCE',
          details: `Vendor operational blackout: ${block.reason || 'Blocked period'}`,
          blockedUntil: block.endDate.toISOString(),
        });
        if (!nextAvailableTime || block.endDate.toISOString() > nextAvailableTime) {
          nextAvailableTime = block.endDate.toISOString();
        }
      }
    }

    const isAvailable = blockingFactors.length === 0 && (state === FleetOperationalState.AVAILABLE || state === FleetOperationalState.ACTIVE);

    // 3. Alternative Recommendations (if vehicle is unavailable and requested)
    let alternatives: FleetAvailabilityExplanation['alternativeVehicles'] = undefined;
    if (!isAvailable && (options?.includeAlternatives !== false)) {
      alternatives = await this.findAlternativeVehicles(carId, car.type as string, car.pickupHubId || undefined);
    }

    return {
      carId,
      isAvailable,
      operationalState: state,
      reason: blockingFactors.length > 0 ? blockingFactors[0].details : undefined,
      blockingFactors: blockingFactors.length > 0 ? blockingFactors : undefined,
      nextAvailableAt: nextAvailableTime,
      turnaroundBufferMinutes: bufferMinutes,
      alternativeVehicles: alternatives,
    };
  }

  /**
   * Finds substitute alternative vehicles within the same vehicle class or at adjacent branches.
   */
  async findAlternativeVehicles(
    currentCarId: string,
    categoryType: string,
    branchId?: string,
  ): Promise<FleetAvailabilityExplanation['alternativeVehicles']> {
    try {
      const candidates = await this.prisma.car.findMany({
        where: {
          id: { not: currentCarId },
          isAvailable: true,
          type: categoryType as any,
          pickupHubId: branchId || undefined,
        },
        include: { pickupHub: true },
        take: 3,
      });

      return candidates.map((c) => ({
        carId: c.id,
        make: c.make,
        model: c.model,
        vehicleClass: (c.type as unknown as VehicleClass) || VehicleClass.MIDSIZE,
        branchId: c.pickupHubId || 'platform',
        branchName: c.pickupHub?.name || 'Central Hub',
        pricePerDay: Number(c.pricePerDay),
      }));
    } catch {
      return [];
    }
  }
}
