import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_fleet_repository.dart';
import '../../domain/models/vendor_fleet_models.dart';
import '../../data/api_admin_fleet_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminFleetRepositoryProvider = Provider<AdminFleetRepository>((ref) {
  return ApiAdminFleetRepository(apiClient: ref.watch(apiClientProvider));
});

// --- KPIs ---
final fleetKpisProvider = FutureProvider<FleetKpisModel>((ref) async {
  final repo = ref.watch(adminFleetRepositoryProvider);
  return repo.getFleetKPIs();
});

// --- Filters ---
final fleetSearchQueryProvider = StateProvider<String?>((ref) => null);
final fleetCityFilterProvider = StateProvider<String?>((ref) => null);
final fleetCarTypeFilterProvider = StateProvider<String?>((ref) => null);
final fleetAvailabilityFilterProvider = StateProvider<bool?>((ref) => null);
final fleetVendorFilterProvider = StateProvider<String?>((ref) => null);
final fleetServiceAreaFilterProvider = StateProvider<String?>((ref) => null);
final fleetOperationalStatusFilterProvider = StateProvider<String?>((ref) => null);
final fleetVerificationStatusFilterProvider = StateProvider<String?>((ref) => null);

// --- Operations Fleet Vehicles Provider ---
final adminFleetVehiclesProvider = FutureProvider<List<AdminFleetVehicleModel>>((ref) async {
  final repo = ref.watch(adminFleetRepositoryProvider);

  final search = ref.watch(fleetSearchQueryProvider);
  final city = ref.watch(fleetCityFilterProvider);
  final vendorId = ref.watch(fleetVendorFilterProvider);
  final serviceAreaId = ref.watch(fleetServiceAreaFilterProvider);
  final opStatus = ref.watch(fleetOperationalStatusFilterProvider);
  final verStatus = ref.watch(fleetVerificationStatusFilterProvider);

  return repo.getFleetVehicles(
    search: search,
    city: city,
    vendorId: vendorId,
    serviceAreaId: serviceAreaId,
    operationalStatus: opStatus,
    verificationStatus: verStatus,
  );
});

// --- Legacy List Provider ---
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

// --- Family Providers ---
final carDetailProvider = FutureProvider.family<CarModel, String>((ref, carId) async {
  final repo = ref.watch(adminFleetRepositoryProvider);
  return repo.getCarDetail(carId);
});

final vehicleReadinessProvider = FutureProvider.family<VehicleReadinessModel, String>((ref, carId) async {
  final repo = ref.watch(adminFleetRepositoryProvider);
  return repo.getVehicleReadiness(carId);
});

final vehicleAuditLogsProvider = FutureProvider.family<List<VehicleAuditLogModel>, String>((ref, carId) async {
  final repo = ref.watch(adminFleetRepositoryProvider);
  return repo.getVehicleAuditLogs(carId);
});

// --- Action controller for fleet mutations ---
class AdminFleetController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AdminFleetController(this._ref) : super(const AsyncValue.data(null));

  void _invalidateAll(String carId) {
    _ref.invalidate(fleetKpisProvider);
    _ref.invalidate(adminFleetVehiclesProvider);
    _ref.invalidate(adminFleetProvider);
    _ref.invalidate(carDetailProvider(carId));
    _ref.invalidate(vehicleReadinessProvider(carId));
    _ref.invalidate(vehicleAuditLogsProvider(carId));
  }

  Future<void> verifyVehicle(String carId, {String? notes, bool? autoActivate}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).verifyVehicle(
            carId,
            notes: notes,
            autoActivate: autoActivate,
          );
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectVehicle(String carId, {required String reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).rejectVehicle(carId, reason: reason);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> activateVehicle(String carId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).activateVehicle(carId, reason: reason);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deactivateVehicle(String carId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).deactivateVehicle(carId, reason: reason);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> suspendVehicle(String carId, {required String reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).suspendVehicle(carId, reason: reason);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> retireVehicle(String carId, {required String reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).retireVehicle(carId, reason: reason);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> startMaintenance(
    String carId, {
    required String reason,
    String? expectedReturnDate,
    bool? overrideConflictingBookings,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).startMaintenance(
            carId,
            reason: reason,
            expectedReturnDate: expectedReturnDate,
            overrideConflictingBookings: overrideConflictingBookings,
          );
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> completeMaintenance(String carId, {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).completeMaintenance(carId, notes: notes);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deactivateCarListing(String carId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).deactivateCarListing(carId);
      _invalidateAll(carId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleMileagePackageActive(String carId, String packageId, bool isActive) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminFleetRepositoryProvider).toggleMileagePackageActive(carId, packageId, isActive);
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
