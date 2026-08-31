import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/models/operations_models.dart';
import '../../data/api_dashboard_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import 'package:models/models.dart';
import '../../../bookings/presentation/providers/vendor_bookings_providers.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return ApiDashboardRepository(apiClient: ref.watch(apiClientProvider));
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    throw Exception('No vendor logged in');
  }
  return ref.read(dashboardRepositoryProvider).getStats(vendorId);
});

final latestBookingRequestsProvider = FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    throw Exception('No vendor logged in');
  }
  return ref.read(dashboardRepositoryProvider).getLatestBookingRequests(vendorId);
});

final operationsTriageProvider = FutureProvider.autoDispose<List<TriageItem>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    return [];
  }
  return ref.read(dashboardRepositoryProvider).getOperationsTriage(vendorId);
});

final todayOperationsProvider = FutureProvider.autoDispose<List<TodayTimelineItem>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    return [];
  }
  return ref.read(dashboardRepositoryProvider).getTodayOperations(vendorId);
});

final bookingMatrixProvider = FutureProvider.autoDispose<BookingMatrix>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    return const BookingMatrix(
      todayCount: 0,
      pendingCount: 0,
      upcomingCount: 0,
      completedCount: 0,
      activeCount: 0,
    );
  }
  return ref.read(dashboardRepositoryProvider).getBookingMatrix(vendorId);
});

final fleetSummaryProvider = FutureProvider.autoDispose<FleetSummary>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    return const FleetSummary(
      totalCars: 0,
      availableCars: 0,
      onTripCars: 0,
      unavailableCars: 0,
    );
  }
  return ref.read(dashboardRepositoryProvider).getFleetSummary(vendorId);
});

final earningsSnapshotProvider = FutureProvider.autoDispose<EarningsSnapshot>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    return const EarningsSnapshot(
      thisMonthEarnings: 0,
      availableBalance: 0,
      heldEarnings: 0,
      totalEarnings: 0,
      totalPaidOut: 0,
    );
  }
  return ref.read(dashboardRepositoryProvider).getEarningsSnapshot(vendorId);
});

class DashboardController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> respondToBooking(String bookingId, bool accept) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(vendorBookingsRepositoryProvider).updateBookingStatus(
        bookingId,
        accept ? 'confirmed' : 'cancelled',
      );
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(latestBookingRequestsProvider);
      ref.invalidate(operationsTriageProvider);
      ref.invalidate(todayOperationsProvider);
      ref.invalidate(bookingMatrixProvider);
      ref.invalidate(vendorBookingsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> rejectBooking(String bookingId, String reason) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(vendorBookingsRepositoryProvider).rejectBooking(bookingId, reason);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(latestBookingRequestsProvider);
      ref.invalidate(operationsTriageProvider);
      ref.invalidate(todayOperationsProvider);
      ref.invalidate(bookingMatrixProvider);
      ref.invalidate(vendorBookingsProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final dashboardControllerProvider = AutoDisposeAsyncNotifierProvider<DashboardController, void>(() {
  return DashboardController();
});

