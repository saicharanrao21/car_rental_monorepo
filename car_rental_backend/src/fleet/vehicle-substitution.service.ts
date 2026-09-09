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
import { VehicleAllocationService } from './vehicle-allocation.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  CarCategory,
  Role,
  BookingStatus,
  SubstitutionDecision,
  SubstitutionReason,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface EvaluateSubstitutionRequest {
  bookingId: string;
  reason: SubstitutionReason;
  reasonDetails?: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
  allowUpgrade?: boolean;
  maxBranchRadiusKm?: number;
}

export interface SubstitutionCandidate {
  carId: string;
  make: string;
  model: string;
  year: number;
  vehicleClass: CarCategory;
  registrationNumber: string;
  branchId?: string;
  branchName?: string;
  distanceKm: number;
  dailyRate: number;
  isUpgrade: boolean;
  score: number;
  matchType: 'EXACT_CLASS' | 'EQUIVALENT' | 'UPGRADE' | 'OTHER_BRANCH';
}

export interface SubstitutionEvaluationResult {
  bookingId: string;
  originalCarId: string;
  originalClass: CarCategory;
  recommendedDecision: SubstitutionDecision;
  reason: SubstitutionReason;
  bestCandidate: SubstitutionCandidate | null;
  allCandidates: SubstitutionCandidate[];
  priceDifference: number;
  requiresCustomerApproval: boolean;
  isFreeUpgrade: boolean;
  explanation: string;
}

export interface ExecuteSubstitutionRequest {
  bookingId: string;
  targetCarId?: string;
  decision: SubstitutionDecision;
  reason: SubstitutionReason;
  reasonDetails?: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
  customerApproved?: boolean;
  waivePriceDifference?: boolean;
}

@Injectable()
export class VehicleSubstitutionService {
  private readonly logger = new Logger(VehicleSubstitutionService.name);

  // Hierarchy of vehicle upgrades
  private readonly upgradeHierarchy: CarCategory[] = [
    CarCategory.HATCHBACK,
    CarCategory.SEDAN,
    CarCategory.SUV,
    CarCategory.LUXURY,
  ];

  constructor(
    private readonly prisma: PrismaService,
    private readonly availabilityService: FleetAvailabilityService,
    private readonly allocationService: VehicleAllocationService,
    private readonly bookingLockService: BookingLockService,
  ) {}

