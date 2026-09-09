import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory, TripType, DiscountType, BookingStatus } from '@prisma/client';

export interface PromotionEvaluationContext {
  customerId?: string;
  vendorId: string;
  branchId?: string;
  vehicleClass: CarCategory;
  tripType?: TripType;
  subtotal: number;
  durationDays: number;
  startDate: Date;
  endDate: Date;
  existingDiscountsCount?: number;
}

export interface PromotionEvaluationResult {
  isValid: boolean;
  code: string;
  description: string;
  discountType: DiscountType;
  discountAmount: number;
  effectiveDiscountAmount: number;
  isStackable: boolean;
  rejectionReason?: string;
}

@Injectable()
export class PromotionEngineService {
  private readonly logger = new Logger(PromotionEngineService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Authoritatively evaluates whether a coupon code or promotional rule is applicable,
   * enforcing multi-tenant vendor restrictions, branch scope, vehicle class limits,
   * duration thresholds, customer usage quotas, and stacking invariants.
   */
  async evaluatePromotion(
    code: string,
    ctx: PromotionEvaluationContext,
  ): Promise<PromotionEvaluationResult> {
    const normalizedCode = code.trim().toUpperCase();

    const coupon = await this.prisma.coupon.findUnique({
      where: { code: normalizedCode },
      include: {
        vendor: true,
        branch: true,
      },
    });

    if (!coupon) {
      throw new NotFoundException(`Promotional coupon code '${normalizedCode}' not found.`);
    }

    if (!coupon.isActive) {
      return this.reject(normalizedCode, coupon.description, 'This promotion is currently inactive.');
    }

    const now = new Date();
    if (coupon.startDate && now < coupon.startDate) {
      return this.reject(normalizedCode, coupon.description, 'This promotion has not started yet.');
    }

    if (coupon.expiresAt && now > coupon.expiresAt) {
      return this.reject(normalizedCode, coupon.description, 'This promotional coupon has expired.');
    }

    // 1. Multi-tenant vendor scoping check
    if (coupon.vendorId && coupon.vendorId !== ctx.vendorId) {
      return this.reject(
        normalizedCode,
        coupon.description,
        `This coupon is exclusive to vendor '${coupon.vendor?.businessName || coupon.vendorId}'.`,
      );
    }

    // 2. Branch scoping check
    if (coupon.branchId && ctx.branchId && coupon.branchId !== ctx.branchId) {
      return this.reject(
        normalizedCode,
        coupon.description,
        `This coupon is valid only at branch '${coupon.branch?.name || coupon.branchId}'.`,
      );
    }

    // 3. Vehicle class restriction
    if (coupon.carCategory && coupon.carCategory !== ctx.vehicleClass) {
      return this.reject(
        normalizedCode,
        coupon.description,
        `This coupon is valid only for ${coupon.carCategory} category vehicles.`,
      );
    }

    // 4. Trip type restriction
    if (coupon.tripType && ctx.tripType && coupon.tripType !== ctx.tripType) {
      return this.reject(
        normalizedCode,
        coupon.description,
        `This coupon applies only to ${coupon.tripType} rentals.`,
      );
    }

    // 5. Minimum rental duration check
    if (coupon.minRentalDays && ctx.durationDays < coupon.minRentalDays) {
      return this.reject(
        normalizedCode,
        coupon.description,
        `Rental duration must be at least ${coupon.minRentalDays} days to apply this coupon.`,
      );
    }

    // 6. Minimum booking amount check
    if (coupon.minBookingAmount) {
      const minAmount = Number(coupon.minBookingAmount);
      if (ctx.subtotal < minAmount) {
        return this.reject(
          normalizedCode,
          coupon.description,
          `Minimum booking amount of ₹${minAmount.toFixed(2)} required (current subtotal: ₹${ctx.subtotal.toFixed(2)}).`,
        );
      }
    }

    // 7. Global usage limit check
    if (coupon.globalUsageLimit !== null && coupon.globalUsageLimit !== undefined) {
      if (coupon.usageCount >= coupon.globalUsageLimit) {
        return this.reject(normalizedCode, coupon.description, 'Coupon usage limit has been reached.');
      }
    }

    // 8. Customer specific checks
    if (ctx.customerId) {
      // First booking only check
      if (coupon.firstBookingOnly) {
        const previousBookings = await this.prisma.booking.count({
          where: {
            customerId: ctx.customerId,
            status: { in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.COMPLETED] },
          },
        });
        if (previousBookings > 0) {
          return this.reject(
            normalizedCode,
            coupon.description,
            'This promotion is reserved exclusively for first-time bookings.',
          );
        }
      }

      // Per customer limit
      if (coupon.perCustomerLimit && coupon.perCustomerLimit > 0) {
        const customerUsages = await this.prisma.couponUsage.count({
          where: {
            couponId: coupon.id,
            customerId: ctx.customerId,
          },
        });
        if (customerUsages >= coupon.perCustomerLimit) {
          return this.reject(
            normalizedCode,
            coupon.description,
            `You have already used this coupon the maximum allowed times (${coupon.perCustomerLimit}).`,
          );
        }
      }
    }

    // 9. Stacking rules
    if (!coupon.stackable && ctx.existingDiscountsCount && ctx.existingDiscountsCount > 0) {
      return this.reject(
        normalizedCode,
        coupon.description,
        'This promotional coupon cannot be stacked with other active discounts.',
      );
    }

    // 10. Compute exact discount amount
    const discountVal = Number(coupon.discountValue);
    let calculatedDiscount = 0;

    if (coupon.discountType === DiscountType.PERCENTAGE) {
      calculatedDiscount = (ctx.subtotal * discountVal) / 100;
      if (coupon.maxDiscountAmount) {
        calculatedDiscount = Math.min(calculatedDiscount, Number(coupon.maxDiscountAmount));
      }
    } else {
      calculatedDiscount = discountVal;
    }

    // Discount cannot exceed subtotal
    const effectiveDiscount = Math.max(0, Math.min(ctx.subtotal, calculatedDiscount));

    return {
      isValid: true,
      code: coupon.code,
      description: coupon.description || 'Promotional Discount',
      discountType: coupon.discountType,
      discountAmount: Math.round(calculatedDiscount * 100) / 100,
      effectiveDiscountAmount: Math.round(effectiveDiscount * 100) / 100,
      isStackable: coupon.stackable,
    };
  }

  private reject(
    code: string,
    description: string | null,
    reason: string,
  ): PromotionEvaluationResult {
    return {
      isValid: false,
      code,
      description: description || 'Promotional Discount',
      discountType: DiscountType.FIXED,
      discountAmount: 0,
      effectiveDiscountAmount: 0,
      isStackable: false,
      rejectionReason: reason,
    };
  }
}
