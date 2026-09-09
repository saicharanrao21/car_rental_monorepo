import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_refund_tracker_card.dart';

void main() {
  final baseBooking = BookingModel(
    id: 'BK_P36_CUST_01',
    customerId: 'cust_p36',
    vendorId: 'vnd_p36',
    carId: 'car_p36',
    tripType: 'Self-Drive',
    pickupLocation: 'Indiranagar, Bangalore',
    dropLocation: 'Indiranagar, Bangalore',
    startDate: DateTime(2026, 9, 15, 10, 0),
    endDate: DateTime(2026, 9, 17, 10, 0),
    totalFare: 7500.0,
    platformFee: 750.0,
    gstAmount: 135.0,
    netToVendor: 6615.0,
    status: 'pending',
    createdAt: DateTime.now(),
  );

  group('Phase 36: Customer App Payment & Financial State Tests', () {
    testWidgets('1. Renders PAYMENT PENDING on initial order creation',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking,
        paymentStatus: 'CREATED',
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

      expect(find.text('PAYMENT PENDING'), findsOneWidget);
      expect(find.text('Total Amount Payable'), findsOneWidget);
    });

    testWidgets('2. Renders RECONCILING PAYMENT during async verification / polling',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking,
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
    });

    testWidgets('3. Renders server-authoritative PAID & CAPTURED with payment reference',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking.copyWith(status: 'confirmed'),
        paymentStatus: 'CAPTURED',
        razorpayPaymentId: 'pay_p36_verified_123',
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
      expect(find.textContaining('Payment Reference: pay_p36_verified_123'), findsOneWidget);
      expect(find.text('Total Amount Paid'), findsOneWidget);
    });

    testWidgets('4. Renders PAYMENT FAILED badge when payment gateway rejects attempt',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking,
        paymentStatus: 'FAILED',
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

      expect(find.text('PAYMENT FAILED'), findsOneWidget);
    });

    testWidgets('5. Renders ORDER EXPIRED badge when payment order timed out',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking,
        paymentStatus: 'EXPIRED',
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

      expect(find.text('ORDER EXPIRED'), findsOneWidget);
    });

    testWidgets('6. Renders REFUND PENDING and tracker when booking is cancelled',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking.copyWith(
          status: 'cancelled',
        ),
        paymentStatus: 'REFUND_PENDING',
        refundAmount: 5625.0,
        cancellationFee: 1875.0,
        cancellationReason: 'Flight schedule change',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BookingDetailPricingCard(item: item),
                  BookingRefundTrackerCard(item: item),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('REFUND PENDING'), findsWidgets);
      expect(find.text('Cancellation & Refund Details'), findsOneWidget);
      expect(find.textContaining('5,625'), findsWidgets);
    });

    testWidgets('7. Renders PARTIALLY REFUNDED badge when cancellation penalty applies',
        (tester) async {
      final item = CustomerBookingItem(
        booking: baseBooking.copyWith(
          status: 'cancelled',
        ),
        paymentStatus: 'PARTIALLY_REFUNDED',
        refundAmount: 3750.0,
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

      expect(find.text('PARTIALLY REFUNDED'), findsOneWidget);
    });
  });
}
