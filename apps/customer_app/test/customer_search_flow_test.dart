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
import 'package:customer_app/features/wishlist/wishlist_providers.dart';
import 'package:ui_kit/ui_kit.dart';

class MockModernSearchRepo implements SearchRepository {
  final List<CarModel> cars;
  final bool shouldThrow;

  MockModernSearchRepo(this.cars, {this.shouldThrow = false});

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
    String? fuelType,
    int? seating,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async {
    if (shouldThrow) {
      throw Exception('Network connection error');
    }

    var result = cars.where((c) {
      if (tripType != null && !c.availableTripTypes.contains(tripType)) {
        return false;
      }
      if (carType != null && c.type.toLowerCase() != carType.toLowerCase()) {
        return false;
      }
      if (isAC != null && c.isAC != isAC) {
        return false;
      }
      if (fuelType != null && c.fuelType.toLowerCase() != fuelType.toLowerCase()) {
        return false;
      }
      if (seating != null && c.seating < seating) {
        return false;
      }
      if (minPrice != null && c.pricePerDay < minPrice) {
        return false;
      }
      if (maxPrice != null && c.pricePerDay > maxPrice) {
        return false;
      }
      if (minRating != null && c.rating < minRating) {
        return false;
      }
      return true;
    }).toList();

    if (sortBy == 'Price Low-High') {
      result.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
    } else if (sortBy == 'Price High-Low') {
      result.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
    } else if (sortBy == 'Rating') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return result;
  }
}

void main() {
  final mockCars = [
    const CarModel(
      id: 'car_1',
      vendorId: 'vendor_1',
      make: 'Maruti Suzuki',
      model: 'Swift',
      year: 2023,
      type: 'Hatchback',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      pricePerKm: 12.0,
      pricePerDay: 1800.0,
      pricePerHour: 150.0,
      photos: [],
      rating: 4.8,
      isSponsored: true,
      availableTripTypes: ['Self-Drive'],
    ),
    const CarModel(
      id: 'car_2',
      vendorId: 'vendor_2',
      make: 'Hyundai',
      model: 'Verna',
      year: 2024,
      type: 'Sedan',
      fuelType: 'Diesel',
      seating: 5,
      isAC: true,
      pricePerKm: 16.0,
      pricePerDay: 2800.0,
      pricePerHour: 220.0,
      photos: [],
      rating: 4.5,
      availableTripTypes: ['Self-Drive'],
    ),
    const CarModel(
      id: 'car_3',
      vendorId: 'vendor_3',
      make: 'Mahindra',
      model: 'XUV700',
      year: 2024,
      type: 'SUV',
      fuelType: 'Diesel',
      seating: 7,
      isAC: true,
      pricePerKm: 22.0,
      pricePerDay: 4800.0,
      pricePerHour: 350.0,
      photos: [],
      rating: 4.9,
      availableTripTypes: ['Self-Drive'],
    ),
  ];

  group('Customer App Modernized Search, Filters, Sorting & Card Tests (Phase 29.4)', () {
    testWidgets('Renders search results, header context, and DDS vehicle cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo(mockCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Andheri West',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and summary context
      expect(find.byType(SearchSummaryCard), findsOneWidget);
      expect(find.text('Andheri West, Mumbai'), findsOneWidget);
      expect(find.text('Self-Drive'), findsWidgets);
      expect(find.text('3 vehicles found'), findsOneWidget);

      // Filter bar
      expect(find.byType(SearchFilterBarWidget), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);

      // Vehicle cards
      expect(find.byType(SearchCarCard), findsNWidgets(3));
      expect(find.text('Maruti Suzuki Swift'), findsOneWidget);
      expect(find.text('Hyundai Verna'), findsOneWidget);
      expect(find.text('Mahindra XUV700'), findsOneWidget);
      expect(find.text('SPONSORED'), findsOneWidget);
    });

    testWidgets('Wishlist toggle updates wishlistedIdsProvider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo(mockCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find first wishlist button
      final heartBtn = find.byTooltip('Save Car').first;
      expect(heartBtn, findsOneWidget);

      await tester.tap(heartBtn);
      await tester.pumpAndSettle();

      expect(container.read(wishlistIdsProvider), contains('car_1'));
    });

    testWidgets('Sort modal updates sort order', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo(mockCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sort Pill
      final sortPill = find.text('Sort: Recommended');
      expect(sortPill, findsOneWidget);
      await tester.tap(sortPill);
      await tester.pumpAndSettle();

      // Sort modal appears
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Price High-Low'), findsOneWidget);

      // Select Price High-Low
      await tester.tap(find.widgetWithText(ListTile, 'Price High-Low'));
      await tester.pumpAndSettle();

      expect(container.read(sortByProvider), 'Price High-Low');
    });

    testWidgets('Master filter modal applies multi-criteria filters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo(mockCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Master Filters button
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Filter sheet opens
      expect(find.widgetWithText(DriveGoChip, 'SUV'), findsOneWidget);

      // Select SUV category
      await tester.tap(find.widgetWithText(DriveGoChip, 'SUV'));
      await tester.pumpAndSettle();

      // Tap Apply Filters
      await tester.tap(find.text('Apply Filters (1)'));
      await tester.pumpAndSettle();

      // Results update to SUV only
      expect(container.read(searchCarCategoryFilterProvider), 'SUV');
      expect(find.text('1 vehicle found'), findsOneWidget);
      expect(find.text('Mahindra XUV700'), findsOneWidget);
      expect(find.text('Maruti Suzuki Swift'), findsNothing);
    });

    testWidgets('Empty state with filter mismatch shows clear filters action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo(mockCars)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set category to Luxury (which returns 0 items in mock)
      container.read(searchCarCategoryFilterProvider.notifier).state = 'Luxury';
      await tester.pumpAndSettle();

      // Filter mismatch empty state
      expect(find.text('No Cars Match Filters'), findsOneWidget);
      expect(find.text('Clear All Filters'), findsOneWidget);

      // Tap Clear All Filters
      await tester.tap(find.text('Clear All Filters'));
      await tester.pumpAndSettle();

      expect(container.read(searchCarCategoryFilterProvider), isNull);
      expect(find.text('3 vehicles found'), findsOneWidget);
    });

    testWidgets('Error state renders DriveGoErrorState with retry option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(MockModernSearchRepo([], shouldThrow: true)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchResultsPage(
              city: 'Mumbai',
              tripType: 'Self-Drive',
              start: '2026-09-01T10:00:00.000Z',
              end: '2026-09-03T10:00:00.000Z',
              pickup: 'Bandra',
              drop: '',
              category: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DriveGoErrorState), findsOneWidget);
      expect(find.text('Search Failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
