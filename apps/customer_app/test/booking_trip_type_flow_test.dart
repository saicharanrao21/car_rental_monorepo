import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/features/booking/presentation/widgets/trip_details_step.dart';
import 'package:customer_app/features/booking/presentation/pages/booking_flow_page.dart';
import 'package:customer_app/features/car_detail/presentation/providers/car_detail_providers.dart';
import 'package:customer_app/features/car_detail/domain/repositories/car_detail_repository.dart';
import 'package:customer_app/features/home/home_providers.dart';

class MockCarDetailRepository implements CarDetailRepository {
  final CarModel car;
  final VendorModel vendor;

  MockCarDetailRepository({required this.car, required this.vendor});

  @override
  Future<CarModel> getCarById(String id) async => car;

  @override
  Future<VendorModel> getVendorById(String vendorId) async => vendor;

  @override
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId) async => [];
}

void main() {
  const testVendor = VendorModel(
    id: 'vendor_101',
    businessName: 'Apex Car Rentals',
    ownerName: 'Rahul Sharma',
    city: 'Mumbai',
    businessType: 'INDIVIDUAL',
    verificationStatus: 'verified',
    rating: 4.8,
  );

  const selfDriveOnlyCar = CarModel(
    id: 'car_sd_001',
    vendorId: 'vendor_101',
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

  const outstationOnlyCar = CarModel(
    id: 'car_out_002',
    vendorId: 'vendor_101',
    make: 'Toyota',
    model: 'Innova Crysta',
    year: 2023,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 7,
    isAC: true,
    photos: [],
    pricePerKm: 18.0,
    pricePerDay: 4000.0,
    pricePerHour: 300.0,
    availableTripTypes: ['Outstation', 'Local'],
  );

  group('Booking Trip Type Flow & Immutability Tests', () {
    test(
        '1. BookingDraftNotifier.init preserves Self-Drive without fallback and sets driverIncluded = false',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookingDraftProvider.notifier);
      notifier.init(
        car: selfDriveOnlyCar,
        vendorId: testVendor.id,
        tripType: 'Self-Drive',
        pickupLocation: 'Bandra, Mumbai',
        dropLocation: 'Bandra, Mumbai',
      );

      final draft = container.read(bookingDraftProvider);
      expect(draft.tripType, 'Self-Drive');
      expect(draft.driverIncluded, isFalse);
      expect(draft.carId, 'car_sd_001');
    });

    test(
        '2. BookingDraftNotifier.init preserves Outstation without fallback and sets driverIncluded = true',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookingDraftProvider.notifier);
      notifier.init(
        car: outstationOnlyCar,
        vendorId: testVendor.id,
        tripType: 'Outstation',
        pickupLocation: 'Mumbai',
        dropLocation: 'Pune',
      );

      final draft = container.read(bookingDraftProvider);
      expect(draft.tripType, 'Outstation');
      expect(draft.driverIncluded, isTrue);
      expect(draft.carId, 'car_out_002');
    });

    testWidgets(
        '3. TripDetailsStep renders immutable service badge and NO editable trip type dropdown',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingDraftProvider.overrideWith(() => BookingDraftNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(bookingDraftProvider.notifier).init(
                          car: selfDriveOnlyCar,
                          vendorId: testVendor.id,
                          tripType: 'Self-Drive',
                          pickupLocation: 'Andheri East',
                          dropLocation: 'Andheri East',
                        );
                  });
                  return TripDetailsStep(
                    car: selfDriveOnlyCar,
                    vendor: testVendor,
                    onNext: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Immutable service badge should be visible
      expect(find.text('Service: Self-Drive'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Chauffeur not included • Drive at your own pace'),
          findsOneWidget);
      expect(find.text('Self-Drive (No Chauffeur)'), findsOneWidget);

      // Verify NO DropdownButton / editable trip selector exists
      expect(find.byType(DropdownButton), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);
    });

    testWidgets('4. TripDetailsStep adapts labels for Outstation trip type',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingDraftProvider.overrideWith(() => BookingDraftNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(bookingDraftProvider.notifier).init(
                          car: outstationOnlyCar,
                          vendorId: testVendor.id,
                          tripType: 'Outstation',
                          pickupLocation: 'Mumbai',
                          dropLocation: 'Lonavala',
                        );
                  });
                  return TripDetailsStep(
                    car: outstationOnlyCar,
                    vendor: testVendor,
                    onNext: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Outstation immutable service badge
      expect(find.text('Service: Outstation'), findsOneWidget);
      expect(find.text('Professional chauffeur included • Inter-city travel'),
          findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Chauffeur Included'), findsOneWidget);
    });

    testWidgets(
        '5. BookingFlowPage shows IncompatibleTripTypeView when car does NOT support selected trip type',
        (tester) async {
      final mockRepo = MockCarDetailRepository(
        car: outstationOnlyCar, // Only supports Outstation and Local
        vendor: testVendor,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            carDetailRepositoryProvider.overrideWithValue(mockRepo),
            selectedTripTypeProvider.overrideWith(
                (ref) => 'Self-Drive'), // Incompatible with outstationOnlyCar
          ],
          child: const MaterialApp(
            home: BookingFlowPage(carId: 'car_out_002'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Incompatible trip type error view must be shown
      expect(find.text('Trip Type Not Supported'), findsOneWidget);
      expect(
        find.textContaining(
            'Toyota Innova Crysta (2023) is not eligible for Self-Drive bookings'),
        findsOneWidget,
      );
      expect(find.text('Browse Self-Drive Cars'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);

      // Normal booking steps should NOT be shown
      expect(find.text('Step 1 of 5: Trip Details'), findsNothing);
      expect(find.text('Next: Add-ons'), findsNothing);
    });

    testWidgets(
        '6. BookingFlowPage proceeds to Trip Details when car supports selected trip type',
        (tester) async {
      final mockRepo = MockCarDetailRepository(
        car: selfDriveOnlyCar, // Supports Self-Drive
        vendor: testVendor,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            carDetailRepositoryProvider.overrideWithValue(mockRepo),
            selectedTripTypeProvider.overrideWith((ref) => 'Self-Drive'),
          ],
          child: const MaterialApp(
            home: BookingFlowPage(carId: 'car_sd_001'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Normal booking flow should be active
      expect(find.text('Step 1 of 5: Trip Details'), findsOneWidget);
      expect(find.text('Service: Self-Drive'), findsOneWidget);
      expect(find.text('Next: Add-ons'), findsOneWidget);
      expect(find.text('Trip Type Not Supported'), findsNothing);
    });
  });
}
