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

  final hostYardBooking = BookingModel(
    id: 'BK_HOST_YARD_03',
    customerId: 'cust_103',
    vendorId: 'v1',
    carId: 'car_123',
    tripType: 'Self-Drive',
    pickupLocation: 'Primary Operating Yard, Andheri',
    dropLocation: 'Primary Operating Yard, Andheri',
    pickupName: 'Primary Operating Yard, Andheri',
    dropName: 'Primary Operating Yard, Andheri',
    pickupAddress: 'Plot 12, MIDC, Andheri East, Mumbai',
    pickupLatitude: 19.1136,
    pickupLongitude: 72.8697,
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 4000.0,
    platformFee: 400.0,
    gstAmount: 720.0,
    netToVendor: 2880.0,
    status: 'confirmed',
    createdAt: DateTime.now(),
    deliveryType: 'HUB_PICKUP',
    pickupHubId: 'hub_andheri_yard',
    returnHubId: 'hub_andheri_yard',
    deliveryFee: 0.0,
    pickupFee: 0.0,
    returnFee: 0.0,
    oneWayFee: 0.0,
  );

  final legacyBooking = BookingModel(
    id: 'BK_LEGACY_04',
    customerId: 'cust_104',
    vendorId: 'v1',
    carId: 'car_123',
    tripType: 'Local',
    pickupLocation: 'Mumbai Central',
    dropLocation: 'Mumbai Central',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 2500.0,
    platformFee: 250.0,
    gstAmount: 450.0,
    netToVendor: 1800.0,
    status: 'completed',
    createdAt: DateTime.now(),
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
            bookingsMap: {
              doorstepBooking.id: doorstepBooking,
              relocationBooking.id: relocationBooking,
              hostYardBooking.id: hostYardBooking,
              legacyBooking.id: legacyBooking,
              booking.id: booking,
            },
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
    testWidgets('1. Doorstep fulfillment operational card renders correctly', (tester) async {
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

      expect(find.text('Trip Schedule & Fulfillment'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY DESTINATION'), findsOneWidget);
    });

    testWidgets('2. Doorstep address is displayed', (tester) async {
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

      expect(find.text('Flat 402, Sea Green Apts, Worli Sea Face, Mumbai'), findsWidgets);
    });

    testWidgets('3. GPS navigation action uses persisted coordinates', (tester) async {
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

      expect(find.textContaining('GPS: 19.018, 72.818'), findsOneWidget);

      await tester.tap(find.textContaining('GPS: 19.018, 72.818'));
      await tester.pump();
      expect(find.textContaining('Opening GPS navigation'), findsOneWidget);
    });

    testWidgets('4. Multi-branch return location is displayed', (tester) async {
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

      expect(find.text('DIFFERENT RETURN BRANCH'), findsWidgets);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
    });

    testWidgets('5. One-way relocation fee is rendered correctly', (tester) async {
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

      expect(find.text('+₹250 Relocation'), findsOneWidget);
      expect(find.text('One-Way Relocation Fee'), findsOneWidget);
    });

    testWidgets('6. Fulfillment payout itemization is rendered correctly', (tester) async {
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

      expect(find.text('FULFILLMENT REVENUE BREAKDOWN'), findsOneWidget);
      expect(find.text('Delivery Fee'), findsOneWidget);
      expect(find.text('+₹350 Earned'), findsOneWidget);
      expect(find.text('Doorstep Delivery (Earned)'), findsOneWidget);
    });

    testWidgets('7. Host Yard handover context renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: hostYardBooking,
          child: const HandoverInspectionPage(bookingId: 'BK_HOST_YARD_03'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HANDOVER LOCATION'), findsOneWidget);
      expect(find.text('HOST YARD'), findsOneWidget);
      expect(find.text('Vehicle handover at the vendor\'s selected operating yard.'), findsOneWidget);
    });

    testWidgets('8. Doorstep handover context renders correctly', (tester) async {
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

      expect(find.text('HANDOVER LOCATION'), findsOneWidget);
      expect(find.text('DOORSTEP DISPATCH'), findsOneWidget);
      expect(find.text('Vehicle is being handed over at the customer\'s persisted delivery address.'), findsOneWidget);
    });

    testWidgets('9. Return inspection displays authoritative destination', (tester) async {
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

      expect(find.text('RETURN DESTINATION'), findsOneWidget);
      expect(find.text('RELOCATION BRANCH'), findsOneWidget);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
      expect(find.text('Vehicle scheduled for return at alternate branch (Relocation).'), findsOneWidget);
    });

    testWidgets('10. Booking without fulfillment remains backward compatible', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: legacyBooking,
          child: const VendorBookingDetailPage(bookingId: 'BK_LEGACY_04'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip Schedule & Fulfillment'), findsOneWidget);
      expect(find.text('HOST YARD'), findsOneWidget);
      expect(find.text('Mumbai Central'), findsWidgets);
      expect(find.text('Total Customer Fare'), findsOneWidget);
    });

    testWidgets('11. Null/absent optional fulfillment fields do not crash the UI', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyFulfillmentBooking = BookingModel(
        id: 'BK_EMPTY_05',
        customerId: 'cust_empty',
        vendorId: 'v1',
        carId: 'car_empty',
        tripType: 'Outstation',
        pickupLocation: 'Pune City Yard',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3),
        totalFare: 8000.0,
        platformFee: 800.0,
        gstAmount: 1440.0,
        netToVendor: 5760.0,
        status: 'confirmed',
        createdAt: DateTime.now(),
        deliveryType: null,
        pickupHubId: null,
        returnHubId: null,
        pickupName: null,
        dropName: null,
        pickupAddress: null,
        deliveryAddress: null,
        deliveryFee: null,
        pickupFee: null,
        returnFee: null,
        oneWayFee: null,
        deliveryLatitude: null,
        deliveryLongitude: null,
      );

      await tester.pumpWidget(
        createSubject(
          booking: emptyFulfillmentBooking,
          child: const VendorBookingDetailPage(bookingId: 'BK_EMPTY_05'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pune City Yard'), findsWidgets);
      expect(find.text('HOST YARD'), findsOneWidget);
    });

    testWidgets('12. Confirmed booking renders active pickup handover workflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: doorstepBooking, // confirmed
          child: const VendorBookingDetailPage(bookingId: 'BK_DOORSTEP_01'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vehicle Handover & Pickup Flow'), findsOneWidget);
    });

    testWidgets('13. Ongoing booking renders active return handover workflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: relocationBooking, // ongoing
          child: const VendorBookingDetailPage(bookingId: 'BK_RELOC_02'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vehicle Return & Handover Flow'), findsOneWidget);
    });

    testWidgets('14. Completed booking does not render active inspection workflow actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: legacyBooking, // completed
          child: const VendorBookingDetailPage(bookingId: 'BK_LEGACY_04'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vehicle Handover & Pickup Flow'), findsNothing);
      expect(find.text('Vehicle Return & Handover Flow'), findsNothing);
    });
  });
}
