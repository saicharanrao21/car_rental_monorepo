import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DateRangeDto } from '../common/dto/date-range.dto';
import { BookingStatus, ReferralStatus, Role } from '@prisma/client';

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

  async getRevenueSummary(dto: DateRangeDto, city?: string) {
    const { start, end } = this.parseDates(dto);

    const whereClause: any = {
      createdAt: {
        gte: start,
        lte: end,
      },
    };

    if (city) {
      whereClause.car = {
        vendor: {
          city: {
            equals: city,
            mode: 'insensitive',
          },
        },
      };
    }

    const bookings = await this.prisma.booking.findMany({
      where: whereClause,
      select: {
        totalFare: true,
        baseFare: true,
        platformFee: true,
        gstAmount: true,
        protectionFee: true,
        deliveryFee: true,
        discountAmount: true,
        netToVendor: true,
        refundAmount: true,
        status: true,
      },
    });

    let grossBookingValue = 0;
    let baseFareRevenue = 0;
    let platformRevenue = 0;
    let gstCollected = 0;
    let protectionRevenue = 0;
    let deliveryRevenue = 0;
    let discountTotal = 0;
    let vendorPayouts = 0;
    let refundTotal = 0;

    bookings.forEach((b) => {
      if (b.status !== BookingStatus.CANCELLED) {
        grossBookingValue += Number(b.totalFare) || 0;
        baseFareRevenue += Number(b.baseFare) || 0;
        platformRevenue += Number(b.platformFee) || 0;
        gstCollected += Number(b.gstAmount) || 0;
        protectionRevenue += Number(b.protectionFee) || 0;
        deliveryRevenue += Number(b.deliveryFee) || 0;
        discountTotal += Number(b.discountAmount) || 0;
      }
      if (b.status === BookingStatus.COMPLETED) {
        vendorPayouts += Number(b.netToVendor) || 0;
      }
      if (b.status === BookingStatus.CANCELLED || (Number(b.refundAmount) || 0) > 0) {
        refundTotal += Number(b.refundAmount) || 0;
      }
    });

    // Net platform revenue is platform fee + protection + delivery minus discount absorbed by platform
    const netPlatformRevenue = Number(
      (platformRevenue + protectionRevenue + deliveryRevenue - discountTotal).toFixed(2),
    );

    // Concurrently fetch platform liability metrics
    const [walletAgg, loyaltyAgg, rewardedReferrals] = await Promise.all([
      this.prisma.wallet.aggregate({
        _sum: { availableBalance: true },
      }),
      this.prisma.loyaltyAccount.aggregate({
        _sum: { pointsBalance: true },
      }),
      this.prisma.referralAttribution.findMany({
        where: {
          status: ReferralStatus.REWARDED,
          rewardedAt: {
            gte: start,
            lte: end,
          },
        },
        select: {
          referrerRewardAmount: true,
          refereeRewardAmount: true,
        },
      }),
    ]);

    const walletLiability = Number(walletAgg._sum.availableBalance) || 0;
    const loyaltyPoints = loyaltyAgg._sum.pointsBalance || 0;
    const loyaltyLiability = Number((loyaltyPoints / 2).toFixed(2));

    const referralCost = rewardedReferrals.reduce(
      (sum, r) => sum + Number(r.referrerRewardAmount) + Number(r.refereeRewardAmount),
      0,
    );

    return {
      // Core existing properties for 100% backward compatibility
      grossBookingValue: Number(grossBookingValue.toFixed(2)),
      platformRevenue: Number(platformRevenue.toFixed(2)),
      vendorPayouts: Number(vendorPayouts.toFixed(2)),
      gstCollected: Number(gstCollected.toFixed(2)),

      // Granular financial components
      baseFareRevenue: Number(baseFareRevenue.toFixed(2)),
      protectionRevenue: Number(protectionRevenue.toFixed(2)),
      deliveryRevenue: Number(deliveryRevenue.toFixed(2)),
      discountTotal: Number(discountTotal.toFixed(2)),
      refundTotal: Number(refundTotal.toFixed(2)),
      netPlatformRevenue,

      // Balance sheet liabilities
      walletLiability,
      loyaltyLiability,
      referralCost,
    };
  }

  async getRevenueOverTime(dto: DateRangeDto, city?: string) {
    const { start, end } = this.parseDates(dto);

    const whereClause: any = {
      createdAt: {
        gte: start,
        lte: end,
      },
      status: {
        not: BookingStatus.CANCELLED,
      },
    };

    if (city) {
      whereClause.car = {
        vendor: {
          city: {
            equals: city,
            mode: 'insensitive',
          },
        },
      };
    }

    const bookings = await this.prisma.booking.findMany({
      where: whereClause,
      select: {
        createdAt: true,
        platformFee: true,
        totalFare: true,
      },
    });

    // Generate date map
    const dailyRev: { [dateStr: string]: { platformFee: number; gmv: number } } = {};
    const current = new Date(start);
    while (current <= end) {
      const dateStr = current.toISOString().split('T')[0];
      dailyRev[dateStr] = { platformFee: 0, gmv: 0 };
      current.setDate(current.getDate() + 1);
    }

    bookings.forEach((b) => {
      const dateStr = b.createdAt.toISOString().split('T')[0];
      if (dailyRev[dateStr] !== undefined) {
        dailyRev[dateStr].platformFee += Number(b.platformFee) || 0;
        dailyRev[dateStr].gmv += Number(b.totalFare) || 0;
      }
    });

    return Object.keys(dailyRev)
      .map((date) => ({
        date,
        amount: Number(dailyRev[date].platformFee.toFixed(2)),
        gmv: Number(dailyRev[date].gmv.toFixed(2)),
      }))
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
        status: true,
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

    const cityStats: {
      [city: string]: { count: number; totalFareSum: number; completedCount: number };
    } = {};

    bookings.forEach((b) => {
      const city = b.car?.vendor?.city || 'Unknown';
      if (!cityStats[city]) {
        cityStats[city] = { count: 0, totalFareSum: 0, completedCount: 0 };
      }
      cityStats[city].count++;
      if (b.status !== BookingStatus.CANCELLED) {
        cityStats[city].totalFareSum += Number(b.totalFare) || 0;
      }
      if (b.status === BookingStatus.COMPLETED) {
        cityStats[city].completedCount++;
      }
    });

    return Object.keys(cityStats).map((city) => ({
      city,
      count: cityStats[city].count,
      totalFare: Number(cityStats[city].totalFareSum.toFixed(2)),
      completedCount: cityStats[city].completedCount,
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
        status: true,
      },
    });

    const tripStats: {
      [tripType: string]: { count: number; totalFareSum: number };
    } = {};

    bookings.forEach((b) => {
      const type = b.tripType;
      if (!tripStats[type]) {
        tripStats[type] = { count: 0, totalFareSum: 0 };
      }
      tripStats[type].count++;
      if (b.status !== BookingStatus.CANCELLED) {
        tripStats[type].totalFareSum += Number(b.totalFare) || 0;
      }
    });

    return Object.keys(tripStats).map((tripType) => ({
      tripType,
      count: tripStats[tripType].count,
      totalFare: Number(tripStats[tripType].totalFareSum.toFixed(2)),
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
        netToVendor: true,
        totalFare: true,
      },
    });

    const vendorRevenue: {
      [vendorId: string]: { platformFee: number; grossFare: number; netPayout: number };
    } = {};

    bookings.forEach((b) => {
      if (!vendorRevenue[b.vendorId]) {
        vendorRevenue[b.vendorId] = { platformFee: 0, grossFare: 0, netPayout: 0 };
      }
      vendorRevenue[b.vendorId].platformFee += Number(b.platformFee) || 0;
      vendorRevenue[b.vendorId].grossFare += Number(b.totalFare) || 0;
      vendorRevenue[b.vendorId].netPayout += Number(b.netToVendor) || 0;
    });

    const sortedVendorIds = Object.keys(vendorRevenue)
      .sort((a, b) => vendorRevenue[b].platformFee - vendorRevenue[a].platformFee)
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
          platformRevenueGenerated: Number(vendorRevenue[id].platformFee.toFixed(2)),
          grossFareGenerated: Number(vendorRevenue[id].grossFare.toFixed(2)),
          netPayout: Number(vendorRevenue[id].netPayout.toFixed(2)),
        };
      })
      .sort((a, b) => b.platformRevenueGenerated - a.platformRevenueGenerated);
  }

  async getBookingLifecycleStats(dto: DateRangeDto, city?: string) {
    const { start, end } = this.parseDates(dto);

    const whereClause: any = {
      createdAt: {
        gte: start,
        lte: end,
      },
    };

    if (city) {
      whereClause.car = {
        vendor: {
          city: {
            equals: city,
            mode: 'insensitive',
          },
        },
      };
    }

    const bookings = await this.prisma.booking.findMany({
      where: whereClause,
      select: {
        id: true,
        status: true,
        totalFare: true,
        startDate: true,
        endDate: true,
        refundAmount: true,
      },
    });

    const totalBookings = bookings.length;
    let completedBookings = 0;
    let cancelledBookings = 0;
    let confirmedBookings = 0;
    let ongoingBookings = 0;
    let pendingBookings = 0;
    let totalNonCancelledFare = 0;
    let nonCancelledCount = 0;
    let totalDurationMs = 0;

    const statusCounts: { [key in BookingStatus]?: number } = {};

    bookings.forEach((b) => {
      statusCounts[b.status] = (statusCounts[b.status] || 0) + 1;

      if (b.status === BookingStatus.COMPLETED) completedBookings++;
      if (b.status === BookingStatus.CANCELLED) cancelledBookings++;
      if (b.status === BookingStatus.CONFIRMED) confirmedBookings++;
      if (b.status === BookingStatus.ONGOING) ongoingBookings++;
      if (b.status === BookingStatus.PENDING) pendingBookings++;

      if (b.status !== BookingStatus.CANCELLED) {
        totalNonCancelledFare += Number(b.totalFare) || 0;
        nonCancelledCount++;
      }

      const dur = b.endDate.getTime() - b.startDate.getTime();
      if (dur > 0) {
        totalDurationMs += dur;
      }
    });

    const completionRate =
      totalBookings > 0 ? Number(((completedBookings / totalBookings) * 100).toFixed(1)) : 0;
    const cancellationRate =
      totalBookings > 0 ? Number(((cancelledBookings / totalBookings) * 100).toFixed(1)) : 0;
    const averageBookingValue =
      nonCancelledCount > 0 ? Number((totalNonCancelledFare / nonCancelledCount).toFixed(2)) : 0;
    const averageDurationDays =
      totalBookings > 0
        ? Number((totalDurationMs / totalBookings / (1000 * 60 * 60 * 24)).toFixed(1))
        : 0;

    return {
      totalBookings,
      completedBookings,
      cancelledBookings,
      confirmedBookings,
      ongoingBookings,
      pendingBookings,
      completionRate,
      cancellationRate,
      averageBookingValue,
      averageDurationDays,
      statusDistribution: statusCounts,
    };
  }

  async getFleetUtilizationStats(city?: string) {
    const whereCar: any = {};
    if (city) {
      whereCar.vendor = {
        city: {
          equals: city,
          mode: 'insensitive',
        },
      };
    }

    const [totalCars, availableCars, ongoingBookings, totalFareAgg] = await Promise.all([
      this.prisma.car.count({ where: whereCar }),
      this.prisma.car.count({
        where: { ...whereCar, isAvailable: true },
      }),
      this.prisma.booking.count({
        where: {
          status: { in: [BookingStatus.ONGOING, BookingStatus.HANDOVER_READY] },
          ...(city
            ? {
                car: {
                  vendor: { city: { equals: city, mode: 'insensitive' } },
                },
              }
            : {}),
        },
      }),
      this.prisma.booking.aggregate({
        where: {
          status: { not: BookingStatus.CANCELLED },
          ...(city
            ? {
                car: {
                  vendor: { city: { equals: city, mode: 'insensitive' } },
                },
              }
            : {}),
        },
        _sum: { totalFare: true },
      }),
    ]);

    const activeCars = ongoingBookings;
    const utilizationRate =
      totalCars > 0 ? Number(((activeCars / totalCars) * 100).toFixed(1)) : 0;
    const totalFareSum = Number(totalFareAgg._sum.totalFare) || 0;
    const avgRevenuePerCar =
      totalCars > 0 ? Number((totalFareSum / totalCars).toFixed(2)) : 0;

    return {
      totalCars,
      availableCars,
      activeCars,
      utilizationRate,
      avgRevenuePerCar,
    };
  }

  async getCustomerGrowthStats(dto: DateRangeDto) {
    const { start, end } = this.parseDates(dto);

    const [totalRegisteredCustomers, newCustomersInRange, allCustomerBookings] =
      await Promise.all([
        this.prisma.user.count({
          where: { role: Role.CUSTOMER },
        }),
        this.prisma.user.count({
          where: {
            role: Role.CUSTOMER,
            createdAt: { gte: start, lte: end },
          },
        }),
        this.prisma.booking.findMany({
          where: {
            status: { not: BookingStatus.CANCELLED },
          },
          select: {
            customerId: true,
            totalFare: true,
          },
        }),
      ]);

    const bookingCountsByCustomer: { [customerId: string]: { count: number; spend: number } } = {};
    allCustomerBookings.forEach((b) => {
      if (!bookingCountsByCustomer[b.customerId]) {
        bookingCountsByCustomer[b.customerId] = { count: 0, spend: 0 };
      }
      bookingCountsByCustomer[b.customerId].count++;
      bookingCountsByCustomer[b.customerId].spend += Number(b.totalFare) || 0;
    });

    const uniqueBookingCustomers = Object.keys(bookingCountsByCustomer).length;
    let repeatCustomers = 0;
    let totalSpend = 0;

    Object.values(bookingCountsByCustomer).forEach((val) => {
      if (val.count >= 2) {
        repeatCustomers++;
      }
      totalSpend += val.spend;
    });

    const repeatCustomerRate =
      uniqueBookingCustomers > 0
        ? Number(((repeatCustomers / uniqueBookingCustomers) * 100).toFixed(1))
        : 0;

    const avgCustomerSpend =
      uniqueBookingCustomers > 0
        ? Number((totalSpend / uniqueBookingCustomers).toFixed(2))
        : 0;

    return {
      totalRegisteredCustomers,
      newCustomersInRange,
      uniqueBookingCustomers,
      repeatCustomers,
      repeatCustomerRate,
      avgCustomerSpend,
    };
  }

  async getAddonAdoptionStats(dto: DateRangeDto, city?: string) {
    const { start, end } = this.parseDates(dto);

    const whereClause: any = {
      createdAt: {
        gte: start,
        lte: end,
      },
    };

    if (city) {
      whereClause.car = {
        vendor: {
          city: {
            equals: city,
            mode: 'insensitive',
          },
        },
      };
    }

    const bookings = await this.prisma.booking.findMany({
      where: whereClause,
      select: {
        protectionFee: true,
        deliveryFee: true,
        driverIncluded: true,
        couponId: true,
        discountAmount: true,
      },
    });

    const totalBookings = bookings.length;
    let protectionCount = 0;
    let deliveryCount = 0;
    let driverCount = 0;
    let couponCount = 0;

    bookings.forEach((b) => {
      if ((Number(b.protectionFee) || 0) > 0) protectionCount++;
      if ((Number(b.deliveryFee) || 0) > 0) deliveryCount++;
      if (b.driverIncluded) driverCount++;
      if (b.couponId || (Number(b.discountAmount) || 0) > 0) couponCount++;
    });

    return {
      totalBookings,
      protectionCount,
      protectionAdoptionRate:
        totalBookings > 0 ? Number(((protectionCount / totalBookings) * 100).toFixed(1)) : 0,
      deliveryCount,
      deliveryAdoptionRate:
        totalBookings > 0 ? Number(((deliveryCount / totalBookings) * 100).toFixed(1)) : 0,
      driverCount,
      driverAdoptionRate:
        totalBookings > 0 ? Number(((driverCount / totalBookings) * 100).toFixed(1)) : 0,
      couponCount,
      couponUsageRate:
        totalBookings > 0 ? Number(((couponCount / totalBookings) * 100).toFixed(1)) : 0,
    };
  }

  async exportRevenueCsv(dto: DateRangeDto, city?: string, status?: BookingStatus): Promise<string> {
    const { start, end } = this.parseDates(dto);

    const whereClause: any = {
      createdAt: {
        gte: start,
        lte: end,
      },
    };

    if (status) {
      whereClause.status = status;
    }

    if (city) {
      whereClause.car = {
        vendor: {
          city: {
            equals: city,
            mode: 'insensitive',
          },
        },
      };
    }

    const bookings = await this.prisma.booking.findMany({
      where: whereClause,
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
            city: true,
          },
        },
        car: {
          select: {
            make: true,
            model: true,
            registrationNumber: true,
          },
        },
        payment: {
          select: {
            status: true,
            refundStatus: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const escapeCsv = (val: any) => {
      if (val === null || val === undefined) return '""';
      const str = String(val).replace(/"/g, '""');
      return `"${str}"`;
    };

    const headers = [
      'Booking ID',
      'Created At',
      'Customer Name',
      'Customer Phone',
      'Vendor Business',
      'Car',
      'Registration',
      'City',
      'Trip Type',
      'Status',
      'Start Date',
      'End Date',
      'Base Fare (INR)',
      'Platform Fee (INR)',
      'GST (INR)',
      'Protection Fee (INR)',
      'Delivery Fee (INR)',
      'Discount (INR)',
      'Total Fare (INR)',
      'Net to Vendor (INR)',
      'Payment Status',
      'Refund Status',
    ];

    const rows = bookings.map((b) => [
      escapeCsv(b.id),
      escapeCsv(b.createdAt.toISOString()),
      escapeCsv(b.customer?.name || 'N/A'),
      escapeCsv(b.customer?.phone || 'N/A'),
      escapeCsv(b.vendor?.businessName || 'N/A'),
      escapeCsv(`${b.car?.make || ''} ${b.car?.model || ''}`.trim()),
      escapeCsv(b.car?.registrationNumber || 'N/A'),
      escapeCsv(b.vendor?.city || 'N/A'),
      escapeCsv(b.tripType),
      escapeCsv(b.status),
      escapeCsv(b.startDate.toISOString()),
      escapeCsv(b.endDate.toISOString()),
      escapeCsv(Number(b.baseFare) || 0),
      escapeCsv(Number(b.platformFee) || 0),
      escapeCsv(Number(b.gstAmount) || 0),
      escapeCsv(Number(b.protectionFee) || 0),
      escapeCsv(Number(b.deliveryFee) || 0),
      escapeCsv(Number(b.discountAmount) || 0),
      escapeCsv(Number(b.totalFare) || 0),
      escapeCsv(Number(b.netToVendor) || 0),
      escapeCsv(b.payment?.status || 'UNPAID'),
      escapeCsv(b.payment?.refundStatus || 'NONE'),
    ]);

    return [headers.join(','), ...rows.map((r) => r.join(','))].join('\r\n');
  }
}
