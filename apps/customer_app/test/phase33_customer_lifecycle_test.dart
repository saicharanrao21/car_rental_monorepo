import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_header_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_actions_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockCar = CarModel(
    id: 'car-p33-1',
    vendorId: 'vendor-p33-1',
    make: 'Hyundai',
    model: 'Creta SX',
    year: 2024,
    type: 'SUV',
    fuelType: 'Petrol',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 12.0,
    pricePerDay: 3000.0,
    pricePerHour: 200.0,
    registrationNumber: 'KA-01-MJ-9988',
    isAvailable: true,
  );

  const mockVendor = VendorModel(
    id: 'vendor-p33-1',
    businessName: 'Royal Fleet Rentals',
    ownerName: 'Vikram Patel',
    city: 'Bengaluru',
    phone: '+919123456780',
    verificationStatus: 'VERIFIED',
  );

  CustomerBookingItem createItem(String status, {String? paymentStatus = 'paid'}) {
    return CustomerBookingItem(
      booking: BookingModel(
        id: 'bk_p33_lifecycle_001',
        customerId: 'cust_001',
        vendorId: 'vendor-p33-1',
        carId: 'car-p33-1',
        tripType: 'Self-Drive',
        pickupLocation: 'Koramangala Hub',
        dropLocation: 'Indiranagar Hub',
        startDate: DateTime(2026, 9, 10, 10),
        endDate: DateTime(2026, 9, 15, 10),
        totalFare: 12000,
        platformFee: 1200,
        gstAmount: 2160,
        netToVendor: 8640,
        status: status,
        createdAt: DateTime(2026, 9, 5),
      ),
      car: mockCar,
      vendor: mockVendor,
      paymentStatus: paymentStatus,
    );
  }

  Widget createWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Phase 33 — Customer Booking Lifecycle Orchestration UI Tests', () {
    testWidgets('1. Lifecycle state rendering: CONFIRMED state renders StatusBadge and Pickup PIN CTA', (tester) async {
      final item = createItem('confirmed');

      await tester.pumpWidget(createWidget(
        Column(
          children: [
            BookingDetailHeaderCard(item: item),
            BookingDetailActionsCard(item: item),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hyundai Creta SX'), findsOneWidget);
      expect(find.text('View Pickup Handover PIN'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);
    });

    testWidgets('2. Lifecycle state rendering: HANDOVER_READY displays ready banner & Pickup PIN', (tester) async {
      final item = createItem('handover_ready');

      await tester.pumpWidget(createWidget(
        Column(
          children: [
            BookingDetailHeaderCard(item: item),
            BookingDetailActionsCard(item: item),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Show Pickup PIN to Host'), findsOneWidget);
      expect(find.text('View Inspection Checklist'), findsOneWidget);
    });

    testWidgets('3. Server-authoritative updates: ONGOING state renders Return PIN and Extension CTAs', (tester) async {
      final item = createItem('ongoing');

      await tester.pumpWidget(createWidget(
        Column(
          children: [
            BookingDetailHeaderCard(item: item),
            BookingDetailActionsCard(item: item),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extend Trip Duration'), findsOneWidget);
      expect(find.text('Return PIN'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Emergency Assistance (SOS)'), findsOneWidget);
    });

    testWidgets('4. Return pending lifecycle state renders active trip return actions', (tester) async {
      final item = createItem('return_pending');

      await tester.pumpWidget(createWidget(
        Column(
          children: [
            BookingDetailHeaderCard(item: item),
            BookingDetailActionsCard(item: item),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Return PIN'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
    });

    testWidgets('5. Terminal state COMPLETED renders cleanly without mutable transition buttons', (tester) async {
      final item = createItem('completed');

      await tester.pumpWidget(createWidget(
        Column(
          children: [
            BookingDetailHeaderCard(item: item),
            BookingDetailActionsCard(item: item),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extend Trip Duration'), findsNothing);
      expect(find.text('View Pickup Handover PIN'), findsNothing);
      expect(find.text('Complete Payment'), findsNothing);
    });

    testWidgets('6. Action loading: When payment is processing, AppButton displays loading indicator', (tester) async {
      final item = createItem('pending', paymentStatus: 'created');

      await tester.pumpWidget(createWidget(
        BookingDetailActionsCard(
          item: item,
          isProcessingPayment: true,
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
