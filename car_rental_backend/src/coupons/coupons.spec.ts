import { Test, TestingModule } from '@nestjs/testing';
import { CouponsService } from './coupons.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { DiscountType, TripType, CarCategory, BookingStatus } from '@prisma/client';
import { NotFoundException, BadRequestException } from '@nestjs/common';

describe('CouponsService', () => {
  let service: CouponsService;

  const mockCouponPercentage = {
    id: 'coupon-pct-1',
    code: 'SAVE20',
    description: '20% OFF up to 500',
    discountType: DiscountType.PERCENTAGE,
    discountValue: 20,
    maxDiscountAmount: 500,
    minBookingAmount: 1000,
    startDate: null,
    expiresAt: null,
    isActive: true,
    globalUsageLimit: 100,
    perCustomerLimit: 1,
    firstBookingOnly: false,
    city: null,
    tripType: null,
    carCategory: null,
    usageCount: 5,
  };

  const mockCouponFixed = {
    id: 'coupon-fix-1',
    code: 'FLAT300',
    description: 'Flat 300 OFF',
    discountType: DiscountType.FIXED,
    discountValue: 300,
    maxDiscountAmount: null,
    minBookingAmount: 500,
    startDate: null,
    expiresAt: null,
    isActive: true,
    globalUsageLimit: 50,
    perCustomerLimit: 2,
    firstBookingOnly: false,
    city: 'Mumbai',
    tripType: TripType.SELF_DRIVE,
    carCategory: CarCategory.SUV,
    usageCount: 10,
  };

  const mockCouponExpired = {
    ...mockCouponPercentage,
    id: 'coupon-exp',
    code: 'EXPIRED10',
    expiresAt: new Date(Date.now() - 86400000), // Yesterday
  };

  const mockCouponFuture = {
    ...mockCouponPercentage,
    id: 'coupon-fut',
    code: 'FUTURE10',
    startDate: new Date(Date.now() + 86400000), // Tomorrow
  };

  const mockCouponInactive = {
    ...mockCouponPercentage,
    id: 'coupon-inact',
    code: 'INACTIVE',
    isActive: false,
  };

  const mockCouponLimitReached = {
    ...mockCouponPercentage,
    id: 'coupon-limit',
    code: 'MAXEDOUT',
    globalUsageLimit: 10,
    usageCount: 10,
  };

  const mockCouponFirstOnly = {
    ...mockCouponPercentage,
    id: 'coupon-first',
    code: 'FIRSTFLY',
    firstBookingOnly: true,
  };

  const mockPrismaService = {
    coupon: {
      findUnique: jest.fn().mockImplementation(({ where }) => {
        const c = where.code;
        if (c === 'SAVE20') return Promise.resolve(mockCouponPercentage);
        if (c === 'FLAT300') return Promise.resolve(mockCouponFixed);
        if (c === 'EXPIRED10') return Promise.resolve(mockCouponExpired);
        if (c === 'FUTURE10') return Promise.resolve(mockCouponFuture);
        if (c === 'INACTIVE') return Promise.resolve(mockCouponInactive);
        if (c === 'MAXEDOUT') return Promise.resolve(mockCouponLimitReached);
        if (c === 'FIRSTFLY') return Promise.resolve(mockCouponFirstOnly);
        return Promise.resolve(null);
      }),
      findMany: jest.fn().mockResolvedValue([mockCouponPercentage, mockCouponFixed]),
      create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'c-new', ...data })),
      update: jest.fn().mockImplementation(({ where, data }) => Promise.resolve({ id: where.id, ...data })),
      delete: jest.fn().mockResolvedValue({ id: 'c-del' }),
    },
    couponUsage: {
      count: jest.fn().mockImplementation(({ where }) => {
        if (where.customerId === 'user-used' && where.couponId === 'coupon-pct-1') {
          return Promise.resolve(1);
        }
        return Promise.resolve(0);
      }),
    },
    booking: {
      count: jest.fn().mockImplementation(({ where }) => {
        if (where.customerId === 'user-old') return Promise.resolve(2);
        return Promise.resolve(0);
      }),
    },
    car: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'car-1',
        type: CarCategory.SUV,
        vendor: { city: 'Mumbai' },
      }),
    },
  };

  const mockAuditLogService = {
    log: jest.fn().mockResolvedValue({}),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CouponsService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: AuditLogService, useValue: mockAuditLogService },
      ],
    }).compile();

    service = module.get<CouponsService>(CouponsService);
  });

  it('1. Valid percentage coupon calculates 20% discount', async () => {
    const res = await service.validateCoupon('user-1', {
      code: 'SAVE20',
      subtotal: 2000,
    });
    expect(res.valid).toBe(true);
    expect(res.discountAmount).toBe(400); // 20% of 2000
    expect(res.finalPayableAmount).toBe(1600);
  });

  it('2. Valid fixed coupon subtracts exact amount', async () => {
    const res = await service.validateCoupon('user-1', {
      code: 'FLAT300',
      subtotal: 2000,
      city: 'Mumbai',
      tripType: TripType.SELF_DRIVE,
      carCategory: CarCategory.SUV,
    });
    expect(res.valid).toBe(true);
    expect(res.discountAmount).toBe(300);
    expect(res.finalPayableAmount).toBe(1700);
  });

  it('3. Maximum discount cap restricts discount', async () => {
    const res = await service.validateCoupon('user-1', {
      code: 'SAVE20',
      subtotal: 5000, // 20% would be 1000, but cap is 500
    });
    expect(res.discountAmount).toBe(500);
    expect(res.finalPayableAmount).toBe(4500);
  });

  it('4. Minimum booking amount throws exception if subtotal too low', async () => {
    await expect(
      service.validateCoupon('user-1', {
        code: 'SAVE20',
        subtotal: 800, // Min is 1000
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('5. Not-yet-active coupon throws exception', async () => {
    await expect(
      service.validateCoupon('user-1', { code: 'FUTURE10', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('6. Expired coupon throws exception', async () => {
    await expect(
      service.validateCoupon('user-1', { code: 'EXPIRED10', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('7. Inactive coupon throws exception', async () => {
    await expect(
      service.validateCoupon('user-1', { code: 'INACTIVE', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('8. Global usage limit throws exception when maxed out', async () => {
    await expect(
      service.validateCoupon('user-1', { code: 'MAXEDOUT', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('9. Per-customer limit prevents duplicate use', async () => {
    await expect(
      service.validateCoupon('user-used', { code: 'SAVE20', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('10. First-booking-only rejects existing customers', async () => {
    await expect(
      service.validateCoupon('user-old', { code: 'FIRSTFLY', subtotal: 2000 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('11. City restriction rejects invalid city', async () => {
    await expect(
      service.validateCoupon('user-1', {
        code: 'FLAT300',
        subtotal: 2000,
        city: 'Delhi', // Valid only in Mumbai
        tripType: TripType.SELF_DRIVE,
        carCategory: CarCategory.SUV,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('12. Trip-type restriction rejects invalid trip type', async () => {
    await expect(
      service.validateCoupon('user-1', {
        code: 'FLAT300',
        subtotal: 2000,
        city: 'Mumbai',
        tripType: TripType.OUTSTATION, // Valid only for SELF_DRIVE
        carCategory: CarCategory.SUV,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('13. Car-category restriction rejects invalid vehicle category', async () => {
    await expect(
      service.validateCoupon('user-1', {
        code: 'FLAT300',
        subtotal: 2000,
        city: 'Mumbai',
        tripType: TripType.SELF_DRIVE,
        carCategory: CarCategory.HATCHBACK, // Valid only for SUV
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('14. Discount cannot exceed subtotal (zero/negative protection)', async () => {
    // For FLAT300 with subtotal 200, if minBookingAmount is 100
    const mockCouponBigFixed = {
      ...mockCouponFixed,
      discountValue: 1000,
      minBookingAmount: 100,
    };
    mockPrismaService.coupon.findUnique.mockResolvedValueOnce(mockCouponBigFixed);

    const res = await service.validateCoupon('user-1', {
      code: 'FLAT300',
      subtotal: 400, // Fixed 1000 > subtotal 400
      city: 'Mumbai',
      tripType: TripType.SELF_DRIVE,
      carCategory: CarCategory.SUV,
    });
    expect(res.discountAmount).toBe(400);
    expect(res.finalPayableAmount).toBe(0);
  });

  it('15. Invalid code throws NotFoundException', async () => {
    await expect(
      service.validateCoupon('user-1', { code: 'NOCODE99', subtotal: 1000 }),
    ).rejects.toThrow(NotFoundException);
  });
});
