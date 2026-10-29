import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/supported_cities/domain/models/city_control_tower_models.dart';
import 'package:admin_panel/features/supported_cities/domain/repositories/supported_cities_repository.dart';
import 'package:admin_panel/features/supported_cities/presentation/pages/supported_cities_page.dart';
import 'package:admin_panel/features/supported_cities/presentation/providers/supported_cities_providers.dart';

class MockSupportedCitiesControlTowerRepo implements SupportedCitiesRepository {
  final List<EnrichedSupportedCity> cities = [
    const EnrichedSupportedCity(
      city: SupportedCityModel(
        id: 'city-hyd',
        name: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.3850,
        longitude: 78.4867,
        isActive: true,
      ),
      serviceAreas: [
        CityServiceAreaModel(
          id: 'area-hitec',
          cityId: 'city-hyd',
          name: 'Hitec City',
          status: 'ACTIVE',
          latitude: 17.4483,
          longitude: 78.3800,
          radiusMeters: 6000,
          vendorCount: 3,
          carCount: 15,
        ),
        CityServiceAreaModel(
          id: 'area-gachibowli',
          cityId: 'city-hyd',
          name: 'Gachibowli',
          status: 'COMING_SOON',
          latitude: 17.4401,
          longitude: 78.3489,
          radiusMeters: 5000,
          vendorCount: 1,
          carCount: 4,
        ),
      ],
      totalVendors: 4,
      totalCars: 19,
    ),
    const EnrichedSupportedCity(
      city: SupportedCityModel(
        id: 'city-blr',
        name: 'Bengaluru',
        state: 'Karnataka',
        latitude: 12.9716,
        longitude: 77.5946,
        isActive: false,
      ),
      serviceAreas: [
        CityServiceAreaModel(
          id: 'area-koramangala',
          cityId: 'city-blr',
          name: 'Koramangala',
          status: 'INACTIVE',
          latitude: 12.9352,
          longitude: 77.6245,
          radiusMeters: 4000,
          vendorCount: 0,
          carCount: 0,
        ),
      ],
      totalVendors: 0,
      totalCars: 0,
    ),
  ];

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async {
    return cities.map((c) => c.city).toList();
  }

  @override
  Future<List<EnrichedSupportedCity>> getEnrichedSupportedCities() async {
    return cities;
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
    return SupportedCityModel(
      id: 'city-new',
      name: name,
      state: state,
      latitude: latitude,
      longitude: longitude,
      isActive: isActive,
    );
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
    return SupportedCityModel(
      id: id,
      name: name ?? 'Hyderabad',
      state: state ?? 'Telangana',
      latitude: latitude ?? 17.3850,
      longitude: longitude ?? 78.4867,
      isActive: isActive ?? true,
    );
  }

  @override
  Future<void> deleteSupportedCity(String id) async {}

