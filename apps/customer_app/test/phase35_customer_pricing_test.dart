import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:customer_app/features/booking/presentation/widgets/booking_price_breakdown_card.dart';
import 'package:customer_app/features/booking/presentation/widgets/fare_breakdown_step.dart';
import 'package:customer_app/features/booking/domain/repositories/booking_repository.dart';

class MockPricingBookingRepository implements BookingRepository {
  BookingQuoteModel? quoteToReturn;
  BookingModel? lastCreatedBooking;
  int refreshQuoteCallCount = 0;

  @override
  Future<BookingQuoteModel> getQuote({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? tripType,
    String? mileagePackageId,
    String? protectionPlanId,
    String? pickupLocationId,
    String? returnLocationId,
    String? deliveryAddress,
    double? customerLatitude,
    double? customerLongitude,
    String? couponCode,
    String? idempotencyKey,
  }) async {
    return quoteToReturn ??
        BookingQuoteModel(
          quoteId: 'quote_test_abc_123',
          tenantId: 'tenant_1',
          carId: carId,
          vehicleName: 'Hyundai Creta',
          registrationNumber: 'MH02AB1234',
          tripType: tripType ?? 'SELF_DRIVE',
          startDate: startDate,
          endDate: endDate,
          durationDays: 2,
          durationHours: 48,
          currency: 'INR',
          pricingVersion: 'v1.0',
          subtotal: 4000.0,
          discountTotal: 0.0,
          feesTotal: 150.0,
          taxTotal: 747.0,
          depositTotal: 3000.0,
          tripFare: 4897.0,
          totalPayable: 7897.0,
          netToVendor: 3600.0,
          status: 'ACTIVE',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          lineItems: const [
            BookingQuoteLineItemModel(
              type: 'BASE_RENTAL',
              name: 'Base Vehicle Rental (2 days)',
              rate: 2000.0,
              quantity: 2.0,
              amount: 4000.0,
              displayOrder: 1,
            ),
            BookingQuoteLineItemModel(
              type: 'PLATFORM_FEE',
              name: 'Platform Convenience Fee',
              rate: 150.0,
              quantity: 1.0,
              amount: 150.0,
              displayOrder: 2,
            ),
            BookingQuoteLineItemModel(
              type: 'TAX_GST',
              name: 'Statutory GST (18%)',
              rate: 747.0,
              quantity: 1.0,
              amount: 747.0,
              displayOrder: 3,
            ),
            BookingQuoteLineItemModel(
              type: 'SECURITY_DEPOSIT',
              name: 'Refundable Security Deposit',
              rate: 3000.0,
              quantity: 1.0,
              amount: 3000.0,
              isRefundable: true,
              displayOrder: 4,
            ),
          ],
        );
  }

  @override
  Future<BookingQuoteModel> refreshQuote(String quoteId) async {
    refreshQuoteCallCount++;
    return getQuote(
      carId: 'car_123',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 2)),
    );
  }

  @override
  Future<BookingQuoteModel?> getQuoteById(String quoteId) async => getQuote(
        carId: 'car_123',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
      );

  @override
  Future<BookingModel> createBooking(BookingModel draft) async {
    lastCreatedBooking = draft;
    return draft.copyWith(id: 'BK_PRICING_OK_123');
  }

  @override
  Future<BookingModel?> getBookingById(String id) async => null;

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
  }) async =>
      CouponValidationResultModel(
        valid: true,
        couponId: 'cpn_1',
        code: code,
        description: 'Mock Coupon',
        discountType: 'FIXED',
        discountValue: 500,
        discountAmount: 500,
        finalPayableAmount: (subtotal ?? 1000) - 500,
      );

  @override
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  }) async => {
        'isAvailable': true,
        'deliveryFee': 300.0,
        'returnFee': 0.0,
        'oneWayFee': 0.0,
        'totalFulfillmentFee': 300.0,
      };

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) =>
      CommissionConfigModel(
        id: 'cfg_1',
        city: city,
        carCategory: carCategory,
        tripType: tripType,
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

  @override
  Future<VehicleAvailabilityResult> checkVehicleAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? hubId,
  }) async =>
      VehicleAvailabilityResult(
        available: true,
        carId: carId,
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      );

  @override
  Future<VehicleHoldModel> createVehicleHold({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    int ttlSeconds = 900,
    String? idempotencyKey,
  }) async =>
      VehicleHoldModel(
        id: 'hold_123',
        carId: carId,
        customerId: 'cust_1',
        vendorId: 'vend_1',
        startDate: startDate,
        endDate: endDate,
        expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
        status: 'ACTIVE',
      );

  @override
  Future<bool> releaseVehicleHold(String holdId) async => true;
}

