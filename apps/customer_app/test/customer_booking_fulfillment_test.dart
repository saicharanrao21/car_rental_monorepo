import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:customer_app/features/booking/presentation/widgets/fulfillment_selection_card.dart';
import 'package:customer_app/features/booking/presentation/widgets/booking_price_breakdown_card.dart';
import 'package:customer_app/features/booking/presentation/pages/booking_confirmation_page.dart';
import 'package:customer_app/features/booking/domain/repositories/booking_repository.dart';

class MockFulfillmentBookingRepository implements BookingRepository {
  BookingModel? lastCreatedBooking;

  @override
  Future<BookingModel> createBooking(BookingModel draft) async {
    lastCreatedBooking = draft;
    return draft.copyWith(id: 'BK_CONFIRMED_999');
  }

  @override
  Future<BookingModel?> getBookingById(String id) async {
    if (lastCreatedBooking != null && (id == lastCreatedBooking!.id || id == 'BK_CONFIRMED_999')) {
      return lastCreatedBooking!.copyWith(id: 'BK_CONFIRMED_999');
    }
    return BookingModel(
      id: id,
      customerId: 'cust_123',
      vendorId: 'v1',
      carId: 'car_123',
      tripType: 'SELF_DRIVE',
      pickupLocation: 'Main Yard, Andheri East',
      dropLocation: 'Airport Terminal 2',
      startDate: DateTime(2026, 9, 10, 10, 0),
      endDate: DateTime(2026, 9, 12, 10, 0),
      totalFare: 4500.0,
      platformFee: 400.0,
      gstAmount: 700.0,
      netToVendor: 3400.0,
      status: 'confirmed',
      createdAt: DateTime.now(),
      pickupHubId: 'hub_yard_1',
      returnHubId: 'pub_mum_csmia',
      pickupName: 'Mumbai Central Hub',
      dropName: 'CSMIA Terminal 2 Hub',
      pickupAddress: 'Plot 42, Andheri East, Mumbai',
      deliveryAddress: 'CSMIA Arrivals Gate 3, Mumbai',
      deliveryFee: 300.0,
      pickupFee: 100.0,
      returnFee: 50.0,
      oneWayFee: 250.0,
      deliveryType: 'DOORSTEP_DELIVERY',
    );
  }

  @override
  Future<List<BookingModel>> getBookingsForCustomer(String customerId) async => [];

  @override
  Future<BookingModel> cancelBooking(String bookingId) async => throw UnimplementedError();

  @override
  Future<CouponValidationResultModel> validateCoupon({
    required String code,
    String? carId,
    double? subtotal,
    String? city,
    String? tripType,
    String? carCategory,
  }) async => CouponValidationResultModel(
        valid: false,
        couponId: '',
        code: code,
        description: 'Invalid',
        discountType: 'PERCENTAGE',
        discountValue: 0,
        discountAmount: 0,
        finalPayableAmount: subtotal ?? 0,
      );

  @override
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  }) async {
    if (deliveryAddress != null && deliveryAddress.contains('Far Away')) {
      return {
        'isAvailable': false,
        'distanceKm': 45.0,
        'deliveryFee': 0.0,
        'pickupFee': 0.0,
        'returnFee': 0.0,
        'oneWayFee': 0.0,
        'totalFulfillmentFee': 0.0,
        'reason': 'Address (45 km) exceeds vendor max delivery radius of 25 km.',
      };
    }

    final isDiff = pickupLocationId != null && returnLocationId != null && pickupLocationId != returnLocationId;
    return {
      'isAvailable': true,
      'distanceKm': 12.5,
      'deliveryFee': deliveryAddress != null ? 350.0 : 0.0,
      'pickupFee': pickupLocationId == 'hub_premium' ? 150.0 : 0.0,
      'returnFee': returnLocationId == 'hub_airport' ? 100.0 : 0.0,
      'oneWayFee': isDiff ? 250.0 : 0.0,
      'oneWaySurcharge': isDiff ? 250.0 : 0.0,
      'totalFulfillmentFee': (deliveryAddress != null ? 350.0 : 0.0) + (isDiff ? 250.0 : 0.0),
    };
  }

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) => CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );
}

