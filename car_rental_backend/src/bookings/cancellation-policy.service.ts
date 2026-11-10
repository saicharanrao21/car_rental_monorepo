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
  rentalFare: Decimal;
  amountPaid: Decimal;
  cancellationFeePercent: number;
  cancellationFee: Decimal;
  refundAmountPercent: number;
  refundAmount: Decimal;            // Strictly the rental fare refund (FND-CONF-09)
  depositRefundAmount: Decimal;     // Monetary security deposit refund (held separately)
  deliveryRefundAmount?: Decimal;   // Doorstep delivery fee refund (FND-UNRES-02)
  totalRefundAmount: Decimal;       // Combined customer cash refund (fare + delivery + deposit)
  refundAmountInPaise: number;      // Total refund in paise for payment gateway dispatch
  fareRefundInPaise: number;
  depositRefundInPaise: number;
  isEligibleForRefund: boolean;
}

export interface CalculateCancellationParams {
  startDate: Date;
  cancellationTime?: Date;
  amountPaid: Decimal | number;
  depositAmount?: Decimal | number;
  deliveryFee?: Decimal | number;
  includeDeliveryFeeInRefundBase?: boolean; // FND-UNRES-02: Configurable delivery fee treatment
  actorRole: Role;
  isAdminOverride?: boolean;
  isPendingConfirmation?: boolean;
  cancellationMatrix?: CancellationMatrixConfig;
}

/**
 * Confirmed Founder Cancellation Schedule (FND-CONF-08, FND-CONF-10, FND-CONF-13):
 * - Before dealer acceptance: 100% rental fare refund (takes precedence over all time-based tiers)
 * - > 48 hours before pickup: 90% customer refund (10% fee)
 * - 24–48 hours before pickup: 75% customer refund (25% fee)
 * - 6–24 hours before pickup: 50% customer refund (50% fee)
 * - < 6 hours before pickup: 0% customer refund (100% fee)
 * - Trip pickup / No-show: 0% customer refund (100% fee)
 * - Dealer cancellation / rejection: 100% rental fare refund (FND-CONF-12)
 */
