import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ValidateCouponDto } from './dto/validate-coupon.dto';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { UpdateCouponDto } from './dto/update-coupon.dto';
import { DiscountType, BookingStatus } from '@prisma/client';
import { AuditLogService } from '../admin/audit-log.service';

@Injectable()
export class CouponsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  // 1. Authoritative Server-side Coupon Validation
  async validateCoupon(customerId: string, dto: ValidateCouponDto) {
    const code = dto.code.trim().toUpperCase();
    const now = new Date();

    const coupon = await this.prisma.coupon.findUnique({
      where: { code },
    });

    if (!coupon) {
      throw new NotFoundException('Invalid coupon code.');
    }

    if (!coupon.isActive) {
      throw new BadRequestException('This coupon is currently inactive.');
    }

    if (coupon.startDate && new Date(coupon.startDate) > now) {
      throw new BadRequestException('This coupon is not active yet.');
    }

    if (coupon.expiresAt && new Date(coupon.expiresAt) < now) {
      throw new BadRequestException('This coupon has expired.');
    }

    if (
      coupon.globalUsageLimit !== null &&
      coupon.globalUsageLimit !== undefined &&
      coupon.usageCount >= coupon.globalUsageLimit
    ) {
      throw new BadRequestException(
        'This coupon has reached its global usage limit.',
      );
    }

    // Check per-customer limit
    const perCustomerLimit = coupon.perCustomerLimit ?? 1;
    const userUsageCount = await this.prisma.couponUsage.count({
      where: {
        couponId: coupon.id,
        customerId,
      },
    });

    if (userUsageCount >= perCustomerLimit) {
      throw new BadRequestException(
        'You have reached the maximum redemptions for this coupon.',
      );
    }

    // Check first-booking restriction
    if (coupon.firstBookingOnly) {
      const existingBookingsCount = await this.prisma.booking.count({
        where: {
          customerId,
          status: {
            in: [
              BookingStatus.CONFIRMED,
              BookingStatus.ONGOING,
              BookingStatus.COMPLETED,
            ],
          },
        },
      });

      if (existingBookingsCount > 0) {
        throw new BadRequestException(
          'This coupon is valid for your first booking only.',
        );
      }
    }

    // Resolve car context if carId is provided
    let carCategory = dto.carCategory;
    let carCity = dto.city;

    if (dto.carId) {
      const car = await this.prisma.car.findUnique({
        where: { id: dto.carId },
        include: { vendor: true },
      });
      if (car) {
        carCategory = carCategory || car.type;
        carCity = carCity || car.vendor.city;
      }
    }

    // Check City restriction
    if (coupon.city && carCity) {
      if (coupon.city.toLowerCase() !== carCity.toLowerCase()) {
        throw new BadRequestException(
          `This coupon is valid only in ${coupon.city}.`,
        );
      }
    }

    // Check Trip-Type restriction
    if (coupon.tripType && dto.tripType) {
      if (coupon.tripType !== dto.tripType) {
        throw new BadRequestException(
          `This coupon is valid only for ${coupon.tripType} trips.`,
        );
      }
    }

    // Check Car Category restriction
    if (coupon.carCategory && carCategory) {
      if (coupon.carCategory !== carCategory) {
        throw new BadRequestException(
          `This coupon is valid only for ${coupon.carCategory} vehicles.`,
        );
      }
    }

    // Check minimum booking amount
    const subtotal = dto.subtotal || 0;
    if (
      coupon.minBookingAmount !== null &&
      coupon.minBookingAmount !== undefined
    ) {
      const minAmount = Number(coupon.minBookingAmount);
      if (subtotal < minAmount) {
        throw new BadRequestException(
          `Booking amount must be at least ₹${minAmount} to use this coupon.`,
        );
      }
    }

    // Calculate authoritative discount amount
    let calculatedDiscount = 0;
    const discountVal = Number(coupon.discountValue);

    if (coupon.discountType === DiscountType.PERCENTAGE) {
      calculatedDiscount = (subtotal * discountVal) / 100;
      if (
        coupon.maxDiscountAmount !== null &&
        coupon.maxDiscountAmount !== undefined
      ) {
        const maxCap = Number(coupon.maxDiscountAmount);
        calculatedDiscount = Math.min(calculatedDiscount, maxCap);
      }
    } else if (coupon.discountType === DiscountType.FIXED) {
      calculatedDiscount = discountVal;
    }

    // Discount cannot exceed subtotal
    calculatedDiscount = Math.min(calculatedDiscount, subtotal);
    calculatedDiscount = Math.round(calculatedDiscount * 100) / 100;

    const finalPayableAmount = Math.max(0, subtotal - calculatedDiscount);

    return {
      valid: true,
      couponId: coupon.id,
      code: coupon.code,
      description: coupon.description,
      discountType: coupon.discountType,
      discountValue: discountVal,
      maxDiscountAmount: coupon.maxDiscountAmount
        ? Number(coupon.maxDiscountAmount)
        : null,
      minBookingAmount: coupon.minBookingAmount
        ? Number(coupon.minBookingAmount)
        : null,
      discountAmount: calculatedDiscount,
      finalPayableAmount,
    };
  }

  // 2. Fetch Customer Available Coupons
  async getAvailableCoupons(customerId: string, city?: string) {
    const now = new Date();
    const coupons = await this.prisma.coupon.findMany({
      where: {
        isActive: true,
        OR: [{ startDate: null }, { startDate: { lte: now } }],
        AND: [{ OR: [{ expiresAt: null }, { expiresAt: { gte: now } }] }],
      },
      orderBy: { createdAt: 'desc' },
    });

    const eligibleCoupons: any[] = [];
    for (const c of coupons) {
      // Filter out global usage limit reached
      if (c.globalUsageLimit !== null && c.usageCount >= c.globalUsageLimit) {
        continue;
      }
      // Filter out city mismatch if city is passed
      if (c.city && city && c.city.toLowerCase() !== city.toLowerCase()) {
        continue;
      }

      // Check per-customer limit
      const userUsageCount = await this.prisma.couponUsage.count({
        where: { couponId: c.id, customerId },
      });
      if (userUsageCount >= (c.perCustomerLimit ?? 1)) {
        continue;
      }

      eligibleCoupons.push({
        id: c.id,
        code: c.code,
        description: c.description,
        discountType: c.discountType,
        discountValue: Number(c.discountValue),
        maxDiscountAmount: c.maxDiscountAmount
          ? Number(c.maxDiscountAmount)
          : null,
        minBookingAmount: c.minBookingAmount
          ? Number(c.minBookingAmount)
          : null,
        expiresAt: c.expiresAt,
        city: c.city,
        tripType: c.tripType,
        carCategory: c.carCategory,
        firstBookingOnly: c.firstBookingOnly,
      });
    }

    return eligibleCoupons;
  }

  // 3. Admin: Get all coupons
  async findAllAdmin() {
    const coupons = await this.prisma.coupon.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { usages: true } },
      },
    });

    return coupons.map((c) => ({
      ...c,
      discountValue: Number(c.discountValue),
      maxDiscountAmount: c.maxDiscountAmount
        ? Number(c.maxDiscountAmount)
        : null,
      minBookingAmount: c.minBookingAmount
        ? Number(c.minBookingAmount)
        : null,
      usageCount: c._count.usages,
    }));
  }

  // 4. Admin: Create coupon
  async createCoupon(dto: CreateCouponDto, adminUserId: string) {
    const code = dto.code.trim().toUpperCase();

    const existing = await this.prisma.coupon.findUnique({
      where: { code },
    });
    if (existing) {
      throw new BadRequestException(
        `A coupon with code '${code}' already exists.`,
      );
    }

    const coupon = await this.prisma.coupon.create({
      data: {
        code,
        description: dto.description,
        discountType: dto.discountType,
        discountValue: dto.discountValue,
        maxDiscountAmount: dto.maxDiscountAmount,
        minBookingAmount: dto.minBookingAmount,
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        isActive: dto.isActive ?? true,
        globalUsageLimit: dto.globalUsageLimit,
        perCustomerLimit: dto.perCustomerLimit ?? 1,
        firstBookingOnly: dto.firstBookingOnly ?? false,
        city: dto.city,
        tripType: dto.tripType,
        carCategory: dto.carCategory,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'COUPON_CREATED',
      'Coupon',
      coupon.id,
      dto,
    );

    return {
      ...coupon,
      discountValue: Number(coupon.discountValue),
    };
  }

  // 5. Admin: Update coupon
  async updateCoupon(id: string, dto: UpdateCouponDto, adminUserId: string) {
    const existing = await this.prisma.coupon.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Coupon not found.');
    }

    const data: any = { ...dto };
    if (dto.code) {
      data.code = dto.code.trim().toUpperCase();
    }
    if (dto.startDate) {
      data.startDate = new Date(dto.startDate);
    }
    if (dto.expiresAt) {
      data.expiresAt = new Date(dto.expiresAt);
    }

    const coupon = await this.prisma.coupon.update({
      where: { id },
      data,
    });

    await this.auditLogService.log(
      adminUserId,
      'COUPON_UPDATED',
      'Coupon',
      coupon.id,
      dto,
    );

    return {
      ...coupon,
      discountValue: Number(coupon.discountValue),
    };
  }

  // 6. Admin: Delete coupon
  async deleteCoupon(id: string, adminUserId: string) {
    const existing = await this.prisma.coupon.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Coupon not found.');
    }

    await this.prisma.coupon.delete({ where: { id } });

    await this.auditLogService.log(
      adminUserId,
      'COUPON_DELETED',
      'Coupon',
      id,
      {},
    );

    return { success: true, message: 'Coupon deleted successfully.' };
  }
}