  /**
   * 1. EVALUATE SUBSTITUTION:
   * Scans candidate pool and deterministically selects best alternative with decision classification.
   */
  async evaluateSubstitution(req: EvaluateSubstitutionRequest): Promise<SubstitutionEvaluationResult> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: req.bookingId },
      include: {
        car: { include: { pickupHub: true } },
        vendor: true,
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
        `Cannot substitute vehicle for booking in terminal status '${booking.status}'.`,
      );
    }

    const originalCar = booking.car;
    const targetClass = (booking.vehicleClass as CarCategory) || originalCar.type;
    const homeBranchId = booking.pickupHubId || originalCar.pickupHubId;
    const allowUpgrade = req.allowUpgrade !== false;
    const maxRadius = req.maxBranchRadiusKm || 30;

    // 1. Fetch potential candidates from the same vendor
    const candidateCars = await this.prisma.car.findMany({
      where: {
        vendorId: booking.vendorId,
        id: { not: originalCar.id },
        isAvailable: true,
        operationalStatus: { in: ['ACTIVE', 'AVAILABLE'] as any },
      },
      include: { pickupHub: true },
    });

    const evaluatedCandidates: SubstitutionCandidate[] = [];

    for (const c of candidateCars) {
      // Check conflict-free availability
      const isFree = await this.availabilityService.isVehicleAvailable(
        c.id,
        { startDate: booking.startDate, endDate: booking.endDate },
        { bufferMinutes: 60, excludeBookingId: booking.id },
      );

      if (!isFree) continue;

      const isSameBranch = homeBranchId && c.pickupHubId === homeBranchId;
      const isSameClass = c.type === targetClass;
      const isUpgrade = this.isClassUpgrade(targetClass, c.type);

      // Distance estimation (0 if same hub, or estimated)
      const distanceKm = isSameBranch ? 0 : 10;
      if (distanceKm > maxRadius) continue;

      // Score computation:
      // Same Branch (+40), Exact Class (+40), Newer Model (+10), Free Upgrade (+20)
      let score = 0;
      let matchType: SubstitutionCandidate['matchType'] = 'EXACT_CLASS';

      if (isSameBranch && isSameClass) {
        score = 100 + (c.year - originalCar.year) * 2;
        matchType = 'EXACT_CLASS';
      } else if (isSameBranch && isUpgrade && allowUpgrade) {
        score = 85 + (c.year - originalCar.year);
        matchType = 'UPGRADE';
      } else if (!isSameBranch && isSameClass) {
        score = 70 - distanceKm;
        matchType = 'OTHER_BRANCH';
      } else if (!isSameBranch && isUpgrade && allowUpgrade) {
        score = 60 - distanceKm;
        matchType = 'UPGRADE';
      } else {
        continue;
      }

      evaluatedCandidates.push({
        carId: c.id,
        make: c.make,
        model: c.model,
        year: c.year,
        vehicleClass: c.type,
        registrationNumber: c.registrationNumber,
        branchId: c.pickupHubId || undefined,
        branchName: c.pickupHub?.name || undefined,
        distanceKm,
        dailyRate: Number(c.pricePerDay),
        isUpgrade,
        score,
        matchType,
      });
    }

    evaluatedCandidates.sort((a, b) => b.score - a.score);

    if (evaluatedCandidates.length === 0) {
      return {
        bookingId: booking.id,
        originalCarId: originalCar.id,
        originalClass: targetClass,
        recommendedDecision: SubstitutionDecision.NO_ALTERNATIVE,
        reason: req.reason,
        bestCandidate: null,
        allCandidates: [],
        priceDifference: 0,
        requiresCustomerApproval: false,
        isFreeUpgrade: false,
        explanation: 'No operational vehicles found matching criteria or upgrades across vendor fleet.',
      };
    }

    const best = evaluatedCandidates[0];
    let recommendedDecision: SubstitutionDecision;
    let requiresCustomerApproval = false;
    let isFreeUpgrade = false;

    if (best.matchType === 'EXACT_CLASS' && best.distanceKm === 0) {
      recommendedDecision = SubstitutionDecision.AUTO_SUBSTITUTE;
    } else if (best.isUpgrade) {
      recommendedDecision = SubstitutionDecision.UPGRADE_REQUIRED;
      isFreeUpgrade = true;
    } else if (best.matchType === 'OTHER_BRANCH') {
      recommendedDecision = SubstitutionDecision.CUSTOMER_APPROVAL_REQUIRED;
      requiresCustomerApproval = true;
    } else {
      recommendedDecision = SubstitutionDecision.MANUAL_SUBSTITUTE;
    }

    const originalDaily = Number(originalCar.pricePerDay);
    const priceDifference = Math.max(0, best.dailyRate - originalDaily);

    return {
      bookingId: booking.id,
      originalCarId: originalCar.id,
      originalClass: targetClass,
      recommendedDecision,
      reason: req.reason,
      bestCandidate: best,
      allCandidates: evaluatedCandidates,
      priceDifference: isFreeUpgrade ? 0 : priceDifference,
      requiresCustomerApproval,
      isFreeUpgrade,
      explanation: `Selected alternative #${best.carId} (${best.make} ${best.model}, ${best.vehicleClass}) via ${recommendedDecision}`,
    };
  }

  /**
   * 2. EXECUTE SUBSTITUTION:
   * Commits substitution, updates booking, reassigns allocation, and records immutable decision record.
   */
  async executeSubstitution(req: ExecuteSubstitutionRequest) {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);

    try {
      const evaluation = await this.evaluateSubstitution({
        bookingId: req.bookingId,
        reason: req.reason,
        reasonDetails: req.reasonDetails,
        actorId: req.actorId,
        actorRole: req.actorRole,
      });

      if (req.decision === SubstitutionDecision.NO_ALTERNATIVE || (!req.targetCarId && !evaluation.bestCandidate)) {
        throw new ConflictException(
          'Cannot execute substitution: No alternative vehicle available.',
        );
      }

      const targetCarId = req.targetCarId || evaluation.bestCandidate!.carId;
      const targetCar = await this.prisma.car.findUnique({
        where: { id: targetCarId },
      });

      if (!targetCar) {
        throw new NotFoundException(`Target vehicle #${targetCarId} not found.`);
      }

      const isUpgrade = this.isClassUpgrade(evaluation.originalClass, targetCar.type);
      const isFreeUpgrade = req.waivePriceDifference || isUpgrade || evaluation.isFreeUpgrade;

      // Reallocate vehicle using allocation service
      const allocationResult = await this.allocationService.allocateVehicle({
        bookingId: req.bookingId,
        targetCarId,
        strategy: 'MANUAL_OVERRIDE',
        reason: `Substituted from #${evaluation.originalCarId} due to ${req.reason}`,
        allocatedBy: req.actorId,
        allocatedByRole: req.actorRole === 'SYSTEM' ? Role.ADMIN : req.actorRole,
        allowUpgrade: true,
      });

      // Persist immutable substitution audit record
      const substitutionRecord = await this.prisma.vehicleSubstitutionRecord.create({
        data: {
          bookingId: req.bookingId,
          originalCarId: evaluation.originalCarId,
          substitutedCarId: targetCar.id,
          decision: req.decision,
          reason: req.reason,
          reasonDetails: req.reasonDetails,
          originalClass: evaluation.originalClass,
          substitutedClass: targetCar.type,
          priceDifference: new Decimal(isFreeUpgrade ? 0 : evaluation.priceDifference),
          isCustomerApproved: req.customerApproved ?? !evaluation.requiresCustomerApproval,
          isFreeUpgrade,
          authorizedBy: req.actorId,
          authorizedRole: req.actorRole === 'SYSTEM' ? Role.ADMIN : req.actorRole,
          metadata: {
            previousCarId: evaluation.originalCarId,
            newCarRegistration: targetCar.registrationNumber,
            allocationRecordId: allocationResult.allocationRecordId,
          },
        },
      });

      // Synchronize FulfillmentRecord if exists
      await this.prisma.fulfillmentRecord.updateMany({
        where: { bookingId: req.bookingId },
        data: {
          carId: targetCar.id,
          stage: 'ALLOCATED',
        },
      });

      this.logger.log(
        `[SUBSTITUTION-SUCCESS] Booking #${req.bookingId}: Car #${evaluation.originalCarId} substituted with #${targetCar.id} (${req.decision})`,
      );

      return {
        success: true,
        substitutionId: substitutionRecord.id,
        bookingId: req.bookingId,
        decision: req.decision,
        originalCarId: evaluation.originalCarId,
        substitutedCarId: targetCar.id,
        substitutedVehicle: `${targetCar.make} ${targetCar.model} (${targetCar.registrationNumber})`,
        vehicleClass: targetCar.type,
        isFreeUpgrade,
        priceDifference: isFreeUpgrade ? 0 : evaluation.priceDifference,
        allocation: allocationResult,
        message: `Vehicle successfully substituted to ${targetCar.make} ${targetCar.model}.`,
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  // Helper: Class upgrade check
  private isClassUpgrade(original: CarCategory, candidate: CarCategory): boolean {
    const origIdx = this.upgradeHierarchy.indexOf(original);
    const candIdx = this.upgradeHierarchy.indexOf(candidate);
    return origIdx >= 0 && candIdx > origIdx;
  }
}
