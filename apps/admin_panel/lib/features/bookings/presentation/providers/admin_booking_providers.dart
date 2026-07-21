import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_booking_repository.dart';
import '../../data/api_admin_booking_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminBookingRepositoryProvider = Provider<AdminBookingRepository>((ref) {
  return ApiAdminBookingRepository(apiClient: ref.watch(apiClientProvider));
});

// Filters
final bookingCityFilterProvider = StateProvider<String?>((ref) => null);
final bookingDateRangeFilterProvider = StateProvider<DateTimeRange?>((ref) => null);
final bookingTripTypeFilterProvider = StateProvider<String?>((ref) => null);
final bookingStatusFilterProvider = StateProvider<String?>((ref) => null);
final bookingVendorFilterProvider = StateProvider<String?>((ref) => null); // Vendor ID
final bookingCarTypeFilterProvider = StateProvider<String?>((ref) => null);

// List Provider watching filters
final adminBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final repo = ref.watch(adminBookingRepositoryProvider);
  
  final city = ref.watch(bookingCityFilterProvider);
  final dateRange = ref.watch(bookingDateRangeFilterProvider);
  final tripType = ref.watch(bookingTripTypeFilterProvider);
  final status = ref.watch(bookingStatusFilterProvider);
  final vendorId = ref.watch(bookingVendorFilterProvider);
  final carType = ref.watch(bookingCarTypeFilterProvider);

  return repo.getBookings(
    city: city,
    dateRange: dateRange,
    tripType: tripType,
    status: status,
    vendorId: vendorId,
    carType: carType,
  );
});

// Family Provider for details
final bookingDetailBundleProvider = FutureProvider.family<BookingDetailBundle, String>((ref, bookingId) async {
  final repo = ref.watch(adminBookingRepositoryProvider);
  return repo.getBookingDetail(bookingId);
});

// Action controller for booking mutations (e.g. override status, dispute)
class AdminBookingController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  AdminBookingController(this._ref) : super(const AsyncValue.data(null));

  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminBookingRepositoryProvider).overrideBookingStatus(bookingId, newStatus);
      _ref.invalidate(adminBookingsProvider);
      _ref.invalidate(bookingDetailBundleProvider(bookingId));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> flagBookingDispute(String bookingId, String note) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminBookingRepositoryProvider).flagBookingDispute(bookingId, note);
      _ref.invalidate(adminBookingsProvider);
      _ref.invalidate(bookingDetailBundleProvider(bookingId));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminBookingControllerProvider = StateNotifierProvider<AdminBookingController, AsyncValue<void>>((ref) {
  return AdminBookingController(ref);
});
