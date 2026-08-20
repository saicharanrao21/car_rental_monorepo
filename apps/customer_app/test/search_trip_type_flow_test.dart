import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/search/presentation/pages/search_results_page.dart';
import 'package:customer_app/features/search/presentation/providers/search_providers.dart';
import 'package:customer_app/features/search/domain/repositories/search_repository.dart';
import 'package:customer_app/features/search/presentation/widgets/search_car_card.dart';
import 'package:customer_app/features/search/presentation/widgets/search_summary_card.dart';
import 'package:customer_app/features/search/presentation/widgets/search_filter_bar_widget.dart';
import 'package:customer_app/features/search/presentation/widgets/choose_trip_type_view.dart';
import 'package:customer_app/features/search/presentation/widgets/search_trip_details_form.dart';
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
    DateTime? startDate,
    DateTime? endDate,
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
      if (carType != null && c.type != carType) {
        return false;
      }
      if (isAC != null && c.isAC != isAC) {
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

  group('Date-First Car Availability & Trip Search Flow Tests (Phase 13)', () {
    testWidgets(
        'Scenario 1: Navbar search with no tripType shows Choose Trip Type -> Trip Details Form -> Available Cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
      expect(find.byType(ChooseTripTypeView), findsOneWidget);
      expect(find.text('Choose Trip Type'), findsOneWidget);
      expect(find.text('Self-Drive Cars'), findsOneWidget);
      expect(find.text('Outstation Travel'), findsOneWidget);

      // 2. Select Self-Drive
      await tester.tap(find.text('Self-Drive Cars'));
      await tester.pumpAndSettle();

      // 3. Trip Search Details Form is displayed
      expect(find.byType(SearchTripDetailsForm), findsOneWidget);
      expect(find.text('Trip Details — Self-Drive'), findsOneWidget);
      expect(find.text('Search Available Cars'), findsOneWidget);

      // 4. Submit Trip Details Form
      await tester.tap(find.text('Search Available Cars'));
      await tester.pumpAndSettle();

      // 5. Verify Self-Drive available results UI & compact summary bar
      expect(container.read(searchTripTypeProvider), 'Self-Drive');
      expect(container.read(selectedTripTypeProvider), 'Self-Drive');
      expect(find.byType(SearchSummaryCard), findsOneWidget);
      expect(find.byType(SearchFilterBarWidget), findsOneWidget);
      expect(find.byType(SearchCarCard), findsOneWidget);
      expect(find.text('Change Search'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Toyota Innova'), findsNothing);
    });

    testWidgets(
        'Scenario 2: Navbar search with no tripType shows Choose Trip Type -> Outstation Details Form -> Outstation Cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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

      // Outstation details form is displayed
      expect(find.byType(SearchTripDetailsForm), findsOneWidget);
      expect(find.text('Trip Details — Outstation'), findsOneWidget);
      expect(find.text('Destination City / Address'), findsOneWidget);

      // Submit Outstation form
      await tester.tap(find.text('Search Available Cars'));
      await tester.pumpAndSettle();

      // Verify Outstation results UI
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(container.read(selectedTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets(
        'Scenario 3: Homepage search with Self-Drive & dates directly renders available cars without duplicate prompt',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
              start: '2026-08-24T10:00:00.000Z',
              end: '2026-08-26T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Decision screen & details form are SKIPPED
      expect(find.byType(ChooseTripTypeView), findsNothing);
      expect(find.byType(SearchTripDetailsForm), findsNothing);

      // Directly renders Search Summary Bar and available cars
      expect(container.read(searchTripTypeProvider), 'Self-Drive');
      expect(find.byType(SearchSummaryCard), findsOneWidget);
      expect(find.text('Change Search'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Toyota Innova'), findsNothing);
    });

    testWidgets(
        'Scenario 4: Homepage search with Outstation & dates directly renders Outstation cars',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
              start: '2026-08-24T10:00:00.000Z',
              end: '2026-08-26T10:00:00.000Z',
              pickup: 'Mumbai',
              drop: 'Pune',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Directly renders Outstation car listings
      expect(find.byType(ChooseTripTypeView), findsNothing);
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets(
        'Scenario 5: Change Search button re-opens Trip Details Form and updates results upon submitting',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
              start: '2026-08-24T10:00:00.000Z',
              end: '2026-08-26T10:00:00.000Z',
              pickup: '',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Change Search'), findsOneWidget);

      // Tap Change Search
      await tester.tap(find.text('Change Search'));
      await tester.pumpAndSettle();

      // Form is displayed
      expect(find.byType(SearchTripDetailsForm), findsOneWidget);
      expect(find.text('Trip Details — Self-Drive'), findsOneWidget);
      expect(find.text('Search Available Cars'), findsOneWidget);

      // Change trip type via button
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Select Trip Type'), findsOneWidget);
      await tester.tap(find.text('Outstation'));
      await tester.pumpAndSettle();

      // Submit modified form
      await tester.tap(find.text('Search Available Cars'));
      await tester.pumpAndSettle();

      // Results update to Outstation
      expect(container.read(searchTripTypeProvider), 'Outstation');
      expect(find.text('Toyota Innova'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets(
        'Scenario 6: Filter bar interaction updates provider state and shows clear button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
              start: '2026-08-24T10:00:00.000Z',
              end: '2026-08-26T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear (1)'), findsNothing);

      // Tap AC / Non-AC toggle
      final acFinder = find.text('AC / Non-AC');
      await tester.ensureVisible(acFinder);
      await tester.tap(acFinder);
      await tester.pumpAndSettle();

      expect(container.read(searchACFilterProvider), isTrue);
      expect(find.text('Clear (1)'), findsOneWidget);

      // Tap Clear
      final clearFinder = find.text('Clear (1)');
      await tester.ensureVisible(clearFinder);
      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      expect(container.read(searchACFilterProvider), isNull);
      expect(find.text('Clear (1)'), findsNothing);
    });

    testWidgets(
        'Scenario 7: SearchCarCard renders vehicle specs, pricing, and View Details button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
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
              start: '2026-08-24T10:00:00.000Z',
              end: '2026-08-26T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SearchCarCard), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('5 Seats'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });
  });
}
