import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/presentation/widgets/fare_breakdown_step.dart';

void main() {
  const testCar = CarModel(
    id: 'car_test_001',
    vendorId: 'vendor_test_001',
    make: 'Hyundai',
    model: 'i20',
    year: 2023,
    type: 'Hatchback',
    fuelType: 'Petrol',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 12.0,
    pricePerDay: 2200.0,
    pricePerHour: 180.0,
    registrationNumber: 'TS 09 AB 1234',
    isAvailable: true,
    blockedDates: [],
    availableTripTypes: ['Local', 'Outstation'],
  );

  const testVendor = VendorModel(
    id: 'vendor_test_001',
    businessName: 'DriveGo Prime Fleet',
    ownerName: 'Test Owner',
    city: 'Hyderabad',
    verificationStatus: 'VERIFIED',
  );

  Widget buildTestWidget({required double width}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 700,
              child: FareBreakdownStep(
                car: testCar,
                vendor: testVendor,
                onBack: () {},
                onNext: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('BUG-03 Regression: FareBreakdownStep layout constraints under AppTheme', () {
    testWidgets('renders cleanly on narrow mobile viewport (320px) without infinite-width crash',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(width: 320));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Enter promo code'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('renders cleanly on standard mobile viewport (390px)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(width: 390));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter promo code'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on tablet/desktop viewport (800px)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(width: 800));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter promo code'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
