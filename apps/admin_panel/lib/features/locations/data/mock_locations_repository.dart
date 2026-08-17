import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/locations_repository.dart';

class MockLocationsRepository with LatencySimulator implements LocationsRepository {
  @override
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city}) async {
    await simulateLatency();

    return const OperationalLocationOverviewModel(
      vendors: [
        VendorLocationItemModel(
          id: 'vnd_1',
          businessName: 'Royal Fleet Garage',
          ownerName: 'Vikram Mehta',
          city: 'Hyderabad',
          latitude: 17.4483,
          longitude: 78.3915,
        ),
        VendorLocationItemModel(
          id: 'vnd_2',
          businessName: 'Coastal Cars Hub',
          ownerName: 'Sunil Rao',
          city: 'Mumbai',
          latitude: 19.0760,
          longitude: 72.8777,
        ),
      ],
      activeBookings: [
        ActiveTripLocationItemModel(
          id: 'bkg_1',
          tripType: 'SELF_DRIVE',
          pickupLocation: 'Hitec City Hub',
          dropLocation: 'RGIA Airport',
          pickupLatitude: 17.4483,
          pickupLongitude: 78.3915,
          deliveryLatitude: null,
          deliveryLongitude: null,
          status: 'ONGOING',
          customerName: 'Rahul Sharma',
          customerPhone: '+919876543210',
          carName: 'Hyundai Creta (AT)',
          registrationNumber: 'TS09EA1234',
        ),
      ],
      activeEmergencies: [
        EmergencyLocationItemModel(
          id: 'sos_1',
          incidentType: 'FLAT_TYRE',
          status: 'REQUESTED',
          latitude: 17.3850,
          longitude: 78.4867,
          locationAddress: 'PVNR Expressway Pillar 120',
          customerName: 'Priya Reddy',
          customerPhone: '+919876543211',
        ),
      ],
      totalHubs: 5,
      totalActiveGarages: 2,
      totalOnTripVehicles: 1,
      totalActiveSosAlerts: 1,
    );
  }

  @override
  Future<LocationAddressModel> reverseGeocode(double lat, double lng) async {
    await simulateLatency();
    return LocationAddressModel(
      formattedAddress: 'Hitec City, Hyderabad, Telangana',
      locality: 'Madhapur',
      city: 'Hyderabad',
      state: 'Telangana',
      postalCode: '500081',
      latitude: lat,
      longitude: lng,
    );
  }

  @override
  Future<RouteEstimateModel> calculateDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    await simulateLatency();
    return const RouteEstimateModel(
      distanceKm: 15.2,
      estimatedMinutes: 30,
      formattedDistance: '15.2 km',
      formattedDuration: '30 mins',
    );
  }
}