  @override
  Future<List<CityServiceAreaModel>> getCityServiceAreas(String cityId) async {
    return cities.firstWhere((c) => c.city.id == cityId).serviceAreas;
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
    return CityServiceAreaModel(
      id: 'area-new',
      cityId: cityId,
      name: name,
      status: status,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
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
    return CityServiceAreaModel(
      id: id,
      cityId: 'city-hyd',
      name: name ?? 'Hitec City',
      status: status ?? 'ACTIVE',
      latitude: latitude ?? 17.4483,
      longitude: longitude ?? 78.3800,
      radiusMeters: radiusMeters ?? 6000,
    );
  }

  @override
  Future<void> setServiceAreaStatus(String id, String status, {String? reason}) async {}

  @override
  Future<ReadinessReport> getServiceAreaReadiness(String serviceAreaId) async {
    return const ReadinessReport(
      targetId: 'area-hitec',
      targetName: 'Hitec City',
      isReadyToLaunch: true,
      checklist: [
        ReadinessCheckItem(
          criterion: 'PARENT_CITY_ACTIVE',
          label: 'Parent City Operational',
          passed: true,
          description: 'Hyderabad is operational.',
        ),
        ReadinessCheckItem(
          criterion: 'GEOMETRY_VALID',
          label: 'Geofence Valid',
          passed: true,
          description: 'Valid radius 6000m.',
        ),
        ReadinessCheckItem(
          criterion: 'PARTNER_COVERAGE',
          label: 'Partner Coverage',
          passed: true,
          description: '3 vendors assigned.',
        ),
        ReadinessCheckItem(
          criterion: 'FLEET_INVENTORY',
          label: 'Fleet Inventory',
          passed: true,
          description: '15 vehicles stationed.',
        ),
      ],
    );
  }

  @override
  Future<ImpactReport> getServiceAreaImpact(String serviceAreaId) async {
    return const ImpactReport(
      targetId: 'area-hitec',
      targetName: 'Hitec City',
      affectedVendorsCount: 3,
      affectedVehiclesCount: 15,
      upcomingBookingsCount: 4,
      activeRentalsCount: 1,
      safeToDeactivate: false,
      recommendations: [
        'Alert: 1 active rental is currently ongoing in Hitec City.',
        '4 upcoming confirmed bookings will require vendor reassignment.',
      ],
    );
  }

  @override
  Future<ReadinessReport> getCityReadiness(String cityId) async {
    return const ReadinessReport(
      targetId: 'city-hyd',
      targetName: 'Hyderabad',
      isReadyToLaunch: true,
      checklist: [
        ReadinessCheckItem(
          criterion: 'HAS_SERVICE_AREAS',
          label: 'Configured Service Localities',
          passed: true,
          description: '2 area(s) configured.',
        ),
        ReadinessCheckItem(
          criterion: 'ACTIVE_SERVICE_AREAS',
          label: 'Active Service Localities',
          passed: true,
          description: '1 active service area.',
        ),
        ReadinessCheckItem(
          criterion: 'PARTNER_COVERAGE',
          label: 'Vendor Partner Presence',
          passed: true,
          description: '4 partner vendors active.',
        ),
        ReadinessCheckItem(
          criterion: 'FLEET_INVENTORY',
          label: 'Bookable Fleet Inventory',
          passed: true,
          description: '19 vehicles available.',
        ),
      ],
    );
  }

  @override
  Future<ImpactReport> getCityImpact(String cityId) async {
    return const ImpactReport(
      targetId: 'city-hyd',
      targetName: 'Hyderabad',
      affectedVendorsCount: 4,
      affectedVehiclesCount: 19,
      upcomingBookingsCount: 4,
      activeRentalsCount: 1,
      safeToDeactivate: false,
      recommendations: [
        'Deactivating Hyderabad will pause all 2 service area(s).',
        'Alert: 1 active rental currently ongoing in Hyderabad.',
      ],
    );
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        supportedCitiesRepositoryProvider.overrideWithValue(MockSupportedCitiesControlTowerRepo()),
      ],
      child: const MaterialApp(
        home: SupportedCitiesPage(),
      ),
    );
  }

  testWidgets('Renders City & Serviceability Control Tower with KPIs and master table', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify Title & KPI strip
    expect(find.text('City & Serviceability Control Tower'), findsOneWidget);
    expect(find.text('Operational Cities'), findsOneWidget);
    expect(find.text('Service Areas (Localities)'), findsNWidgets(2)); // in KPI and table column
    expect(find.text('Vendor Partner Presence'), findsOneWidget);
    expect(find.text('Stationed Fleet Inventory'), findsOneWidget);

    // Verify Cities listed
    expect(find.text('Hyderabad'), findsOneWidget);
    expect(find.text('Bengaluru'), findsOneWidget);
    expect(find.text('2 Areas (1 Active)'), findsOneWidget);
    expect(find.text('4 Assigned'), findsNWidgets(2)); // in KPI + Hyderabad row
    expect(find.text('19 Vehicles'), findsNWidgets(2)); // in KPI + Hyderabad row
  });

  testWidgets('Opens Service Areas Workspace sheet when clicking on areas pill', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap on the Service Areas pill
    final pill = find.text('2 Areas (1 Active)');
    await tester.ensureVisible(pill);
    await tester.tap(pill);
    await tester.pumpAndSettle();

    // Verify Workspace sheet is opened
    expect(find.text('Hyderabad — Service Areas & Localities'), findsOneWidget);
    expect(find.text('Hitec City'), findsOneWidget);
    expect(find.text('Gachibowli'), findsOneWidget);
    expect(find.text('3 Vendors'), findsOneWidget);
    expect(find.text('15 Fleet'), findsOneWidget);
    expect(find.text('Add Service Area'), findsOneWidget);
  });

  testWidgets('Displays Launch Readiness report dialog', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final button = find.byTooltip('Launch Readiness Checklist').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad Launch Readiness'), findsOneWidget);
    expect(find.text('All service criteria met. Ready to serve customer bookings.'), findsOneWidget);
    expect(find.text('Configured Service Localities'), findsOneWidget);
    expect(find.text('Vendor Partner Presence'), findsNWidgets(2)); // KPI + Dialog
    expect(find.text('Bookable Fleet Inventory'), findsOneWidget);
  });

  testWidgets('Displays Deactivation Blast Radius Impact Preview dialog', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final button = find.byTooltip('Deactivation Blast Radius & Impact Preview').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad Deactivation Impact Preview'), findsOneWidget);
    expect(find.textContaining('HIGH OPERATIONAL RISK'), findsOneWidget);
    expect(find.text('Vendors Affected'), findsOneWidget);
    expect(find.text('Vehicles Offline'), findsOneWidget);
    expect(find.text('Upcoming Trips'), findsOneWidget);
    expect(find.text('Active Rentals'), findsOneWidget);
    expect(find.text('Force Deactivate (Unsafe)'), findsOneWidget);
  });
}
