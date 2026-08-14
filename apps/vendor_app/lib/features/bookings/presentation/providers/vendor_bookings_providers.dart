import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/vendor_bookings_repository.dart';
import '../../data/api_vendor_bookings_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

final vendorBookingsRepositoryProvider = Provider<VendorBookingsRepository>((ref) {
  return ApiVendorBookingsRepository(apiClient: ref.watch(apiClientProvider));
});

final vendorBookingsTabProvider = StateProvider<int>((ref) => 0);

final vendorBookingsProvider = AsyncNotifierProvider.autoDispose<VendorBookingsNotifier, List<BookingModel>>(() {
  return VendorBookingsNotifier();
});

final bookingInspectionsProvider = FutureProvider.family.autoDispose<List<InspectionModel>, String>((ref, bookingId) async {
  final repo = ref.watch(vendorBookingsRepositoryProvider);
  return repo.getInspections(bookingId);
});

class VendorBookingsNotifier extends AutoDisposeAsyncNotifier<List<BookingModel>> {
  @override
  FutureOr<List<BookingModel>> build() async {
    final session = ref.watch(vendorSessionProvider);
    final vendorId = session.vendor?.id;
    if (vendorId == null) {
      return [];
    }

    final tabIndex = ref.watch(vendorBookingsTabProvider);
    final statusFilter = _getStatusForTab(tabIndex);

    final list = await ref.watch(vendorBookingsRepositoryProvider).getBookingsForVendor(
      vendorId,
      statusFilter: statusFilter,
    );
    // Sort by createdAt descending
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  String _getStatusForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'pending';
      case 1:
        return 'confirmed';
      case 2:
        return 'ongoing';
      case 3:
        return 'completed';
      case 4:
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  Future<bool> updateStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.updateBookingStatus(
        bookingId,
        newStatus,
        handoverOtp: handoverOtp,
        reason: reason,
      );
    });
    ref.invalidateSelf();
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(latestBookingRequestsProvider);
    ref.invalidate(bookingInspectionsProvider(bookingId));
    return !result.hasError;
  }

  Future<bool> reject(String bookingId, String reason) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.rejectBooking(bookingId, reason);
    });
    ref.invalidateSelf();
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(latestBookingRequestsProvider);
    return !result.hasError;
  }

  Future<bool> submitInspection(
    String bookingId, {
    required String type,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool finalize = true,
  }) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.upsertInspection(
        bookingId,
        type: type,
        odometer: odometer,
        fuelPercent: fuelPercent,
        conditionNotes: conditionNotes,
        damagePhotos: damagePhotos,
        finalize: finalize,
      );
    });
    ref.invalidate(bookingInspectionsProvider(bookingId));
    return !result.hasError;
  }

  Future<bool> sendHandoverOtp(String bookingId, String otpType) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.sendHandoverOtp(bookingId, otpType);
    });
    return !result.hasError;
  }
}
