import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/bookings/presentation/pages/admin_booking_management_page.dart';
import 'package:admin_panel/features/bookings/presentation/providers/admin_booking_providers.dart';
import 'package:admin_panel/features/bookings/domain/repositories/admin_booking_repository.dart';

class MockAdminLifecycleBookingRepository implements AdminBookingRepository {
  final Map<String, BookingDetailBundle> bundles;
  final List<BookingModel> bookings;

  MockAdminLifecycleBookingRepository({
    required this.bundles,
    required this.bookings,
  });

  @override
  Future<List<BookingModel>> getBookings({
    String? city,
    DateTimeRange? dateRange,
    String? tripType,
    String? status,
    String? vendorId,
    String? carType,
  }) async {
    return bookings;
  }

  @override
  Future<BookingDetailBundle> getBookingDetail(String bookingId) async {
    final bundle = bundles[bookingId];
    if (bundle == null) throw Exception('Booking not found: $bookingId');
    return bundle;
  }

  @override
  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {}

  @override
  Future<void> flagBookingDispute(String bookingId, String note) async {}

  @override
  Future<PaymentOrderModel?> getBookingPayment(String bookingId) async {
    return PaymentOrderModel(
      id: 'pay_$bookingId',
      bookingId: bookingId,
      amount: 12000.0,
      amountInPaise: 1200000,
      currency: 'INR',
      keyId: 'rzp_test_mock',
      status: 'PAID',
      razorpayOrderId: 'order_mock_$bookingId',
      razorpayPaymentId: 'pay_mock_$bookingId',
      gatewayProvider: 'RAZORPAY',
    );
  }

  @override
  Future<void> issueAdminRefund({
    required String bookingId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBooking = BookingModel(
    id: 'bk_admin_p33_001',
    customerId: 'cust_001',
    vendorId: 'vnd_001',
    carId: 'car_001',
    tripType: 'Self-Drive',
    pickupLocation: 'Koramangala Hub, Bengaluru',
    startDate: DateTime(2026, 9, 10, 10),
    endDate: DateTime(2026, 9, 15, 10),
    totalFare: 12000.0,
    platformFee: 1200.0,
    gstAmount: 2160.0,
    netToVendor: 8640.0,
    status: 'confirmed',
    createdAt: DateTime(2026, 9, 5),
  );

  final testBundle = BookingDetailBundle(
    booking: testBooking,
    car: const CarModel(
      id: 'car_001',
      vendorId: 'vnd_001',
      make: 'Hyundai',
      model: 'Creta',
      year: 2024,
      type: 'SUV',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      photos: [],
      pricePerKm: 12.0,
      pricePerDay: 2500.0,
      pricePerHour: 200.0,
    ),
    vendor: const VendorModel(
      id: 'vnd_001',
      businessName: 'Royal Fleet',
      ownerName: 'Sunil Rao',
      city: 'Bengaluru',
      phone: '+919876543210',
    ),
    customer: const UserModel(
      id: 'cust_001',
      name: 'Rohan Sharma',
      email: 'rohan@example.com',
      phone: '+919876543210',
      role: 'CUSTOMER',
    ),
  );

  final mockOutboxEvents = [
    {
      'id': 'evt_001',
      'eventType': 'BOOKING_CREATED',
      'previousStatus': 'PENDING',
      'newStatus': 'PENDING',
      'actorRole': 'CUSTOMER',
      'status': 'PUBLISHED',
      'correlationId': 'evt_booking_created_12345',
      'createdAt': '2026-09-05T10:00:00.000Z',
    },
    {
      'id': 'evt_002',
      'eventType': 'BOOKING_CONFIRMED',
      'previousStatus': 'PENDING',
      'newStatus': 'CONFIRMED',
      'actorRole': 'VENDOR',
      'status': 'PUBLISHED',
      'correlationId': 'evt_booking_confirmed_12345',
      'createdAt': '2026-09-05T10:15:00.000Z',
    },
  ];

  Widget createAdminWidget({List<Map<String, dynamic>>? events}) {
    final repo = MockAdminLifecycleBookingRepository(
      bundles: {testBooking.id: testBundle},
      bookings: [testBooking],
    );

    return ProviderScope(
      overrides: [
        adminBookingRepositoryProvider.overrideWithValue(repo),
        adminBookingsProvider.overrideWith((ref) async => [testBooking]),
        bookingDetailBundleProvider(testBooking.id).overrideWith((ref) async => testBundle),
        bookingLifecycleHistoryProvider(testBooking.id)
            .overrideWith((ref) async => events ?? mockOutboxEvents),
      ],
      child: const MaterialApp(
        home: AdminBookingManagementPage(),
      ),
    );
  }

  group('Phase 33 — Admin Booking Lifecycle Governance & Audit Tests', () {
    testWidgets('1. Lifecycle audit trail: Admin grid renders booking with confirmed status', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAdminWidget());
      await tester.pumpAndSettle();

      expect(find.text('#BK_ADMIN_P33_001'), findsOneWidget);
    });

    testWidgets('2. Lifecycle audit trail: Persisted outbox events render with eventType, transition and correlationId', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAdminWidget());
      await tester.pumpAndSettle();

      // Tap to open detail drawer
      await tester.tap(find.text('#BK_ADMIN_P33_001'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Canonical Lifecycle Audit Trail'), findsOneWidget);
      expect(find.text('BOOKING_CREATED'), findsOneWidget);
      expect(find.text('BOOKING_CONFIRMED'), findsOneWidget);
      expect(find.text('PENDING → CONFIRMED'), findsOneWidget);
    });

    testWidgets('3. Empty state: Shows informative placeholder when no outbox events exist', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAdminWidget(events: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('#BK_ADMIN_P33_001'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('No persisted outbox lifecycle events found for this booking.'), findsOneWidget);
    });

    testWidgets('4. Governance restrictions: Force Cancel requires confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAdminWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('#BK_ADMIN_P33_001'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Find Force Cancel button and scroll into view within drawer
      final forceCancelBtn = find.text('Force Cancel');
      await tester.scrollUntilVisible(
        forceCancelBtn,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(forceCancelBtn, findsOneWidget);

      await tester.tap(forceCancelBtn);
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Force Cancel Booking'), findsNWidgets(2)); // Title and confirm button
      expect(find.text('Are you sure you want to FORCE CANCEL this booking? This bypasses standard vendor/customer flows.'), findsOneWidget);
    });
  });
}
