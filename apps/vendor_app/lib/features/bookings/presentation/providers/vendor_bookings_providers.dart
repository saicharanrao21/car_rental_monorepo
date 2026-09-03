import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/vendor_bookings_repository.dart';
import '../../data/api_vendor_bookings_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../fleet/presentation/providers/fleet_providers.dart';

final vendorBookingsRepositoryProvider = Provider<VendorBookingsRepository>((ref) {
  return ApiVendorBookingsRepository(apiClient: ref.watch(apiClientProvider));
});

final vendorBookingsTabProvider = StateProvider<int>((ref) => 0);

final operationsFilterTabProvider = StateProvider<int>((ref) => 0); // 0: All, 1: Handover, 2: Vehicle Out, 3: Return Due, 4: Completed

final vendorBookingsProvider = AsyncNotifierProvider.autoDispose<VendorBookingsNotifier, List<BookingModel>>(() {
  return VendorBookingsNotifier();
});

final singleBookingProvider = FutureProvider.family.autoDispose<BookingModel?, String>((ref, bookingId) async {
  final bookingsAsync = ref.watch(vendorBookingsProvider);
  final inMemory = bookingsAsync.valueOrNull?.where((b) => b.id == bookingId).firstOrNull;
  if (inMemory != null) return inMemory;

  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) return null;

  try {
    final list = await ref.watch(vendorBookingsRepositoryProvider).getBookingsForVendor(vendorId);
    return list.where((b) => b.id == bookingId).firstOrNull;
  } catch (_) {
    return null;
  }
});

final bookingInspectionsProvider = FutureProvider.family.autoDispose<List<InspectionModel>, String>((ref, bookingId) async {
  try {
    final repo = ref.watch(vendorBookingsRepositoryProvider);
    return await repo.getInspections(bookingId);
  } catch (_) {
    return [];
  }
});

final bookingDamageClaimsProvider = FutureProvider.family.autoDispose<List<DamageClaimModel>, String>((ref, bookingId) async {
  try {
    final repo = ref.watch(vendorBookingsRepositoryProvider);
    return await repo.getDamageClaims(bookingId);
  } catch (_) {
    return [];
  }
});

final vendorBookingEmergencyProvider =
    FutureProvider.family.autoDispose<EmergencyRequestModel?, String>((ref, bookingId) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.dio.get('/emergency/requests/booking/$bookingId');
    if (response.data == null) return null;
    return EmergencyRequestModel.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Local offline drafts stored in-memory for network failure resilience
final offlineInspectionDraftsProvider = StateProvider<Map<String, Map<String, dynamic>>>((ref) => {});

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
    ref.invalidate(fleetCarsProvider);
    return !result.hasError;
  }

  Future<bool> markHandoverReady(String bookingId) async {
    return updateStatus(bookingId, 'handover_ready');
  }

  Future<bool> initiateReturn(String bookingId) async {
    return updateStatus(bookingId, 'return_pending');
  }

  Future<bool> reject(String bookingId, String reason) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.rejectBooking(bookingId, reason);
    });
    ref.invalidateSelf();
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(latestBookingRequestsProvider);
    ref.invalidate(fleetCarsProvider);
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

  Future<bool> completeHandover({
    required String bookingId,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    String? handoverOtp,
  }) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.upsertInspection(
        bookingId,
        type: 'PRE_TRIP',
        odometer: odometer,
        fuelPercent: fuelPercent,
        conditionNotes: conditionNotes,
        damagePhotos: damagePhotos,
        finalize: true,
      );
      await repo.updateBookingStatus(
        bookingId,
        'ongoing',
        handoverOtp: handoverOtp,
      );
    });

    ref.invalidateSelf();
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(latestBookingRequestsProvider);
    ref.invalidate(bookingInspectionsProvider(bookingId));
    ref.invalidate(fleetCarsProvider);
    return !result.hasError;
  }

  Future<bool> completeReturn({
    required String bookingId,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    String? returnOtp,
  }) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.upsertInspection(
        bookingId,
        type: 'POST_TRIP',
        odometer: odometer,
        fuelPercent: fuelPercent,
        conditionNotes: conditionNotes,
        damagePhotos: damagePhotos,
        finalize: true,
      );
      if (returnOtp != null && returnOtp.isNotEmpty) {
        await repo.updateBookingStatus(
          bookingId,
          'completed',
          handoverOtp: returnOtp,
        );
      }
    });

    ref.invalidateSelf();
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(latestBookingRequestsProvider);
    ref.invalidate(bookingInspectionsProvider(bookingId));
    ref.invalidate(fleetCarsProvider);
    return !result.hasError;
  }

  Future<bool> sendHandoverOtp(String bookingId, String otpType) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.sendHandoverOtp(bookingId, otpType);
    });
    return !result.hasError;
  }

  Future<bool> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  }) async {
    final repo = ref.read(vendorBookingsRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.submitDamageClaim(
        bookingId,
        claimedAmount: claimedAmount,
        description: description,
        damagePhotos: damagePhotos,
        vendorNotes: vendorNotes,
      );
    });
    ref.invalidate(bookingDamageClaimsProvider(bookingId));
    return !result.hasError;
  }
}
