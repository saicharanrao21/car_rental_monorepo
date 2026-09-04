import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/features/locations/presentation/providers/locations_providers.dart';
import 'package:vendor_app/features/locations/presentation/pages/location_detail_page.dart';
import 'package:vendor_app/features/locations/presentation/pages/vendor_location_settings_page.dart';

class _MockVendorLocationsNotifier extends VendorLocationsNotifier {
  final List<VendorLocationModel> _mockLocations;

  _MockVendorLocationsNotifier(super.ref, [List<VendorLocationModel>? initial])
      : _mockLocations = initial ??
            [
              VendorLocationModel(
                id: 'loc_main_yard',
                vendorId: 'v_1',
                name: 'Kavuri Hills Hub',
                address: 'Plot 42, Phase 2, Kavuri Hills, Madhapur',
                city: 'Hyderabad',
                latitude: 17.4435,
                longitude: 78.3912,
                type: VendorLocationType.vendorYard,
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
                serviceRadiusKm: 10.0,
                assignedCarCount: 2,
                assignedCarIds: ['car_1', 'car_2'],
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime.now(),
              ),
              VendorLocationModel(
                id: 'loc_airport',
                vendorId: 'v_1',
                name: 'Rajiv Gandhi International Airport (RGIA)',
                address: 'Shamshabad',
                city: 'Hyderabad',
                latitude: 17.2403,
                longitude: 78.4294,
                type: VendorLocationType.airport,
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
                assignedCarCount: 1,
                assignedCarIds: ['car_3'],
                createdAt: DateTime(2026, 2, 10),
                updatedAt: DateTime.now(),
              ),
            ] {
    state = AsyncValue.data(_mockLocations);
  }

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

  @override
  Future<VendorLocationModel> assignVehiclesToLocation(
    String locationId,
    List<String> assignedCarIds,
  ) async {
    final current = state.value ?? [];
    final loc = current.firstWhere((l) => l.id == locationId);
    final updated = loc.copyWith(
      assignedCarIds: assignedCarIds,
      assignedCarCount: assignedCarIds.length,
    );
    return updateLocation(updated);
  }
}

class _MockLocationExceptionsNotifier extends LocationExceptionsNotifier {
  _MockLocationExceptionsNotifier(super.ref, super.locationId, [List<LocationExceptionModel>? initial]) {
    state = AsyncValue.data(
      initial ??
          [
            LocationExceptionModel(
              id: 'exc_test_1',
              locationId: locationId,
              date: DateTime(2026, 9, 15),
              exceptionType: LocationExceptionType.holiday,
              isClosed: true,
              reason: 'Public Holiday - Ganesh Chaturthi',
            ),
          ],
    );
  }

  @override
  Future<void> loadExceptions() async {}

  @override
  Future<LocationExceptionModel> addException(LocationExceptionModel exception) async {
    final current = state.value ?? [];
    final updated = [...current, exception]..sort((a, b) => a.date.compareTo(b.date));
    state = AsyncValue.data(updated);
    return exception;
  }

