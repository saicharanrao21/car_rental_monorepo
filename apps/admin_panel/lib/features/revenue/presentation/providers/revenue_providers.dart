import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/revenue/domain/repositories/revenue_repository.dart';
import 'package:admin_panel/features/revenue/data/mock_revenue_repository.dart';

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return MockRevenueRepository();
});

// Default: This month (start of month to end of today)
final revenueDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return DateTimeRange(start: startOfMonth, end: endOfToday);
});

// Summary provider
final revenueSummaryProvider = FutureProvider<RevenueSummary>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  return repo.getSummary(range);
});

// Time series provider
final revenueOverTimeProvider = FutureProvider<List<double>>((ref) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final range = ref.watch(revenueDateRangeProvider);
  return repo.getRevenueOverTime(range);
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
  // Re-watches range to trigger update if needed, limit to 10
  ref.watch(revenueDateRangeProvider);
  return repo.getTopVendorsByRevenue(limit: 10);
});
