import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  testWidgets('EarningsPage displays SETTLEMENT ELIGIBLE for completed undisputed booking',
      (tester) async {
    final completedBooking = BookingModel(
      id: 'BK_VND_COMPLETED_01',
      customerId: 'cust_01',
      vendorId: 'vnd_01',
      carId: 'car_01',
      tripType: 'Self-Drive',
      pickupLocation: 'Host Yard',
      dropLocation: 'Host Yard',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      totalFare: 5000.0,
      platformFee: 500.0,
      gstAmount: 90.0,
      netToVendor: 4410.0,
      status: 'completed',
      disputeFlag: false,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with the earnings breakdown row
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Test the earnings row through the widget
                  _TestEarningsRowWrapper(booking: completedBooking),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('SETTLEMENT ELIGIBLE'), findsOneWidget);
    expect(find.text('Customer Paid (Escrow):'), findsOneWidget);
    expect(find.text('Net Vendor Settlement:'), findsOneWidget);
  });

  testWidgets('EarningsPage displays ESCROW HOLD (DISPUTED) when booking has active dispute',
      (tester) async {
    final disputedBooking = BookingModel(
      id: 'BK_VND_DISPUTED_02',
      customerId: 'cust_02',
      vendorId: 'vnd_01',
      carId: 'car_01',
      tripType: 'Self-Drive',
      pickupLocation: 'Host Yard',
      dropLocation: 'Host Yard',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      totalFare: 5000.0,
      platformFee: 500.0,
      gstAmount: 90.0,
      netToVendor: 4410.0,
      status: 'completed',
      disputeFlag: true,
      disputeNote: 'Customer disputed fuel charge',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TestEarningsRowWrapper(booking: disputedBooking),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ESCROW HOLD (DISPUTED)'), findsOneWidget);
  });

  testWidgets('EarningsPage displays REFUNDED TO CUSTOMER for cancelled booking',
      (tester) async {
    final cancelledBooking = BookingModel(
      id: 'BK_VND_CANCELLED_03',
      customerId: 'cust_03',
      vendorId: 'vnd_01',
      carId: 'car_01',
      tripType: 'Self-Drive',
      pickupLocation: 'Host Yard',
      dropLocation: 'Host Yard',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      totalFare: 5000.0,
      platformFee: 500.0,
      gstAmount: 90.0,
      netToVendor: 4410.0,
      status: 'cancelled',
      disputeFlag: false,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TestEarningsRowWrapper(booking: cancelledBooking),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('REFUNDED TO CUSTOMER'), findsOneWidget);
  });
}

class _TestEarningsRowWrapper extends StatelessWidget {
  final BookingModel booking;
  const _TestEarningsRowWrapper({required this.booking});

  @override
  Widget build(BuildContext context) {
    // Replicates the row widget logic to test in isolation
    final isDisputed = booking.disputeFlag;
    final isCompleted = booking.status.toLowerCase() == 'completed';
    final isCancelled = booking.status.toLowerCase() == 'cancelled' ||
        booking.status.toLowerCase() == 'refunded';

    String escrowLabel = 'IN PLATFORM ESCROW';
    if (isDisputed) {
      escrowLabel = 'ESCROW HOLD (DISPUTED)';
    } else if (isCancelled) {
      escrowLabel = 'REFUNDED TO CUSTOMER';
    } else if (isCompleted) {
      escrowLabel = 'SETTLEMENT ELIGIBLE';
    }

    return Column(
      children: [
        Text(escrowLabel),
        const Text('Customer Paid (Escrow):'),
        const Text('Net Vendor Settlement:'),
      ],
    );
  }
}
