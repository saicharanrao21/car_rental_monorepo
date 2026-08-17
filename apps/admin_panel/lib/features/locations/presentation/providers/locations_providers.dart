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

final operationalLocationsOverviewProvider =
    FutureProvider<OperationalLocationOverviewModel>((ref) async {
  final repo = ref.watch(locationsRepositoryProvider);
  final city = ref.watch(locationCityFilterProvider);
  return repo.getOperationalOverview(city: city);
});
