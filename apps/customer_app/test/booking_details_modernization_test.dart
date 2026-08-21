import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_header_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_schedule_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_package_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_actions_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_refund_tracker_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/active_trip_hero_card.dart';

void main() {
  final sampleCar = CarModel(
    id: 'car_creta',
    vendorId: 'vendor_apex',
    make: 'Hyundai',
    model: 'Creta',
    year: 2023,
    type: 'SUV',
    fuelType: 'Diesel',
    seating: 5,
    isAC: true,
    pricePerKm: 14.0,
    pricePerDay: 3500.0,
    pricePerHour: 250.0,
    photos: ['https://example.com/creta.jpg'],
    registrationNumber: 'MH02CD5678',
    isAvailable: true,
    availableTripTypes: ['Self-Drive', 'Outstation'],
  );

  final sampleVendor = const VendorModel(
    id: 'vendor_apex',
    businessName: 'Apex Luxury Rentals',
    ownerName: 'Rajesh Kumar',
    city: 'Mumbai',
    businessType: 'FLEET_OPERATOR',
    verificationStatus: 'VERIFIED',
    rating: 4.9,
  );


  final confirmedItem = CustomerBookingItem(
    booking: BookingModel(
      id: 'bk_conf_123',
      customerId: 'cust_1',
      carId: 'car_creta',
      vendorId: 'vendor_apex',
      status: 'confirmed',
      startDate: DateTime.now().add(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 3)),
      totalFare: 7000,
      platformFee: 700,
      gstAmount: 1260,
      netToVendor: 5040,
      tripType: 'Self-Drive',
      pickupLocation: 'Mumbai Airport T2',
      dropLocation: 'Mumbai Airport T2',
      createdAt: DateTime.now(),
    ),
    car: sampleCar,
    vendor: sampleVendor,
    mileagePackageName: 'Standard 150 km/day',
    includedKmTotal: 300,
    extraKmRate: 14.0,
    protectionCode: 'ZERO_DEP',
    protectionFee: 599.0,
    deliveryType: 'DOORSTEP_DELIVERY',
    deliveryAddress: 'Bandra West, Mumbai',
    deliveryFee: 300.0,
    razorpayPaymentId: 'pay_test_999888',
    paymentStatus: 'PAID',
  );

  final ongoingItem = CustomerBookingItem(
    booking: BookingModel(
      id: 'bk_ong_456',
      customerId: 'cust_1',
      carId: 'car_creta',
      vendorId: 'vendor_apex',
      status: 'ongoing',
      startDate: DateTime.now().subtract(const Duration(hours: 12)),
      endDate: DateTime.now().add(const Duration(days: 1, hours: 12)),
      totalFare: 7000,
      platformFee: 700,
      gstAmount: 1260,
      netToVendor: 5040,
      tripType: 'Self-Drive',
      pickupLocation: 'Bandra West',
      createdAt: DateTime.now(),
    ),
    car: sampleCar,
    vendor: sampleVendor,
    mileagePackageName: 'Unlimited Package',
    protectionCode: 'STANDARD',
  );

  final cancelledItem = CustomerBookingItem(
    booking: BookingModel(
      id: 'bk_can_789',
      customerId: 'cust_1',
      carId: 'car_creta',
      vendorId: 'vendor_apex',
      status: 'cancelled',
      startDate: DateTime.now().add(const Duration(days: 4)),
      endDate: DateTime.now().add(const Duration(days: 6)),
      totalFare: 7000,
      platformFee: 700,
      gstAmount: 1260,
      netToVendor: 5040,
      tripType: 'Self-Drive',
      pickupLocation: 'Andheri',
      createdAt: DateTime.now(),
    ),
    car: sampleCar,
    vendor: sampleVendor,
    cancellationReason: 'Found alternative travel arrangements',
    cancellationFee: 0,
    refundAmount: 7000,
    paymentStatus: 'REFUNDED',
  );

  group('Booking Details Modernization Widget Tests', () {
    testWidgets('1. Header card renders vehicle specs and registration number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailHeaderCard(item: confirmedItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('MH02CD5678'), findsOneWidget);
      expect(find.text('Host: Apex Luxury Rentals'), findsOneWidget);
    });

    testWidgets('2. Schedule card renders pickup/return timeline and doorstep delivery', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailScheduleCard(item: confirmedItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trip Schedule & Locations'), findsOneWidget);
      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY'), findsOneWidget);
      expect(find.text('Bandra West, Mumbai'), findsOneWidget);
      expect(find.text('DROP-OFF / RETURN'), findsOneWidget);
    });

    testWidgets('3. Package card renders mileage limits and Zero-Dep protection badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailPackageCard(item: confirmedItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Package & Protection Details'), findsOneWidget);
      expect(find.text('Standard 150 km/day'), findsOneWidget);
      expect(find.text('Included: 300 km • Extra km rate: ₹14/km'), findsOneWidget);
      expect(find.text('Zero-Deductible Peace of Mind'), findsOneWidget);
    });

    testWidgets('4. Pricing card renders transparent fare breakdown and Razorpay ID', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailPricingCard(item: confirmedItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Payment & Fare Breakdown'), findsOneWidget);
      expect(find.text('PAID IN FULL'), findsOneWidget);
      expect(find.text('Doorstep Delivery Fee'), findsOneWidget);
      expect(find.text('Goods & Services Tax (GST 18%)'), findsOneWidget);
      expect(find.textContaining('pay_test_999888'), findsOneWidget);
    });

    testWidgets('5. Refund tracker card renders 3-step cancellation stepper on cancelled booking',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingRefundTrackerCard(item: cancelledItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cancellation & Refund Details'), findsOneWidget);
      expect(find.text('Booking Cancelled'), findsOneWidget);
      expect(find.text('Policy Verified & Refund Calculated'), findsOneWidget);
      expect(find.text('Refund Credited to Original Method'), findsOneWidget);
    });

    testWidgets('6. Actions card renders context-aware actions for Confirmed vs Ongoing',
        (tester) async {
      // Test Confirmed state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailActionsCard(item: confirmedItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('View Pickup Handover PIN'), findsOneWidget);
      expect(find.text('View Inspection Checklist'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);

      // Test Ongoing state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailActionsCard(item: ongoingItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Extend Trip Duration'), findsOneWidget);
      expect(find.text('Return PIN'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Emergency Assistance (SOS)'), findsOneWidget);
    });

    testWidgets('7. ActiveTripHeroCard renders live pulsing badge and return countdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveTripHeroCard(item: ongoingItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ACTIVE TRIP IN PROGRESS'), findsOneWidget);
      expect(find.text('Manage Trip'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
    });
  });
}