void main() {
  const testCar = CarModel(
    id: 'car_123',
    vendorId: 'vend_1',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 5,
    isAC: true,
    photos: ['https://example.com/creta.jpg'],
    pricePerKm: 15.0,
    pricePerDay: 2000.0,
    pricePerHour: 150.0,
    registrationNumber: 'MH02AB1234',
    availableTripTypes: ['Local', 'Outstation', 'Self-Drive'],
    isAvailable: true,
  );

  const testVendor = VendorModel(
    id: 'vend_1',
    businessName: 'Apex Mobility Solutions',
    ownerName: 'Rahul Mehta',
    email: 'vendor@apex.com',
    phone: '+91 98765 43210',
    city: 'Mumbai',
    addressLine: 'Andheri East, Mumbai',
    verificationStatus: 'verified',
  );

  group('Phase 35 Customer App Pricing & Quote Integrity Tests', () {
    test('1. BookingQuoteModel deserialization and duration invariants', () {
      final now = DateTime.now();
      final quote = BookingQuoteModel(
        quoteId: 'quote_calc_1',
        tenantId: 'tenant_1',
        carId: 'car_123',
        vehicleName: 'Hyundai Creta',
        registrationNumber: 'MH02AB1234',
        tripType: 'SELF_DRIVE',
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
        durationDays: 3,
        durationHours: 72,
        currency: 'INR',
        pricingVersion: 'v1.0',
        subtotal: 6000.0,
        discountTotal: 0.0,
        feesTotal: 150.0,
        taxTotal: 1107.0,
        depositTotal: 3000.0,
        tripFare: 7257.0,
        totalPayable: 10257.0,
        netToVendor: 5400.0,
        status: 'ACTIVE',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );

      expect(quote.isExpired, isFalse);
      expect(quote.durationDays, 3);
      expect(quote.totalPayable, 10257.0);
      expect(quote.tripFare, 7257.0);
      expect(quote.depositTotal, 3000.0);
    });

    testWidgets('2. BookingPriceBreakdownCard renders authoritative line items and quote badge', (tester) async {
      final repo = MockPricingBookingRepository();
      final quote = await repo.getQuote(
        carId: testCar.id,
        startDate: DateTime(2026, 9, 10, 10, 0),
        endDate: DateTime(2026, 9, 12, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingPriceBreakdownCard(
                  car: testCar,
                  vendor: testVendor,
                  originalRentalFare: 4000.0,
                  discountPercent: 0.0,
                  discountLabel: '',
                  discountAmount: 0.0,
                  result: const FareCalculatorResult(
                    baseFare: 4000.0,
                    platformFee: 150.0,
                    gst: 747.0,
                    total: 4897.0,
                    netToVendor: 3600.0,
                  ),
                  finalPayable: 7897.0,
                  config: repo.getCommissionConfig(city: 'Mumbai', carCategory: 'SUV', tripType: 'Self-Drive'),
                  quote: quote,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Authoritative badge and quote ID
      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('Authoritative'), findsOneWidget);
      expect(find.textContaining('v1.0'), findsOneWidget);

      // Verify line items
      expect(find.text('Base Vehicle Rental (2 days)'), findsOneWidget);
      expect(find.text('Platform Convenience Fee'), findsOneWidget);
      expect(find.text('Statutory GST (18%)'), findsOneWidget);
      expect(find.text('Refundable Security Deposit'), findsOneWidget);

      // Verify Total Payable row
      expect(find.text('Total Payable Amount'), findsOneWidget);
    });

    testWidgets('3. Quote expired alert renders and allows refreshing quote', (tester) async {
      final repo = MockPricingBookingRepository();
      final expiredQuote = BookingQuoteModel(
        quoteId: 'quote_expired_999',
        tenantId: 'tenant_1',
        carId: testCar.id,
        vehicleName: 'Hyundai Creta',
        registrationNumber: 'MH02AB1234',
        tripType: 'SELF_DRIVE',
        startDate: DateTime.now().subtract(const Duration(hours: 2)),
        endDate: DateTime.now().add(const Duration(days: 2)),
        durationDays: 2,
        durationHours: 48,
        currency: 'INR',
        pricingVersion: 'v1.0',
        subtotal: 4000.0,
        discountTotal: 0.0,
        feesTotal: 150.0,
        taxTotal: 747.0,
        depositTotal: 3000.0,
        tripFare: 4897.0,
        totalPayable: 7897.0,
        netToVendor: 3600.0,
        status: 'EXPIRED',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      repo.quoteToReturn = expiredQuote;

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(repo),
        ],
      );

      // Initialize draft with expired quote
      container.read(bookingDraftProvider.notifier).update(
            (d) => d.copyWith(
              carId: testCar.id,
              vendorId: testVendor.id,
              authoritativeQuote: expiredQuote,
              quoteId: expiredQuote.quoteId,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: FareBreakdownStep(
                car: testCar,
                vendor: testVendor,
                onBack: () {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify expired banner is shown
      expect(find.textContaining('Quote expired'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      // Tap Refresh button
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(repo.refreshQuoteCallCount, 1);
    });

    test('4. Booking creation passes authoritative quoteId to repository', () async {
      final repo = MockPricingBookingRepository();
      final activeQuote = await repo.getQuote(
        carId: testCar.id,
        startDate: DateTime.now().add(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 3)),
      );

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(repo),
        ],
      );

      container.read(bookingDraftProvider.notifier).update(
            (d) => d.copyWith(
              carId: testCar.id,
              vendorId: testVendor.id,
              authoritativeQuote: activeQuote,
              quoteId: activeQuote.quoteId,
              totalFare: activeQuote.totalPayable,
            ),
          );

      final draft = container.read(bookingDraftProvider);
      final created = await container.read(createBookingFlowProvider.notifier).submit(
            customerId: 'cust_test_456',
            draft: draft,
          );

      expect(created, isNotNull);
      expect(repo.lastCreatedBooking, isNotNull);
      expect(repo.lastCreatedBooking!.carId, testCar.id);
      expect(repo.lastCreatedBooking!.totalFare, activeQuote.totalPayable);

      container.dispose();
    });
  });
}
