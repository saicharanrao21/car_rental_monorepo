import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Location Models Tests', () {
    test('CoordinatesModel and LocationAddressModel serialization & deserialization', () {
      final json = {
        'formattedAddress': 'Hitec City, Madhapur, Hyderabad',
        'locality': 'Madhapur',
        'city': 'Hyderabad',
        'state': 'Telangana',
        'postalCode': '500081',
        'latitude': 17.4483,
        'longitude': 78.3915,
      };

      final address = LocationAddressModel.fromJson(json);
      expect(address.city, 'Hyderabad');
      expect(address.postalCode, '500081');
      expect(address.latitude, 17.4483);

      final outJson = address.toJson();
      expect(outJson['city'], 'Hyderabad');
      expect(outJson['latitude'], 17.4483);
    });

    test('RouteEstimateModel serialization & deserialization', () {
      final json = {
        'distanceKm': 14.5,
        'estimatedMinutes': 32,
        'formattedDistance': '14.5 km',
        'formattedDuration': '32 mins',
      };

      final route = RouteEstimateModel.fromJson(json);
      expect(route.distanceKm, 14.5);
      expect(route.estimatedMinutes, 32);
      expect(route.formattedDistance, '14.5 km');
      expect(route.formattedDuration, '32 mins');

      final outJson = route.toJson();
      expect(outJson['distanceKm'], 14.5);
      expect(outJson['estimatedMinutes'], 32);
    });

    test('OperationalLocationOverviewModel serialization & deserialization', () {
      final json = {
        'vendors': [
          {
            'id': 'vnd_1',
            'businessName': 'Prime Fleet',
            'ownerName': 'Vikram',
            'city': 'Hyderabad',
            'latitude': 17.4,
            'longitude': 78.4,
          }
        ],
        'activeBookings': [
          {
            'id': 'bkg_1',
            'tripType': 'SELF_DRIVE',
            'pickupLocation': 'Airport',
            'dropLocation': null,
            'pickupLatitude': 17.24,
            'pickupLongitude': 78.42,
            'deliveryLatitude': null,
            'deliveryLongitude': null,
            'status': 'ONGOING',
            'customer': {'name': 'Sai', 'phone': '+919999999999'},
            'car': {'make': 'Hyundai Creta', 'model': '', 'registrationNumber': 'TS09AA1111'},
          }
        ],
        'activeEmergencies': [
          {
            'id': 'sos_1',
            'incidentType': 'FLAT_TYRE',
            'status': 'REQUESTED',
            'latitude': 17.35,
            'longitude': 78.45,
            'locationAddress': 'Outer Ring Road',
            'customer': {'name': 'Priya', 'phone': '+918888888888'},
          }
        ],
        'totalHubs': 5,
        'totalActiveGarages': 1,
        'totalOnTripVehicles': 1,
        'totalActiveSosAlerts': 1,
      };

      final overview = OperationalLocationOverviewModel.fromJson(json);
      expect(overview.totalHubs, 5);
      expect(overview.vendors.length, 1);
      expect(overview.activeBookings.first.carName, 'Hyundai Creta');
      expect(overview.activeEmergencies.first.incidentType, 'FLAT_TYRE');

      final outJson = overview.toJson();
      expect(outJson['totalHubs'], 5);
    });
  });
}