export const DEFAULT_CANCELLATION_MATRIX: CancellationMatrixConfig = {
  tiers: [
    {
      minHoursBeforePickup: 48,
      feePercent: 10,
      tier: 'TIER_GT_48H',
      description: 'Cancellation more than 48 hours before pickup (90% refund)',
    },
    {
      minHoursBeforePickup: 24,
      feePercent: 25,
      tier: 'TIER_24_TO_48H',
      description: 'Cancellation between 24 and 48 hours before pickup (75% refund)',
    },
    {
      minHoursBeforePickup: 6,
      feePercent: 50,
      tier: 'TIER_6_TO_24H',
      description: 'Cancellation between 6 and 24 hours before pickup (50% refund)',
    },
    {
      minHoursBeforePickup: 0,
      feePercent: 100,
      tier: 'TIER_LT_6H',
      description: 'Cancellation within 6 hours of pickup time (0% refund / Non-refundable)',
    },
  ],
  afterStartFeePercent: 100,
  afterStartTier: 'NO_REFUND_AFTER_START',
  afterStartDescription: 'Cancellation after trip pickup time or no-show (Non-refundable)',
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
      includeDeliveryFeeInRefundBase = false,
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
    const deliveryFeeDecimal = params.deliveryFee
      ? params.deliveryFee instanceof Decimal
        ? params.deliveryFee
        : new Decimal(params.deliveryFee)
      : new Decimal(0);

    const paidNumber = paidDecimal.toNumber();
    const depositNumber = depositDecimal.toNumber();
    const deliveryFeeNumber = deliveryFeeDecimal.toNumber();

    // Determine refundable rental fare base (FND-CONF-09 & FND-UNRES-02)
    // Security deposit is NEVER part of rental fare.
    // Doorstep delivery fee inclusion in refund base is configurable (default false).
    let fareNumber: number;
    if (includeDeliveryFeeInRefundBase) {
      fareNumber = Math.max(0, paidNumber - depositNumber);
    } else {
      fareNumber = Math.max(0, paidNumber - depositNumber - deliveryFeeNumber);
    }

    // Calculate hours remaining before trip pickup
    const diffMs = startDate.getTime() - cancellationTime.getTime();
    const hoursRemaining = Number((diffMs / (1000 * 60 * 60)).toFixed(2));

    let tier: string;
    let tierDescription: string;
    let feePercent: number;
    let refundPercent: number;

    // 0. Pending Owner Confirmation -> Always 100% Full Refund if cancelled before owner accepts (FND-CONF-10 & FND-CONF-13 precedence)
    if (isPendingConfirmation) {
      tier = 'PENDING_CONFIRMATION_FULL_REFUND';
      tierDescription = 'Full refund (Booking cancelled prior to host confirmation)';
      feePercent = 0;
      refundPercent = 100;
    }
    // 1. Vendor Cancellation / Rejection -> Always 100% Refund (FND-CONF-12)
    else if (actorRole === Role.VENDOR) {
      tier = 'VENDOR_CANCELLED';
      tierDescription = 'Cancelled or rejected by fleet owner (100% rental fare refund)';
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
    // 3. Time-based Policy Matrix Evaluation (FND-CONF-08)
    else if (hoursRemaining < 0) {
      // Cancellation after trip start time
      tier = cancellationMatrix.afterStartTier || 'NO_REFUND_AFTER_START';
      tierDescription =
        cancellationMatrix.afterStartDescription ||
        'Cancellation after trip pickup time or no-show (Non-refundable)';
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
        // If highest tier is 48h (or similar threshold), strictly greater qualifies for that tier
        const isMatch =
          t.minHoursBeforePickup === 48
            ? hoursRemaining > 48
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
          'Cancellation after trip pickup time or no-show (Non-refundable)';
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
    const fareRefundNumber = Number(
      ((fareNumber * refundPercent) / 100).toFixed(2),
    );

    // Delivery fee handling (FND-UNRES-02):
    let deliveryRefundNumber = 0;
    if (!includeDeliveryFeeInRefundBase && deliveryFeeNumber > 0) {
      // If cancelled before trip pickup, refund delivery fee in full
      if (hoursRemaining >= 0 || isPendingConfirmation || actorRole === Role.VENDOR || (actorRole === Role.ADMIN && isAdminOverride)) {
        deliveryRefundNumber = deliveryFeeNumber;
      }
    }

    // Security deposit is held isolated and 100% released on pre-trip cancellation (FND-CONF-09)
    const depositRefundNumber = depositNumber;

    // Total cash returned to customer
    const totalRefundNumber = Number(
      (fareRefundNumber + deliveryRefundNumber + depositRefundNumber).toFixed(2),
    );

    const cancellationFee = new Decimal(feeAmountNumber);
    const refundAmount = new Decimal(fareRefundNumber);
    const depositRefundAmount = new Decimal(depositRefundNumber);
    const deliveryRefundAmount = new Decimal(deliveryRefundNumber);
    const totalRefundAmount = new Decimal(totalRefundNumber);
    const refundAmountInPaise = Math.round(totalRefundNumber * 100);
    const fareRefundInPaise = Math.round(fareRefundNumber * 100);
    const depositRefundInPaise = Math.round(depositRefundNumber * 100);

    return {
      tier,
      tierDescription,
      startDate,
      cancellationTime,
      hoursRemaining,
      rentalFare: new Decimal(fareNumber),
      amountPaid: paidDecimal,
      cancellationFeePercent: feePercent,
      cancellationFee,
      refundAmountPercent: refundPercent,
      refundAmount,
      depositRefundAmount,
      deliveryRefundAmount,
      totalRefundAmount,
      refundAmountInPaise,
      fareRefundInPaise,
      depositRefundInPaise,
      isEligibleForRefund: totalRefundNumber > 0,
    };
  }
}
