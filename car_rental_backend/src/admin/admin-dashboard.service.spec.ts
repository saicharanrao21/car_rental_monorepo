import { Test, TestingModule } from '@nestjs/testing';
import { AdminDashboardService } from './admin-dashboard.service';
import { PrismaService } from '../prisma/prisma.service';
import { Role, BookingStatus, VerificationStatus } from '@prisma/client';

describe('AdminDashboardService', () => {
  let service: AdminDashboardService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      user: {
        count: jest.fn().mockResolvedValue(120),
      },
      vendor: {
        count: jest.fn().mockResolvedValue(15),
        findMany: jest.fn().mockResolvedValue([]),
      },
      booking: {
        count: jest.fn().mockResolvedValue(8),
        findMany: jest.fn().mockResolvedValue([
          { totalFare: '2500.00', platformFee: '250.00', createdAt: new Date() },
        ]),
        aggregate: jest.fn().mockResolvedValue({
          _sum: { totalFare: 20000 },
        }),
      },
      car: {
        count: jest.fn().mockImplementation((args?: any) => {
          if (args?.where?.operationalStatus === 'ACTIVE') return Promise.resolve(20);
          return Promise.resolve(25);
        }),
      },
      customerKyc: {
        count: jest.fn().mockResolvedValue(3),
      },
      payout: {
        count: jest.fn().mockResolvedValue(2),
      },
      paymentRefund: {
        count: jest.fn().mockResolvedValue(1),
      },
      vendorSecurityDeposit: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { paidAmount: 25000 },
        }),
      },
      dispute: {
        count: jest.fn().mockResolvedValue(0),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminDashboardService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<AdminDashboardService>(AdminDashboardService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getKpis', () => {
    it('should aggregate KPIs using paidAmount and return correct financial metrics', async () => {
      const kpis = await service.getKpis();

      expect(kpis).toBeDefined();
      expect(kpis.totalUsers).toBe(120);
      expect(kpis.totalVendors).toBe(15);
      expect(kpis.activeBookings).toBe(8);
      expect(kpis.grossBookingValue).toBe(20000);
      expect(kpis.heldDepositLiability).toBe(25000);
      expect(kpis.totalCars).toBe(25);
      expect(kpis.availableCars).toBe(20);
      expect(kpis.fleetUtilizationPct).toBe(20); // (25-20)/25 * 100 = 20%
      expect(kpis.pendingKycReviews).toBe(3);
      expect(kpis.pendingPayoutsCount).toBe(2);
      expect(kpis.pendingRefundsCount).toBe(1);

      // Verify vendorSecurityDeposit was queried with paidAmount
      expect(prisma.vendorSecurityDeposit.aggregate).toHaveBeenCalledWith({
        _sum: { paidAmount: true },
        where: { status: { in: ['PAID', 'HELD'] } },
      });

      // Verify paymentRefund was queried with REQUESTED, PENDING
      expect(prisma.paymentRefund.count).toHaveBeenCalledWith({
        where: { status: { in: ['REQUESTED', 'PENDING'] } },
      });
    });
  });

  describe('getBookingsPerDay', () => {
    it('should calculate daily booking distribution for specified days', async () => {
      prisma.booking.findMany.mockResolvedValueOnce([
        { createdAt: new Date() },
      ]);
      const res = await service.getBookingsPerDay(7);
      expect(res).toHaveLength(7);
      expect(res[res.length - 1].count).toBe(1);
    });
  });

  describe('getRevenuePerCity', () => {
    it('should aggregate revenue per city correctly', async () => {
      prisma.booking.findMany.mockResolvedValueOnce([
        { totalFare: 5000, car: { vendor: { city: 'Mumbai' } } },
        { totalFare: 3000, car: { vendor: { city: 'Mumbai' } } },
        { totalFare: 2000, car: { vendor: { city: 'Delhi' } } },
      ]);

      const res = await service.getRevenuePerCity(30);
      expect(res).toEqual(
        expect.arrayContaining([
          { city: 'Mumbai', revenue: 8000 },
          { city: 'Delhi', revenue: 2000 },
        ]),
      );
    });
  });
});

