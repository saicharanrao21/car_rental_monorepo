import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/bookings/presentation/pages/admin_booking_management_page.dart';
import 'package:admin_panel/features/bookings/presentation/providers/admin_booking_providers.dart';
import 'package:admin_panel/features/bookings/domain/repositories/admin_booking_repository.dart';

class MockAdminPaymentGovernanceRepository implements AdminBookingRepository {
  final BookingDetailBundle bundle;
  final PaymentOrderModel payment;

  MockAdminPaymentGovernanceRepository({
    required this.bundle,
    required this.payment,
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
    return [bundle.booking];
  }

  @override
  Future<BookingDetailBundle> getBookingDetail(String bookingId) async {
    return bundle;
  }

  @override
  Future<PaymentOrderModel?> getBookingPayment(String bookingId) async {
    return payment;
  }

  @override
  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {}

  @override
  Future<void> flagBookingDispute(String bookingId, String note) async {}

  @override
  Future<void> issueAdminRefund({
    required String bookingId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {}
}

void main() {
  final testBooking = BookingModel(
    id: 'BK_ADM_PAY_01',
    customerId: 'cust_01',
    vendorId: 'vnd_01',
    carId: 'car_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Bandra West',
    dropLocation: 'Bandra West',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 3),
    totalFare: 7500.0,
    platformFee: 750.0,
    gstAmount: 135.0,
    netToVendor: 6615.0,
    status: 'completed',
    disputeFlag: false,
    createdAt: DateTime.now(),
  );

  const testCar = CarModel(
    id: 'car_01',
    vendorId: 'vnd_01',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 15.0,
    pricePerDay: 2500.0,
    pricePerHour: 150.0,
  );

  const testVendor = VendorModel(
    id: 'vnd_01',
    businessName: 'Apex Rentals Mumbai',
    ownerName: 'Vikram Mehta',
    city: 'Mumbai',
    verificationStatus: 'VERIFIED',
    phone: '9876543210',
  );

  const testCustomer = UserModel(
    id: 'cust_01',
    name: 'Rahul Sharma',
    phone: '9988776655',
    email: 'rahul@example.com',
    role: 'customer',
  );

  final testBundle = BookingDetailBundle(
    booking: testBooking,
    car: testCar,
    vendor: testVendor,
    customer: testCustomer,
  );

  const testPayment = PaymentOrderModel(
    id: 'pay_rec_01',
    bookingId: 'BK_ADM_PAY_01',
    amount: 7500.0,
    amountInPaise: 750000,
    currency: 'INR',
    keyId: 'rzp_test_key',
    status: 'PAID',
    razorpayOrderId: 'order_rzp_999888',
    razorpayPaymentId: 'pay_rzp_777666',
    gatewayProvider: 'RAZORPAY',
    refunds: [
      PaymentRefundModel(
        id: 'ref_01',
        bookingId: 'BK_ADM_PAY_01',
        gatewayRefundId: 'rfnd_rzp_001',
        idempotencyKey: 'idem_key_001',
        requestedAmount: 1000.0,
        processedAmount: 1000.0,
        currency: 'INR',
        reason: 'Partial cancellation credit',
        status: 'PROCESSED',
      ),
    ],
  );

  testWidgets('Admin Booking Detail renders authoritative Payment & Escrow Governance section',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockAdminPaymentGovernanceRepository(
      bundle: testBundle,
      payment: testPayment,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminBookingRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminBookingManagementPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify booking card exists in data grid with '#' prefix
    expect(find.text('#BK_ADM_PAY_01'), findsOneWidget);

    // Tap on row to open drawer
    await tester.tap(find.text('#BK_ADM_PAY_01'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Payment Integrity & Escrow section


    expect(find.text('Payment Integrity & Escrow'), findsOneWidget);
    expect(find.text('Gateway Order ID'), findsOneWidget);
    expect(find.text('order_rzp_999888'), findsOneWidget);
    expect(find.text('Gateway Payment ID'), findsOneWidget);
    expect(find.text('pay_rzp_777666'), findsOneWidget);
    expect(find.text('ELIGIBLE FOR VENDOR PAYOUT'), findsOneWidget);

    // Verify Refund record
    expect(find.text('Refund Records:'), findsOneWidget);
    expect(find.textContaining('₹1000 • PROCESSED'), findsOneWidget);
    expect(find.text('Issue Authoritative Refund'), findsOneWidget);
  });
}
