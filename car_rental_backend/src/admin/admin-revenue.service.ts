import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DateRangeDto } from '../common/dto/date-range.dto';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class AdminRevenueService {
  constructor(private prisma: PrismaService) {}

  private parseDates(dto: DateRangeDto) {
    const start = new Date(dto.startDate);
    start.setHours(0, 0, 0, 0);

    const end = new Date(dto.endDate);
    end.setHours(23, 59, 59, 999);

    return { start, end };
  }

  async getRevenueSummary(dto: DateRangeDto) {
    const { start, end } = this.parseDates(dto);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: start,
          lte: end,
        },
      },
      select: {
        totalFare: true,
        platformFee: true,
        gstAmount: true,
        netToVendor: true,
        status: true,
      },
    });

    let grossBookingValue = 0;
    let platformRevenue = 0;
    let gstCollected = 0;
    let vendorPayouts = 0;

    bookings.forEach((b) => {
      if (b.status !== BookingStatus.CANCELLED) {
        grossBookingValue += Number(b.totalFare);
        platformRevenue += Number(b.platformFee);
        gstCollected += Number(b.gstAmount);
      }
      if (b.status === BookingStatus.COMPLETED) {
        vendorPayouts += Number(b.netToVendor);
      }
    });

    return {
      grossBookingValue,
      platformRevenue,
      vendorPayouts,
      gstCollected,
    };
  }

  async getRevenueOverTime(dto: DateRangeDto) {
    const { start, end } = this.parseDates(dto);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: start,
          lte: end,
        },
        status: {
          not: BookingStatus.CANCELLED,
        },
      },
      select: {
        createdAt: true,
        platformFee: true,
      },
    });

    // Generate date map
    const dailyRev: { [dateStr: string]: number } = {};
    const current = new Date(start);
    while (current <= end) {
      const dateStr = current.toISOString().split('T')[0];
      dailyRev[dateStr] = 0;
      current.setDate(current.getDate() + 1);
    }

    bookings.forEach((b) => {
      const dateStr = b.createdAt.toISOString().split('T')[0];
      if (dailyRev[dateStr] !== undefined) {
        dailyRev[dateStr] += Number(b.platformFee);
      }
    });

    return Object.keys(dailyRev)
      .map((date) => ({ date, amount: dailyRev[date] }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async getBookingsByCity(dto: DateRangeDto) {
    const { start, end } = this.parseDates(dto);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: start,
          lte: end,
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

    const cityStats: { [city: string]: { count: number; totalFareSum: number } } = {};

    bookings.forEach((b) => {
      const city = b.car?.vendor?.city || 'Unknown';
      if (!cityStats[city]) {
        cityStats[city] = { count: 0, totalFareSum: 0 };
      }
      cityStats[city].count++;
      cityStats[city].totalFareSum += Number(b.totalFare);
    });

    return Object.keys(cityStats).map((city) => ({
      city,
      count: cityStats[city].count,
      totalFare: cityStats[city].totalFareSum,
    }));
  }

  async getBookingsByTripType(dto: DateRangeDto) {
    const { start, end } = this.parseDates(dto);

    const bookings = await this.prisma.booking.findMany({
      where: {
        createdAt: {
          gte: start,
          lte: end,
        },
      },
      select: {
        tripType: true,
        totalFare: true,
      },
    });

    const tripStats: { [tripType: string]: { count: number; totalFareSum: number } } = {};

    bookings.forEach((b) => {
      const type = b.tripType;
      if (!tripStats[type]) {
        tripStats[type] = { count: 0, totalFareSum: 0 };
      }
      tripStats[type].count++;
      tripStats[type].totalFareSum += Number(b.totalFare);
    });

    return Object.keys(tripStats).map((tripType) => ({
      tripType,
      count: tripStats[tripType].count,
      totalFare: tripStats[tripType].totalFareSum,
    }));
  }

  async getTopVendorsByRevenue(limit = 10) {
    const bookings = await this.prisma.booking.findMany({
      where: {
        status: {
          not: BookingStatus.CANCELLED,
        },
      },
      select: {
        vendorId: true,
        platformFee: true,
      },
    });

    const vendorRevenue: { [vendorId: string]: number } = {};
    bookings.forEach((b) => {
      vendorRevenue[b.vendorId] = (vendorRevenue[b.vendorId] || 0) + Number(b.platformFee);
    });

    const sortedVendorIds = Object.keys(vendorRevenue)
      .sort((a, b) => vendorRevenue[b] - vendorRevenue[a])
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
        city: true,
      },
    });

    return sortedVendorIds
      .map((id) => {
        const v = vendors.find((vendor) => vendor.id === id);
        return {
          vendorId: id,
          businessName: v?.businessName || 'Unknown',
          ownerName: v?.ownerName || 'Unknown',
          city: v?.city || 'Unknown',
          platformRevenueGenerated: vendorRevenue[id],
        };
      })
      .sort((a, b) => b.platformRevenueGenerated - a.platformRevenueGenerated);
  }
}
