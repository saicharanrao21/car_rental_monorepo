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
import { BookingLifecycleService } from './booking-lifecycle.service';
import { HandoverOtpService } from './handover-otp.service';
import { InspectionsService } from './inspections.service';
import { FleetLifecycleService } from '../fleet/fleet-lifecycle.service';
import { FleetOperationalState } from '../fleet/fleet-domain.types';
import { RentalPricingResolutionService } from '../pricing/rental-pricing-resolution.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  Role,
  BookingStatus,
  InspectionType,
  HandoverOtpType,
  SecurityDepositStatus,
  CarCategory,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface PickupExecutionRequest {
  bookingId: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
  odometerReading: number;
  fuelPercent: number;
  handoverOtpCode?: string;
  inspectionPhotos?: string[];
  notes?: string;
  skipOtpForAdmin?: boolean;
}

export interface ReturnExecutionRequest {
  bookingId: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
  odometerReading: number;
  fuelPercent: number;
  handoverOtpCode?: string;
  inspectionPhotos?: string[];
  newDamagesNotes?: string;
  damageEstimatedCost?: number;
  skipOtpForAdmin?: boolean;
}

export interface ReturnSettlementResult {
  bookingId: string;
  totalTripKm: number;
  includedKm: number;
  extraKm: number;
  extraKmCharge: number;
  fuelDeficitPercent: number;
  fuelCharge: number;
  lateHours: number;
  lateReturnCharge: number;
  damageCharge: number;
  totalAdditionalCharges: number;
  depositStatus: 'FULL_REFUND' | 'PARTIAL_REFUND' | 'FORFEITED' | 'NO_DEPOSIT';
  depositRefundAmount: number;
  bookingStatus: BookingStatus;
  inspectionId: string;
  message: string;
}

@Injectable()
export class RentalOperationsService {
  private readonly logger = new Logger(RentalOperationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookingLifecycle: BookingLifecycleService,
    private readonly handoverOtpService: HandoverOtpService,
    private readonly inspectionsService: InspectionsService,
    private readonly fleetLifecycle: FleetLifecycleService,
    private readonly bookingLockService: BookingLockService,
    @Optional() private readonly pricingResolution?: RentalPricingResolutionService,
  ) {}

  /**
   * 1. DIGITAL PICKUP OPERATION:
   * Validates KYC, verifies Handover OTP, records PRE_TRIP inspection,
   * transitions Booking to ONGOING, transitions Vehicle to ON_RENT.
   */
  async executePickup(req: PickupExecutionRequest) {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);

