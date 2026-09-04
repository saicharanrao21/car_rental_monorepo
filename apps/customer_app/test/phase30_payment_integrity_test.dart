import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_refund_tracker_card.dart';

void main() {
  final baseBooking = BookingModel(
    id: 'BK_P30_TEST_01',
    customerId: 'cust_p30',
    vendorId: 'vnd_p30',
    carId: 'car_p30',
    tripType: 'Self-Drive',
    pickupLocation: 'Koramangala, Bangalore',
    dropLocation: 'Koramangala, Bangalore',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 6000.0,
    platformFee: 600.0,
    gstAmount: 108.0,
    netToVendor: 5292.0,
    status: 'confirmed',
    createdAt: DateTime.now(),
  );

  testWidgets('BookingDetailPricingCard renders server-authoritative PAID & CAPTURED status',
      (tester) async {
    final item = CustomerBookingItem(
      booking: baseBooking,
      paymentStatus: 'CAPTURED',
      razorpayPaymentId: 'pay_auth_captured_999',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingDetailPricingCard(item: item),
          ),
        ),
      ),
    );

    expect(find.text('PAID & CAPTURED'), findsOneWidget);
    expect(find.textContaining('Payment Reference: pay_auth_captured_999'), findsOneWidget);
    expect(find.text('Total Amount Paid'), findsOneWidget);
  });

  testWidgets('BookingDetailPricingCard renders RECONCILING PAYMENT when verification is pending',
      (tester) async {
    final item = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'pending'),
      paymentStatus: 'VERIFYING',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingDetailPricingCard(item: item),
          ),
        ),
      ),
    );

    expect(find.text('RECONCILING PAYMENT'), findsOneWidget);
    expect(find.text('Total Amount Payable'), findsOneWidget);
  });

  testWidgets('BookingDetailPricingCard renders REFUND PENDING & PARTIALLY REFUNDED badges',
      (tester) async {
    final itemRefundPending = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'refund_pending'),
      paymentStatus: 'REFUND_PENDING',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingDetailPricingCard(item: itemRefundPending),
          ),
        ),
      ),
    );

    expect(find.text('REFUND PENDING'), findsOneWidget);

    final itemPartiallyRefunded = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'confirmed'),
      paymentStatus: 'PARTIALLY_REFUNDED',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingDetailPricingCard(item: itemPartiallyRefunded),
          ),
        ),
      ),
    );

    expect(find.text('PARTIALLY REFUNDED'), findsOneWidget);
  });

  testWidgets('BookingRefundTrackerCard renders step-by-step refund progress',
      (tester) async {
    final item = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'refunded'),
      paymentStatus: 'REFUNDED',
      cancellationReason: 'Customer requested schedule adjustment',
      cancellationFee: 0.0,
      refundAmount: 6000.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingRefundTrackerCard(item: item),
          ),
        ),
      ),
    );

    expect(find.text('Cancellation & Refund Details'), findsOneWidget);
    expect(find.text('REFUND CREDITED'), findsOneWidget);
    expect(find.text('Booking Cancelled'), findsOneWidget);
    expect(find.text('Reason: Customer requested schedule adjustment'), findsOneWidget);
    expect(find.text('Free cancellation • 100% Refund Approved'), findsOneWidget);
    expect(find.text('Refund Credited to Original Method'), findsOneWidget);
    expect(find.text('Net Refundable Amount:'), findsOneWidget);
  });
}
