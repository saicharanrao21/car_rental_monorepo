import 'package:models/models.dart';

abstract class SupportedCitiesRepository {
  Future<List<SupportedCityModel>> getSupportedCities();
  Future<SupportedCityModel> addSupportedCity({
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required bool isActive,
  });
  Future<SupportedCityModel> updateSupportedCity(
    String id, {
    String? name,
    String? state,
    double? latitude,
    double? longitude,
    bool? isActive,
  });
  Future<void> deleteSupportedCity(String id);
}
