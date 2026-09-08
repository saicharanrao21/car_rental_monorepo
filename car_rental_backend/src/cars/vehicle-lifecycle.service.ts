import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { REDIS_NAMESPACES } from '../redis/redis-namespace.constants';
import { VehicleOperationalStatus, Role } from '@prisma/client';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';

export interface LifecycleActor {
  id: string;
  role: Role;
  vendorId?: string;
}

export interface TransitionOptions {
  reason?: string;
  metadata?: Record<string, any>;
  skipEligibilityCheck?: boolean; // Admin override if explicitly needed
}

@Injectable()
export class VehicleLifecycleService {
  private readonly logger = new Logger(VehicleLifecycleService.name);

  // Transition matrix defining valid (fromStatus -> allowed toStatus set)
  private readonly allowedTransitions: Record<VehicleOperationalStatus, VehicleOperationalStatus[]> = {
    [VehicleOperationalStatus.DRAFT]: [
      VehicleOperationalStatus.PENDING_VERIFICATION,
      VehicleOperationalStatus.ACTIVE,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.PENDING_VERIFICATION]: [
      VehicleOperationalStatus.ACTIVE,
      VehicleOperationalStatus.INACTIVE,
      VehicleOperationalStatus.DRAFT,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.ACTIVE]: [
      VehicleOperationalStatus.INACTIVE,
      VehicleOperationalStatus.MAINTENANCE,
      VehicleOperationalStatus.SUSPENDED,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.INACTIVE]: [
      VehicleOperationalStatus.ACTIVE,
      VehicleOperationalStatus.MAINTENANCE,
      VehicleOperationalStatus.SUSPENDED,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.MAINTENANCE]: [
      VehicleOperationalStatus.ACTIVE,
      VehicleOperationalStatus.INACTIVE,
      VehicleOperationalStatus.SUSPENDED,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.SUSPENDED]: [
      VehicleOperationalStatus.ACTIVE,
      VehicleOperationalStatus.INACTIVE,
      VehicleOperationalStatus.RETIRED,
    ],
    [VehicleOperationalStatus.RETIRED]: [], // Terminal state
  };

  constructor(
    private readonly prisma: PrismaService,
    private readonly eligibilityService: VehicleOperationsEligibilityService,
    @Optional() private readonly bookingLockService?: BookingLockService,
    @Optional() private readonly cacheService?: RedisCacheService,
  ) {}

  /**
   * Validates if a lifecycle transition from one status to another is permitted.
   */
  isValidTransition(from: VehicleOperationalStatus, to: VehicleOperationalStatus): boolean {
    if (from === to) return true;
    const allowed = this.allowedTransitions[from];
    return !!allowed && allowed.includes(to);
  }

