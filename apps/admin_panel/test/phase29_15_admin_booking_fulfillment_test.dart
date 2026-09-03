import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/bookings/presentation/pages/admin_booking_management_page.dart';
import 'package:admin_panel/features/bookings/presentation/providers/admin_booking_providers.dart';
import 'package:admin_panel/features/bookings/domain/repositories/admin_booking_repository.dart';

class MockAdminFulfillmentBookingRepository implements AdminBookingRepository {
  final Map<String, BookingDetailBundle> bundles;
  final List<BookingModel> bookings;

  MockAdminFulfillmentBookingRepository({
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
}

void main() {
  final doorstepBooking = BookingModel(
    id: 'BK_ADM_DOORSTEP_01',
    customerId: 'cust_901',
    vendorId: 'vnd_901',
    carId: 'car_901',
    tripType: 'Self-Drive',
    pickupLocation: 'Main Yard, Andheri East',
    dropLocation: 'Main Yard, Andheri East',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 5500.0,
    platformFee: 500.0,
    gstAmount: 900.0,
    netToVendor: 4100.0,
    status: 'confirmed',
    createdAt: DateTime.now(),
    deliveryType: 'DOORSTEP_DELIVERY',
    deliveryAddress: 'Flat 402, Sea Green Apts, Worli Sea Face, Mumbai',
    deliveryLatitude: 19.0178,
    deliveryLongitude: 72.8178,
    deliveryFee: 350.0,
    pickupFee: 0.0,
    returnFee: 0.0,
    oneWayFee: 0.0,
  );

  final relocationBooking = BookingModel(
    id: 'BK_ADM_RELOC_02',
    customerId: 'cust_902',
    vendorId: 'vnd_901',
    carId: 'car_901',
    tripType: 'Self-Drive',
    pickupLocation: 'Andheri East Main Yard',
    dropLocation: 'Bandra Kurla Complex Branch',
    pickupName: 'Andheri East Main Yard',
    dropName: 'Bandra Kurla Complex Branch',
    pickupAddress: 'Plot 42, Andheri-Kurla Road, Mumbai',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 6200.0,
    platformFee: 600.0,
    gstAmount: 1000.0,
    netToVendor: 4600.0,
    status: 'ongoing',
    createdAt: DateTime.now(),
    deliveryType: 'HUB_PICKUP',
    pickupHubId: 'hub_andheri',
    returnHubId: 'hub_bkc',
    deliveryFee: 0.0,
    pickupFee: 100.0,
    returnFee: 150.0,
    oneWayFee: 250.0,
  );

  const mockCar = CarModel(
    id: 'car_901',
    vendorId: 'vnd_901',
    make: 'Hyundai',
    model: 'Creta SX(O)',
    year: 2024,
    type: 'SUV',
    fuelType: 'Petrol',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 12.0,
    pricePerDay: 2500.0,
    pricePerHour: 150.0,
  );

  const mockVendor = VendorModel(
    id: 'vnd_901',
    businessName: 'Apex Mobility Mumbai',
    ownerName: 'Rajesh Varma',
    city: 'Mumbai',
    phone: '+91 98765 43210',
    verificationStatus: 'verified',
  );

  const mockCustomer = UserModel(
    id: 'cust_901',
    name: 'Aarav Mehta',
    phone: '+91 91234 56789',
    email: 'aarav.mehta@example.com',
    role: 'customer',
  );

  final doorstepBundle = BookingDetailBundle(
    booking: doorstepBooking,
    car: mockCar,
    vendor: mockVendor,
    customer: mockCustomer,
  );

  final relocationBundle = BookingDetailBundle(
    booking: relocationBooking,
    car: mockCar,
    vendor: mockVendor,
    customer: mockCustomer,
  );

  Widget createSubject({
    required Widget child,
    required List<BookingModel> bookings,
    required Map<String, BookingDetailBundle> bundles,
  }) {
    return ProviderScope(
      overrides: [
        adminBookingRepositoryProvider.overrideWithValue(
          MockAdminFulfillmentBookingRepository(
            bookings: bookings,
            bundles: bundles,
          ),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Phase 29.15: Admin Control Tower — Booking Fulfillment Inspection Tests', () {
    testWidgets('1. Admin Booking Detail Drawer renders Doorstep Delivery snapshot and GPS coordinates',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          bookings: [doorstepBooking],
          bundles: {'BK_ADM_DOORSTEP_01': doorstepBundle},
          child: const AdminBookingManagementPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Open booking drawer
      expect(find.text('#BK_ADM_DOORSTEP_01'), findsOneWidget);
      await tester.tap(find.text('#BK_ADM_DOORSTEP_01'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Fulfillment & Trip Snapshot section
      expect(find.text('Fulfillment & Trip Snapshot'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY'), findsOneWidget);
      expect(find.text('Flat 402, Sea Green Apts, Worli Sea Face, Mumbai'), findsOneWidget);
      expect(find.text('19.0178, 72.8178'), findsOneWidget);

      // Verify Itemized Fare Breakdown
      expect(find.text('Fare Breakdown & Fulfillment'), findsOneWidget);
      expect(find.text('Doorstep Delivery Fee'), findsOneWidget);
      expect(find.text('₹350.00'), findsOneWidget);

      // Verify Admin Governance Controls
      expect(find.text('Force Cancel'), findsOneWidget);
      expect(find.text('Force Complete'), findsOneWidget);
    });

    testWidgets('2. Admin Booking Detail Drawer renders Branch Relocation snapshot and itemized fees',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          bookings: [relocationBooking],
          bundles: {'BK_ADM_RELOC_02': relocationBundle},
          child: const AdminBookingManagementPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open booking drawer
      expect(find.text('#BK_ADM_RELOC_02'), findsOneWidget);
      await tester.tap(find.text('#BK_ADM_RELOC_02'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Fulfillment & Trip Snapshot section
      expect(find.text('Fulfillment & Trip Snapshot'), findsOneWidget);
      expect(find.text('BRANCH RELOCATION'), findsOneWidget);
      expect(find.text('Andheri East Main Yard'), findsWidgets);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);

      // Verify Itemized Fare Breakdown
      expect(find.text('Fare Breakdown & Fulfillment'), findsOneWidget);
      expect(find.text('One-Way Relocation Fee'), findsOneWidget);
      expect(find.text('₹250.00'), findsOneWidget);
      expect(find.text('Pickup Hub Fee'), findsOneWidget);
      expect(find.text('₹100.00'), findsOneWidget);
      expect(find.text('Return Hub Fee'), findsOneWidget);
      expect(find.text('₹150.00'), findsOneWidget);
    });
  });
}