void main() {
  const testCar = CarModel(
    id: 'car_test_1',
    vendorId: 'v1',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 5,
    isAC: true,
    registrationNumber: 'MH02XY9999',
    photos: ['https://example.com/car.jpg'],
    pricePerKm: 15.0,
    pricePerDay: 2500.0,
    pricePerHour: 200.0,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'LOCAL', 'OUTSTATION'],
    blockedDates: [],
  );

  const testVendor = VendorModel(
    id: 'v1',
    businessName: 'DriveGo Premium Mumbai',
    ownerName: 'Rajesh Sharma',
    city: 'Mumbai',
    rating: 4.8,
  );

  group('Customer Booking Fulfillment Integration Tests', () {
    testWidgets('1. FulfillmentSelectionCard renders pickup and return options cleanly',
        (tester) async {
      final mockRepo = MockFulfillmentBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FulfillmentSelectionCard(
                  car: testCar,
                  vendor: testVendor,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Handover & Fulfillment'), findsOneWidget);
      expect(find.text('1. PICKUP METHOD'), findsOneWidget);
      expect(find.text('2. RETURN METHOD'), findsOneWidget);
      expect(find.text('Return to same location as pickup (Free)'), findsOneWidget);
      expect(find.text('Host Yard'), findsWidgets);
      expect(find.text('Airport/Rail'), findsWidgets);
      expect(find.text('Doorstep'), findsOneWidget);
    });

    testWidgets('2. Tapping Doorstep Delivery reveals delivery address input field',
        (tester) async {
      final mockRepo = MockFulfillmentBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FulfillmentSelectionCard(
                  car: testCar,
                  vendor: testVendor,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Doorstep chip for pickup
      await tester.tap(find.text('Doorstep'));
      await tester.pumpAndSettle();

      expect(find.text('Doorstep Delivery Address'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('3. Unchecking same-location toggle reveals different return location modes',
        (tester) async {
      final mockRepo = MockFulfillmentBookingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FulfillmentSelectionCard(
                  car: testCar,
                  vendor: testVendor,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap same location toggle to uncheck it
      await tester.tap(find.text('Return to same location as pickup (Free)'));
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Select Return Branch'), findsOneWidget);
    });

    testWidgets('4. Authoritative error state displays warning when out-of-radius',
        (tester) async {
      final mockRepo = MockFulfillmentBookingRepository();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: FulfillmentSelectionCard(
                      car: testCar,
                      vendor: testVendor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate address outside service radius
      container.read(bookingDraftProvider.notifier).update(
            (d) => d.copyWith(
              hasDoorstepDelivery: true,
              deliveryAddress: 'Far Away Hills, Out of City',
            ),
          );
      await container.read(bookingDraftProvider.notifier).refreshAuthoritativeQuote(
            repo: mockRepo,
            vendorId: 'v1',
          );
      await tester.pumpAndSettle();

      expect(find.textContaining('exceeds vendor max delivery radius'), findsOneWidget);
    });

    testWidgets('5. BookingPriceBreakdownCard itemizes fulfillment fees',
        (tester) async {
      const fareResult = FareCalculatorResult(
        baseFare: 3000.0,
        platformFee: 300.0,
        gst: 594.0,
        total: 3894.0,
        netToVendor: 2700.0,
      );

      final config = CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: BookingPriceBreakdownCard(
                      car: testCar,
                      vendor: testVendor,
                      originalRentalFare: 3000.0,
                      discountPercent: 0.0,
                      discountLabel: '',
                      discountAmount: 0.0,
                      result: fareResult,
                      finalPayable: 4844.0,
                      config: config,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            deliveryFee: 350.0,
            returnPickupFee: 200.0,
            pickupFee: 100.0,
            returnFee: 50.0,
            oneWayFee: 250.0,
          ));
      await tester.pumpAndSettle();

      expect(find.text('Doorstep Delivery'), findsOneWidget);
      expect(find.text('Doorstep Collection'), findsOneWidget);
      expect(find.text('Pickup Location Fee'), findsOneWidget);
      expect(find.text('Return Location Fee'), findsOneWidget);
      expect(find.text('One-Way Relocation Fee'), findsOneWidget);
    });

    testWidgets('6. BookingConfirmationPage renders immutable persisted fulfillment snapshot',
        (tester) async {
      final mockRepo = MockFulfillmentBookingRepository();
      final mockBooking = await mockRepo.getBookingById('BK_CONFIRMED_999');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(mockRepo),
            bookingWithDetailsProvider('BK_CONFIRMED_999').overrideWith(
              (ref) => BookingWithDetails(
                booking: mockBooking!,
                car: testCar,
                vendor: testVendor,
              ),
            ),
          ],
          child: const MaterialApp(
            home: BookingConfirmationPage(bookingId: 'BK_CONFIRMED_999'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('Trip Summary'), findsOneWidget);
      expect(find.textContaining('Mumbai Central Hub'), findsOneWidget);
      expect(find.textContaining('CSMIA Terminal 2 Hub'), findsOneWidget);
      expect(find.text('Fulfillment Fees'), findsOneWidget);
      expect(find.textContaining('Delivery: ₹300'), findsOneWidget);
      expect(find.textContaining('One-Way: ₹250'), findsOneWidget);
    });
  });
}
