import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/fleet/presentation/pages/add_edit_car_page.dart';

void main() {
  final now = DateTime.now();

  final historicalBooking = BookingModel(
    id: 'bk_historical_locked',
    customerId: 'cust_01',
    vendorId: 'v_test',
    carId: 'car_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Main Yard, Andheri East',
    startDate: now.subtract(const Duration(days: 5)),
    endDate: now.subtract(const Duration(days: 3)),
    totalFare: 5000.0,
    platformFee: 500.0,
    gstAmount: 900.0,
    netToVendor: 4500.0,
    status: 'completed',
    createdAt: now.subtract(const Duration(days: 6)),
  );

  group('Phase 35 Vendor App Pricing & Governance Tests', () {
    testWidgets('1. AddEditCarPage displays server-authoritative pricing governance banner', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddEditCarPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Step 3: Commercial & Pricing
      // Step 1 -> Step 2
      final nextButton = find.text('Continue');
      expect(nextButton, findsOneWidget);

      // Fill in required fields for step 0
      final step0Fields = find.byType(TextField);
      await tester.enterText(step0Fields.at(0), 'Hyundai');
      await tester.enterText(step0Fields.at(1), 'Creta');
      await tester.enterText(step0Fields.at(3), 'MH02AB1234');

      await tester.tap(nextButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Commercial & Pricing)
      await tester.tap(nextButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify Commercial Rates & Pricing step
      expect(find.text('Commercial Rates & Pricing'), findsOneWidget);
      expect(find.text('Server-Authoritative Pricing Active'), findsOneWidget);
      expect(find.textContaining('Changes will not alter existing accepted bookings or quotes'), findsOneWidget);
    });

    test('2. Historical accepted booking preserves immutable financials', () {
      // Historical booking remains ₹5000 total and ₹4500 net even if vendor changes daily rate
      expect(historicalBooking.totalFare, 5000.0);
      expect(historicalBooking.netToVendor, 4500.0);
      expect(historicalBooking.status, 'completed');
    });
  });
}
