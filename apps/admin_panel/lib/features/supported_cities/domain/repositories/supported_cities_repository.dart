import 'package:models/models.dart';
import '../models/city_control_tower_models.dart';

abstract class SupportedCitiesRepository {
  Future<List<SupportedCityModel>> getSupportedCities();
  Future<List<EnrichedSupportedCity>> getEnrichedSupportedCities();

  Future<SupportedCityModel> addSupportedCity({
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required bool isActive,
    List<String>? enabledTripTypes,
  });

  Future<SupportedCityModel> updateSupportedCity(
    String id, {
    String? name,
    String? state,
    double? latitude,
    double? longitude,
    bool? isActive,
    List<String>? enabledTripTypes,
  });

  Future<void> deleteSupportedCity(String id);

  // Service Area Methods
  Future<List<CityServiceAreaModel>> getCityServiceAreas(String cityId);

  Future<CityServiceAreaModel> createServiceArea({
    required String cityId,
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String status = 'ACTIVE',
  });

  Future<CityServiceAreaModel> updateServiceArea(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? status,
  });

  Future<void> setServiceAreaStatus(
    String id,
    String status, {
    String? reason,
  });

  // Readiness & Impact Methods
  Future<ReadinessReport> getServiceAreaReadiness(String serviceAreaId);
  Future<ImpactReport> getServiceAreaImpact(String serviceAreaId);
  Future<ReadinessReport> getCityReadiness(String cityId);
  Future<ImpactReport> getCityImpact(String cityId);
}
