import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/locations_repository.dart';

class ApiLocationsRepository implements LocationsRepository {
  final ApiClient _apiClient;

  ApiLocationsRepository(this._apiClient);

  @override
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city}) async {
    final queryParams = <String, dynamic>{};
    if (city != null && city.isNotEmpty && city != 'All') {
      queryParams['city'] = city;
    }

    final response = await _apiClient.dio.get(
      '/locations/admin/overview',
      queryParameters: queryParams,
    );

    return OperationalLocationOverviewModel.fromJson(response.data);
  }

  @override
  Future<LocationAddressModel> reverseGeocode(double lat, double lng) async {
    final response = await _apiClient.dio.get(
      '/locations/reverse-geocode',
      queryParameters: {'lat': lat, 'lng': lng},
    );

    return LocationAddressModel.fromJson(response.data);
  }

  @override
  Future<RouteEstimateModel> calculateDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final response = await _apiClient.dio.get(
      '/locations/distance',
      queryParameters: {
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
      },
    );

    return RouteEstimateModel.fromJson(response.data);
  }

  @override
  Future<List<VendorLocationModel>> getPublicCatalog({String? city}) async {
    final queryParams = <String, dynamic>{};
    if (city != null && city.isNotEmpty && city != 'All') {
      queryParams['city'] = city;
    }

    try {
      final response = await _apiClient.dio.get(
        '/locations/admin/locations',
        queryParameters: queryParams,
      );

      final List list = response.data is List ? response.data : (response.data['locations'] ?? []);
      return list.map((item) => VendorLocationModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      final fallbackResponse = await _apiClient.dio.get(
        '/locations/public/catalog',
        queryParameters: queryParams,
      );
      final List list = fallbackResponse.data is List ? fallbackResponse.data : (fallbackResponse.data['locations'] ?? []);
      return list.map((item) => VendorLocationModel.fromJson(item as Map<String, dynamic>)).toList();
    }
  }

  @override
  Future<void> updateLocationStatus(String locationId, String status) async {
    await _apiClient.dio.patch(
      '/locations/admin/locations/$locationId/status',
      data: {'status': status.toUpperCase()},
    );
  }

  @override
  Future<List<SupportedCityModel>> getSupportedCities({bool includeInactive = true}) async {
    final response = await _apiClient.dio.get(
      '/locations/admin/cities',
      queryParameters: {'all': includeInactive.toString()},
    );

    final List list = response.data as List;
    return list.map((item) => SupportedCityModel.fromJson(item as Map<String, dynamic>)).toList();
  }
}
