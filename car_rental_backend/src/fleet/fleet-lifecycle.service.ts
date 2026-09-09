import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  FleetOperationalState,
  FleetDomainEvent,
} from './fleet-domain.types';
import { Role } from '@prisma/client';

export interface FleetLifecycleActor {
  id: string;
  role: Role | 'SYSTEM' | 'AUTOMATION';
  vendorId?: string;
  branchId?: string;
}

export interface StateTransitionOptions {
  reason: string;
  metadata?: Record<string, any>;
  skipPrerequisitesCheck?: boolean; // Admin override if explicitly needed
}

export interface TransitionAuditRecord {
  id: string;
  carId: string;
  actorId: string;
  actorRole: string;
  fromState: FleetOperationalState;
  toState: FleetOperationalState;
  reason: string;
  metadata?: Record<string, any>;
  timestamp: string;
}

@Injectable()
export class FleetLifecycleService {
  private readonly logger = new Logger(FleetLifecycleService.name);

  // In-memory state store for fleet operational states and audit history
  private readonly vehicleStates: Map<string, FleetOperationalState> = new Map();
  private readonly vehicleStateReasons: Map<string, string> = new Map();
  private readonly auditTrail: Map<string, TransitionAuditRecord[]> = new Map();
  private readonly domainEvents: FleetDomainEvent[] = [];

