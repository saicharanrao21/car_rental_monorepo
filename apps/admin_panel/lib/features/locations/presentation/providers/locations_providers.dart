import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/locations/domain/repositories/locations_repository.dart';
import 'package:admin_panel/features/locations/data/api_locations_repository.dart';

final locationsRepositoryProvider = Provider<LocationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiLocationsRepository(apiClient);
});

final locationCityFilterProvider = StateProvider<String>((ref) => 'All');
final locationTypeFilterProvider = StateProvider<String>((ref) => 'ALL');
final locationStatusFilterProvider = StateProvider<String>((ref) => 'ALL');
final locationSearchQueryProvider = StateProvider<String>((ref) => '');

final selectedLocationForInspectionProvider =
    StateProvider<VendorLocationModel?>((ref) => null);

final operationalLocationsOverviewProvider =
    FutureProvider<OperationalLocationOverviewModel>((ref) async {
  final repo = ref.watch(locationsRepositoryProvider);
  final city = ref.watch(locationCityFilterProvider);
  return repo.getOperationalOverview(city: city);
});

final locationCatalogProvider =
    FutureProvider.autoDispose<List<VendorLocationModel>>((ref) async {
  final repo = ref.watch(locationsRepositoryProvider);
  final city = ref.watch(locationCityFilterProvider);
  return repo.getPublicCatalog(city: city == 'All' ? null : city);
});

final supportedCitiesListProvider =
    FutureProvider.autoDispose<List<SupportedCityModel>>((ref) async {
  final repo = ref.watch(locationsRepositoryProvider);
  return repo.getSupportedCities(includeInactive: true);
});

class LocationGovernanceController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> updateStatus(String locationId, String status) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final repo = ref.read(locationsRepositoryProvider);
      await repo.updateLocationStatus(locationId, status);
      ref.invalidate(locationCatalogProvider);
      ref.invalidate(operationalLocationsOverviewProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final locationGovernanceControllerProvider =
    AutoDisposeAsyncNotifierProvider<LocationGovernanceController, void>(() {
  return LocationGovernanceController();
});
