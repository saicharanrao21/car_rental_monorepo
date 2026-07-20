import 'package:flutter/material.dart';
import 'package:models/models.dart';

class RevenueSummary {
  final double grossBookingValue;
  final double platformRevenue;
  final double vendorPayouts;
  final double gstCollected;

  const RevenueSummary({
    required this.grossBookingValue,
    required this.platformRevenue,
    required this.vendorPayouts,
    required this.gstCollected,
  });
}

abstract class RevenueRepository {
  Future<RevenueSummary> getSummary(DateTimeRange range);
  Future<List<double>> getRevenueOverTime(DateTimeRange range);
  Future<Map<String, double>> getBookingsByCity(DateTimeRange range);
  Future<Map<String, int>> getBookingsByTripType(DateTimeRange range);
  Future<List<VendorModel>> getTopVendorsByRevenue({int limit = 10});
}
