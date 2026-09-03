import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';

class MockFulfillmentVendorBookingsRepository implements VendorBookingsRepository {
  final Map<String, BookingModel> bookingsMap;
  final Map<String, List<InspectionModel>> inspectionsMap;

  MockFulfillmentVendorBookingsRepository({
    required this.bookingsMap,
    this.inspectionsMap = const {},
  });

  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    return bookingsMap.values.where((b) => b.vendorId == vendorId).toList();
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {}

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {}

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async {
    return inspectionsMap[bookingId] ?? [];
  }

  @override
  Future<InspectionModel> upsertInspection(
    String bookingId, {
    required String type,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool finalize = true,
  }) async {
    return InspectionModel(
      id: 'insp_123',
      bookingId: bookingId,
      type: type,
      performedById: 'vendor_1',
      odometer: odometer,
      fuelPercent: fuelPercent,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendHandoverOtp(String bookingId, String otpType) async {}

  @override
  Future<List<DamageClaimModel>> getDamageClaims(String bookingId) async => [];

  @override
  Future<DamageClaimModel> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  }) async => throw UnimplementedError();
}

void main() {
  final doorstepBooking = BookingModel(
    id: 'BK_DOORSTEP_01',
    customerId: 'cust_101',
    vendorId: 'v1',
    carId: 'car_123',
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
    id: 'BK_RELOC_02',
    customerId: 'cust_102',
    vendorId: 'v1',
    carId: 'car_123',
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

  Widget createSubject({
    required Widget child,
    required BookingModel booking,
    List<InspectionModel> inspections = const [],
  }) {
    return ProviderScope(
      overrides: [
        vendorBookingsRepositoryProvider.overrideWithValue(
          MockFulfillmentVendorBookingsRepository(
            bookingsMap: {booking.id: booking},
            inspectionsMap: {booking.id: inspections},
          ),
        ),
        singleBookingProvider(booking.id).overrideWith((ref) => Future.value(booking)),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Phase 29.14: Vendor Booking Fulfillment & Handover/Return Operational Tests', () {
    testWidgets('1. Vendor Booking Detail renders Doorstep Delivery destination and GPS coordinates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: doorstepBooking,
          child: const VendorBookingDetailPage(bookingId: 'BK_DOORSTEP_01'),
        ),
      );

      await tester.pumpAndSettle();

      // Verified fulfillment header and badge
      expect(find.text('Trip Schedule & Fulfillment'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY'), findsOneWidget);

      // Verified delivery destination and full address
      expect(find.text('DOORSTEP DELIVERY DESTINATION'), findsOneWidget);
      expect(find.text('Flat 402, Sea Green Apts, Worli Sea Face, Mumbai'), findsWidgets);

      // Verified GPS action button with coordinates
      expect(find.textContaining('GPS: 19.018, 72.818'), findsOneWidget);

      // Verified itemized delivery earnings row
      expect(find.text('Doorstep Delivery (Earned)'), findsOneWidget);
    });

    testWidgets('2. Vendor Booking Detail renders Branch Relocation with surcharge badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: relocationBooking,
          child: const VendorBookingDetailPage(bookingId: 'BK_RELOC_02'),
        ),
      );

      await tester.pumpAndSettle();

      // Verified relocation fulfillment badge
      expect(find.text('BRANCH RELOCATION'), findsOneWidget);

      // Verified pickup and return branch cards
      expect(find.text('Andheri East Main Yard'), findsWidgets);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
      expect(find.text('+₹250 Relocation'), findsOneWidget);

      // Verified itemized earnings
      expect(find.text('One-Way Relocation (Earned)'), findsOneWidget);
      expect(find.text('Pickup Hub Fee (Earned)'), findsOneWidget);
      expect(find.text('Return Hub Fee (Earned)'), findsOneWidget);
    });

    testWidgets('3. HandoverInspectionPage renders Authoritative Handover Location Banner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: doorstepBooking,
          child: const HandoverInspectionPage(bookingId: 'BK_DOORSTEP_01'),
        ),
      );

      await tester.pumpAndSettle();

      // Step 0 Identity renders handover location banner
      expect(find.text('HANDOVER LOCATION'), findsOneWidget);
      expect(find.text('DOORSTEP DISPATCH'), findsOneWidget);
      expect(find.text('Flat 402, Sea Green Apts, Worli Sea Face, Mumbai'), findsOneWidget);
    });

    testWidgets('4. ReturnInspectionPage renders Authoritative Return Destination Banner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: relocationBooking,
          child: const ReturnInspectionPage(bookingId: 'BK_RELOC_02'),
        ),
      );

      await tester.pumpAndSettle();

      // Step 0 Odometer/Fuel renders return destination banner
      expect(find.text('RETURN DESTINATION'), findsOneWidget);
      expect(find.text('RELOCATION BRANCH'), findsOneWidget);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
    });
  });
}
