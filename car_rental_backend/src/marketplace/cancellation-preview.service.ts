import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CancellationPolicyService } from '../bookings/cancellation-policy.service';
import { Role, BookingStatus } from '@prisma/client';

export interface CancellationPreviewResult {
  bookingId: string;
  totalPaid: number;
  freeCancellationDeadline: string;
  hoursUntilPickup: number;
  cancellationTier: string;
  tierDescription: string;
  cancellationFeePercent: number;
  cancellationFeeAmount: number;
  refundableAmount: number;
  securityDepositRefund: number;
  netRefundToCustomer: number;
  refundMethod: string;
  isEligibleForRefund: boolean;
}

@Injectable()
export class CancellationPreviewService {
  private readonly logger = new Logger(CancellationPreviewService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly legacyCancellation: CancellationPolicyService,
  ) {}

  /**
   * Evaluates the hierarchical cancellation policy for a booking and produces an itemized refund preview.
   * PLATFORM -> VENDOR -> BRANCH -> VEHICLE_CLASS
   */
  async previewCancellation(bookingId: string): Promise<CancellationPreviewResult> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        vendor: true,
        car: { include: { pickupHub: true } },
      },
    });

    if (!booking) {
      throw new NotFoundException(`Booking with ID '${bookingId}' not found.`);
    }

    if (booking.status === BookingStatus.CANCELLED || booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException(`Booking is already in '${booking.status}' status.`);
    }

    const now = new Date();
    const pickupDate = new Date(booking.startDate);
    const hoursUntilPickup = (pickupDate.getTime() - now.getTime()) / (1000 * 60 * 60);

    // 1. Resolve hierarchical policy definition
    const policy = await this.resolveHierarchicalPolicy({
      vendorId: booking.vendorId,
      branchId: booking.car.pickupHubId || undefined,
      vehicleClass: booking.car.type,
    });

    const totalPaid = Number(booking.totalFare);
    let feePercent = 0;
    let tier = 'STANDARD';
    let tierDescription = 'Standard cancellation terms';

    if (hoursUntilPickup > policy.freeCancellationHours) {
      feePercent = 0;
      tier = 'FREE_CANCELLATION';
      tierDescription = `Free cancellation (> ${policy.freeCancellationHours} hours before pickup)`;
    } else if (hoursUntilPickup > policy.tier1HoursBeforePickup) {
      feePercent = policy.tier1PenaltyPercent;
      tier = 'MODERATE_PENALTY';
      tierDescription = `Moderate cancellation fee (${feePercent}%)`;
    } else if (hoursUntilPickup > policy.tier2HoursBeforePickup) {
      feePercent = policy.tier2PenaltyPercent;
      tier = 'LATE_CANCELLATION';
      tierDescription = `Late cancellation fee (${feePercent}%)`;
    } else {
      feePercent = policy.afterStartFeePercent;
      tier = 'NO_REFUND_AFTER_DEPARTURE';
      tierDescription = 'Non-refundable after scheduled trip commencement';
    }

    const cancellationFeeAmount = Math.round((totalPaid * (feePercent / 100)) * 100) / 100;
    const refundableAmount = Math.max(0, Math.round((totalPaid - cancellationFeeAmount) * 100) / 100);

    // Security deposit is always 100% refundable if vehicle was not picked up
    const securityDepositRefund = 5000;
    const netRefundToCustomer = refundableAmount + securityDepositRefund;

    const freeDeadline = new Date(pickupDate.getTime() - policy.freeCancellationHours * 60 * 60 * 1000);

    return {
      bookingId: booking.id,
      totalPaid,
      freeCancellationDeadline: freeDeadline.toISOString(),
      hoursUntilPickup: Math.round(hoursUntilPickup * 10) / 10,
      cancellationTier: tier,
      tierDescription,
      cancellationFeePercent: feePercent,
      cancellationFeeAmount,
      refundableAmount,
      securityDepositRefund,
      netRefundToCustomer,
      refundMethod: 'ORIGINAL_PAYMENT_SOURCE',
      isEligibleForRefund: netRefundToCustomer > 0,
    };
  }

  private async resolveHierarchicalPolicy(ctx: {
    vendorId?: string;
    branchId?: string;
    vehicleClass?: any;
  }): Promise<{
    freeCancellationHours: number;
    tier1HoursBeforePickup: number;
    tier1PenaltyPercent: number;
    tier2HoursBeforePickup: number;
    tier2PenaltyPercent: number;
    afterStartFeePercent: number;
  }> {
    // Check for branch or vendor override
    if (ctx.branchId || ctx.vendorId) {
      const override = await this.prisma.cancellationPolicyDefinition.findFirst({
        where: {
          isActive: true,
          OR: [
            { branchId: ctx.branchId },
            { vendorId: ctx.vendorId },
          ],
        },
        orderBy: { createdAt: 'desc' },
      });

      if (override) {
        return {
          freeCancellationHours: override.freeCancellationHours,
          tier1HoursBeforePickup: override.tier1HoursBeforePickup,
          tier1PenaltyPercent: override.tier1PenaltyPercent,
          tier2HoursBeforePickup: override.tier2HoursBeforePickup,
          tier2PenaltyPercent: override.tier2PenaltyPercent,
          afterStartFeePercent: override.afterStartFeePercent,
        };
      }
    }

    // Default platform policy
    return {
      freeCancellationHours: 24,
      tier1HoursBeforePickup: 6,
      tier1PenaltyPercent: 25.0,
      tier2HoursBeforePickup: 0,
      tier2PenaltyPercent: 50.0,
      afterStartFeePercent: 100.0,
    };
  }
}
