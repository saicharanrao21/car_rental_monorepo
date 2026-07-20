import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
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
      ref.invalidate(vendorBookingsProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final dashboardControllerProvider = AutoDisposeAsyncNotifierProvider<DashboardController, void>(() {
  return DashboardController();
});
