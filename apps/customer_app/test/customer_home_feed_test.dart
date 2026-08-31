import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/home/presentation/pages/home_page.dart';
import 'package:customer_app/features/home/presentation/widgets/home_available_cars_section.dart';
import 'package:customer_app/features/home/presentation/widgets/home_popular_cities_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_trust_assurance_widget.dart';
import 'package:customer_app/features/home/home_providers.dart';
import 'package:customer_app/features/home/domain/repositories/home_repository.dart';

class MockHomeMarketplaceRepo implements HomeRepository {
  final List<CarModel> cars;
  final List<SupportedCityModel> cities;

  MockHomeMarketplaceRepo({
    this.cars = const [
      CarModel(
        id: 'car-mumbai-1',
        vendorId: 'v1',
        make: 'Hyundai',
        model: 'Creta',
        year: 2023,
        type: 'SUV',
        fuelType: 'Diesel',
        seating: 5,
        isAC: true,
        photos: ['https://example.com/creta.jpg'],
        pricePerKm: 14.0,
        pricePerDay: 2400.0,
        pricePerHour: 200.0,
        isSponsored: false,
        distanceKm: 3.2,
      ),
      CarModel(
        id: 'car-mumbai-2',
        vendorId: 'v2',
        make: 'Maruti Suzuki',
        model: 'Swift',
        year: 2022,
        type: 'Hatchback',
        fuelType: 'Petrol',
        seating: 5,
        isAC: true,
        photos: ['https://example.com/swift.jpg'],
        pricePerKm: 12.0,
        pricePerDay: 1700.0,
        pricePerHour: 140.0,
        isSponsored: true,
      ),
    ],
    this.cities = const [
      SupportedCityModel(id: 'c1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
      SupportedCityModel(id: 'c2', name: 'Delhi', state: 'Delhi', latitude: 28.6139, longitude: 77.2090),
      SupportedCityModel(id: 'c3', name: 'Bangalore', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946),
    ],
  });

  @override
  Future<List<CarModel>> getCarsByCity(String city, {double? lat, double? lng, String sortBy = 'RECOMMENDED'}) async {
    if (city.toLowerCase() == 'emptycity') return [];
    return cars;
  }

  @override
  Future<List<VendorModel>> getTopVendorsByCity(String city) async => [
        const VendorModel(
          id: 'v1',
          businessName: 'Apex Drive Mumbai',
          ownerName: 'Rajesh Kulkarni',
          city: 'Mumbai',
          locality: 'Bandra West',
          rating: 4.8,
          totalTrips: 210,
          verificationStatus: 'verified',
        ),
      ];

  @override
  Future<List<BannerModel>> getBanners() async => [
        const BannerModel(
          id: 'b1',
          imageUrl: 'https://example.com/banner.jpg',
          title: 'Monsoon Roadtrip Offers',
          ctaLink: '/search?tripType=Self-Drive',
          displayOrder: 1,
        ),
      ];

  @override
  Future<PublicSettingsModel> getPublicSettings() async => const PublicSettingsModel(
        platformName: 'DriveGo',
        supportEmail: 'support@drivego.in',
        supportPhone: '+919876543210',
        enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
      );

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async => cities;

  @override
  Future<SupportedCityModel> getNearestCity(double lat, double lng) async => cities.first;
}

void main() {
  group('Customer Home Marketplace Feed & Search Entry (Phase 29.3)', () {
    testWidgets('1. Available cars section renders real vehicles with price tags, badges, and specs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeMarketplaceRepo()),
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

      // Verify Available Cars Section
      expect(find.byType(HomeAvailableCarsSection), findsOneWidget);
      expect(find.text('Available in Mumbai'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Maruti Suzuki Swift'), findsOneWidget);
      expect(find.text('SPONSORED'), findsOneWidget);
      expect(find.text('5 Seats'), findsWidgets);
      expect(find.text('Diesel'), findsOneWidget);
      expect(find.text('3.2 km'), findsOneWidget);
    });

    testWidgets('2. Popular Cities Widget renders supported cities and switches selected city on tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeMarketplaceRepo()),
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

      expect(find.byType(HomePopularCitiesWidget), findsOneWidget);
      expect(find.text('Explore Popular Cities'), findsOneWidget);

      final bangaloreFinder = find.text('Bangalore');
      await tester.ensureVisible(bangaloreFinder);
      await tester.pumpAndSettle();

      // Tap on Bangalore
      await tester.tap(bangaloreFinder);
      await tester.pumpAndSettle();

      expect(container.read(selectedCityProvider), equals('Bangalore'));
    });

    testWidgets('3. DriveGo Assurance section renders all 4 platform trust cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeMarketplaceRepo()),
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

      expect(find.byType(HomeTrustAssuranceWidget), findsOneWidget);
      expect(find.text('The DriveGo Assurance'), findsOneWidget);
      expect(find.text('Verified Partners'), findsOneWidget);
      expect(find.text('Transparent Pricing'), findsOneWidget);
      expect(find.text('Digital OTP Handover'), findsOneWidget);
      expect(find.text('24/7 Roadside Help'), findsOneWidget);
    });

    testWidgets('4. Quick date shortcuts (Today, Tomorrow, Weekend, 7 Days) update date range', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeMarketplaceRepo()),
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

      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('This Weekend'), findsOneWidget);

      // Tap Tomorrow
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();

      final range = container.read(selectedDateRangeProvider);
      expect(range, isNotNull);
      expect(range!.duration.inDays, equals(1));
    });

    testWidgets('5. Empty state is displayed when selected city has no available cars', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(MockHomeMarketplaceRepo()),
          selectedCityProvider.overrideWith((ref) => 'EmptyCity'),
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

      expect(find.text('No Cars Available in EmptyCity'), findsOneWidget);
      expect(find.text('Choose Another City'), findsOneWidget);
    });
  });
}
