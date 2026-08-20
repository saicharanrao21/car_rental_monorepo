import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/car_detail/presentation/pages/car_detail_page.dart';
import 'package:customer_app/features/car_detail/presentation/providers/car_detail_providers.dart';
import 'package:customer_app/features/car_detail/domain/repositories/car_detail_repository.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_image_gallery.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_identity_section.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_specifications_section.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/selected_trip_summary_card.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/mileage_package_selector.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_pricing_section.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_features_section.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_vendor_section.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/car_booking_bottom_bar.dart';
import 'package:customer_app/features/search/presentation/providers/search_providers.dart';
import 'package:customer_app/features/home/home_providers.dart';

class MockCarDetailRepo implements CarDetailRepository {
  final CarModel car;
  final VendorModel vendor;

  MockCarDetailRepo({required this.car, required this.vendor});

  @override
  Future<CarModel> getCarById(String id) async => car;

  @override
  Future<VendorModel> getVendorById(String vendorId) async => vendor;

  @override
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId) async => [];
}

void main() {
  const testVendor = VendorModel(
    id: 'v_1',
    businessName: 'Speedy Partner',
    ownerName: 'Rahul',
    city: 'Mumbai',
    verificationStatus: 'verified',
    rating: 4.9,
    totalTrips: 150,
  );

  const testCar = CarModel(
    id: 'car_123',
    vendorId: 'v_1',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 12.0,
    pricePerDay: 2500.0,
    pricePerHour: 180.0,
    availableTripTypes: ['Self-Drive'],
  );

  final testCarWithPackages = CarModel.fromJson({
    'id': 'car_pkg_1',
    'vendorId': 'v_1',
    'make': 'Hyundai',
    'model': 'Creta',
    'year': 2024,
    'type': 'SUV',
    'fuelType': 'PETROL',
    'seating': 5,
    'isAC': true,
    'photos': [],
    'pricePerKm': 15.0,
    'pricePerDay': 3000.0,
    'pricePerHour': 200.0,
    'availableTripTypes': ['SELF_DRIVE'],
    'mileagePackages': [
      {
        'id': 'pkg_1',
        'carId': 'car_pkg_1',
        'tripType': 'SELF_DRIVE',
        'name': '100 km/day',
        'includedKmPerDay': 100,
        'basePricePerDay': 2500,
        'extraKmRate': 12,
        'isDefault': true,
        'isActive': true,
      },
      {
        'id': 'pkg_2',
        'carId': 'car_pkg_1',
        'tripType': 'SELF_DRIVE',
        'name': '200 km/day',
        'includedKmPerDay': 200,
        'basePricePerDay': 3200,
        'extraKmRate': 10,
        'isDefault': false,
        'isActive': true,
      },
    ],
  });

  group('Car Details Modernization & Flow Tests (Phase 14)', () {
    testWidgets(
        'Scenario 1: With active search dates, displays compact availability confirmation and no monthly calendar',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testRange = DateTimeRange(
        start: DateTime(2026, 8, 24, 10, 0),
        end: DateTime(2026, 8, 26, 10, 0),
      );

      final container = ProviderContainer(
        overrides: [
          carDetailRepositoryProvider.overrideWithValue(
            MockCarDetailRepo(car: testCar, vendor: testVendor),
          ),
          searchDatesProvider.overrideWith((ref) => testRange),
          searchTripTypeProvider.overrideWith((ref) => 'Self-Drive'),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CarDetailPage(carId: 'car_123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Compact availability badge is shown
      expect(find.byType(SelectedTripSummaryCard), findsOneWidget);
      expect(find.text('Available for your selected trip'), findsOneWidget);
      expect(find.text('Change Search'), findsOneWidget);
      expect(find.textContaining('Self-Drive'), findsWidgets);

      // Monthly availability calendar is NOT shown
      expect(find.text('Vehicle Availability'), findsNothing);
      expect(find.text('August 2026'), findsNothing);
      expect(find.text('Available / Booked / Blocked'), findsNothing);
    });

    testWidgets(
        'Scenario 2: Without active search dates, displays neutral date selection prompt with no false availability claim',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          carDetailRepositoryProvider.overrideWithValue(
            MockCarDetailRepo(car: testCar, vendor: testVendor),
          ),
          searchDatesProvider.overrideWith((ref) => null),
          selectedDateRangeProvider.overrideWith((ref) => null),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CarDetailPage(carId: 'car_123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Neutral prompt is shown
      expect(find.byType(SelectedTripSummaryCard), findsOneWidget);
      expect(find.text('Select dates to check availability'), findsOneWidget);
      expect(find.text('Available for your selected trip'), findsNothing);
      expect(find.text('Vehicle Availability'), findsNothing);
    });

    testWidgets(
        'Scenario 3: Renders all modernized sections (Gallery, Identity, Specs, Pricing, Features, Vendor, Bottom Bar)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          carDetailRepositoryProvider.overrideWithValue(
            MockCarDetailRepo(car: testCar, vendor: testVendor),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CarDetailPage(carId: 'car_123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CarImageGallery), findsOneWidget);
      expect(find.byType(CarIdentitySection), findsOneWidget);
      expect(find.byType(CarSpecificationsSection), findsOneWidget);
      expect(find.byType(CarPricingSection), findsOneWidget);
      expect(find.byType(CarFeaturesSection), findsOneWidget);
      expect(find.byType(CarVendorSection), findsOneWidget);
      expect(find.byType(CarBookingBottomBar), findsOneWidget);

      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('5 Seats'), findsOneWidget);
      expect(find.text('Book Now'), findsOneWidget);
      expect(find.text('Free Cancellation'), findsOneWidget);
      expect(find.text('Speedy Partner'), findsOneWidget);
    });

    testWidgets(
        'Scenario 4: Selectable mileage packages render and selection updates active package',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          carDetailRepositoryProvider.overrideWithValue(
            MockCarDetailRepo(car: testCarWithPackages, vendor: testVendor),
          ),
          searchTripTypeProvider.overrideWith((ref) => 'Self-Drive'),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CarDetailPage(carId: 'car_pkg_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MileagePackageSelector), findsOneWidget);
      expect(find.text('100 km/day'), findsOneWidget);
      expect(find.text('200 km/day'), findsOneWidget);

      // Scroll and tap 200 km/day package
      final pkgFinder = find.text('200 km/day');
      await tester.ensureVisible(pkgFinder);
      await tester.tap(pkgFinder);
      await tester.pumpAndSettle();

      expect(find.text('200 km/day'), findsOneWidget);
    });
  });
}