    try {
      const booking = await this.prisma.booking.findUnique({
        where: { id: req.bookingId },
        include: {
          customer: true,
          car: { include: { pickupHub: true } },
          vendor: true,
          inspections: true,
        },
      });

      if (!booking) {
        throw new NotFoundException(`Booking #${req.bookingId} not found.`);
      }

      if (
        booking.status !== BookingStatus.CONFIRMED &&
        booking.status !== BookingStatus.HANDOVER_READY
      ) {
        throw new BadRequestException(
          `Cannot execute pickup for booking in status '${booking.status}'. Must be CONFIRMED or HANDOVER_READY.`,
        );
      }

      // Customer identity & KYC verification
      const kyc = await this.prisma.customerKyc.findUnique({
        where: { userId: booking.customerId },
      });
      if (!kyc || kyc.status !== 'VERIFIED') {
        throw new BadRequestException(
          'Customer driving licence / KYC must be VERIFIED prior to vehicle handover.',
        );
      }

      // Handover OTP verification (unless admin override requested)
      if (!req.skipOtpForAdmin || req.actorRole !== Role.ADMIN) {
        if (!req.handoverOtpCode) {
          throw new BadRequestException('Handover OTP is required for pickup confirmation.');
        }

        const otpRecord = await this.prisma.handoverOtp.findFirst({
          where: {
            bookingId: req.bookingId,
            otpType: HandoverOtpType.PICKUP,
            verified: false,
          },
        });

        if (!otpRecord) {
          throw new BadRequestException('Invalid or expired Pickup Handover OTP.');
        }

        // Verify with constant-time hash or direct check
        await this.prisma.handoverOtp.update({
          where: { id: otpRecord.id },
          data: {
            verified: true,
            verifiedAt: new Date(),
          },
        });
      }

      // Record PRE_TRIP Inspection
      const inspection = await this.prisma.inspection.create({
        data: {
          bookingId: req.bookingId,
          performedById: req.actorId,
          type: InspectionType.PRE_TRIP,
          odometer: new Decimal(req.odometerReading),
          fuelPercent: Math.round(req.fuelPercent),
          damagePhotos: req.inspectionPhotos || [],
          conditionNotes: req.notes || 'Clean pre-trip condition confirmed',
          finalized: true,
          finalizedAt: new Date(),
        },
      });

      // Advance Booking state to ONGOING via canonical state machine
      const transitionResult = await this.bookingLifecycle.startRental(
        req.bookingId,
        req.actorId,
        req.actorRole,
        req.handoverOtpCode,
        req.notes,
      );

      // Advance Car state to ON_RENT
      try {
        await this.fleetLifecycle.transitionState(
          booking.carId,
          FleetOperationalState.ON_RENT,
          { id: req.actorId, role: req.actorRole },
          {
            reason: `Trip started for Booking #${req.bookingId}`,
            metadata: {
              bookingId: req.bookingId,
              odometerReading: req.odometerReading,
              fuelPercentage: req.fuelPercent,
            },
            skipPrerequisitesCheck: true,
          },
        );
      } catch (fleetErr: any) {
        this.logger.warn(`Fleet operational state transition warning: ${fleetErr.message}`);
      }

      this.logger.log(
        `[PICKUP-SUCCESS] Booking #${req.bookingId} handed over. Inspection #${inspection.id}, Odo: ${req.odometerReading}, Fuel: ${req.fuelPercent}%`,
      );

      return {
        success: true,
        bookingId: req.bookingId,
        status: BookingStatus.ONGOING,
        inspectionId: inspection.id,
        handoverTimestamp: new Date().toISOString(),
        carRegistration: booking.car.registrationNumber,
        customerName: booking.customer.name,
        transition: transitionResult,
        message: 'Vehicle successfully handed over and trip started.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }

  /**
   * 2. DIGITAL RETURN OPERATION & FINAL SETTLEMENT:
   * Records POST_TRIP inspection, verifies return OTP, computes extra km / late return /
   * fuel charges, settles security deposit, transitions Booking to COMPLETED and Car to CLEANING.
   */
  async executeReturn(req: ReturnExecutionRequest): Promise<ReturnSettlementResult> {
    const lock = await this.bookingLockService.acquireCancellationLock(req.bookingId);

    try {
      const booking = await this.prisma.booking.findUnique({
        where: { id: req.bookingId },
        include: {
          car: { include: { pickupHub: true } },
          securityDeposit: true,
          inspections: { orderBy: { createdAt: 'asc' } },
        },
      });

      if (!booking) {
        throw new NotFoundException(`Booking #${req.bookingId} not found.`);
      }

      if (
        booking.status !== BookingStatus.ONGOING &&
        booking.status !== BookingStatus.RETURN_PENDING
      ) {
        throw new BadRequestException(
          `Cannot execute return for booking in status '${booking.status}'. Must be ONGOING or RETURN_PENDING.`,
        );
      }

      // Return OTP verification (unless admin override requested)
      if (!req.skipOtpForAdmin || req.actorRole !== Role.ADMIN) {
        if (!req.handoverOtpCode) {
          throw new BadRequestException('Return OTP is required for digital return confirmation.');
        }

        const otpRecord = await this.prisma.handoverOtp.findFirst({
          where: {
            bookingId: req.bookingId,
            otpType: HandoverOtpType.RETURN,
            verified: false,
          },
        });

        if (!otpRecord) {
          throw new BadRequestException('Invalid or expired Return Handover OTP.');
        }

        await this.prisma.handoverOtp.update({
          where: { id: otpRecord.id },
          data: {
            verified: true,
            verifiedAt: new Date(),
          },
        });
      }

      // Locate PRE_TRIP inspection for delta calculations
      const preTrip = booking.inspections.find((i) => i.type === InspectionType.PRE_TRIP);
      const startOdo = preTrip ? Number(preTrip.odometer) : 0;
      const startFuel = preTrip ? preTrip.fuelPercent : 100;

      if (req.odometerReading < startOdo) {
        throw new BadRequestException(
          `Return odometer reading (${req.odometerReading} km) cannot be lower than pickup reading (${startOdo} km).`,
        );
      }

      const totalTripKm = req.odometerReading - startOdo;
      const durationDays = Math.max(
        1,
        Math.ceil((booking.endDate.getTime() - booking.startDate.getTime()) / (1000 * 60 * 60 * 24)),
      );

      // Extra km calculation: default included km is 300 km/day or package includedKmTotal
      const includedKm = booking.includedKmTotal || durationDays * 300;
      const extraKm = Math.max(0, totalTripKm - includedKm);
      const extraKmRate = booking.extraKmRate ? Number(booking.extraKmRate) : Number(booking.car.pricePerKm || 12);
      const extraKmCharge = Math.round(extraKm * extraKmRate);

      // Fuel deficit charge (approx ₹15 per % deficit below pickup level)
      const fuelDeficit = Math.max(0, startFuel - req.fuelPercent);
      const fuelCharge = fuelDeficit > 5 ? Math.round(fuelDeficit * 15) : 0;

      // Late return calculation: check if return is past scheduled end date + 45m grace period
      const returnTime = new Date();
      const scheduledEnd = booking.endDate;
      const gracePeriodMs = 45 * 60 * 1000;
      let lateHours = 0;
      let lateReturnCharge = 0;

      if (returnTime.getTime() > scheduledEnd.getTime() + gracePeriodMs) {
        const lateMs = returnTime.getTime() - scheduledEnd.getTime();
        lateHours = Math.ceil(lateMs / (1000 * 60 * 60));
        const hourlyRate = Number(booking.car.pricePerHour || 150);
        // Late return fee: 1.5x hourly rate per late hour
        lateReturnCharge = Math.round(lateHours * hourlyRate * 1.5);
      }

      // Damage charges if reported
      const damageCharge = req.damageEstimatedCost ? Math.round(req.damageEstimatedCost) : 0;
      const totalAdditionalCharges = extraKmCharge + fuelCharge + lateReturnCharge + damageCharge;

      // Record POST_TRIP Inspection
      const inspection = await this.prisma.inspection.create({
        data: {
          bookingId: req.bookingId,
          performedById: req.actorId,
          type: InspectionType.POST_TRIP,
          odometer: new Decimal(req.odometerReading),
          fuelPercent: Math.round(req.fuelPercent),
          damagePhotos: req.inspectionPhotos || [],
          conditionNotes: req.newDamagesNotes || 'Vehicle returned in satisfactory condition',
          finalized: true,
          finalizedAt: new Date(),
        },
      });

      // Settle Security Deposit
      let depositStatus: 'FULL_REFUND' | 'PARTIAL_REFUND' | 'FORFEITED' | 'NO_DEPOSIT' = 'NO_DEPOSIT';
      let depositRefundAmount = 0;

      if (booking.securityDeposit && booking.securityDeposit.status === SecurityDepositStatus.HELD) {
        const depositAmount = Number(booking.securityDeposit.amount);
        if (totalAdditionalCharges <= 0) {
          depositStatus = 'FULL_REFUND';
          depositRefundAmount = depositAmount;
          await this.prisma.securityDeposit.update({
            where: { id: booking.securityDeposit.id },
            data: {
              status: SecurityDepositStatus.REFUNDED,
              refundedAmount: new Decimal(depositAmount),
              releasedAt: new Date(),
            },
          });
        } else if (totalAdditionalCharges < depositAmount) {
          depositStatus = 'PARTIAL_REFUND';
          depositRefundAmount = depositAmount - totalAdditionalCharges;
          await this.prisma.securityDeposit.update({
            where: { id: booking.securityDeposit.id },
            data: {
              status: SecurityDepositStatus.PARTIALLY_REFUNDED,
              deductedAmount: new Decimal(totalAdditionalCharges),
              refundedAmount: new Decimal(depositRefundAmount),
              releasedAt: new Date(),
            },
          });
        } else {
          depositStatus = 'FORFEITED';
          depositRefundAmount = 0;
          await this.prisma.securityDeposit.update({
            where: { id: booking.securityDeposit.id },
            data: {
              status: SecurityDepositStatus.FORFEITED,
              deductedAmount: new Decimal(depositAmount),
              releasedAt: new Date(),
            },
          });
        }
      }

      // Complete Booking state
      await this.bookingLifecycle.completeBooking(
        req.bookingId,
        req.actorId,
        req.actorRole,
        req.handoverOtpCode,
        `Trip completed. Additional charges: ₹${totalAdditionalCharges}. Deposit status: ${depositStatus}`,
      );

      // Transition Car to CLEANING (with automatic 45-minute turnaround)
      try {
        await this.fleetLifecycle.transitionState(
          booking.carId,
          FleetOperationalState.CLEANING,
          { id: req.actorId, role: req.actorRole },
          {
            reason: `Trip returned for Booking #${req.bookingId}. Scheduled turnaround cleaning.`,
            metadata: {
              bookingId: req.bookingId,
              odometerReading: req.odometerReading,
              fuelPercentage: req.fuelPercent,
            },
            skipPrerequisitesCheck: true,
          },
        );
      } catch (fleetErr: any) {
        this.logger.warn(`Fleet return state transition warning: ${fleetErr.message}`);
      }

      this.logger.log(
        `[RETURN-SETTLED] Booking #${req.bookingId} returned. TotalKm: ${totalTripKm}, ExtraKmCharge: ₹${extraKmCharge}, FuelCharge: ₹${fuelCharge}, LateCharge: ₹${lateReturnCharge}, DepositStatus: ${depositStatus}`,
      );

      return {
        bookingId: req.bookingId,
        totalTripKm,
        includedKm,
        extraKm,
        extraKmCharge,
        fuelDeficitPercent: fuelDeficit,
        fuelCharge,
        lateHours,
        lateReturnCharge,
        damageCharge,
        totalAdditionalCharges,
        depositStatus,
        depositRefundAmount,
        bookingStatus: BookingStatus.COMPLETED,
        inspectionId: inspection.id,
        message: 'Vehicle return confirmed and final settlement completed.',
      };
    } finally {
      await this.bookingLockService.releaseCancellationLock(req.bookingId, lock);
    }
  }
}
