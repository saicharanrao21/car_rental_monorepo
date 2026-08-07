import 'package:core/core.dart';
import 'package:models/models.dart';
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
  Future<SupportedCityModel> addSupportedCity({
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required bool isActive,
  }) async {
    final response = await _apiClient.dio.post(
      '/admin/supported-cities',
      data: {
        'name': name,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'isActive': isActive,
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
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (state != null) data['state'] = state;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (isActive != null) data['isActive'] = isActive;

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
}
