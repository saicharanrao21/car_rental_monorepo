import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/revenue_repository.dart';

class MockRevenueRepository with LatencySimulator implements RevenueRepository {
  @override
  Future<RevenueSummary> getSummary(DateTimeRange range) async {
    await simulateLatency();

    final filteredBookings = MockData.bookings.where((b) {
      return b.createdAt.isAfter(range.start) && b.createdAt.isBefore(range.end);
    }).toList();

    if (filteredBookings.isEmpty) {
      // Synthesize realistic summary data if mock data is sparse
      final days = range.end.difference(range.start).inDays.clamp(1, 30);
      return RevenueSummary(
        grossBookingValue: days * 12500.0,
        platformRevenue: days * 1250.0,
        vendorPayouts: days * 10000.0,
        gstCollected: days * 225.0,
      );
    }

    double gross = 0.0;
    double platform = 0.0;
    double payouts = 0.0;
    double gst = 0.0;

    for (final b in filteredBookings) {
      gross += b.totalFare;
      platform += b.platformFee;
      payouts += b.netToVendor;
      gst += b.gstAmount;
    }

    return RevenueSummary(
      grossBookingValue: gross,
      platformRevenue: platform,
      vendorPayouts: payouts,
      gstCollected: gst,
    );
  }

  @override
  Future<List<double>> getRevenueOverTime(DateTimeRange range) async {
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
        // Synthesize variance to make it visually look premium
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

    final Map<String, double> vendorRevenue = {};
    for (final b in MockData.bookings) {
      vendorRevenue[b.vendorId] = (vendorRevenue[b.vendorId] ?? 0.0) + b.totalFare;
    }

    // fallback for empty case
    if (vendorRevenue.isEmpty) {
      for (final v in MockData.vendors) {
        vendorRevenue[v.id] = (v.rating * 15000.0) + (v.totalTrips * 350.0);
      }
    }

    final sortedVendors = List<VendorModel>.from(MockData.vendors);
    sortedVendors.sort((a, b) {
      final revA = vendorRevenue[a.id] ?? 0.0;
      final revB = vendorRevenue[b.id] ?? 0.0;
      return revB.compareTo(revA);
    });

    return sortedVendors.take(limit).toList();
  }
}