  /**
   * Transitions a vehicle from its current operational status to a new target status.
   * Performs transition validity checks, actor permission checks, server-authoritative
   * eligibility verification, transactional audit logging, and cache invalidations.
   */
  async transitionStatus(
    carId: string,
    targetStatus: VehicleOperationalStatus,
    actor: LifecycleActor,
    options?: TransitionOptions,
  ) {
    let lockToken: string | null = null;

    if (this.bookingLockService) {
      lockToken = await this.bookingLockService.acquireLock(carId, 5000);
      if (!lockToken) {
        throw new BadRequestException('Vehicle lifecycle update in progress. Please retry.');
      }
    }

    try {
      const car = await this.prisma.car.findUnique({
        where: { id: carId },
        include: { vendor: true },
      });

      if (!car) {
        throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
      }

      // Check ownership if actor is vendor
      if (actor.role === Role.VENDOR) {
        if (actor.vendorId && car.vendorId !== actor.vendorId) {
          throw new ForbiddenException('You do not have permission to modify this vehicle.');
        }
      }

      const currentStatus = car.operationalStatus;

      // Idempotent: If already in target status, return current car
      if (currentStatus === targetStatus) {
        return car;
      }

      // Check transition validity against transition matrix
      if (!this.isValidTransition(currentStatus, targetStatus)) {
        throw new BadRequestException(
          `Illegal lifecycle transition: Cannot move vehicle from '${currentStatus}' to '${targetStatus}'.`,
        );
      }

      // Role authorization boundaries
      const isAdmin = actor.role === Role.ADMIN || actor.role === Role.SUPPORT_AGENT;

      // Admin-only transitions:
      // 1. Moving out of SUSPENDED requires ADMIN
      if (currentStatus === VehicleOperationalStatus.SUSPENDED && !isAdmin) {
        throw new ForbiddenException('Only platform administrators can lift a vehicle suspension.');
      }

      // 2. Moving into SUSPENDED or RETIRED requires ADMIN
      if (
        (targetStatus === VehicleOperationalStatus.SUSPENDED ||
          targetStatus === VehicleOperationalStatus.RETIRED) &&
        !isAdmin
      ) {
        throw new ForbiddenException('Only platform administrators can suspend or retire a vehicle.');
      }

      // 3. Activating directly from DRAFT or PENDING_VERIFICATION requires ADMIN
      if (
        (currentStatus === VehicleOperationalStatus.DRAFT ||
          currentStatus === VehicleOperationalStatus.PENDING_VERIFICATION) &&
        targetStatus === VehicleOperationalStatus.ACTIVE &&
        !isAdmin
      ) {
        throw new ForbiddenException(
          'Vehicle verification and initial activation must be approved by platform administration.',
        );
      }

      // Server-authoritative activation eligibility check
      if (targetStatus === VehicleOperationalStatus.ACTIVE && !options?.skipEligibilityCheck) {
        const eligibility = await this.eligibilityService.evaluateEligibility(carId, {
          skipCache: true,
        });

        if (!eligibility.eligible) {
          const blockerMessages = eligibility.blockers
            .filter((b) => b.severity === 'BLOCKER')
            .map((b) => b.message)
            .join(' | ');
          throw new BadRequestException(
            `Vehicle activation rejected by operational readiness engine: ${blockerMessages}`,
          );
        }
      }

      // Execute status update and audit log in a transaction
      const updatedCar = await this.prisma.$transaction(async (tx) => {
        const updated = await tx.car.update({
          where: { id: carId },
          data: {
            operationalStatus: targetStatus,
            // Synchronize legacy isAvailable boolean
            isAvailable: targetStatus === VehicleOperationalStatus.ACTIVE,
            ...(targetStatus === VehicleOperationalStatus.ACTIVE
              ? {
                  maintenanceReason: null,
                  maintenanceStartedAt: null,
                  expectedReturnDate: null,
                }
              : {}),
          },
        });

        await tx.vehicleAuditLog.create({
          data: {
            carId,
            actorId: actor.id,
            actorRole: actor.role,
            action: `TRANSITION_${targetStatus}`,
            fromStatus: currentStatus,
            toStatus: targetStatus,
            reason: options?.reason || null,
            metadata: options?.metadata ? (options.metadata as any) : undefined,
          },
        });

        return updated;
      });

      // Invalidate relevant Redis caches
      await this.invalidateCaches(carId, car.vendorId);

      this.logger.log(
        `Vehicle ${carId} transitioned from ${currentStatus} to ${targetStatus} by ${actor.role} (${actor.id})`,
      );

      return updatedCar;
    } finally {
      if (this.bookingLockService && lockToken) {
        await this.bookingLockService.releaseLock(carId, lockToken);
      }
    }
  }

  /**
   * Invalidates all caches associated with this vehicle and vendor fleet.
   */
  async invalidateCaches(carId: string, vendorId: string): Promise<void> {
    await this.eligibilityService.invalidateEligibilityCache(carId);

    if (this.cacheService) {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.CAR_DETAIL(carId));
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_FLEET(vendorId));
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.FLEET_KPI());
    }
  }
}
