import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role, BookingStatus, VerificationStatus } from '@prisma/client';

@Injectable()
export class AdminDashboardService {
  constructor(private prisma: PrismaService) {}

  async getKpis() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      totalUsers,
      totalVendors,
      activeBookings,
      todaysBookings,
      gbvAggregate,
      pendingVendors,
      pendingKyc,
      pendingPayouts,
      pendingRefunds,
      depositAggregate,
      totalCars,
      activeCars,
      activeDisputes,
    ] = await Promise.all([
      this.prisma.user.count({
        where: { role: Role.CUSTOMER },
      }),
      this.prisma.vendor.count(),
      this.prisma.booking.count({
        where: {
          status: {
            in: [
              BookingStatus.PENDING,
              BookingStatus.CONFIRMED,
              BookingStatus.ONGOING,
            ],
          },
        },
      }),
      this.prisma.booking.findMany({
        where: {
          createdAt: {
            gte: today,
          },
        },
        select: {
          platformFee: true,
        },
      }),
      this.prisma.booking.aggregate({
        _sum: { totalFare: true },
        where: {
          status: {
            in: [
              BookingStatus.CONFIRMED,
              BookingStatus.ONGOING,
              BookingStatus.COMPLETED,
            ],
          },
        },
      }),
      this.prisma.vendor.count({
        where: { verificationStatus: VerificationStatus.PENDING },
      }),
      (this.prisma as any).customerKyc
        ? (this.prisma as any).customerKyc.count({ where: { status: 'PENDING' } })
        : 0,
      (this.prisma as any).payout
        ? (this.prisma as any).payout.count({ where: { status: 'PENDING' } })
        : 0,
      (this.prisma as any).refund
        ? (this.prisma as any).refund.count({ where: { status: 'PENDING' } })
        : 0,
      (this.prisma as any).vendorSecurityDeposit
        ? (this.prisma as any).vendorSecurityDeposit.aggregate({
            _sum: { amount: true },
            where: { status: { in: ['PAID', 'HELD'] } },
          })
        : { _sum: { amount: 0 } },
      this.prisma.car.count(),
      this.prisma.car.count({
        where: { operationalStatus: 'ACTIVE' },
      }),
      (this.prisma as any).dispute
        ? (this.prisma as any).dispute.count({
            where: { status: { in: ['OPEN', 'UNDER_REVIEW'] } },
          })
        : 0,
    ]);

    const todaysRevenue = todaysBookings.reduce(
      (sum, b) => sum + Number(b.platformFee),
      0,
    );

    const grossBookingValue = Number(gbvAggregate?._sum?.totalFare || 0);
    const heldDepositLiability = Number(depositAggregate?._sum?.amount || 0);
    const fleetUtilizationPct =
      totalCars > 0
        ? Math.round(((totalCars - activeCars) / totalCars) * 100)
        : 0;

    return {
      totalUsers,
      totalVendors,
      activeBookings,
      todaysRevenue,
      grossBookingValue,
      pendingVendorApprovals: pendingVendors,
      pendingKycReviews: pendingKyc,
      pendingPayoutsCount: pendingPayouts,
      pendingRefundsCount: pendingRefunds,
      heldDepositLiability,
      totalCars,
      availableCars: activeCars,
      fleetUtilizationPct,
      activeDisputes,
    };
  }

  async getBookingsPerDay(days = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days + 1);
    cutoffDate.setHours(0, 0, 0, 0);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: cutoffDate,
        },
      },
      select: {
        createdAt: true,
      },
    });

    // Initialize map of dates
    const dailyCounts: { [dateStr: string]: number } = {};
    for (let i = 0; i < days; i++) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      dailyCounts[dateStr] = 0;
    }

    // Populate counts
    bookings.forEach((b) => {
      const dateStr = b.createdAt.toISOString().split('T')[0];
      if (dailyCounts[dateStr] !== undefined) {
        dailyCounts[dateStr]++;
      }
    });

    // Format list sorted by date ascending
    return Object.keys(dailyCounts)
      .map((date) => ({ date, count: dailyCounts[date] }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async getRevenuePerCity(days = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days + 1);
    cutoffDate.setHours(0, 0, 0, 0);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: cutoffDate,
        },
        status: {
          not: BookingStatus.CANCELLED,
        },
      },
      select: {
        totalFare: true,
        car: {
          select: {
            vendor: {
              select: {
                city: true,
              },
            },
          },
        },
      },
    });

    const revenueByCity: { [city: string]: number } = {};

    bookings.forEach((b) => {
      const city = b.car?.vendor?.city || 'Unknown';
      const amount = Number(b.totalFare);
      revenueByCity[city] = (revenueByCity[city] || 0) + amount;
    });

    return Object.keys(revenueByCity).map((city) => ({
      city,
      revenue: revenueByCity[city],
    }));
  }

  async getRecentBookings(limit = 10) {
    return this.prisma.booking.findMany({
      take: limit,
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        customer: {
          select: {
            name: true,
            phone: true,
            email: true,
          },
        },
        vendor: {
          select: {
            businessName: true,
            ownerName: true,
          },
        },
        car: {
          select: {
            make: true,
            model: true,
            registrationNumber: true,
          },
        },
      },
    });
  }

  async getPendingVendorApprovals() {
    return this.prisma.vendor.findMany({
      where: {
        verificationStatus: VerificationStatus.PENDING,
      },
      include: {
        user: {
          select: {
            name: true,
            phone: true,
            email: true,
          },
        },
      },
    });
  }

  async getTopVendorsByBookings(limit = 5) {
    const bookings = await this.prisma.booking.findMany({
      where: {
        status: {
          not: BookingStatus.CANCELLED,
        },
      },
      select: {
        vendorId: true,
      },
    });

    const vendorCounts: { [vendorId: string]: number } = {};
    bookings.forEach((b) => {
      vendorCounts[b.vendorId] = (vendorCounts[b.vendorId] || 0) + 1;
    });

    const sortedVendorIds = Object.keys(vendorCounts)
      .sort((a, b) => vendorCounts[b] - vendorCounts[a])
      .slice(0, limit);

    const vendors = await this.prisma.vendor.findMany({
      where: {
        id: {
          in: sortedVendorIds,
        },
      },
      select: {
        id: true,
        businessName: true,
        ownerName: true,
      },
    });

    return sortedVendorIds
      .map((id) => {
        const v = vendors.find((vendor) => vendor.id === id);
        return {
          vendorId: id,
          businessName: v?.businessName || 'Unknown',
          ownerName: v?.ownerName || 'Unknown',
          bookingsCount: vendorCounts[id],
        };
      })
      .sort((a, b) => b.bookingsCount - a.bookingsCount);
  }
}
