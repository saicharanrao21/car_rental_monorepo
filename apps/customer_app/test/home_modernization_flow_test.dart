import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/home/presentation/pages/home_page.dart';
import 'package:customer_app/features/home/presentation/widgets/home_header_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_trip_type_selector_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_trip_config_card.dart';
import 'package:customer_app/features/home/presentation/widgets/home_quick_categories_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_banners_carousel_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_top_vendors_widget.dart';
import 'package:customer_app/features/home/home_providers.dart';
import 'package:customer_app/features/home/domain/repositories/home_repository.dart';
import 'package:customer_app/features/location/presentation/widgets/location_selection_sheet.dart';

class MockHomeRepo implements HomeRepository {
  @override
  Future<List<CarModel>> getCarsByCity(String city, {double? lat, double? lng, String? sortBy}) async => [
        const CarModel(
          id: 'car-1',
          vendorId: 'v1',
          make: 'Maruti Suzuki',
          model: 'Swift',
          year: 2023,
          type: 'Hatchback',
          fuelType: 'Petrol',
          seating: 5,
          isAC: true,
          photos: ['https://example.com/car.jpg'],
          pricePerKm: 12.0,
          pricePerDay: 1700.0,
          pricePerHour: 150.0,
        ),
      ];

  @override
  Future<List<VendorModel>> getTopVendorsByCity(String city) async => [
        const VendorModel(
          id: 'v1',
          businessName: 'Apex Drive Logistics',
          ownerName: 'Rajesh Kumar',
          city: 'Mumbai',
          locality: 'Bandra West',
          rating: 4.9,
          totalTrips: 154,
          verificationStatus: 'verified',
        ),
      ];

  @override
  Future<List<BannerModel>> getBanners() async => [
        const BannerModel(
          id: 'b1',
          imageUrl: 'https://example.com/banner.jpg',
          title: 'Special Weekend Deal',
          ctaLink: '/search?tripType=Self-Drive',
          displayOrder: 1,
        ),
      ];

  @override
  Future<PublicSettingsModel> getPublicSettings() async => const PublicSettingsModel(
        platformName: 'DriveGo',
        supportEmail: 'support@drivego.com',
        supportPhone: '+91 9876543210',
        enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
      );

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async => [
        const SupportedCityModel(id: 'c1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
        const SupportedCityModel(id: 'c2', name: 'Pune', state: 'Maharashtra', latitude: 18.5204, longitude: 73.8567),
      ];

  @override
  Future<SupportedCityModel> getNearestCity(double lat, double lng) async => const SupportedCityModel(
        id: 'c1',
        name: 'Mumbai',
        state: 'Maharashtra',
        latitude: 19.0760,
        longitude: 72.8777,
      );
}

void main() {
  group('Home Screen Modernization Tests (Phase 12.3)', () {
    testWidgets('1. Renders modern Home Screen with Header, Trip Type Pills, Hero Card, Categories, Banners, and Top Vendors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeRepo()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomeHeaderWidget), findsOneWidget);
      expect(find.byType(HomeTripTypeSelectorWidget), findsOneWidget);
      expect(find.byType(HomeTripConfigCard), findsOneWidget);
      expect(find.byType(HomeQuickCategoriesWidget), findsOneWidget);
      expect(find.byType(HomeBannersCarouselWidget), findsOneWidget);
      expect(find.byType(HomeTopVendorsWidget), findsOneWidget);

      expect(find.text('Self-Drive'), findsOneWidget);
      expect(find.text('Outstation'), findsOneWidget);
      expect(find.text('PICKUP LOCATION / AREA'), findsOneWidget);
      expect(find.text('RENTAL SCHEDULE'), findsOneWidget);
      expect(find.text('Search Available Cars'), findsOneWidget);
      expect(find.text('Special Weekend Deal'), findsOneWidget);
      expect(find.text('Apex Drive Logistics'), findsOneWidget);
    });

    testWidgets('2. Switching Trip Type to Outstation displays Destination Drop Tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeRepo()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DESTINATION CITY / ADDRESS'), findsNothing);

      // Switch to Outstation
      await tester.tap(find.text('Outstation'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTripTypeProvider), equals('Outstation'));
      expect(find.text('DESTINATION CITY / ADDRESS'), findsOneWidget);
    });

    testWidgets('3. Tapping coming soon trip type shows informational snackbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeRepo()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      expect(find.text('Local service is launching soon in your city!'), findsOneWidget);
    });

    testWidgets('4. Tapping Pickup Location tile opens LocationSelectionSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeRepo()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('PICKUP LOCATION / AREA'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSelectionSheet), findsOneWidget);
      expect(find.text('Select Pickup Location'), findsOneWidget);
    });

    testWidgets('5. Selecting dates updates RENTAL SCHEDULE tile correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeRepo()),
        ],
      );

      // Pre-set a date range in the provider
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 4);
      container.read(selectedDateRangeProvider.notifier).state = DateTimeRange(start: start, end: end);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('01/09/2026 → 04/09/2026 (3 days)'), findsOneWidget);
    });
  });
}
