import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/api_supported_cities_repository.dart';
import '../../domain/models/city_control_tower_models.dart';
import '../../domain/repositories/supported_cities_repository.dart';

final supportedCitiesRepositoryProvider = Provider<SupportedCitiesRepository>((ref) {
  return ApiSupportedCitiesRepository(ref.watch(apiClientProvider));
});

final enrichedSupportedCitiesProvider =
    StateNotifierProvider<EnrichedSupportedCitiesNotifier, AsyncValue<List<EnrichedSupportedCity>>>((ref) {
  return EnrichedSupportedCitiesNotifier(ref.watch(supportedCitiesRepositoryProvider));
});

class EnrichedSupportedCitiesNotifier extends StateNotifier<AsyncValue<List<EnrichedSupportedCity>>> {
  final SupportedCitiesRepository _repository;

  EnrichedSupportedCitiesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCities();
  }

  Future<void> loadCities() async {
    state = const AsyncValue.loading();
    try {
      final cities = await _repository.getEnrichedSupportedCities();
      state = AsyncValue.data(cities);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCity({
    required String name,
    required String stateName,
    required double latitude,
    required double longitude,
    required bool isActive,
    List<String>? enabledTripTypes,
  }) async {
    await _repository.addSupportedCity(
      name: name,
      state: stateName,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
      enabledTripTypes: enabledTripTypes,
    );
    await loadCities();
  }

  Future<void> updateCity(
    String id, {
    String? name,
    String? stateName,
    double? latitude,
    double? longitude,
    bool? isActive,
    List<String>? enabledTripTypes,
  }) async {
    await _repository.updateSupportedCity(
      id,
      name: name,
      state: stateName,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
      enabledTripTypes: enabledTripTypes,
    );
    await loadCities();
  }

  Future<void> deleteCity(String id) async {
    await _repository.deleteSupportedCity(id);
    await loadCities();
  }

  Future<CityServiceAreaModel> createServiceArea({
    required String cityId,
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String status = 'ACTIVE',
  }) async {
    final area = await _repository.createServiceArea(
      cityId: cityId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      status: status,
    );
    await loadCities();
    return area;
  }

  Future<CityServiceAreaModel> updateServiceArea(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? status,
  }) async {
    final area = await _repository.updateServiceArea(
      id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      status: status,
    );
    await loadCities();
    return area;
  }

  Future<void> setServiceAreaStatus(
    String id,
    String status, {
    String? reason,
  }) async {
    await _repository.setServiceAreaStatus(id, status, reason: reason);
    await loadCities();
  }

  Future<ReadinessReport> getServiceAreaReadiness(String id) {
    return _repository.getServiceAreaReadiness(id);
  }

  Future<ImpactReport> getServiceAreaImpact(String id) {
    return _repository.getServiceAreaImpact(id);
  }

  Future<ReadinessReport> getCityReadiness(String id) {
    return _repository.getCityReadiness(id);
  }

  Future<ImpactReport> getCityImpact(String id) {
    return _repository.getCityImpact(id);
  }
}

// Backward-compatible provider for existing widgets / tests
final supportedCitiesProvider =
    StateNotifierProvider<SupportedCitiesNotifier, AsyncValue<List<SupportedCityModel>>>((ref) {
  return SupportedCitiesNotifier(ref.watch(supportedCitiesRepositoryProvider));
});

class SupportedCitiesNotifier extends StateNotifier<AsyncValue<List<SupportedCityModel>>> {
  final SupportedCitiesRepository _repository;

  SupportedCitiesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCities();
  }

  Future<void> loadCities() async {
    state = const AsyncValue.loading();
    try {
      final cities = await _repository.getSupportedCities();
      state = AsyncValue.data(cities);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCity({
    required String name,
    required String stateName,
    required double latitude,
    required double longitude,
    required bool isActive,
  }) async {
    await _repository.addSupportedCity(
      name: name,
      state: stateName,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
    );
    await loadCities();
  }

  Future<void> updateCity(
    String id, {
    String? name,
    String? stateName,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    await _repository.updateSupportedCity(
      id,
      name: name,
      state: stateName,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
    );
    await loadCities();
  }

  Future<void> deleteCity(String id) async {
    await _repository.deleteSupportedCity(id);
    await loadCities();
  }
}
