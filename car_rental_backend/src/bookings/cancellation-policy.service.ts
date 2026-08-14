import { Injectable } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface CancellationCalculationResult {
  tier: string;
  tierDescription: string;
  startDate: Date;
  cancellationTime: Date;
  hoursRemaining: number;
  amountPaid: Decimal;
  cancellationFeePercent: number;
  cancellationFee: Decimal;
  refundAmountPercent: number;
  refundAmount: Decimal;
  refundAmountInPaise: number;
  isEligibleForRefund: boolean;
}

export interface CalculateCancellationParams {
  startDate: Date;
  cancellationTime?: Date;
  amountPaid: Decimal | number;
  actorRole: Role;
  isAdminOverride?: boolean;
}

@Injectable()
export class CancellationPolicyService {
  /**
   * Pure deterministic calculation of cancellation fee and refund amounts
   * based on the authoritative DriveGo cancellation policy.
   */
  calculateCancellation(
    params: CalculateCancellationParams,
  ): CancellationCalculationResult {
    const {
      startDate,
      cancellationTime = new Date(),
      actorRole,
      isAdminOverride = false,
    } = params;

    const paidDecimal =
      params.amountPaid instanceof Decimal
        ? params.amountPaid
        : new Decimal(params.amountPaid);

    const paidNumber = paidDecimal.toNumber();

    // Calculate hours remaining before trip pickup
    const diffMs = startDate.getTime() - cancellationTime.getTime();
    const hoursRemaining = Number((diffMs / (1000 * 60 * 60)).toFixed(2));

    let tier: string;
    let tierDescription: string;
    let feePercent: number;
    let refundPercent: number;

    // 1. Vendor Cancellation / Rejection -> Always 100% Refund
    if (actorRole === Role.VENDOR) {
      tier = 'VENDOR_CANCELLED';
      tierDescription = 'Cancelled or rejected by fleet owner (100% refund)';
      feePercent = 0;
      refundPercent = 100;
    }
    // 2. Admin Override -> 100% Refund
    else if (actorRole === Role.ADMIN && isAdminOverride) {
      tier = 'ADMIN_OVERRIDE_FULL_REFUND';
      tierDescription = 'Administrative full refund override';
      feePercent = 0;
      refundPercent = 100;
    }
    // 3. Time-based Policy
    else if (hoursRemaining > 24) {
      tier = 'FULL_REFUND_FREE_CANCELLATION';
      tierDescription = 'Free cancellation (> 24 hours before pickup)';
      feePercent = 0;
      refundPercent = 100;
    } else if (hoursRemaining >= 6 && hoursRemaining <= 24) {
      tier = 'MODERATE_CANCELLATION';
      tierDescription =
        'Cancellation between 6 and 24 hours before pickup (25% fee)';
      feePercent = 25;
      refundPercent = 75;
    } else if (hoursRemaining >= 0 && hoursRemaining < 6) {
      tier = 'LATE_CANCELLATION';
      tierDescription = 'Cancellation within 6 hours of pickup time (50% fee)';
      feePercent = 50;
      refundPercent = 50;
    } else {
      // hoursRemaining < 0 (After trip start time)
      tier = 'NO_REFUND_AFTER_START';
      tierDescription = 'Cancellation after trip pickup time (Non-refundable)';
      feePercent = 100;
      refundPercent = 0;
    }

    const feeAmountNumber = Number(
      ((paidNumber * feePercent) / 100).toFixed(2),
    );
    const refundAmountNumber = Number(
      ((paidNumber * refundPercent) / 100).toFixed(2),
    );

    const cancellationFee = new Decimal(feeAmountNumber);
    const refundAmount = new Decimal(refundAmountNumber);
    const refundAmountInPaise = Math.round(refundAmountNumber * 100);

    return {
      tier,
      tierDescription,
      startDate,
      cancellationTime,
      hoursRemaining,
      amountPaid: paidDecimal,
      cancellationFeePercent: feePercent,
      cancellationFee,
      refundAmountPercent: refundPercent,
      refundAmount,
      refundAmountInPaise,
      isEligibleForRefund: refundAmountNumber > 0,
    };
  }
}
