import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_vendor_repository.dart';
import '../../data/mock_admin_vendor_repository.dart';

final adminVendorRepositoryProvider = Provider<AdminVendorRepository>((ref) {
  return MockAdminVendorRepository();
});

// Filters
final vendorCityFilterProvider = StateProvider<String?>((ref) => null);
final vendorStatusFilterProvider = StateProvider<String?>((ref) => null);
final vendorSearchQueryProvider = StateProvider<String>((ref) => '');

// List Provider watching filters
final adminVendorsProvider = FutureProvider<List<VendorModel>>((ref) async {
  final repo = ref.watch(adminVendorRepositoryProvider);
  final city = ref.watch(vendorCityFilterProvider);
  final status = ref.watch(vendorStatusFilterProvider);
  final search = ref.watch(vendorSearchQueryProvider);

  return repo.getVendors(
    city: city,
    status: status,
    searchQuery: search,
  );
});

// Detail Bundle
class VendorDetailBundle {
  final VendorModel vendor;
  final int carCount;
  final int bookingCount;
  final List<BookingModel> bookingHistory;

  const VendorDetailBundle({
    required this.vendor,
    required this.carCount,
    required this.bookingCount,
    required this.bookingHistory,
  });
}

// Family Provider for details
final vendorDetailBundleProvider = FutureProvider.family<VendorDetailBundle, String>((ref, vendorId) async {
  final repo = ref.watch(adminVendorRepositoryProvider);

  final vendor = await repo.getVendorById(vendorId);
  final carCount = await repo.getCarCountForVendor(vendorId);
  final bookingCount = await repo.getBookingCountForVendor(vendorId);
  final bookingHistory = await repo.getBookingHistoryForVendor(vendorId);

  return VendorDetailBundle(
    vendor: vendor,
    carCount: carCount,
    bookingCount: bookingCount,
    bookingHistory: bookingHistory,
  );
});

// Action controller for vendor mutations (e.g. approve, suspend, remove, bulk approve)
class AdminVendorController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AdminVendorController(this._ref) : super(const AsyncValue.data(null));

  Future<void> setVendorStatus(String id, String status) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminVendorRepositoryProvider).setVendorStatus(id, status);
      // Invalidate the vendor list and detail provider
      _ref.invalidate(adminVendorsProvider);
      _ref.invalidate(vendorDetailBundleProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> bulkApprove(List<String> ids) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(adminVendorRepositoryProvider);
      for (final id in ids) {
        await repo.setVendorStatus(id, 'verified');
        _ref.invalidate(vendorDetailBundleProvider(id));
      }
      _ref.invalidate(adminVendorsProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminVendorControllerProvider = StateNotifierProvider<AdminVendorController, AsyncValue<void>>((ref) {
  return AdminVendorController(ref);
});
