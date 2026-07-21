import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_fleet_repository.dart';
import '../../data/api_admin_fleet_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminFleetRepositoryProvider = Provider<AdminFleetRepository>((ref) {
  return ApiAdminFleetRepository(apiClient: ref.watch(apiClientProvider));
});

// Filters
final fleetCityFilterProvider = StateProvider<String?>((ref) => null);
final fleetCarTypeFilterProvider = StateProvider<String?>((ref) => null);
final fleetAvailabilityFilterProvider = StateProvider<bool?>((ref) => null);
final fleetVendorFilterProvider = StateProvider<String?>((ref) => null);

// List Provider watching filters
final adminFleetProvider = FutureProvider<List<CarModel>>((ref) async {
  final repo = ref.watch(adminFleetRepositoryProvider);

  final city = ref.watch(fleetCityFilterProvider);
  final carType = ref.watch(fleetCarTypeFilterProvider);
  final isAvailable = ref.watch(fleetAvailabilityFilterProvider);
  final vendorId = ref.watch(fleetVendorFilterProvider);

  return repo.getAllCars(
    city: city,
    carType: carType,
    isAvailable: isAvailable,
    vendorId: vendorId,
  );
});

// Family Provider for details
final carDetailProvider = FutureProvider.family<CarModel, String>((ref, carId) async {
  final repo = ref.watch(adminFleetRepositoryProvider);
  return repo.getCarDetail(carId);
});

// Action controller for fleet mutations
class AdminFleetController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AdminFleetController(this._ref) : super(const AsyncValue.data(null));

  Future<void> deactivateCarListing(String carId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).deactivateCarListing(carId);
      _ref.invalidate(adminFleetProvider);
      _ref.invalidate(carDetailProvider(carId));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminFleetControllerProvider = StateNotifierProvider<AdminFleetController, AsyncValue<void>>((ref) {
  return AdminFleetController(ref);
});
