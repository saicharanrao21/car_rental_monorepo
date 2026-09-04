import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/features/locations/presentation/providers/locations_providers.dart';
import 'package:vendor_app/features/locations/presentation/pages/location_detail_page.dart';
import 'package:vendor_app/features/locations/presentation/pages/vendor_location_settings_page.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase29-17-location-exceptions');

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.runAsync(() async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${evidenceDir.path}/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[EVIDENCE_CAPTURED] ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

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
            LocationExceptionModel(
              id: 'exc_test_2',
              locationId: locationId,
              date: DateTime(2026, 9, 22),
              exceptionType: LocationExceptionType.customHours,
              isClosed: false,
              reason: 'Special Hours - Fleet Audit Inspection',
              specialOpeningTime: '10:00',
              specialClosingTime: '16:00',
            ),
          ],
    );
  }

  @override
  Future<void> loadExceptions() async {}
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

  testWidgets('Capture Phase 29.17 Evidence 01: Location Details & Exceptions List', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: repaintKey,
            child: const LocationDetailPage(locationId: 'loc_main_yard'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveScreenshot(tester, repaintKey, '01_location_exceptions_list.png');
  });

  testWidgets('Capture Phase 29.17 Evidence 02: Add Location Exception Dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
        ],
        child: MaterialApp(
          builder: (context, child) => RepaintBoundary(
            key: repaintKey,
            child: child!,
          ),
          home: const LocationDetailPage(locationId: 'loc_main_yard'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_exception_button')));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, repaintKey, '02_add_exception_dialog.png');
  });

  testWidgets('Capture Phase 29.17 Evidence 03: Assign Stationed Vehicles Dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
        ],
        child: MaterialApp(
          builder: (context, child) => RepaintBoundary(
            key: repaintKey,
            child: child!,
          ),
          home: const LocationDetailPage(locationId: 'loc_main_yard'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('manage_stationed_vehicles_button')));
    await tester.pumpAndSettle();

    await saveScreenshot(tester, repaintKey, '03_vehicle_fleet_assignment_dialog.png');
  });

  testWidgets('Capture Phase 29.17 Evidence 04: Vendor Location Settings Closure Indicator', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorLocationsProvider.overrideWith((ref) => _MockVendorLocationsNotifier(ref)),
          vendorDeliveryPolicyProvider.overrideWith((ref) => _MockVendorDeliveryPolicyNotifier(ref)),
          vendorLocationMatrixProvider.overrideWith((ref) async => []),
          locationExceptionsProvider('loc_main_yard').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_main_yard')),
          locationExceptionsProvider('loc_airport').overrideWith((ref) => _MockLocationExceptionsNotifier(ref, 'loc_airport', [])),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: repaintKey,
            child: const VendorLocationSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveScreenshot(tester, repaintKey, '04_vendor_location_closure_indicator.png');
  });
}
