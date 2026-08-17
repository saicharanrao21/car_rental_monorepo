import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/locations/domain/repositories/locations_repository.dart';
import 'package:admin_panel/features/locations/presentation/providers/locations_providers.dart';
import 'package:admin_panel/features/locations/presentation/pages/operational_map_page.dart';

class TestMockLocationsRepo implements LocationsRepository {
  @override
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city}) async {
    return const OperationalLocationOverviewModel(
      vendors: [
        VendorLocationItemModel(
          id: 'vnd_1',
          businessName: 'Royal Fleet Hub',
          ownerName: 'Vikram Mehta',
          city: 'Hyderabad',
          latitude: 17.4483,
          longitude: 78.3915,
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
      totalActiveGarages: 1,
      totalOnTripVehicles: 1,
      totalActiveSosAlerts: 1,
    );
  }

  @override
  Future<LocationAddressModel> reverseGeocode(double lat, double lng) async {
    return LocationAddressModel(
      formattedAddress: 'Hitec City, Hyderabad',
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
    return const RouteEstimateModel(
      distanceKm: 15.2,
      estimatedMinutes: 30,
      formattedDistance: '15.2 km',
      formattedDuration: '30 mins',
    );
  }
}

void main() {
  testWidgets('OperationalMapPage renders KPI cards, tabs, and location previews', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsRepositoryProvider.overrideWithValue(TestMockLocationsRepo()),
        ],
        child: const MaterialApp(
          home: OperationalMapPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Operational Map & Fleet Locations'), findsOneWidget);

    // Verify KPI summary cards
    expect(find.text('Total Active Hubs'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Active SOS Alerts'), findsOneWidget);

    // Verify active on-trip vehicle tab content
    expect(find.text('Hyundai Creta (AT) (TS09EA1234)'), findsOneWidget);
    expect(find.text('SELF_DRIVE TRIP'), findsOneWidget);

    // Switch to Vendor Garages tab
    await tester.tap(find.text('Vendor Garages & Hubs'));
    await tester.pumpAndSettle();

    expect(find.text('Royal Fleet Hub'), findsOneWidget);
    expect(find.text('GARAGE HUB'), findsOneWidget);

    // Switch to Emergency SOS tab
    await tester.tap(find.text('Emergency SOS Incidents'));
    await tester.pumpAndSettle();

    expect(find.text('SOS Alert: FLAT_TYRE'), findsOneWidget);
    expect(find.text('URGENT DISPATCH'), findsOneWidget);
  });
}
