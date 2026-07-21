import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../../data/api_admin_dashboard_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return ApiAdminDashboardRepository(apiClient: ref.watch(apiClientProvider));
});

final adminKpisProvider = FutureProvider.autoDispose<AdminKpis>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getKpis();
});

final bookingsPerDayProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getBookingsPerDay(days: 30);
});

final revenuePerCityProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getRevenuePerCity();
});

final recentBookingsProvider = FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getRecentBookings(limit: 10);
});

final pendingVendorApprovalsProvider = FutureProvider.autoDispose<List<VendorModel>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getPendingVendorApprovals();
});

final topVendorsProvider = FutureProvider.autoDispose<List<VendorModel>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getTopVendorsByBookings(limit: 5);
});

class AdminDashboardController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> setVendorApprovalStatus(String vendorId, String status) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(adminDashboardRepositoryProvider).setVendorApprovalStatus(vendorId, status);
      // Invalidate relevant providers to refresh the dashboard UI
      ref.invalidate(adminKpisProvider);
      ref.invalidate(pendingVendorApprovalsProvider);
      ref.invalidate(topVendorsProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final adminDashboardControllerProvider =
    AutoDisposeAsyncNotifierProvider<AdminDashboardController, void>(() {
  return AdminDashboardController();
});
