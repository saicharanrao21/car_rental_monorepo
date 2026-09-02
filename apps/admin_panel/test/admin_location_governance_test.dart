import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/locations/domain/repositories/locations_repository.dart';
import 'package:admin_panel/features/locations/presentation/providers/locations_providers.dart';
import 'package:admin_panel/features/locations/presentation/pages/location_governance_page.dart';

class TestMockLocationGovernanceRepo implements LocationsRepository {
  @override
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city}) async {
    return const OperationalLocationOverviewModel(
      vendors: [],
      activeBookings: [],
      activeEmergencies: [],
      totalHubs: 3,
      totalActiveGarages: 1,
      totalOnTripVehicles: 0,
      totalActiveSosAlerts: 0,
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

  @override
  Future<List<VendorLocationModel>> getPublicCatalog({String? city}) async {
    return [
      VendorLocationModel(
        id: 'loc_1',
        vendorId: 'vnd_1',
        name: 'Madhapur Prime Yard',
        type: VendorLocationType.vendorYard,
        status: VendorLocationStatus.active,
        city: 'Hyderabad',
        state: 'Telangana',
        address: 'Hitec City Main Road',
        latitude: 17.4483,
        longitude: 78.3915,
        assignedCarCount: 14,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      VendorLocationModel(
        id: 'loc_2',
        vendorId: 'vnd_1',
        name: 'RGIA Airport Hub',
        type: VendorLocationType.airport,
        status: VendorLocationStatus.active,
        city: 'Hyderabad',
        state: 'Telangana',
        address: 'Shamshabad Terminal 1',
        latitude: 17.2403,
        longitude: 78.4294,
        assignedCarCount: 8,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      VendorLocationModel(
        id: 'loc_3',
        vendorId: 'vnd_2',
        name: 'Secunderabad Station Hub',
        type: VendorLocationType.railwayStation,
        status: VendorLocationStatus.pendingApproval,
        city: 'Hyderabad',
        state: 'Telangana',
        address: 'Station Road',
        latitude: 17.4344,
        longitude: 78.5015,
        assignedCarCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> updateLocationStatus(String locationId, String status) async {}

  @override
  Future<List<SupportedCityModel>> getSupportedCities({bool includeInactive = true}) async {
    return [
      const SupportedCityModel(
        id: 'city_hyd',
        name: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.3850,
        longitude: 78.4867,
        isActive: true,
      ),
    ];
  }
}

void main() {
  testWidgets('LocationGovernancePage renders KPIs, data grid, tabs, and slide-over drawer', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationsRepositoryProvider.overrideWithValue(TestMockLocationGovernanceRepo()),
        ],
        child: const MaterialApp(
          home: LocationGovernancePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Location Governance & Hub Review'), findsOneWidget);
    expect(find.text('Total Managed Hubs'), findsOneWidget);
    expect(find.text('Active Yards & Garages'), findsOneWidget);
    expect(find.text('Airport & Transit Points'), findsOneWidget);
    expect(find.text('Pending Governance Review'), findsOneWidget);

    // Verify Tab Headers
    expect(find.text('All Locations & Governance'), findsOneWidget);
    expect(find.text('Vendor Yards & Garages'), findsOneWidget);
    expect(find.text('Transit Hubs & Airports'), findsOneWidget);
    expect(find.text('Delivery Policies & Matrix'), findsOneWidget);

    // Verify Location rows rendered in table
    expect(find.text('Madhapur Prime Yard'), findsOneWidget);
    expect(find.text('RGIA Airport Hub'), findsOneWidget);
    expect(find.text('Secunderabad Station Hub'), findsOneWidget);

    // Test Inspect button opens Slide-over drawer
    final inspectButtons = find.text('Inspect');
    expect(inspectButtons, findsWidgets);
    await tester.tap(inspectButtons.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Drawer content
    expect(find.text('Location & Geocoordinates'), findsOneWidget);
    expect(find.text('Contact & Fleet Allocation'), findsOneWidget);
    expect(find.text('Operating Schedule'), findsOneWidget);
    expect(find.text('Governance & Review Actions'), findsOneWidget);

    // Close drawer
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Switch to Delivery Policies tab
    await tester.tap(find.text('Delivery Policies & Matrix'));
    await tester.pumpAndSettle();

    expect(find.text('Platform Doorstep Delivery & Fulfillment Governance'), findsOneWidget);
    expect(find.text('Standard Doorstep Delivery'), findsOneWidget);
    expect(find.text('Canonical Matrix Source: PostgreSQL'), findsOneWidget);
  });
}
