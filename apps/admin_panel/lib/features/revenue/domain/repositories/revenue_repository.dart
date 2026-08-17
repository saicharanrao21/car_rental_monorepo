import 'package:flutter/material.dart';
import 'package:models/models.dart';

typedef RevenueSummary = RevenueSummaryModel;

abstract class RevenueRepository {
  Future<RevenueSummaryModel> getSummary(DateTimeRange range, {String? city});
  Future<List<double>> getRevenueOverTime(DateTimeRange range, {String? city});
  Future<Map<String, double>> getBookingsByCity(DateTimeRange range);
  Future<Map<String, int>> getBookingsByTripType(DateTimeRange range);
  Future<List<VendorModel>> getTopVendorsByRevenue({int limit = 10});
  Future<BookingLifecycleStatsModel> getBookingLifecycleStats(DateTimeRange range, {String? city});
  Future<FleetUtilizationModel> getFleetUtilizationStats({String? city});
  Future<CustomerGrowthModel> getCustomerGrowthStats(DateTimeRange range);
  Future<AddonAdoptionModel> getAddonAdoptionStats(DateTimeRange range, {String? city});
  Future<String> exportRevenueCsv(DateTimeRange range, {String? city, String? status});
}
