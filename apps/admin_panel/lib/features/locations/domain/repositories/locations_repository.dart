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
}
