import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

enum PickupOperatingMode {
  atMyLocation,
  multipleLocations,
  publicPoints,
  deliveryToCustomers,
  combination,
}

extension PickupOperatingModeExt on PickupOperatingMode {
  String get title {
    switch (this) {
      case PickupOperatingMode.atMyLocation:
        return 'At my location';
      case PickupOperatingMode.multipleLocations:
        return 'At multiple locations';
      case PickupOperatingMode.publicPoints:
        return 'At selected public points';
      case PickupOperatingMode.deliveryToCustomers:
        return 'I deliver to customers';
      case PickupOperatingMode.combination:
        return 'Combination of these';
    }
  }

  String get description {
    switch (this) {
      case PickupOperatingMode.atMyLocation:
        return 'Customers pick up and return vehicles at your primary yard/garage.';
      case PickupOperatingMode.multipleLocations:
        return 'Customers choose between multiple operating branches in your city.';
      case PickupOperatingMode.publicPoints:
        return 'Customers meet you at airports, railway stations, and transport points.';
      case PickupOperatingMode.deliveryToCustomers:
        return 'You deliver and collect vehicles directly at customer doorstep.';
      case PickupOperatingMode.combination:
        return 'Enable yards, airport points, and doorstep delivery simultaneously.';
    }
  }
}

final pickupOperatingModeProvider = StateProvider<PickupOperatingMode>((ref) {
  return PickupOperatingMode.combination;
});

class VendorLocationsNotifier extends StateNotifier<AsyncValue<List<VendorLocationModel>>> {
  final Ref ref;

  VendorLocationsNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadLocations();
  }

  Future<void> loadLocations() async {
    state = const AsyncValue.loading();
    try {
      final client = ref.read(apiClientProvider).dio;
      final response = await client.get('/locations/vendors/me/locations');
      if (response.statusCode == 200) {
        final list = (response.data as List<dynamic>)
            .map((json) => VendorLocationModel.fromJson(json as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(list);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<VendorLocationModel> addLocation(VendorLocationModel newLocation) async {
    final client = ref.read(apiClientProvider).dio;
    final response = await client.post('/locations/vendors/me/locations', data: newLocation.toJson());
    final created = VendorLocationModel.fromJson(response.data as Map<String, dynamic>);
    final current = state.value ?? [];
    state = AsyncValue.data([...current, created]);
    return created;
  }

  Future<VendorLocationModel> updateLocation(VendorLocationModel updated) async {
    final client = ref.read(apiClientProvider).dio;
    final response = await client.put('/locations/vendors/me/locations/${updated.id}', data: updated.toJson());
    final result = VendorLocationModel.fromJson(response.data as Map<String, dynamic>);
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((loc) => loc.id == result.id ? result : loc).toList(),
    );
    return result;
  }

  Future<void> toggleLocationStatus(String locationId) async {
    final current = state.value ?? [];
    final loc = current.firstWhere((l) => l.id == locationId);
    final newStatus = loc.status == VendorLocationStatus.active
        ? VendorLocationStatus.inactive
        : VendorLocationStatus.active;
    final updated = loc.copyWith(status: newStatus);
    await updateLocation(updated);
  }

  Future<void> deleteLocation(String locationId) async {
    final client = ref.read(apiClientProvider).dio;
    await client.delete('/locations/vendors/me/locations/$locationId');
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((l) => l.id != locationId).toList());
  }

  void clearAllLocations() {
    state = const AsyncValue.data([]);
  }
}

final vendorLocationsProvider =
    StateNotifierProvider<VendorLocationsNotifier, AsyncValue<List<VendorLocationModel>>>((ref) {
  return VendorLocationsNotifier(ref);
});

class VendorDeliveryPolicyNotifier extends StateNotifier<AsyncValue<VendorDeliveryPolicyModel>> {
  final Ref ref;

  VendorDeliveryPolicyNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadPolicy();
  }

  Future<void> loadPolicy() async {
    state = const AsyncValue.loading();
    try {
      final client = ref.read(apiClientProvider).dio;
      final response = await client.get('/locations/vendors/me/policy');
      if (response.statusCode == 200) {
        state = AsyncValue.data(
          VendorDeliveryPolicyModel.fromJson(response.data as Map<String, dynamic>),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePolicy(VendorDeliveryPolicyModel updated) async {
    final client = ref.read(apiClientProvider).dio;
    final response = await client.put('/locations/vendors/me/policy', data: updated.toJson());
    if (response.statusCode == 200) {
      state = AsyncValue.data(
        VendorDeliveryPolicyModel.fromJson(response.data as Map<String, dynamic>),
      );
    }
  }
}

final vendorDeliveryPolicyProvider =
    StateNotifierProvider<VendorDeliveryPolicyNotifier, AsyncValue<VendorDeliveryPolicyModel>>((ref) {
  return VendorDeliveryPolicyNotifier(ref);
});

final vendorLocationMatrixProvider =
    FutureProvider.autoDispose<List<LocationMatrixItemModel>>((ref) async {
  final client = ref.read(apiClientProvider).dio;
  try {
    final response = await client.get('/locations/vendors/me/matrix');
    if (response.statusCode == 200) {
      return (response.data as List<dynamic>)
          .map((json) => LocationMatrixItemModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}
  return [];
});

final locationOperationsSummaryProvider =
    FutureProvider.autoDispose<LocationOperationsSummaryModel>((ref) async {
  final client = ref.read(apiClientProvider).dio;
  try {
    final response = await client.get('/locations/vendors/me/operations-summary');
    if (response.statusCode == 200) {
      return LocationOperationsSummaryModel.fromJson(response.data as Map<String, dynamic>);
    }
  } catch (_) {}
  return const LocationOperationsSummaryModel(
    locations: [],
    totalTodayPickups: 0,
    totalTodayReturns: 0,
    totalDeliveryRequests: 0,
  );
});

final publicLocationCatalogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(apiClientProvider).dio;
  try {
    final response = await client.get('/locations/public/catalog');
    if (response.statusCode == 200) {
      return (response.data as List<dynamic>)
          .map((json) => json as Map<String, dynamic>)
          .toList();
    }
  } catch (_) {}
  return [];
});

