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
}
