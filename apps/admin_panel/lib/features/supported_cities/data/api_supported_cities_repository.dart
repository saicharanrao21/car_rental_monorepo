import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/models/city_control_tower_models.dart';
import '../domain/repositories/supported_cities_repository.dart';

class ApiSupportedCitiesRepository implements SupportedCitiesRepository {
  final ApiClient _apiClient;

  ApiSupportedCitiesRepository(this._apiClient);

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async {
    final response = await _apiClient.dio.get('/admin/supported-cities');
    final list = response.data as List;
    return list.map((json) => SupportedCityModel.fromJson(json)).toList();
  }

  @override
  Future<List<EnrichedSupportedCity>> getEnrichedSupportedCities() async {
    final response = await _apiClient.dio.get('/admin/supported-cities');
    final list = response.data as List;
    return list
        .map((json) => EnrichedSupportedCity.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  @override
  Future<SupportedCityModel> addSupportedCity({
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required bool isActive,
    List<String>? enabledTripTypes,
  }) async {
    final response = await _apiClient.dio.post(
      '/admin/supported-cities',
      data: {
        'name': name,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'isActive': isActive,
        if (enabledTripTypes != null) 'enabledTripTypes': enabledTripTypes,
      },
    );
    return SupportedCityModel.fromJson(response.data);
  }

  @override
  Future<SupportedCityModel> updateSupportedCity(
    String id, {
    String? name,
    String? state,
    double? latitude,
    double? longitude,
    bool? isActive,
    List<String>? enabledTripTypes,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (state != null) data['state'] = state;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (isActive != null) data['isActive'] = isActive;
    if (enabledTripTypes != null) data['enabledTripTypes'] = enabledTripTypes;

    final response = await _apiClient.dio.patch(
      '/admin/supported-cities/$id',
      data: data,
    );
    return SupportedCityModel.fromJson(response.data);
  }

  @override
  Future<void> deleteSupportedCity(String id) async {
    await _apiClient.dio.delete('/admin/supported-cities/$id');
  }

  @override
  Future<List<CityServiceAreaModel>> getCityServiceAreas(String cityId) async {
    final response = await _apiClient.dio.get('/admin/locations/cities/$cityId/service-areas');
    final list = response.data as List;
    return list
        .map((json) => CityServiceAreaModel.fromJson(Map<String, dynamic>.from(json), cityId))
        .toList();
  }

  @override
  Future<CityServiceAreaModel> createServiceArea({
    required String cityId,
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String status = 'ACTIVE',
  }) async {
    final response = await _apiClient.dio.post(
      '/admin/locations/service-areas',
      data: {
        'cityId': cityId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'status': status,
      },
    );
    return CityServiceAreaModel.fromJson(Map<String, dynamic>.from(response.data), cityId);
  }

  @override
  Future<CityServiceAreaModel> updateServiceArea(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (radiusMeters != null) data['radiusMeters'] = radiusMeters;
    if (status != null) data['status'] = status;

    final response = await _apiClient.dio.put(
      '/admin/locations/service-areas/$id',
      data: data,
    );
    return CityServiceAreaModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<void> setServiceAreaStatus(
    String id,
    String status, {
    String? reason,
  }) async {
    await _apiClient.dio.patch(
      '/admin/locations/service-areas/$id/status',
      data: {
        'status': status,
        if (reason != null) 'reason': reason,
      },
    );
  }

  @override
  Future<ReadinessReport> getServiceAreaReadiness(String serviceAreaId) async {
    final response = await _apiClient.dio.get('/admin/locations/service-areas/$serviceAreaId/readiness');
    return ReadinessReport.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<ImpactReport> getServiceAreaImpact(String serviceAreaId) async {
    final response = await _apiClient.dio.get('/admin/locations/service-areas/$serviceAreaId/impact');
    return ImpactReport.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<ReadinessReport> getCityReadiness(String cityId) async {
    final response = await _apiClient.dio.get('/admin/locations/cities/$cityId/readiness');
    return ReadinessReport.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<ImpactReport> getCityImpact(String cityId) async {
    final response = await _apiClient.dio.get('/admin/locations/cities/$cityId/impact');
    return ImpactReport.fromJson(Map<String, dynamic>.from(response.data));
  }
}
