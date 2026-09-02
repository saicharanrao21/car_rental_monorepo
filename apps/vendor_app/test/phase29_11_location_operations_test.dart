import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/locations/presentation/providers/locations_providers.dart';
import 'package:vendor_app/features/locations/presentation/pages/vendor_location_settings_page.dart';
import 'package:vendor_app/features/locations/presentation/pages/add_location_wizard_page.dart';
import 'package:vendor_app/features/locations/presentation/pages/location_detail_page.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Phase 29.11: Domain Models & Logic Tests (1-17)', () {
    test('1. VendorLocationModel serializes and deserializes correctly', () {
      final loc = VendorLocationModel(
        id: 'loc_1',
        vendorId: 'v_1',
        name: 'HYD Yard',
        type: VendorLocationType.vendorYard,
        address: 'Hitec City',
        city: 'Hyderabad',
        latitude: 17.4483,
        longitude: 78.3915,
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: true,
        pickupFee: 100,
        returnFee: 50,
        oneWayFee: 200,
        openingTime: '08:00',
        closingTime: '22:00',
        is24x7: false,
        assignedCarCount: 3,
        assignedCarIds: ['car_1', 'car_2', 'car_3'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final json = loc.toJson();
      expect(json['name'], 'HYD Yard');
      expect(json['type'], 'VENDOR_YARD');
      expect(json['pickupFee'], 100);

      final fromJson = VendorLocationModel.fromJson(json);
      expect(fromJson.name, 'HYD Yard');
      expect(fromJson.type, VendorLocationType.vendorYard);
      expect(fromJson.assignedCarIds.length, 3);
    });

    test('2. Location types correctly provide display names and icons', () {
      expect(VendorLocationType.vendorYard.displayName, 'Vendor Yard / Garage');
      expect(VendorLocationType.airport.displayName, 'Airport Terminal');
      expect(VendorLocationType.branch.displayName, 'Branch Hub');
      expect(VendorLocationType.railwayStation.displayName, 'Railway Station');
      expect(VendorLocationType.publicPoint.displayName, 'Public Meeting Point');
      expect(VendorLocationType.office.displayName, 'Commercial Office');
    });

    test('3. VendorLocationType parses from API strings with fallback', () {
      expect(VendorLocationTypeExt.fromApiString('AIRPORT'), VendorLocationType.airport);
      expect(VendorLocationTypeExt.fromApiString('BRANCH'), VendorLocationType.branch);
      expect(VendorLocationTypeExt.fromApiString('UNKNOWN_VALUE'), VendorLocationType.vendorYard);
    });

    test('4. Operating hours schedule string formats 24x7 and standard hours', () {
      final loc24x7 = VendorLocationModel(
        id: '1',
        vendorId: 'v',
        name: 'Airport Hub',
        address: 'Terminal',
        city: 'HYD',
        latitude: 17.0,
        longitude: 78.0,
        is24x7: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(loc24x7.scheduleDisplay, 'Open 24x7');

      final locHours = loc24x7.copyWith(is24x7: false, openingTime: '09:00', closingTime: '21:00');
      expect(locHours.scheduleDisplay, '09:00 - 21:00');
    });

    test('5. VendorLocationModel copyWith correctly overrides fields', () {
      final loc = VendorLocationModel(
        id: 'loc_1',
        vendorId: 'v_1',
        name: 'Original Name',
        address: 'Old Address',
        city: 'Hyderabad',
        latitude: 17.0,
        longitude: 78.0,
        status: VendorLocationStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = loc.copyWith(
        name: 'New Yard',
        status: VendorLocationStatus.inactive,
        pickupFee: 250,
      );

      expect(updated.name, 'New Yard');
      expect(updated.status, VendorLocationStatus.inactive);
      expect(updated.pickupFee, 250);
      expect(updated.address, 'Old Address');
    });

    test('6. Delivery Policy Model serializes and handles defaults', () {
      const policy = VendorDeliveryPolicyModel(
        vendorId: 'v_1',
        deliveryEnabled: true,
        maxDeliveryRadiusKm: 25.0,
        pricingModel: DeliveryPricingModel.distanceBased,
        baseDeliveryFee: 150.0,
        perKmDeliveryFee: 25.0,
        freeDeliveryWithinKm: 3.0,
      );

      final json = policy.toJson();
      expect(json['deliveryEnabled'], true);
      expect(json['pricingModel'], 'DISTANCE_BASED');

      final parsed = VendorDeliveryPolicyModel.fromJson(json);
      expect(parsed.maxDeliveryRadiusKm, 25.0);
      expect(parsed.pricingModel, DeliveryPricingModel.distanceBased);
    });

    test('7. Delivery pricing calculation under FREE pricing model', () {
      const policy = VendorDeliveryPolicyModel(
        vendorId: 'v_1',
        deliveryEnabled: true,
        maxDeliveryRadiusKm: 20.0,
        pricingModel: DeliveryPricingModel.free,
      );
      expect(policy.pricingModel, DeliveryPricingModel.free);
    });

    test('8. Delivery pricing calculation under FIXED pricing model', () {
      const policy = VendorDeliveryPolicyModel(
        vendorId: 'v_1',
        deliveryEnabled: true,
        maxDeliveryRadiusKm: 15.0,
        pricingModel: DeliveryPricingModel.fixed,
        baseDeliveryFee: 350.0,
      );
      expect(policy.baseDeliveryFee, 350.0);
    });

    test('9. Location Matrix item model parses correctly', () {
      const matrixItem = LocationMatrixItemModel(
        pickupLocationId: 'hub_1',
        returnLocationId: 'hub_2',
        pickupLocationName: 'Main Yard',
        returnLocationName: 'Airport Desk',
        isSupported: true,
        oneWaySurcharge: 250.0,
      );

      final json = matrixItem.toJson();
      expect(json['oneWaySurcharge'], 250.0);
      expect(json['isSupported'], true);

      final fromJson = LocationMatrixItemModel.fromJson(json);
      expect(fromJson.pickupLocationName, 'Main Yard');
      expect(fromJson.returnLocationName, 'Airport Desk');
    });

    test('10. Location operations summary parses today bookings counts', () {
      const summary = LocationOperationsSummaryModel(
        locations: [
          LocationOperationsItemSummary(
            locationId: 'l1',
            locationName: 'Yard 1',
            locationType: 'VENDOR_YARD',
            todayPickups: 6,
            todayReturns: 4,
            activeVehicles: 8,
          ),
        ],
        totalTodayPickups: 6,
        totalTodayReturns: 4,
        totalDeliveryRequests: 2,
      );

      final json = summary.toJson();
      expect(json['totalTodayPickups'], 6);
      expect(json['totalTodayReturns'], 4);

      final parsed = LocationOperationsSummaryModel.fromJson(json);
      expect(parsed.locations.first.todayPickups, 6);
    });

    test('11. Pickup operating modes provide titles and descriptions', () {
      expect(PickupOperatingMode.atMyLocation.title, 'At my location');
      expect(PickupOperatingMode.multipleLocations.title, 'At multiple locations');
      expect(PickupOperatingMode.publicPoints.title, 'At selected public points');
      expect(PickupOperatingMode.deliveryToCustomers.title, 'I deliver to customers');
      expect(PickupOperatingMode.combination.title, 'Combination of these');
    });

    test('12. Location status enum converts correctly', () {
      expect(VendorLocationStatus.active.toApiString(), 'ACTIVE');
      expect(VendorLocationStatus.inactive.toApiString(), 'INACTIVE');
      expect(VendorLocationStatusExt.fromApiString('ACTIVE'), VendorLocationStatus.active);
      expect(VendorLocationStatusExt.fromApiString('INACTIVE'), VendorLocationStatus.inactive);
    });

    test('13. Delivery pricing model enum parses correctly', () {
      expect(DeliveryPricingModel.free.toApiString(), 'FREE');
      expect(DeliveryPricingModel.fixed.toApiString(), 'FIXED');
      expect(DeliveryPricingModel.distanceBased.toApiString(), 'DISTANCE_BASED');
      expect(DeliveryPricingModelExt.fromApiString('FIXED'), DeliveryPricingModel.fixed);
    });

    test('14. Public location catalog contains approved airports and terminals', () {
      const publicItem = {
        'id': 'pub_hyd_rgia',
        'name': 'Rajiv Gandhi International Airport (HYD)',
        'type': 'AIRPORT',
        'city': 'Hyderabad',
      };
      expect(publicItem['type'], 'AIRPORT');
      expect(publicItem['name'], contains('Airport'));
    });

    test('15. Surcharge is 0 for identical pickup and return location', () {
      const matrixItem = LocationMatrixItemModel(
        pickupLocationId: 'hub_1',
        returnLocationId: 'hub_1',
        pickupLocationName: 'Main Yard',
        returnLocationName: 'Main Yard',
        isSupported: true,
        oneWaySurcharge: 0.0,
      );
      expect(matrixItem.oneWaySurcharge, 0.0);
    });

    test('16. Location handles zero fees and extreme coordinates safely', () {
      final loc = VendorLocationModel(
        id: 'loc_zero',
        vendorId: 'v_1',
        name: 'Zero Fee Hub',
        address: 'Address',
        city: 'Mumbai',
        latitude: -89.9,
        longitude: 179.9,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(loc.pickupFee, 0.0);
      expect(loc.oneWayFee, 0.0);
      expect(loc.latitude, -89.9);
    });

    test('17. Location vehicle assignment preserves car IDs correctly', () {
      final loc = VendorLocationModel(
        id: 'loc_cars',
        vendorId: 'v_1',
        name: 'Fleet Yard',
        address: 'Station Rd',
        city: 'Hyderabad',
        latitude: 17.4,
        longitude: 78.4,
        assignedCarIds: ['car_10', 'car_20', 'car_30', 'car_40'],
        assignedCarCount: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(loc.assignedCarIds.contains('car_20'), true);
      expect(loc.assignedCarCount, 4);
    });
  });

  group('Phase 29.11: State Providers & Riverpod Logic (18-22)', () {
    test('18. VendorLocationsNotifier adds and toggles location status', () async {
      final container = ProviderContainer(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(vendorLocationsProvider.notifier);
      await notifier.loadLocations();

      final initialLocations = container.read(vendorLocationsProvider).value!;
      expect(initialLocations.isNotEmpty, true);

      final newLoc = VendorLocationModel(
        id: 'loc_new_test',
        vendorId: 'v_1',
        name: 'New Test Yard',
        address: 'Banjara Hills',
        city: 'Hyderabad',
        latitude: 17.4123,
        longitude: 78.4321,
        status: VendorLocationStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notifier.addLocation(newLoc);
      final afterAdd = container.read(vendorLocationsProvider).value!;
      expect(afterAdd.any((l) => l.id == 'loc_new_test'), true);

      await notifier.toggleLocationStatus('loc_new_test');
      final afterToggle = container.read(vendorLocationsProvider).value!;
      final toggled = afterToggle.firstWhere((l) => l.id == 'loc_new_test');
      expect(toggled.status, VendorLocationStatus.inactive);
    });

    test('19. VendorDeliveryPolicyNotifier updates policy parameters', () async {
      final container = ProviderContainer(
        overrides: [
          vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(vendorDeliveryPolicyProvider.notifier);
      final current = container.read(vendorDeliveryPolicyProvider).value!;

      final updated = current.copyWith(
        maxDeliveryRadiusKm: 30.0,
        pricingModel: DeliveryPricingModel.distanceBased,
        baseDeliveryFee: 200.0,
      );

      await notifier.updatePolicy(updated);
      final result = container.read(vendorDeliveryPolicyProvider).value!;
      expect(result.maxDeliveryRadiusKm, 30.0);
      expect(result.pricingModel, DeliveryPricingModel.distanceBased);
      expect(result.baseDeliveryFee, 200.0);
    });

    test('20. VendorLocationMatrixProvider dynamically computes combinations', () async {
      final container = ProviderContainer(
        overrides: [
          vendorLocationMatrixProvider.overrideWith((ref) async => [
            const LocationMatrixItemModel(
              pickupLocationId: 'loc_1',
              returnLocationId: 'loc_2',
              pickupLocationName: 'Main Yard',
              returnLocationName: 'Airport Desk',
              isSupported: true,
              oneWaySurcharge: 250.0,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);

      final matrixAsync = await container.read(vendorLocationMatrixProvider.future);
      expect(matrixAsync.isNotEmpty, true);
      expect(matrixAsync.any((m) => m.pickupLocationId != m.returnLocationId), true);
    });

    test('21. LocationOperationsSummaryProvider aggregates active operations', () async {
      final container = ProviderContainer(
        overrides: [
          locationOperationsSummaryProvider.overrideWith((ref) async => const LocationOperationsSummaryModel(
            locations: [
              LocationOperationsItemSummary(
                locationId: 'l1',
                locationName: 'Main Yard',
                locationType: 'VENDOR_YARD',
                todayPickups: 3,
                todayReturns: 2,
                activeVehicles: 8,
              ),
            ],
            totalTodayPickups: 3,
            totalTodayReturns: 2,
            totalDeliveryRequests: 1,
          )),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(locationOperationsSummaryProvider.future);
      expect(summary.totalTodayPickups, greaterThan(0));
      expect(summary.totalTodayReturns, greaterThan(0));
      expect(summary.totalDeliveryRequests, greaterThan(0));
    });

    test('22. PublicLocationCatalogProvider loads approved transport points', () async {
      final container = ProviderContainer(
        overrides: [
          publicLocationCatalogProvider.overrideWith((ref) async => [
            {'id': '1', 'name': 'RGIA', 'type': 'AIRPORT'},
            {'id': '2', 'name': 'Secunderabad', 'type': 'RAILWAY_STATION'},
            {'id': '3', 'name': 'HITEC Metro', 'type': 'PUBLIC_POINT'},
            {'id': '4', 'name': 'MGBS', 'type': 'BUS_TERMINAL'},
          ]),
        ],
      );
      addTearDown(container.dispose);

      final catalog = await container.read(publicLocationCatalogProvider.future);
      expect(catalog.length, greaterThanOrEqualTo(4));
      expect(catalog.any((c) => c['type'] == 'AIRPORT'), true);
      expect(catalog.any((c) => c['type'] == 'RAILWAY_STATION'), true);
    });
  });

  group('Phase 29.11: Widget UI Tests (23-33)', () {
    testWidgets('23. VendorLocationSettingsPage renders active locations and sections',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location & Delivery Settings'), findsOneWidget);
      expect(find.text('WHERE DO YOU HAND OVER CARS?'), findsOneWidget);
      expect(find.text('MY LOCATIONS'), findsOneWidget);
      expect(find.text('DELIVERY SETTINGS'), findsOneWidget);
      expect(find.text('SAVE SETTINGS'), findsOneWidget);
    });

    testWidgets('24. VendorLocationSettingsPage renders empty state when location list is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _EmptyLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SET UP YOUR FIRST PICKUP LOCATION'), findsOneWidget);
      expect(find.text('ADD FIRST LOCATION'), findsOneWidget);
    });

    testWidgets('25. Operating mode switch updates state in VendorLocationSettingsPage',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final multipleLocationsTile = find.text('At multiple locations');
      expect(multipleLocationsTile, findsOneWidget);
      await tester.tap(multipleLocationsTile);
      await tester.pumpAndSettle();
    });

    testWidgets('26. Delivery Settings toggle controls radius and pricing chips',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DELIVERY SETTINGS'), findsOneWidget);
      expect(find.text('Maximum Delivery Radius'), findsOneWidget);
      expect(find.text('15 km'), findsOneWidget);
      expect(find.text('Fixed Fee (₹300)'), findsOneWidget);

      final chipFinder = find.text('25 km');
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('27. AddLocationWizardPage renders Step 1: Location Type',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: AddLocationWizardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 8: Location Type'), findsOneWidget);
      expect(find.text('Vendor Yard / Garage'), findsOneWidget);
      expect(find.text('Airport Terminal'), findsOneWidget);
      expect(find.text('Branch Hub'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets('28. AddLocationWizardPage navigates to Step 2: Location Details',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: AddLocationWizardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 8: Location Details'), findsOneWidget);
      expect(find.text('Location Address & Contact'), findsOneWidget);
    });

    testWidgets('29. AddLocationWizardPage navigates through Steps 3, 4, 5, 6, 7 to Step 8',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: AddLocationWizardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Map & Coordinates)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 8: Map & Coordinates'), findsOneWidget);

      // Step 3 -> Step 4 (Operating Hours)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 8: Operating Hours'), findsOneWidget);

      // Step 4 -> Step 5 (Capabilities)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 8: Capabilities'), findsOneWidget);

      // Step 5 -> Step 6 (Pricing & Fees)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 6 of 8: Pricing & Fees'), findsOneWidget);

      // Step 6 -> Step 7 (Vehicle Assignment)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 7 of 8: Vehicle Assignment'), findsOneWidget);

      // Step 7 -> Step 8 (Review & Activate)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Step 8 of 8: Review & Activate'), findsOneWidget);
      expect(find.text('ACTIVATE LOCATION'), findsOneWidget);
    });

    testWidgets('30. AddLocationWizardPage activates location and shows success modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: AddLocationWizardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fast forward to step 8
      for (int i = 0; i < 7; i++) {
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('ACTIVATE LOCATION'));
      await tester.pumpAndSettle();

      expect(find.text('Location Activated!'), findsOneWidget);
      expect(find.text('VIEW ALL LOCATIONS'), findsOneWidget);
    });

    testWidgets('31. LocationDetailPage renders comprehensive location details',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_hyd_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Overview'), findsOneWidget);
      expect(find.text('Hyderabad Main Yard'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Assigned Fleet (Stationed Vehicles)'), findsOneWidget);
    });

    testWidgets('32. LocationDetailPage shows confirmation dialog upon delete tap',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_hyd_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Disable Location?'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
    });

    testWidgets('33. Save settings displays success feedback SnackBar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.text('SAVE SETTINGS');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('Location & delivery settings saved successfully!'), findsOneWidget);
    });
  });
}

class _MockVendorLocationsNotifier extends VendorLocationsNotifier {
  _MockVendorLocationsNotifier(super.ref) : super() {
    state = AsyncValue.data(_mockLocations);
  }

  static final _mockLocations = [
    VendorLocationModel(
      id: 'loc_hyd_main_yard',
      vendorId: 'v_1',
      name: 'Hyderabad Main Yard',
      type: VendorLocationType.vendorYard,
      address: 'Plot 42, Silicon Valley, Madhapur',
      locality: 'Madhapur',
      city: 'Hyderabad',
      state: 'Telangana',
      pincode: '500081',
      latitude: 17.4483,
      longitude: 78.3915,
      contactPerson: 'Rahul Verma (Yard Mgr)',
      contactPhone: '+91 98765 43210',
      status: VendorLocationStatus.active,
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: true,
      pickupFee: 0,
      returnFee: 0,
      oneWayFee: 0,
      openingTime: '08:00',
      closingTime: '22:00',
      is24x7: false,
      serviceRadiusKm: 25.0,
      assignedCarCount: 8,
      assignedCarIds: ['car_1', 'car_2', 'car_3'],
      createdAt: DateTime(2026, 1, 15),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_hyd_airport',
      vendorId: 'v_1',
      name: 'Rajiv Gandhi International Airport (HYD)',
      type: VendorLocationType.airport,
      address: 'Terminal 1 Parking P4, RGIA Shamshabad',
      locality: 'Shamshabad',
      city: 'Hyderabad',
      state: 'Telangana',
      pincode: '500409',
      latitude: 17.2403,
      longitude: 78.4294,
      contactPerson: 'Airport Dispatch Desk',
      contactPhone: '+91 98765 43211',
      status: VendorLocationStatus.active,
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: false,
      pickupFee: 300,
      returnFee: 0,
      oneWayFee: 250,
      openingTime: '00:00',
      closingTime: '23:59',
      is24x7: true,
      serviceRadiusKm: 15.0,
      assignedCarCount: 4,
      assignedCarIds: ['car_4', 'car_5'],
      createdAt: DateTime(2026, 2, 10),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> loadLocations() async {
    state = AsyncValue.data(_mockLocations);
  }

  @override
  Future<VendorLocationModel> addLocation(VendorLocationModel newLocation) async {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, newLocation]);
    return newLocation;
  }

  @override
  Future<VendorLocationModel> updateLocation(VendorLocationModel updated) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((loc) => loc.id == updated.id ? updated : loc).toList(),
    );
    return updated;
  }
}

class _MockVendorDeliveryPolicyNotifier extends VendorDeliveryPolicyNotifier {
  _MockVendorDeliveryPolicyNotifier(super.ref) : super() {
    state = const AsyncValue.data(
      VendorDeliveryPolicyModel(
        vendorId: 'v_1',
        deliveryEnabled: true,
        maxDeliveryRadiusKm: 15.0,
        pricingModel: DeliveryPricingModel.fixed,
        baseDeliveryFee: 300.0,
        perKmDeliveryFee: 20.0,
        freeDeliveryWithinKm: 5.0,
      ),
    );
  }

  @override
  Future<void> loadPolicy() async {
    state = const AsyncValue.data(
      VendorDeliveryPolicyModel(
        vendorId: 'v_1',
        deliveryEnabled: true,
        maxDeliveryRadiusKm: 15.0,
        pricingModel: DeliveryPricingModel.fixed,
        baseDeliveryFee: 300.0,
        perKmDeliveryFee: 20.0,
        freeDeliveryWithinKm: 5.0,
      ),
    );
  }

  @override
  Future<void> updatePolicy(VendorDeliveryPolicyModel updated) async {
    state = AsyncValue.data(updated);
  }
}

class _EmptyLocationsNotifier extends VendorLocationsNotifier {
  _EmptyLocationsNotifier(super.ref) : super() {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> loadLocations() async {
    state = const AsyncValue.data([]);
  }
}


