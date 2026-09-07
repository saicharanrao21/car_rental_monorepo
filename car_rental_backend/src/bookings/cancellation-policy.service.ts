import { Injectable, Optional } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { SystemConfigService } from '../config-engine/system-config.service';
import { CancellationMatrixConfig } from '../config-engine/system-config.interface';

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
  depositAmount?: Decimal | number;
  actorRole: Role;
  isAdminOverride?: boolean;
  isPendingConfirmation?: boolean;
  cancellationMatrix?: CancellationMatrixConfig;
}

export const DEFAULT_CANCELLATION_MATRIX: CancellationMatrixConfig = {
  tiers: [
    {
      minHoursBeforePickup: 24,
      feePercent: 0,
      tier: 'FULL_REFUND_FREE_CANCELLATION',
      description: 'Free cancellation (> 24 hours before pickup)',
    },
    {
      minHoursBeforePickup: 6,
      feePercent: 25,
      tier: 'MODERATE_CANCELLATION',
      description: 'Cancellation between 6 and 24 hours before pickup (25% fee)',
    },
    {
      minHoursBeforePickup: 0,
      feePercent: 50,
      tier: 'LATE_CANCELLATION',
      description: 'Cancellation within 6 hours of pickup time (50% fee)',
    },
  ],
  afterStartFeePercent: 100,
  afterStartTier: 'NO_REFUND_AFTER_START',
  afterStartDescription: 'Cancellation after trip pickup time (Non-refundable)',
};

@Injectable()
export class CancellationPolicyService {
  constructor(
    @Optional() private readonly configService?: SystemConfigService,
  ) {}

  /**
   * Async helper that resolves current configuration from SystemConfigService
   * unless a historical matrix is already specified in params.
   */
  async calculateCancellationWithConfig(
    params: CalculateCancellationParams,
  ): Promise<CancellationCalculationResult> {
    if (params.cancellationMatrix) {
      return this.calculateCancellation(params);
    }

    let matrix: CancellationMatrixConfig = DEFAULT_CANCELLATION_MATRIX;
    if (this.configService) {
      try {
        const configured = await this.configService.getCancellationMatrixConfig();
        if (configured && Array.isArray(configured.tiers) && configured.tiers.length > 0) {
          matrix = configured;
        }
      } catch {
        // Fallback to default matrix
      }
    }

    return this.calculateCancellation({
      ...params,
      cancellationMatrix: matrix,
    });
  }

  /**
   * Pure deterministic calculation of cancellation fee and refund amounts
   * based on the authoritative DriveGo cancellation policy matrix.
   */
  calculateCancellation(
    params: CalculateCancellationParams,
  ): CancellationCalculationResult {
    const {
      startDate,
      cancellationTime = new Date(),
      actorRole,
      isAdminOverride = false,
      isPendingConfirmation = false,
      cancellationMatrix = DEFAULT_CANCELLATION_MATRIX,
    } = params;

    const paidDecimal =
      params.amountPaid instanceof Decimal
        ? params.amountPaid
        : new Decimal(params.amountPaid);
    const depositDecimal = params.depositAmount
      ? params.depositAmount instanceof Decimal
        ? params.depositAmount
        : new Decimal(params.depositAmount)
      : new Decimal(0);

    const paidNumber = paidDecimal.toNumber();
    const depositNumber = depositDecimal.toNumber();
    const fareNumber = Math.max(0, paidNumber - depositNumber);

    // Calculate hours remaining before trip pickup
    const diffMs = startDate.getTime() - cancellationTime.getTime();
    const hoursRemaining = Number((diffMs / (1000 * 60 * 60)).toFixed(2));

    let tier: string;
    let tierDescription: string;
    let feePercent: number;
    let refundPercent: number;

    // 0. Pending Owner Confirmation -> Always 100% Full Refund if cancelled before owner accepts
    if (isPendingConfirmation) {
      tier = 'PENDING_CONFIRMATION_FULL_REFUND';
      tierDescription = 'Full refund (Booking cancelled prior to host confirmation)';
      feePercent = 0;
      refundPercent = 100;
    }
    // 1. Vendor Cancellation / Rejection -> Always 100% Refund
    else if (actorRole === Role.VENDOR) {
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
    // 3. Time-based Policy Matrix Evaluation
    else if (hoursRemaining < 0) {
      // Cancellation after trip start time
      tier = cancellationMatrix.afterStartTier || 'NO_REFUND_AFTER_START';
      tierDescription =
        cancellationMatrix.afterStartDescription ||
        'Cancellation after trip pickup time (Non-refundable)';
      feePercent =
        typeof cancellationMatrix.afterStartFeePercent === 'number'
          ? cancellationMatrix.afterStartFeePercent
          : 100;
      refundPercent = Math.max(0, 100 - feePercent);
    } else {
      const tiers = Array.isArray(cancellationMatrix.tiers)
        ? [...cancellationMatrix.tiers].sort(
            (a, b) => b.minHoursBeforePickup - a.minHoursBeforePickup,
          )
        : DEFAULT_CANCELLATION_MATRIX.tiers;

      let matched: any = null;
      for (const t of tiers) {
        // For 24+ hour tier (or top tier), strictly greater than 24h qualifies for full refund
        const isMatch =
          t.minHoursBeforePickup === 24
            ? hoursRemaining > 24
            : hoursRemaining >= t.minHoursBeforePickup;
        if (isMatch) {
          matched = t;
          break;
        }
      }

      if (matched) {
        tier = matched.tier;
        tierDescription = matched.description;
        feePercent = matched.feePercent;
        refundPercent = Math.max(0, 100 - feePercent);
      } else {
        tier = cancellationMatrix.afterStartTier || 'NO_REFUND_AFTER_START';
        tierDescription =
          cancellationMatrix.afterStartDescription ||
          'Cancellation after trip pickup time (Non-refundable)';
        feePercent =
          typeof cancellationMatrix.afterStartFeePercent === 'number'
            ? cancellationMatrix.afterStartFeePercent
            : 100;
        refundPercent = Math.max(0, 100 - feePercent);
      }
    }

    const feeAmountNumber = Number(
      ((fareNumber * feePercent) / 100).toFixed(2),
    );
    const refundAmountNumber = Number(
      (paidNumber - feeAmountNumber).toFixed(2),
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
