import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_host_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_actions_card.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';

void main() {
  const mockVendor = VendorModel(
    id: 'vendor_123',
    businessName: 'Royal Auto Rentals Pvt Ltd',
    ownerName: 'Vikram Malhotra',
    city: 'Mumbai',
    locality: 'Bandra West',
    phone: '+919876543210',
    rating: 4.8,
    verificationStatus: 'VERIFIED',
  );

  final mockBooking = BookingModel(
    id: 'bk_gate_001',
    customerId: 'cust_001',
    vendorId: 'vendor_123',
    carId: 'car_123',
    tripType: 'Self-Drive',
    pickupLocation: 'Mumbai Airport',
    startDate: DateTime.now().add(const Duration(days: 1)),
    endDate: DateTime.now().add(const Duration(days: 3)),
    totalFare: 5000.0,
    platformFee: 500.0,
    gstAmount: 250.0,
    netToVendor: 4250.0,
    status: 'pending',
    createdAt: DateTime.now(),
  );

  group('Phase 23A: Owner Confirmation Gate & Host Details Privacy UI Tests', () {
    testWidgets('1. BookingDetailHostCard strictly hides Contact Host button when isConfirmed is false', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailHostCard(
                vendor: mockVendor,
                bookingId: 'bk_gate_001',
                isConfirmed: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Help & Support is available, but Contact Host is strictly HIDDEN
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Contact Host'), findsNothing);
    });

    testWidgets('2. BookingDetailHostCard displays Contact Host button when isConfirmed is true', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailHostCard(
                vendor: mockVendor,
                bookingId: 'bk_gate_001',
                isConfirmed: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Contact Host is visible when owner has confirmed booking
      expect(find.text('Contact Host'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
    });

    testWidgets('3. BookingDetailActionsCard displays Cancel Booking Request and hides Complete Payment when paid awaiting confirmation', (tester) async {
      final item = CustomerBookingItem(
        booking: mockBooking,
        vendor: mockVendor,
        paymentStatus: 'PAID',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailActionsCard(
                item: item,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: "Complete Payment" is NOT shown because payment is already paid
      expect(find.textContaining('Complete Payment'), findsNothing);
      expect(find.text('Cancel Booking Request'), findsOneWidget);
    });

    testWidgets('4. BookingDetailActionsCard displays Complete Payment when pending and unpaid', (tester) async {
      final item = CustomerBookingItem(
        booking: mockBooking,
        vendor: mockVendor,
        paymentStatus: 'CREATED',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailActionsCard(
                item: item,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: "Complete Payment" is shown for unpaid bookings
      expect(find.textContaining('Complete Payment'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);
    });
  });
}
