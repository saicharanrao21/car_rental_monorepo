import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/booking/presentation/widgets/trip_details_step.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';

void main() {
  const vendor = VendorModel(
    id: 'vendor_1',
    businessName: 'Apex Drive Mumbai',
    ownerName: 'Apex Owner',
    phone: '+919876543210',
    email: 'apex@example.com',
    city: 'Mumbai',
    locality: 'Bandra',
  );

  final carWithPackages = CarModel.fromJson({
    'id': 'car_pkg_1',
    'vendorId': 'vendor_1',
    'make': 'Hyundai',
    'model': 'Creta',
    'year': 2023,
    'type': 'SUV',
    'fuelType': 'Petrol',
    'seating': 5,
    'isAC': true,
    'photos': [],
    'pricePerKm': 15.0,
    'pricePerDay': 3000.0,
    'pricePerHour': 200.0,
    'availableTripTypes': ['SELF_DRIVE', 'OUTSTATION'],
    'mileagePackages': [
      {
        'id': 'pkg_100',
        'carId': 'car_pkg_1',
        'tripType': 'SELF_DRIVE',
        'name': '100 km/day',
        'includedKmPerDay': 100,
        'basePricePerDay': 2500,
        'extraKmRate': 12,
        'isDefault': false,
        'isActive': true,
      },
      {
        'id': 'pkg_200',
        'carId': 'car_pkg_1',
        'tripType': 'SELF_DRIVE',
        'name': '200 km/day',
        'includedKmPerDay': 200,
        'basePricePerDay': 3200,
        'extraKmRate': 10,
        'isDefault': true,
        'isActive': true,
      },
      {
        'id': 'pkg_unlimited',
        'carId': 'car_pkg_1',
        'tripType': 'SELF_DRIVE',
        'name': 'Unlimited',
        'includedKmPerDay': null,
        'basePricePerDay': 4200,
        'extraKmRate': 0,
        'isDefault': false,
        'isActive': true,
      },
    ],
  });

  final legacyCarWithoutPackages = CarModel.fromJson({
    'id': 'car_legacy_1',
    'vendorId': 'vendor_1',
    'make': 'Maruti',
    'model': 'Swift',
    'year': 2022,
    'type': 'Hatchback',
    'fuelType': 'Petrol',
    'seating': 5,
    'isAC': true,
    'photos': [],
    'pricePerKm': 12.0,
    'pricePerDay': 2000.0,
    'pricePerHour': 150.0,
    'availableTripTypes': ['SELF_DRIVE'],
    'mileagePackages': [],
  });

  group('Customer App Mileage Packages Flow Tests', () {
    testWidgets('1. Package cards render for car with packages and manual distance input is ABSENT',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      container.read(bookingDraftProvider.notifier).init(
            car: carWithPackages,
            vendorId: vendor.id,
            tripType: 'Self-Drive',
            startDate: DateTime(2026, 8, 24, 10, 0),
            endDate: DateTime(2026, 8, 27, 10, 0), // 3 days
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TripDetailsStep(
                car: carWithPackages,
                vendor: vendor,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Package headers & cards must be visible
      expect(find.text('Choose your mileage package'), findsOneWidget);
      expect(find.text('100 km/day'), findsOneWidget);
      expect(find.text('200 km/day'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);

      // Default package (200 km/day) should be preselected with Popular badge
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Total included: 600 km (200 km/day)'), findsOneWidget);

      // Manual numeric input must NOT be present when packages exist
      expect(find.text('Estimated Distance (km)'), findsNothing);
    });

    testWidgets('2. Tapping a different package updates the selection and calculated total km',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      container.read(bookingDraftProvider.notifier).init(
            car: carWithPackages,
            vendorId: vendor.id,
            tripType: 'Self-Drive',
            startDate: DateTime(2026, 8, 24, 10, 0),
            endDate: DateTime(2026, 8, 26, 10, 0), // 2 days
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TripDetailsStep(
                car: carWithPackages,
                vendor: vendor,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 100 km/day package card
      await tester.tap(find.text('100 km/day'));
      await tester.pumpAndSettle();

      final draft = container.read(bookingDraftProvider);
      expect(draft.selectedMileagePackageId, 'pkg_100');
      expect(draft.selectedMileagePackage?.name, '100 km/day');
      expect(draft.selectedMileagePackage?.totalIncludedKm(2), 200);
    });

    testWidgets('3. Legacy car without packages gracefully renders legacy distance input',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      container.read(bookingDraftProvider.notifier).init(
            car: legacyCarWithoutPackages,
            vendorId: vendor.id,
            tripType: 'Self-Drive',
            startDate: DateTime(2026, 8, 24, 10, 0),
            endDate: DateTime(2026, 8, 26, 10, 0),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TripDetailsStep(
                car: legacyCarWithoutPackages,
                vendor: vendor,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No mileage package cards
      expect(find.text('Choose your mileage package'), findsNothing);

      // Legacy Estimated Distance input must be visible
      expect(find.text('Estimated Distance (km)'), findsOneWidget);
    });
  });
}
