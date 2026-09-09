import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FleetAvailabilityService } from './fleet-availability.service';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CarCategory, Role, BookingStatus } from '@prisma/client';

export type AllocationStrategy =
  | 'EXACT_VEHICLE'
  | 'SAME_CLASS'
  | 'AUTOMATIC'
  | 'BRANCH_BASED'
  | 'NEAREST_SUITABLE'
  | 'MANUAL_OVERRIDE';

export interface AllocateVehicleRequest {
  bookingId: string;
  targetCarId?: string;
  strategy: AllocationStrategy;
  reason?: string;
  allocatedBy: string;
  allocatedByRole: Role;
  allowUpgrade?: boolean;
}

export interface AllocationResult {
  success: boolean;
  bookingId: string;
  allocatedCarId: string;
  vehicleRegistration: string;
  vehicleModel: string;
  vehicleClass: CarCategory;
  strategy: AllocationStrategy;
  allocationRecordId: string;
  previousCarId?: string;
  allocatedAt: Date;
  message: string;
}

@Injectable()
export class VehicleAllocationService {
  private readonly logger = new Logger(VehicleAllocationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly availabilityService: FleetAvailabilityService,
    private readonly lifecycleService: FleetLifecycleService,
    private readonly bookingLockService: BookingLockService,
  ) {}

