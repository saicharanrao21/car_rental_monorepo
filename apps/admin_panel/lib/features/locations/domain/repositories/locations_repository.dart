import 'package:models/models.dart';

abstract class LocationsRepository {
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city});
  Future<LocationAddressModel> reverseGeocode(double lat, double lng);
  Future<RouteEstimateModel> calculateDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  });
  Future<List<VendorLocationModel>> getPublicCatalog({String? city});
  Future<void> updateLocationStatus(String locationId, String status);
  Future<List<SupportedCityModel>> getSupportedCities({bool includeInactive = true});
}