  @override
  Future<void> deleteException(String exceptionId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != exceptionId).toList());
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
  Future<void> loadPolicy() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  group('Phase 29.17: Location Exceptions & Fleet Assignment Unit Tests', () {
    test('1. LocationExceptionsNotifier manages exception additions and deletions', () async {
      final container = ProviderContainer(
        overrides: [
          locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationExceptionsProvider('loc_main_yard').notifier);
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value!.first.reason, contains('Ganesh Chaturthi'));

      final newException = LocationExceptionModel(
        id: 'exc_test_2',
        locationId: 'loc_main_yard',
        date: DateTime(2026, 10, 2),
        exceptionType: LocationExceptionType.holiday,
        isClosed: true,
        reason: 'Gandhi Jayanti',
      );

      await notifier.addException(newException);
      expect(notifier.state.value!.length, 2);
      expect(notifier.state.value!.last.reason, 'Gandhi Jayanti');

      await notifier.deleteException('exc_test_1');
      expect(notifier.state.value!.length, 1);
      expect(notifier.state.value!.first.id, 'exc_test_2');
    });

    test('2. VendorLocationsNotifier assigns vehicle IDs and updates count', () async {
      final container = ProviderContainer(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(vendorLocationsProvider.notifier);
      final loc = notifier.state.value!.first;
      expect(loc.assignedCarCount, 2);

      await notifier.assignVehiclesToLocation(loc.id, ['car_1', 'car_2', 'car_3', 'car_4']);
      final updated = notifier.state.value!.firstWhere((l) => l.id == loc.id);
      expect(updated.assignedCarCount, 4);
      expect(updated.assignedCarIds, contains('car_4'));
    });
  });

  group('Phase 29.17: LocationDetailPage Widget Tests', () {
    testWidgets('3. Renders LocationDetailPage with exceptions and fleet assignment cards',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Overview'), findsOneWidget);
      expect(find.text('Kavuri Hills Hub'), findsOneWidget);
      expect(find.text('Operating Hours & Exceptions'), findsOneWidget);
      expect(find.text('Public Holiday - Ganesh Chaturthi'), findsOneWidget);
      expect(find.text('CLOSED'), findsOneWidget);
      expect(find.text('Assigned Fleet (Stationed Vehicles)'), findsOneWidget);
      expect(find.text('2 vehicles currently assigned to this location.'), findsOneWidget);
      expect(find.byKey(const Key('add_exception_button')), findsOneWidget);
      expect(find.byKey(const Key('manage_stationed_vehicles_button')), findsOneWidget);
    });

    testWidgets('4. Schedules new location exception via Add Exception dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late _MockLocationExceptionsNotifier capturedExceptionsNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            locationExceptionsProvider('loc_main_yard').overrideWith((ref) {
              capturedExceptionsNotifier = _MockLocationExceptionsNotifier(ref, 'loc_main_yard', []);
              return capturedExceptionsNotifier;
            }),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No scheduled exceptions. Normal operating hours apply.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_exception_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Location Exception'), findsOneWidget);
      expect(find.byKey(const Key('save_exception_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('save_exception_button')));
      await tester.pumpAndSettle();

      expect(capturedExceptionsNotifier.state.value!.isNotEmpty, true);
      expect(find.text('CLOSED'), findsOneWidget);
    });

    testWidgets('5. Deletes an existing exception via delete button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late _MockLocationExceptionsNotifier capturedExceptionsNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            locationExceptionsProvider('loc_main_yard').overrideWith((ref) {
              capturedExceptionsNotifier = _MockLocationExceptionsNotifier(
                ref,
                'loc_main_yard',
                [
                  LocationExceptionModel(
                    id: 'exc_to_delete',
                    locationId: 'loc_main_yard',
                    date: DateTime(2026, 9, 20),
                    exceptionType: LocationExceptionType.temporaryClosure,
                    isClosed: true,
                    reason: 'Emergency Water Pipeline Repair',
                  ),
                ],
              );
              return capturedExceptionsNotifier;
            }),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Water Pipeline Repair'), findsOneWidget);
      expect(find.byKey(const Key('delete_exception_exc_to_delete')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete_exception_exc_to_delete')));
      await tester.pumpAndSettle();

      expect(capturedExceptionsNotifier.state.value!.isEmpty, true);
      expect(find.text('No scheduled exceptions. Normal operating hours apply.'), findsOneWidget);
    });

    testWidgets('6. Opens fleet assignment dialog and updates assigned vehicles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late _MockVendorLocationsNotifier capturedLocationsNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) {
              capturedLocationsNotifier = _MockVendorLocationsNotifier(ref);
              return capturedLocationsNotifier;
            }),
            locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard', [])),
          ],
          child: const MaterialApp(
            home: LocationDetailPage(locationId: 'loc_main_yard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('manage_stationed_vehicles_button')));
      await tester.pumpAndSettle();

      expect(find.text('Assign Stationed Vehicles'), findsOneWidget);
      expect(find.byKey(const Key('fleet_checkbox_car_1')), findsOneWidget);
      expect(find.byKey(const Key('fleet_checkbox_car_3')), findsOneWidget);

      // Tap car_3 to toggle it on
      await tester.tap(find.byKey(const Key('fleet_checkbox_car_3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_vehicle_assignment_button')));
      await tester.pumpAndSettle();

      final updatedLoc = capturedLocationsNotifier.state.value!.firstWhere((l) => l.id == 'loc_main_yard');
      expect(updatedLoc.assignedCarCount, 3);
      expect(updatedLoc.assignedCarIds, contains('car_3'));
      expect(find.text('3 vehicles currently assigned to this location.'), findsOneWidget);
    });

    testWidgets('7. VendorLocationSettingsPage displays upcoming closure indicator for locations with closures',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
            vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
            vendorLocationMatrixProvider.overrideWith((ref) async => []),
            locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard', [
                  LocationExceptionModel(
                    id: 'exc_1',
                    locationId: 'loc_main_yard',
                    date: DateTime(2026, 9, 15),
                    exceptionType: LocationExceptionType.holiday,
                    isClosed: true,
                    reason: 'Ganesh Chaturthi',
                  ),
                ])),
            locationExceptionsProvider('loc_airport').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_airport', [])),
          ],
          child: const MaterialApp(
            home: VendorLocationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MY LOCATIONS'), findsOneWidget);
      expect(find.text('Kavuri Hills Hub'), findsOneWidget);
      expect(find.text('1 Upcoming Closure'), findsOneWidget);
    });
  });
}