  /**
   * Allocates or reassigns a physical vehicle to a booking using the designated strategy.
   * Serialized via distributed mutex lock to prevent concurrent double-allocation.
   */
  async allocateVehicle(req: AllocateVehicleRequest): Promise<AllocationResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);

    try {
      // 1. Fetch current booking
      const booking = await this.prisma.booking.findUnique({
        where: { id: req.bookingId },
        include: {
          car: { include: { pickupHub: true } },
          vendor: true,
          allocationRecords: { where: { isActive: true } },
        },
      });

      if (!booking) {
        throw new NotFoundException(`Booking #${req.bookingId} not found.`);
      }

      if (
        booking.status === BookingStatus.COMPLETED ||
        booking.status === BookingStatus.CANCELLED ||
        booking.status === BookingStatus.EXPIRED
      ) {
        throw new BadRequestException(
          `Cannot allocate vehicle for booking in terminal status ${booking.status}.`,
        );
      }

      // Multi-tenant check
      if (
        req.allocatedByRole === Role.VENDOR &&
        booking.vendorId !== req.allocatedBy
      ) {
        const vendor = await this.prisma.vendor.findUnique({
          where: { userId: req.allocatedBy },
        });
        if (!vendor || vendor.id !== booking.vendorId) {
          throw new ForbiddenException('Unauthorized: You can only allocate vehicles for your own fleet.');
        }
      }

      const previousAllocation = booking.allocationRecords[0];
      const previousCarId = booking.carId;
      const targetVehicleClass = (booking.vehicleClass as CarCategory) || booking.car.type;
      const targetHubId = booking.pickupHubId || booking.car.pickupHubId;

      let chosenCar: any = null;

      // 2. Select physical car based on strategy
      if (req.strategy === 'EXACT_VEHICLE' || req.strategy === 'MANUAL_OVERRIDE') {
        if (!req.targetCarId) {
          throw new BadRequestException(`A targetCarId is required for strategy '${req.strategy}'.`);
        }
        if (req.strategy === 'MANUAL_OVERRIDE' && (!req.reason || req.reason.trim().length === 0)) {
          throw new BadRequestException('A reason is mandatory when performing a MANUAL_OVERRIDE allocation.');
        }

        chosenCar = await this.prisma.car.findUnique({
          where: { id: req.targetCarId },
          include: { pickupHub: true },
        });

        if (!chosenCar) {
          throw new NotFoundException(`Vehicle #${req.targetCarId} not found.`);
        }

        // Check if vehicle belongs to the booking's vendor
        if (chosenCar.vendorId !== booking.vendorId) {
          throw new BadRequestException('Cannot allocate a vehicle belonging to a different vendor.');
        }

        // Validate availability
        await this.availabilityService.assertVehicleAvailableForBooking(
          chosenCar.id,
          booking.startDate,
          booking.endDate,
          60,
          booking.id,
        );
      } else {
        // Dynamic Allocation Strategies: SAME_CLASS, AUTOMATIC, BRANCH_BASED
        chosenCar = await this.findOptimalVehicleCandidate({
          vendorId: booking.vendorId,
          branchId: targetHubId || undefined,
          targetClass: targetVehicleClass,
          startDate: booking.startDate,
          endDate: booking.endDate,
          excludeBookingId: booking.id,
          allowUpgrade: req.allowUpgrade,
        });

        if (!chosenCar) {
          throw new ConflictException(
            `No available vehicles found matching class ${targetVehicleClass} for the required time window.`,
          );
        }
      }

      // If already allocated to the exact same car, return idempotent success
      if (previousAllocation && previousAllocation.carId === chosenCar.id && previousAllocation.isActive) {
        return {
          success: true,
          bookingId: booking.id,
          allocatedCarId: chosenCar.id,
          vehicleRegistration: chosenCar.registrationNumber,
          vehicleModel: `${chosenCar.make} ${chosenCar.model}`,
          vehicleClass: chosenCar.type,
          strategy: req.strategy,
          allocationRecordId: previousAllocation.id,
          previousCarId,
          allocatedAt: previousAllocation.allocatedAt,
          message: 'Vehicle is already allocated to this booking.',
        };
      }

      // 3. Perform atomic allocation update in transaction
      const now = new Date();
      const isReassignment = !!previousAllocation && previousAllocation.carId !== chosenCar.id;

      const allocationRecord = await this.prisma.$transaction(async (tx) => {
        // Release old allocation record if active
        if (previousAllocation) {
          await tx.vehicleAllocationRecord.update({
            where: { id: previousAllocation.id },
            data: {
              isActive: false,
              releasedAt: now,
            },
          });
        }

        // Create new allocation record
        const record = await tx.vehicleAllocationRecord.create({
          data: {
            bookingId: booking.id,
            carId: chosenCar.id,
            strategy: req.strategy,
            reason: req.reason || (isReassignment ? 'Vehicle reassignment' : 'Initial fleet allocation'),
            allocatedBy: req.allocatedBy,
            allocatedByRole: req.allocatedByRole,
            isActive: true,
            allocatedAt: now,
            metadata: {
              previousCarId: isReassignment ? previousCarId : undefined,
              isUpgrade: chosenCar.type !== targetVehicleClass,
              originalClass: targetVehicleClass,
              allocatedClass: chosenCar.type,
            },
          },
        });

        // Update booking with allocated car and allocation status
        await tx.booking.update({
          where: { id: booking.id },
          data: {
            carId: chosenCar.id,
            allocationStatus: isReassignment ? 'REASSIGNED' : 'ALLOCATED',
            allocationStrategy: req.strategy,
            vehicleClass: chosenCar.type,
          },
        });

        return record;
      });

      this.logger.log(
        `[ALLOCATION] Booking #${booking.id} allocated vehicle #${chosenCar.id} (${chosenCar.registrationNumber}) using strategy ${req.strategy}`,
      );

      return {
        success: true,
        bookingId: booking.id,
        allocatedCarId: chosenCar.id,
        vehicleRegistration: chosenCar.registrationNumber,
        vehicleModel: `${chosenCar.make} ${chosenCar.model}`,
        vehicleClass: chosenCar.type,
        strategy: req.strategy,
        allocationRecordId: allocationRecord.id,
        previousCarId: isReassignment ? previousCarId : undefined,
        allocatedAt: now,
        message: isReassignment
          ? `Vehicle successfully reassigned from #${previousCarId} to #${chosenCar.id}.`
          : `Vehicle #${chosenCar.id} successfully allocated.`,
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * Retrieves chronological vehicle allocation history for a booking.
   */
  async getAllocationHistory(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });
    if (!booking) {
      throw new NotFoundException(`Booking #${bookingId} not found.`);
    }

    return this.prisma.vehicleAllocationRecord.findMany({
      where: { bookingId },
      include: {
        car: {
          select: {
            id: true,
            make: true,
            model: true,
            registrationNumber: true,
            type: true,
            pickupHubId: true,
          },
        },
      },
      orderBy: { allocatedAt: 'desc' },
    });
  }

  /**
   * Private candidate selector: Finds the highest-readiness available car in vendor fleet.
   */
  private async findOptimalVehicleCandidate(opts: {
    vendorId: string;
    branchId?: string;
    targetClass: CarCategory;
    startDate: Date;
    endDate: Date;
    excludeBookingId: string;
    allowUpgrade?: boolean;
  }): Promise<any> {
    const where: any = {
      vendorId: opts.vendorId,
      isAvailable: true,
      operationalStatus: { in: ['ACTIVE', 'AVAILABLE'] },
      type: opts.targetClass,
    };

    if (opts.branchId) {
      where.pickupHubId = opts.branchId;
    }

    let candidates = await this.prisma.car.findMany({
      where,
      include: { pickupHub: true },
    });

    // If no candidate at designated branch, try vendor-wide
    if (candidates.length === 0 && opts.branchId) {
      delete where.pickupHubId;
      candidates = await this.prisma.car.findMany({
        where,
        include: { pickupHub: true },
      });
    }

    // Filter by conflict-free availability
    for (const car of candidates) {
      const isFree = await this.availabilityService.isVehicleAvailable(
        car.id,
        { startDate: opts.startDate, endDate: opts.endDate },
        { bufferMinutes: 60, excludeBookingId: opts.excludeBookingId },
      );
      if (isFree) {
        return car;
      }
    }

    // If upgrade permitted, check higher classes
    if (opts.allowUpgrade) {
      const upgradeOrder: CarCategory[] = [
        CarCategory.HATCHBACK,
        CarCategory.SEDAN,
        CarCategory.SUV,
        CarCategory.LUXURY,
      ];
      const currentIdx = upgradeOrder.indexOf(opts.targetClass);
      if (currentIdx >= 0 && currentIdx < upgradeOrder.length - 1) {
        const nextClass = upgradeOrder[currentIdx + 1];
        return this.findOptimalVehicleCandidate({
          ...opts,
          targetClass: nextClass,
          allowUpgrade: false, // only 1 tier upgrade
        });
      }
    }

    return null;
  }
}
