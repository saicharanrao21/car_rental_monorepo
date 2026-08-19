import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/car_detail/presentation/pages/car_detail_page.dart';
import 'package:customer_app/features/car_detail/presentation/providers/car_detail_providers.dart';
import 'package:customer_app/features/car_detail/domain/repositories/car_detail_repository.dart';
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

  group('Car Details Compact Availability Confirmation Tests (Phase 10.4)', () {
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
      expect(find.text('Available for your selected trip'), findsOneWidget);
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
      expect(find.text('Select dates to check availability'), findsOneWidget);
      expect(find.text('Available for your selected trip'), findsNothing);
      expect(find.text('Vehicle Availability'), findsNothing);
    });
  });
}