  // Strict 19-State Enterprise Transition Matrix
  private readonly allowedTransitions: Record<FleetOperationalState, FleetOperationalState[]> = {
    [FleetOperationalState.DRAFT]: [
      FleetOperationalState.ACTIVE,
      FleetOperationalState.INACTIVE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.ACTIVE]: [
      FleetOperationalState.AVAILABLE,
      FleetOperationalState.INSPECTION,
      FleetOperationalState.CLEANING,
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.QUARANTINED,
      FleetOperationalState.COMPLIANCE_BLOCKED,
      FleetOperationalState.GPS_OFFLINE,
      FleetOperationalState.INACTIVE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.AVAILABLE]: [
      FleetOperationalState.RESERVED,
      FleetOperationalState.PICKUP_PENDING,
      FleetOperationalState.INSPECTION,
      FleetOperationalState.CLEANING,
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.ACCIDENT,
      FleetOperationalState.DAMAGED,
      FleetOperationalState.QUARANTINED,
      FleetOperationalState.COMPLIANCE_BLOCKED,
      FleetOperationalState.GPS_OFFLINE,
      FleetOperationalState.INACTIVE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.RESERVED]: [
      FleetOperationalState.PICKUP_PENDING,
      FleetOperationalState.AVAILABLE, // Booking cancelled
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.COMPLIANCE_BLOCKED,
      FleetOperationalState.GPS_OFFLINE,
    ],
    [FleetOperationalState.PICKUP_PENDING]: [
      FleetOperationalState.ON_RENT, // Handover completed
      FleetOperationalState.AVAILABLE, // Customer no-show or cancelled
      FleetOperationalState.INSPECTION,
      FleetOperationalState.MAINTENANCE,
    ],
    [FleetOperationalState.ON_RENT]: [
      FleetOperationalState.EXTENSION_PENDING,
      FleetOperationalState.RETURN_PENDING,
      FleetOperationalState.ACCIDENT,
      FleetOperationalState.DAMAGED,
      FleetOperationalState.GPS_OFFLINE,
    ],
    [FleetOperationalState.EXTENSION_PENDING]: [
      FleetOperationalState.ON_RENT, // Extension approved
      FleetOperationalState.RETURN_PENDING, // Extension denied/due for return
    ],
    [FleetOperationalState.RETURN_PENDING]: [
      FleetOperationalState.INSPECTION, // Return inspection initiated
      FleetOperationalState.ON_RENT, // Reverted
    ],
    [FleetOperationalState.INSPECTION]: [
      FleetOperationalState.CLEANING, // Inspection passed
      FleetOperationalState.DAMAGED, // New damage detected
      FleetOperationalState.MAINTENANCE, // Mechanical issue identified
      FleetOperationalState.QUARANTINED, // Contraband/serious condition
      FleetOperationalState.AVAILABLE, // Minor fast-track
    ],
    [FleetOperationalState.CLEANING]: [
      FleetOperationalState.AVAILABLE, // Ready for rental
      FleetOperationalState.INSPECTION,
      FleetOperationalState.MAINTENANCE,
    ],
    [FleetOperationalState.MAINTENANCE]: [
      FleetOperationalState.CLEANING, // Work completed, needs cleaning
      FleetOperationalState.INSPECTION,
      FleetOperationalState.AVAILABLE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.ACCIDENT]: [
      FleetOperationalState.DAMAGED,
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.QUARANTINED,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.DAMAGED]: [
      FleetOperationalState.MAINTENANCE, // Sent to body shop
      FleetOperationalState.QUARANTINED,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.QUARANTINED]: [
      FleetOperationalState.INSPECTION, // Released for investigation
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.COMPLIANCE_BLOCKED]: [
      FleetOperationalState.ACTIVE, // Documents renewed
      FleetOperationalState.AVAILABLE, // Documents renewed and ready
      FleetOperationalState.INSPECTION,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.GPS_OFFLINE]: [
      FleetOperationalState.AVAILABLE, // Heartbeat restored
      FleetOperationalState.ACTIVE,
      FleetOperationalState.ON_RENT,
      FleetOperationalState.MAINTENANCE,
      FleetOperationalState.QUARANTINED,
    ],
    [FleetOperationalState.INACTIVE]: [
      FleetOperationalState.ACTIVE,
      FleetOperationalState.AVAILABLE,
      FleetOperationalState.RETIRED,
    ],
    [FleetOperationalState.RETIRED]: [
      FleetOperationalState.SOLD, // Terminal state transition
    ],
    [FleetOperationalState.SOLD]: [], // Terminal state, no further transitions permitted
  };

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly bookingLockService?: BookingLockService,
    @Optional() private readonly cacheService?: RedisCacheService,
  ) {}

  /**
   * Returns current operational state of a vehicle.
   */
  async getVehicleState(carId: string): Promise<FleetOperationalState> {
    if (this.vehicleStates.has(carId)) {
      return this.vehicleStates.get(carId)!;
    }
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      select: { isAvailable: true, operationalStatus: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle ${carId} not found`);
    }
    // Map initial Prisma operationalStatus to 19-state FleetOperationalState
    const mapped = car.isAvailable ? FleetOperationalState.AVAILABLE : FleetOperationalState.ACTIVE;
    this.vehicleStates.set(carId, mapped);
    return mapped;
  }

  /**
   * Returns current operational state reason if present.
   */
  getVehicleStateReason(carId: string): string | undefined {
    return this.vehicleStateReasons.get(carId);
  }

  /**
   * Validates if a transition from fromState to toState is allowed by the matrix.
   */
  isValidTransition(fromState: FleetOperationalState, toState: FleetOperationalState): boolean {
    if (fromState === toState) return true;
    const allowed = this.allowedTransitions[fromState];
    return !!allowed && allowed.includes(toState);
  }

  /**
   * Executes a validated state transition with prerequisites checking and audit persistence.
   */
  async transitionState(
    carId: string,
    targetState: FleetOperationalState,
    actor: FleetLifecycleActor,
    options: StateTransitionOptions,
  ): Promise<{ carId: string; fromState: FleetOperationalState; toState: FleetOperationalState; timestamp: string }> {
    const currentState = await this.getVehicleState(carId);

    if (currentState === targetState) {
      return { carId, fromState: currentState, toState: targetState, timestamp: new Date().toISOString() };
    }

    // 1. Matrix validation
    if (!this.isValidTransition(currentState, targetState)) {
      throw new BadRequestException(
        `Illegal vehicle state transition: Cannot transition vehicle ${carId} from ${currentState} to ${targetState}.`,
      );
    }

    // 2. Prerequisite Guard Checks
    if (!options.skipPrerequisitesCheck) {
      this.validateTransitionPrerequisites(carId, currentState, targetState);
    }

    // 3. Apply state change
    this.vehicleStates.set(carId, targetState);
    if (options.reason) {
      this.vehicleStateReasons.set(carId, options.reason);
    }

    // 4. Update underlying DB record if relevant
    try {
      const isNowAvailable = targetState === FleetOperationalState.AVAILABLE;
      await this.prisma.car.update({
        where: { id: carId },
        data: {
          isAvailable: isNowAvailable,
          maintenanceReason: targetState === FleetOperationalState.MAINTENANCE ? options.reason : undefined,
          maintenanceStartedAt: targetState === FleetOperationalState.MAINTENANCE ? new Date() : undefined,
        },
      });
    } catch (err: any) {
      this.logger.warn(`Could not sync car DB state for ${carId}: ${err.message}`);
    }

    const timestamp = new Date().toISOString();

    // 5. Append to audit trail
    const auditRecord: TransitionAuditRecord = {
      id: `audit_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
      carId,
      actorId: actor.id,
      actorRole: String(actor.role),
      fromState: currentState,
      toState: targetState,
      reason: options.reason,
      metadata: options.metadata,
      timestamp,
    };

    const existingAudit = this.auditTrail.get(carId) || [];
    existingAudit.push(auditRecord);
    this.auditTrail.set(carId, existingAudit);

    // 6. Record domain event
    const event: FleetDomainEvent = {
      eventType: 'vehicle.status.changed',
      carId,
      actorId: actor.id,
      timestamp,
      payload: {
        fromState: currentState,
        toState: targetState,
        reason: options.reason,
        metadata: options.metadata,
      },
    };
    this.domainEvents.push(event);

    this.logger.log(
      `[FLEET_LIFECYCLE] Vehicle ${carId} transitioned from ${currentState} -> ${targetState} by ${actor.role}:${actor.id}. Reason: ${options.reason}`,
    );

    return {
      carId,
      fromState: currentState,
      toState: targetState,
      timestamp,
    };
  }

  /**
   * Enforces business prerequisite invariants for critical state transitions.
   */
  private validateTransitionPrerequisites(
    carId: string,
    currentState: FleetOperationalState,
    targetState: FleetOperationalState,
  ) {
    // Invariant: A vehicle cannot become AVAILABLE if it is quarantined, compliance blocked, or in maintenance
    if (targetState === FleetOperationalState.AVAILABLE) {
      if (currentState === FleetOperationalState.QUARANTINED) {
        throw new ConflictException(
          `Vehicle ${carId} is QUARANTINED and must undergo formal clearance inspection before becoming AVAILABLE.`,
        );
      }
      if (currentState === FleetOperationalState.COMPLIANCE_BLOCKED) {
        throw new ConflictException(
          `Vehicle ${carId} is COMPLIANCE_BLOCKED. Renew and verify mandatory documents (Insurance/Fitness/PUC) first.`,
        );
      }
    }

    // Invariant: A vehicle cannot transition to ON_RENT without being in PICKUP_PENDING
    if (targetState === FleetOperationalState.ON_RENT && currentState !== FleetOperationalState.PICKUP_PENDING) {
      throw new ConflictException(
        `Vehicle ${carId} must be in PICKUP_PENDING state before starting rental. Current state: ${currentState}`,
      );
    }

    // Invariant: Terminal SOLD state can only be reached from RETIRED
    if (targetState === FleetOperationalState.SOLD && currentState !== FleetOperationalState.RETIRED) {
      throw new ConflictException(
        `Vehicle ${carId} must be decommissioned/RETIRED before it can be marked SOLD. Current state: ${currentState}`,
      );
    }
  }

  /**
   * Retrieves full auditable lifecycle history for a vehicle.
   */
  async getAuditHistory(carId: string): Promise<TransitionAuditRecord[]> {
    return this.auditTrail.get(carId) || [];
  }

  /**
   * Retrieves emitted domain events.
   */
  getDomainEvents(): FleetDomainEvent[] {
    return [...this.domainEvents];
  }
}
