import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/api_supported_cities_repository.dart';
import '../../domain/repositories/supported_cities_repository.dart';

final supportedCitiesRepositoryProvider = Provider<SupportedCitiesRepository>((ref) {
  return ApiSupportedCitiesRepository(ref.watch(apiClientProvider));
});

final supportedCitiesProvider = StateNotifierProvider<SupportedCitiesNotifier, AsyncValue<List<SupportedCityModel>>>((ref) {
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
    try {
      await _repository.addSupportedCity(
        name: name,
        state: stateName,
        latitude: latitude,
        longitude: longitude,
        isActive: isActive,
      );
      await loadCities();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCity(
    String id, {
    String? name,
    String? stateName,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    try {
      await _repository.updateSupportedCity(
        id,
        name: name,
        state: stateName,
        latitude: latitude,
        longitude: longitude,
        isActive: isActive,
      );
      await loadCities();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCity(String id) async {
    try {
      await _repository.deleteSupportedCity(id);
      await loadCities();
    } catch (e) {
      rethrow;
    }
  }
}
