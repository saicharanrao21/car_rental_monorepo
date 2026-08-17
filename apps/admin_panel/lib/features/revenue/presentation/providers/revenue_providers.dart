import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/revenue/domain/repositories/revenue_repository.dart';
import 'package:admin_panel/features/revenue/data/api_revenue_repository.dart';

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiRevenueRepository(apiClient);
});

// Default: This month (start of month to end of today)
final revenueDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return DateTimeRange(start: startOfMonth, end: endOfToday);
});

final revenueCityFilterProvider = StateProvider<String?>((ref) => null);

// Summary provider
final revenueSummaryProvider = FutureProvider<RevenueSummaryModel>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  final city = ref.watch(revenueCityFilterProvider);
  return repo.getSummary(range, city: city);
});

// Time series provider
final revenueOverTimeProvider = FutureProvider<List<double>>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  final city = ref.watch(revenueCityFilterProvider);
  return repo.getRevenueOverTime(range, city: city);
});

// City breakdown provider
final bookingsByCityProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  return repo.getBookingsByCity(range);
});

// Trip type breakdown provider
final bookingsByTripTypeProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  return repo.getBookingsByTripType(range);
});

// Top vendors provider
final topVendorsByRevenueProvider = FutureProvider<List<VendorModel>>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  ref.watch(revenueDateRangeProvider);
  return repo.getTopVendorsByRevenue(limit: 10);
});

// Booking lifecycle stats provider
final bookingLifecycleStatsProvider = FutureProvider<BookingLifecycleStatsModel>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  final city = ref.watch(revenueCityFilterProvider);
  return repo.getBookingLifecycleStats(range, city: city);
});

// Fleet utilization provider
final fleetUtilizationProvider = FutureProvider<FleetUtilizationModel>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final city = ref.watch(revenueCityFilterProvider);
  return repo.getFleetUtilizationStats(city: city);
});

// Customer growth provider
final customerGrowthStatsProvider = FutureProvider<CustomerGrowthModel>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  return repo.getCustomerGrowthStats(range);
});

// Addon adoption provider
final addonAdoptionStatsProvider = FutureProvider<AddonAdoptionModel>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  final city = ref.watch(revenueCityFilterProvider);
  return repo.getAddonAdoptionStats(range, city: city);
});
