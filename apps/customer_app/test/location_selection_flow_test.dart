import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_app/features/location/presentation/widgets/location_selection_sheet.dart';
import 'package:customer_app/core/providers/location_provider.dart';
import 'package:customer_app/core/providers/locality_provider.dart';
import 'package:customer_app/core/providers/recent_locations_provider.dart';

// Fake notifier for testing location detection states without physical GPS
class MockUserLocationNotifier extends UserLocationNotifier {
  final LocationDetectionStatus mockStatus;
  final double? mockLat;
  final double? mockLng;
  final String? mockErrorMsg;

  MockUserLocationNotifier({
    this.mockStatus = LocationDetectionStatus.success,
    this.mockLat = 19.0760,
    this.mockLng = 72.8777,
    this.mockErrorMsg,
  }) : super();

  @override
  Future<CurrentLocationResult> detectCurrentLocation() async {
    state = state.copyWith(
      detectionStatus: mockStatus,
      latitude: mockLat,
      longitude: mockLng,
      lastError: mockErrorMsg,
    );

    if (mockStatus == LocationDetectionStatus.success) {
      return CurrentLocationResult(
        status: LocationDetectionStatus.success,
        latitude: mockLat,
        longitude: mockLng,
        resolvedCity: 'Mumbai',
        resolvedLocality: 'Bandra Kurla Complex',
      );
    } else if (mockStatus == LocationDetectionStatus.permissionDenied) {
      return const CurrentLocationResult(
        status: LocationDetectionStatus.permissionDenied,
        message: 'Location permission is required to detect your location.',
      );
    } else if (mockStatus == LocationDetectionStatus.permanentlyDenied) {
      return const CurrentLocationResult(
        status: LocationDetectionStatus.permanentlyDenied,
        message: 'Location access is blocked in app settings. Please enable it in system settings.',
      );
    } else if (mockStatus == LocationDetectionStatus.serviceDisabled) {
      return const CurrentLocationResult(
        status: LocationDetectionStatus.serviceDisabled,
        message: 'Location services are turned off. Please enable GPS in settings.',
      );
    } else {
      return CurrentLocationResult(
        status: LocationDetectionStatus.error,
        message: mockErrorMsg ?? 'Could not retrieve your location. Please select manually.',
      );
    }
  }
}

void main() {
  group('LocationSelectionSheet & Location Flow Tests (Phase 12.2)', () {
    testWidgets('1. Renders LocationSelectionSheet with title, search input, and Use Current Location', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Choose Pickup Location'), findsOneWidget);
      expect(find.text('Use current location'), findsOneWidget);
      expect(find.text('Detect your current location automatically via GPS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Popular Hubs in Mumbai'), findsOneWidget);
      expect(find.text('Chhatrapati Shivaji Maharaj Airport (T2)'), findsOneWidget);
    });

    testWidgets('2. Tapping a popular hub selects location and calls callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? selectedLocation;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {
                  selectedLocation = loc;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Chhatrapati Shivaji Maharaj Airport (T2)'));
      await tester.pumpAndSettle();

      expect(selectedLocation, equals('Chhatrapati Shivaji Maharaj Airport (T2), Mumbai'));
    });

    testWidgets('3. Typing custom search query displays custom location option', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? selectedLocation;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localitySuggestionsProvider.overrideWith((ref, query) async => ['Andheri East', 'Andheri West']),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Drop Location',
                city: 'Mumbai',
                isDropLocation: true,
                onLocationSelected: (loc, {lat, lng}) {
                  selectedLocation = loc;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Juhu Beach');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Use "Juhu Beach"'), findsOneWidget);

      await tester.tap(find.text('Use "Juhu Beach"'));
      await tester.pumpAndSettle();

      expect(selectedLocation, equals('Juhu Beach, Mumbai'));
    });

    testWidgets('4. Recent locations list renders and allows selection', (tester) async {
      SharedPreferences.setMockInitialValues({
        'drivego_recent_locations': ['Powai Lake, Mumbai', 'Colaba Causeway, Mumbai'],
      });
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? selectedLocation;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {
                  selectedLocation = loc;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Locations'), findsOneWidget);
      expect(find.text('Powai Lake, Mumbai'), findsOneWidget);
      expect(find.text('Colaba Causeway, Mumbai'), findsOneWidget);

      await tester.tap(find.text('Powai Lake, Mumbai'));
      await tester.pumpAndSettle();

      expect(selectedLocation, equals('Powai Lake, Mumbai'));
    });

    testWidgets('5. Successful GPS detection resolves location and triggers callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? selectedLocation;
      double? selectedLat;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationProvider.overrideWith((ref) => MockUserLocationNotifier(
              mockStatus: LocationDetectionStatus.success,
              mockLat: 19.0760,
              mockLng: 72.8777,
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {
                  selectedLocation = loc;
                  selectedLat = lat;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(selectedLocation, contains('Bandra Kurla Complex'));
      expect(selectedLat, equals(19.0760));
    });

    testWidgets('6. Permission denied displays explanatory error message and preserves manual selection', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationProvider.overrideWith((ref) => MockUserLocationNotifier(
              mockStatus: LocationDetectionStatus.permissionDenied,
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(find.text('Location permission is required to detect your location.'), findsOneWidget);
      expect(find.text('Popular Hubs in Mumbai'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('7. Location services disabled displays GPS warning and manual option remains usable', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationProvider.overrideWith((ref) => MockUserLocationNotifier(
              mockStatus: LocationDetectionStatus.serviceDisabled,
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LocationSelectionSheet(
                title: 'Choose Pickup Location',
                city: 'Mumbai',
                onLocationSelected: (loc, {lat, lng}) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(find.text('Location services are turned off. Please enable GPS in settings.'), findsOneWidget);
      expect(find.text('Enable GPS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('8. RecentLocationsNotifier stores up to 5 unique locations in SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recentLocationsProvider.notifier);
      await notifier.addLocation('Location 1');
      await notifier.addLocation('Location 2');
      await notifier.addLocation('Location 3');
      await notifier.addLocation('Location 4');
      await notifier.addLocation('Location 5');
      await notifier.addLocation('Location 6');

      final list = container.read(recentLocationsProvider);
      expect(list.length, equals(5));
      expect(list.first, equals('Location 6'));
      expect(list.contains('Location 1'), isFalse);
    });
  });
}
