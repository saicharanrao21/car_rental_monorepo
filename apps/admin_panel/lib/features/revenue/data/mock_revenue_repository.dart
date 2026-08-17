import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/revenue_repository.dart';

class MockRevenueRepository with LatencySimulator implements RevenueRepository {
  @override
  Future<RevenueSummaryModel> getSummary(DateTimeRange range, {String? city}) async {
    await simulateLatency();

    final filteredBookings = MockData.bookings.where((b) {
      return b.createdAt.isAfter(range.start) && b.createdAt.isBefore(range.end);
    }).toList();

    if (filteredBookings.isEmpty) {
      final days = range.end.difference(range.start).inDays.clamp(1, 30);
      return RevenueSummaryModel(
        grossBookingValue: days * 12500.0,
        platformRevenue: days * 1250.0,
        vendorPayouts: days * 10000.0,
        gstCollected: days * 225.0,
        baseFareRevenue: days * 10000.0,
        protectionRevenue: days * 500.0,
        deliveryRevenue: days * 400.0,
        discountTotal: days * 100.0,
        refundTotal: days * 50.0,
        netPlatformRevenue: days * 2050.0,
        walletLiability: 15000.0,
        loyaltyLiability: 2500.0,
        referralCost: 500.0,
      );
    }

    double gross = 0.0;
    double platform = 0.0;
    double payouts = 0.0;
    double gst = 0.0;
    double base = 0.0;

    for (final b in filteredBookings) {
      gross += b.totalFare;
      platform += b.platformFee;
      payouts += b.netToVendor;
      gst += b.gstAmount;
      base += (b.totalFare - b.platformFee - b.gstAmount);
    }

    return RevenueSummaryModel(
      grossBookingValue: gross,
      platformRevenue: platform,
      vendorPayouts: payouts,
      gstCollected: gst,
      baseFareRevenue: base,
      protectionRevenue: 500.0,
      deliveryRevenue: 400.0,
      discountTotal: 100.0,
      refundTotal: 0.0,
      netPlatformRevenue: platform + 800.0,
      walletLiability: 15000.0,
      loyaltyLiability: 2500.0,
      referralCost: 500.0,
    );
  }

  @override
  Future<List<double>> getRevenueOverTime(DateTimeRange range, {String? city}) async {
    await simulateLatency();
    final days = range.end.difference(range.start).inDays.clamp(2, 30);
    final List<double> values = [];

    for (int i = 0; i < days; i++) {
      final dayStart = range.start.add(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayRevenue = MockData.bookings
          .where((b) => b.createdAt.isAfter(dayStart) && b.createdAt.isBefore(dayEnd))
          .map((b) => b.platformFee)
          .fold(0.0, (sum, val) => sum + val);

      if (dayRevenue == 0.0) {
        values.add(1000.0 + ((dayStart.day * 17) % 15) * 200.0);
      } else {
        values.add(dayRevenue);
      }
    }
    return values;
  }

  @override
  Future<Map<String, double>> getBookingsByCity(DateTimeRange range) async {
    await simulateLatency();
    final Map<String, double> cityMap = {};

    for (final b in MockData.bookings) {
      if (b.createdAt.isAfter(range.start) && b.createdAt.isBefore(range.end)) {
        final vendor = MockData.vendors.firstWhere(
          (v) => v.id == b.vendorId,
          orElse: () => const VendorModel(id: '', businessName: '', ownerName: '', city: 'Other', verificationStatus: ''),
        );
        if (vendor.city.isNotEmpty) {
          cityMap[vendor.city] = (cityMap[vendor.city] ?? 0.0) + 1.0;
        }
      }
    }

    if (cityMap.isEmpty) {
      cityMap['Mumbai'] = 14;
      cityMap['Delhi'] = 10;
      cityMap['Bangalore'] = 8;
      cityMap['Chennai'] = 5;
      cityMap['Hyderabad'] = 6;
    }
    return cityMap;
  }

  @override
  Future<Map<String, int>> getBookingsByTripType(DateTimeRange range) async {
    await simulateLatency();
    final Map<String, int> typeMap = {};

    for (final b in MockData.bookings) {
      if (b.createdAt.isAfter(range.start) && b.createdAt.isBefore(range.end)) {
        typeMap[b.tripType] = (typeMap[b.tripType] ?? 0) + 1;
      }
    }

    if (typeMap.isEmpty) {
      typeMap['Local'] = 15;
      typeMap['Outstation'] = 12;
      typeMap['Airport Transfer'] = 8;
      typeMap['Self-Drive'] = 10;
    }
    return typeMap;
  }

  @override
  Future<List<VendorModel>> getTopVendorsByRevenue({int limit = 10}) async {
    await simulateLatency();
    return MockData.vendors.take(limit).toList();
  }

  @override
  Future<BookingLifecycleStatsModel> getBookingLifecycleStats(DateTimeRange range, {String? city}) async {
    await simulateLatency();
    return const BookingLifecycleStatsModel(
      totalBookings: 25,
      completedBookings: 18,
      cancelledBookings: 3,
      confirmedBookings: 2,
      ongoingBookings: 1,
      pendingBookings: 1,
      completionRate: 72.0,
      cancellationRate: 12.0,
      averageBookingValue: 4200.0,
      averageDurationDays: 2.3,
      statusDistribution: {'COMPLETED': 18, 'CANCELLED': 3, 'CONFIRMED': 2, 'ONGOING': 1, 'PENDING': 1},
    );
  }

  @override
  Future<FleetUtilizationModel> getFleetUtilizationStats({String? city}) async {
    await simulateLatency();
    return const FleetUtilizationModel(
      totalCars: 40,
      availableCars: 28,
      activeCars: 12,
      utilizationRate: 30.0,
      avgRevenuePerCar: 5200.0,
    );
  }

  @override
  Future<CustomerGrowthModel> getCustomerGrowthStats(DateTimeRange range) async {
    await simulateLatency();
    return const CustomerGrowthModel(
      totalRegisteredCustomers: 150,
      newCustomersInRange: 25,
      uniqueBookingCustomers: 45,
      repeatCustomers: 18,
      repeatCustomerRate: 40.0,
      avgCustomerSpend: 5400.0,
    );
  }

  @override
  Future<AddonAdoptionModel> getAddonAdoptionStats(DateTimeRange range, {String? city}) async {
    await simulateLatency();
    return const AddonAdoptionModel(
      totalBookings: 25,
      protectionCount: 14,
      protectionAdoptionRate: 56.0,
      deliveryCount: 10,
      deliveryAdoptionRate: 40.0,
      driverCount: 5,
      driverAdoptionRate: 20.0,
      couponCount: 8,
      couponUsageRate: 32.0,
    );
  }

  @override
  Future<String> exportRevenueCsv(DateTimeRange range, {String? city, String? status}) async {
    await simulateLatency();
    return 'Booking ID,Created At,Customer Name,Total Fare\r\n"bkg_1","2026-08-01","John Doe","5000"';
  }
}
