import 'package:models/models.dart';
import '../domain/repositories/supported_cities_repository.dart';

class MockSupportedCitiesRepository implements SupportedCitiesRepository {
  final List<SupportedCityModel> _cities = [
    const SupportedCityModel(id: 'city_mumbai', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777, isActive: true),
    const SupportedCityModel(id: 'city_delhi', name: 'Delhi', state: 'Delhi', latitude: 28.6139, longitude: 77.2090, isActive: true),
    const SupportedCityModel(id: 'city_bangalore', name: 'Bangalore', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946, isActive: true),
    const SupportedCityModel(id: 'city_chennai', name: 'Chennai', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707, isActive: true),
    const SupportedCityModel(id: 'city_hyderabad', name: 'Hyderabad', state: 'Telangana', latitude: 17.3850, longitude: 78.4867, isActive: true),
  ];

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_cities);
  }

  @override
  Future<SupportedCityModel> addSupportedCity({
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required bool isActive,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newCity = SupportedCityModel(
      id: 'city_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      state: state,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
    );
    _cities.add(newCity);
    return newCity;
  }

  @override
  Future<SupportedCityModel> updateSupportedCity(
    String id, {
    String? name,
    String? state,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _cities.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('City not found');
    final updated = _cities[index].copyWith(
      name: name,
      state: state,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
    );
    _cities[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteSupportedCity(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _cities.removeWhere((c) => c.id == id);
  }
}
