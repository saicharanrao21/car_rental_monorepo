import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/search/presentation/pages/search_results_page.dart';
import 'package:customer_app/features/search/presentation/providers/search_providers.dart';
import 'package:customer_app/features/search/domain/repositories/search_repository.dart';
import 'package:customer_app/features/home/home_providers.dart';

class MockSearchRepo implements SearchRepository {
  final List<CarModel> cars;
  MockSearchRepo(this.cars);

  @override
  Future<List<CarModel>> searchCars({
    required String city,
    double? lat,
    double? lng,
    String? tripType,
    String? carType,
    bool? isAC,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async {
    return cars.where((c) {
      if (tripType != null && !c.availableTripTypes.contains(tripType)) {
        return false;
      }
      return true;
    }).toList();
  }
}

void main() {
  final sampleCars = [
    const CarModel(
      id: 'car_self_1',
      vendorId: 'vendor_1',
      make: 'Hyundai',
      model: 'Creta',
      year: 2023,
      type: 'SUV',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      pricePerKm: 15.0,
      pricePerDay: 3000.0,
      pricePerHour: 200.0,
      photos: [],
      availableTripTypes: ['Self-Drive'],
    ),
    const CarModel(
      id: 'car_outstation_1',
      vendorId: 'vendor_2',
      make: 'Toyota',
      model: 'Innova',
      year: 2024,
      type: 'SUV',
      fuelType: 'Diesel',
      seating: 7,
      isAC: true,
      pricePerKm: 20.0,
      pricePerDay: 4500.0,
      pricePerHour: 300.0,
      photos: [],
      availableTripTypes: ['Outstation'],
    ),
  ];

  group('Unified Search With Trip Selection Flow Tests (Phase 10.3)', () {
    testWidgets(
        'Scenario 1: Navbar search with no tripType shows Choose Trip Type, selecting Self-Drive renders Self-Drive cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockSearchRepo(sampleCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: '',
              start: '',
              end: '',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Trip Type decision view is displayed
      expect(find.text('Choose Trip Type'), findsOneWidget);
      expect(find.text('Self-Drive Cars'), findsOneWidget);
      expect(find.text('Outstation Travel'), findsOneWidget);

      // 2. Select Self-Drive
      await tester.tap(find.text('Self-Drive Cars'));
      await tester.pumpAndSettle();

      // 3. Verify Self-Drive results UI
      expect(container.read(searchTripTypeProvider), 'Self-Drive');
      expect(container.read(selectedTripTypeProvider), 'Self-Drive');
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Toyota Innova'), findsNothing); // Outstation-only car is filtered out
    });

    testWidgets(
        'Scenario 2: Navbar search with no tripType shows Choose Trip Type, selecting Outstation renders Outstation cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockSearchRepo(sampleCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: '',
              start: '',
              end: '',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Outstation
      await tester.tap(find.text('Outstation Travel'));
      await tester.pumpAndSettle();

      // Verify Outstation results UI
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(container.read(selectedTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets(
        'Scenario 3 & 5: Homepage search with Self-Drive skips decision screen, directly renders Self-Drive cars with no duplicate prompt',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockSearchRepo(sampleCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '',
              end: '',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Decision screen is SKIPPED
      expect(find.text('Choose Trip Type'), findsNothing);

      // Directly renders Self-Drive car listings
      expect(container.read(searchTripTypeProvider), 'Self-Drive');
      expect(container.read(selectedTripTypeProvider), 'Self-Drive');
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Toyota Innova'), findsNothing);
    });

    testWidgets(
        'Scenario 4: Homepage search with Outstation skips decision screen, directly renders Outstation cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockSearchRepo(sampleCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Outstation',
              start: '',
              end: '',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Directly renders Outstation car listings
      expect(find.text('Choose Trip Type'), findsNothing);
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(container.read(selectedTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets(
        'Scenario 6: Switching trip type via filter bar bottom sheet updates state and refetches results cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockSearchRepo(sampleCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '',
              end: '',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hyundai Creta'), findsOneWidget);

      // Tap trip type filter chip
      await tester.tap(find.text('Self-Drive'));
      await tester.pumpAndSettle();

      // In bottom sheet, select Outstation
      expect(find.text('Select Trip Type'), findsOneWidget);
      await tester.tap(find.text('Outstation'));
      await tester.pumpAndSettle();

      // State is updated to Outstation
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(container.read(selectedTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });
  });
}
