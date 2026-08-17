import { Test, TestingModule } from '@nestjs/testing';
import { AdminRevenueService } from './admin-revenue.service';
import { AdminRevenueController } from './admin-revenue.controller';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus, ReferralStatus, Role, TripType } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('Feature 32 — Admin Analytics & Reports Spec', () => {
  let service: AdminRevenueService;
  let controller: AdminRevenueController;
  let prisma: any;

  const mockDateRange = {
    startDate: '2026-08-01T00:00:00.000Z',
    endDate: '2026-08-31T23:59:59.999Z',
  };

  beforeEach(async () => {
    prisma = {
      booking: {
        findMany: jest.fn(),
        count: jest.fn(),
        aggregate: jest.fn(),
      },
      wallet: {
        aggregate: jest.fn(),
      },
      loyaltyAccount: {
        aggregate: jest.fn(),
      },
      referralAttribution: {
        findMany: jest.fn(),
      },
      car: {
        count: jest.fn(),
      },
      user: {
        count: jest.fn(),
      },
      vendor: {
        findMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminRevenueController],
      providers: [
        AdminRevenueService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<AdminRevenueService>(AdminRevenueService);
    controller = module.get<AdminRevenueController>(AdminRevenueController);
  });

  describe('1. Revenue Summary & Financial Decomposition', () => {
    it('should correctly decompose revenue into base fare, platform fee, GST, protection, delivery, and net margin', async () => {
      const mockBookings = [
        {
          id: 'b1',
          totalFare: 3500,
          baseFare: 2000,
          platformFee: 200,
          gstAmount: 360,
          protectionFee: 500,
          deliveryFee: 440,
          discountAmount: 0,
          netToVendor: 1800,
          refundAmount: 0,
          status: BookingStatus.COMPLETED,
        },
        {
          id: 'b2',
          totalFare: 2200,
          baseFare: 1500,
          platformFee: 150,
          gstAmount: 270,
          protectionFee: 300,
          deliveryFee: 0,
          discountAmount: 100,
          netToVendor: 1350,
          refundAmount: 0,
          status: BookingStatus.CONFIRMED,
        },
        {
          id: 'b3',
          totalFare: 5000,
          baseFare: 4000,
          platformFee: 400,
          gstAmount: 600,
          protectionFee: 0,
          deliveryFee: 0,
          discountAmount: 0,
          netToVendor: 3600,
          refundAmount: 5000,
          status: BookingStatus.CANCELLED,
        },
      ];

      prisma.booking.findMany.mockResolvedValue(mockBookings);
      prisma.wallet.aggregate.mockResolvedValue({ _sum: { availableBalance: 12500 } });
      prisma.loyaltyAccount.aggregate.mockResolvedValue({ _sum: { pointsBalance: 2000 } });
      prisma.referralAttribution.findMany.mockResolvedValue([
        { referrerRewardAmount: 250, refereeRewardAmount: 250 },
      ]);

      const result = await service.getRevenueSummary(mockDateRange);

      // Cancelled booking b3 totalFare and components must NOT be counted in gross/platform
      expect(result.grossBookingValue).toBe(5700); // 3500 + 2200
      expect(result.baseFareRevenue).toBe(3500); // 2000 + 1500
      expect(result.platformRevenue).toBe(350); // 200 + 150
      expect(result.gstCollected).toBe(630); // 360 + 270
      expect(result.protectionRevenue).toBe(800); // 500 + 300
      expect(result.deliveryRevenue).toBe(440); // 440 + 0
      expect(result.discountTotal).toBe(100);

      // Only COMPLETED booking b1 has vendorPayout
      expect(result.vendorPayouts).toBe(1800);

      // Cancelled booking b3 has refund
      expect(result.refundTotal).toBe(5000);

      // Net platform revenue: 350 + 800 + 440 - 100 = 1490
      expect(result.netPlatformRevenue).toBe(1490);

      // Liabilities
      expect(result.walletLiability).toBe(12500);
      expect(result.loyaltyLiability).toBe(1000); // 2000 points / 2 = ₹1000
      expect(result.referralCost).toBe(500); // 250 + 250
    });

    it('should handle zero bookings in range gracefully', async () => {
      prisma.booking.findMany.mockResolvedValue([]);
      prisma.wallet.aggregate.mockResolvedValue({ _sum: { availableBalance: null } });
      prisma.loyaltyAccount.aggregate.mockResolvedValue({ _sum: { pointsBalance: null } });
      prisma.referralAttribution.findMany.mockResolvedValue([]);

      const result = await service.getRevenueSummary(mockDateRange);

      expect(result.grossBookingValue).toBe(0);
      expect(result.platformRevenue).toBe(0);
      expect(result.vendorPayouts).toBe(0);
      expect(result.gstCollected).toBe(0);
      expect(result.netPlatformRevenue).toBe(0);
      expect(result.walletLiability).toBe(0);
      expect(result.loyaltyLiability).toBe(0);
      expect(result.referralCost).toBe(0);
    });

    it('should filter revenue by city when city parameter is supplied', async () => {
      prisma.booking.findMany.mockResolvedValue([]);
      prisma.wallet.aggregate.mockResolvedValue({ _sum: { availableBalance: 0 } });
      prisma.loyaltyAccount.aggregate.mockResolvedValue({ _sum: { pointsBalance: 0 } });
      prisma.referralAttribution.findMany.mockResolvedValue([]);

      await service.getRevenueSummary(mockDateRange, 'Bengaluru');

      expect(prisma.booking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            car: {
              vendor: {
                city: {
                  equals: 'Bengaluru',
                  mode: 'insensitive',
                },
              },
            },
          }),
        }),
      );
    });
  });

  describe('2. Booking Lifecycle & Metrics Analytics', () => {
    it('should calculate completion rate, cancellation rate, and avg booking value correctly', async () => {
      const now = new Date('2026-08-10T10:00:00.000Z');
      const twoDaysLater = new Date('2026-08-12T10:00:00.000Z');

      const mockBookings = [
        {
          id: 'b1',
          status: BookingStatus.COMPLETED,
          totalFare: 4000,
          startDate: now,
          endDate: twoDaysLater,
          refundAmount: 0,
        },
        {
          id: 'b2',
          status: BookingStatus.COMPLETED,
          totalFare: 6000,
          startDate: now,
          endDate: twoDaysLater,
          refundAmount: 0,
        },
        {
          id: 'b3',
          status: BookingStatus.CANCELLED,
          totalFare: 3000,
          startDate: now,
          endDate: twoDaysLater,
          refundAmount: 3000,
        },
        {
          id: 'b4',
          status: BookingStatus.ONGOING,
          totalFare: 2000,
          startDate: now,
          endDate: twoDaysLater,
          refundAmount: 0,
        },
      ];

      prisma.booking.findMany.mockResolvedValue(mockBookings);

      const result = await service.getBookingLifecycleStats(mockDateRange);

      expect(result.totalBookings).toBe(4);
      expect(result.completedBookings).toBe(2);
      expect(result.cancelledBookings).toBe(1);
      expect(result.ongoingBookings).toBe(1);

      // Completion rate: 2 / 4 = 50%
      expect(result.completionRate).toBe(50.0);
      // Cancellation rate: 1 / 4 = 25%
      expect(result.cancellationRate).toBe(25.0);

      // Avg booking value non-cancelled: (4000 + 6000 + 2000) / 3 = 4000
      expect(result.averageBookingValue).toBe(4000.0);
      // Avg duration: 2 days
      expect(result.averageDurationDays).toBe(2.0);
    });

    it('should return 0 rates when no bookings exist', async () => {
      prisma.booking.findMany.mockResolvedValue([]);

      const result = await service.getBookingLifecycleStats(mockDateRange);

      expect(result.totalBookings).toBe(0);
      expect(result.completionRate).toBe(0);
      expect(result.cancellationRate).toBe(0);
      expect(result.averageBookingValue).toBe(0);
      expect(result.averageDurationDays).toBe(0);
    });
  });

  describe('3. Fleet Utilization Analytics', () => {
    it('should calculate vehicle utilization rate and revenue per vehicle', async () => {
      prisma.car.count
        .mockResolvedValueOnce(50) // total cars
        .mockResolvedValueOnce(35); // available cars
      prisma.booking.count.mockResolvedValue(15); // active / ongoing bookings
      prisma.booking.aggregate.mockResolvedValue({ _sum: { totalFare: 150000 } });

      const result = await service.getFleetUtilizationStats();

      expect(result.totalCars).toBe(50);
      expect(result.availableCars).toBe(35);
      expect(result.activeCars).toBe(15);
      // Utilization rate: 15 / 50 = 30%
      expect(result.utilizationRate).toBe(30.0);
      // Avg revenue per car: 150000 / 50 = 3000
      expect(result.avgRevenuePerCar).toBe(3000.0);
    });
  });

  describe('4. Customer Growth & Repeat Metrics', () => {
    it('should calculate repeat customer rate and average customer spend', async () => {
      prisma.user.count
        .mockResolvedValueOnce(100) // total customers
        .mockResolvedValueOnce(20); // new in range

      const mockCustomerBookings = [
        { customerId: 'cust1', totalFare: 2000 },
        { customerId: 'cust1', totalFare: 3000 }, // cust1 has 2 bookings (repeat)
        { customerId: 'cust2', totalFare: 4000 }, // cust2 has 1 booking
        { customerId: 'cust3', totalFare: 1000 }, // cust3 has 1 booking
      ];

      prisma.booking.findMany.mockResolvedValue(mockCustomerBookings);

      const result = await service.getCustomerGrowthStats(mockDateRange);

      expect(result.totalRegisteredCustomers).toBe(100);
      expect(result.newCustomersInRange).toBe(20);
      expect(result.uniqueBookingCustomers).toBe(3);
      expect(result.repeatCustomers).toBe(1); // only cust1
      // Repeat rate: 1 / 3 = 33.3%
      expect(result.repeatCustomerRate).toBe(33.3);
      // Avg spend: (2000 + 3000 + 4000 + 1000) / 3 = 10000 / 3 = 3333.33
      expect(result.avgCustomerSpend).toBe(3333.33);
    });
  });

  describe('5. Addon & Product Adoption Analytics', () => {
    it('should compute adoption percentages for protection, delivery, driver, and coupons', async () => {
      const mockBookings = [
        { protectionFee: 500, deliveryFee: 300, driverIncluded: true, couponId: 'c1', discountAmount: 100 },
        { protectionFee: 0, deliveryFee: 300, driverIncluded: false, couponId: null, discountAmount: 0 },
        { protectionFee: 500, deliveryFee: 0, driverIncluded: false, couponId: null, discountAmount: 0 },
        { protectionFee: 0, deliveryFee: 0, driverIncluded: false, couponId: null, discountAmount: 0 },
      ];

      prisma.booking.findMany.mockResolvedValue(mockBookings);

      const result = await service.getAddonAdoptionStats(mockDateRange);

      expect(result.totalBookings).toBe(4);
      expect(result.protectionCount).toBe(2);
      expect(result.protectionAdoptionRate).toBe(50.0); // 2/4
      expect(result.deliveryCount).toBe(2);
      expect(result.deliveryAdoptionRate).toBe(50.0); // 2/4
      expect(result.driverCount).toBe(1);
      expect(result.driverAdoptionRate).toBe(25.0); // 1/4
      expect(result.couponCount).toBe(1);
      expect(result.couponUsageRate).toBe(25.0); // 1/4
    });
  });

  describe('6. CSV Export & Formatting', () => {
    it('should generate valid RFC 4180 compliant CSV content with complete financial headers', async () => {
      const now = new Date('2026-08-15T12:00:00.000Z');
      const mockBookings = [
        {
          id: 'bkg_123',
          createdAt: now,
          startDate: now,
          endDate: new Date('2026-08-17T12:00:00.000Z'),
          customer: { name: 'John "The Driver" Doe', phone: '+919876543210', email: 'john@example.com' },
          vendor: { businessName: 'DriveGo Bangalore', city: 'Bengaluru' },
          car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'KA01AB1234' },
          tripType: TripType.SELF_DRIVE,
          status: BookingStatus.COMPLETED,
          baseFare: 2000,
          platformFee: 200,
          gstAmount: 360,
          protectionFee: 500,
          deliveryFee: 400,
          discountAmount: 100,
          totalFare: 3360,
          netToVendor: 1800,
          payment: { status: 'PAID', refundStatus: 'NONE' },
        },
      ];

      prisma.booking.findMany.mockResolvedValue(mockBookings);

      const csv = await service.exportRevenueCsv(mockDateRange);

      expect(csv).toContain('Booking ID,Created At,Customer Name');
      expect(csv).toContain('"bkg_123"');
      // Verify double-quote escaping in names
      expect(csv).toContain('"John ""The Driver"" Doe"');
      expect(csv).toContain('"DriveGo Bangalore"');
      expect(csv).toContain('"Hyundai Creta"');
      expect(csv).toContain('"KA01AB1234"');
      expect(csv).toContain('"Bengaluru"');
      expect(csv).toContain('"SELF_DRIVE"');
      expect(csv).toContain('"COMPLETED"');
      expect(csv).toContain('"3360"');
    });
  });

  describe('7. Controller Validation & Guard Checks', () => {
    it('should reject invalid date range where startDate is after endDate', async () => {
      const invalidQuery = {
        startDate: '2026-08-31T00:00:00.000Z',
        endDate: '2026-08-01T00:00:00.000Z',
      };

      await expect(controller.getSummary(invalidQuery)).rejects.toThrow(BadRequestException);
    });

    it('should reject non-date strings with BadRequestException', async () => {
      const invalidQuery = {
        startDate: 'invalid-date',
        endDate: '2026-08-31T00:00:00.000Z',
      };

      await expect(controller.getSummary(invalidQuery)).rejects.toThrow(BadRequestException);
    });
  });
});
