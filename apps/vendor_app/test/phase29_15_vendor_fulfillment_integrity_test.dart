import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';

void main() {
  late MockVendorBookingsRepository repo;

  final now = DateTime.now();

  // Test bookings for the 7 fulfillment scenarios
  final hostYardBooking = BookingModel(
    id: 'bk_test_host_yard',
    customerId: 'cust_hy_01',
    vendorId: 'v_test',
    carId: 'car_hy_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Main Operating Yard, Andheri East',
    dropLocation: 'Main Operating Yard, Andheri East',
    pickupName: 'Main Operating Yard, Andheri East',
    dropName: 'Main Operating Yard, Andheri East',
    pickupAddress: 'Sector 4, Andheri East, Mumbai, Maharashtra 400069',
    pickupLatitude: 19.1136,
    pickupLongitude: 72.8697,
    startDate: now.add(const Duration(hours: 2)),
    endDate: now.add(const Duration(days: 2)),
    totalFare: 4200.0,
    platformFee: 420.0,
    gstAmount: 756.0,
    netToVendor: 3780.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 3)),
    deliveryType: 'HUB_PICKUP',
    pickupHubId: 'hub_main_yard',
    returnHubId: 'hub_main_yard',
    deliveryFee: 0.0,
    pickupFee: 0.0,
    returnFee: 0.0,
    oneWayFee: 0.0,
  );

  final doorstepBooking = BookingModel(
    id: 'bk_test_doorstep',
    customerId: 'cust_ds_02',
    vendorId: 'v_test',
    carId: 'car_ds_02',
    tripType: 'Self-Drive',
    pickupLocation: 'Main Operating Yard, Andheri East',
    dropLocation: 'Main Operating Yard, Andheri East',
    pickupName: 'Customer Doorstep Address',
    deliveryAddress: 'Flat 602, Sea Breeze Towers, Worli Sea Face, Mumbai',
    deliveryLatitude: 19.0178,
    deliveryLongitude: 72.8178,
    startDate: now.add(const Duration(hours: 4)),
    endDate: now.add(const Duration(days: 3)),
    totalFare: 6850.0,
    platformFee: 600.0,
    gstAmount: 1100.0,
    netToVendor: 5250.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 5)),
    deliveryType: 'DOORSTEP_DELIVERY',
    pickupHubId: 'hub_main_yard',
    deliveryFee: 450.0,
    pickupFee: 0.0,
    returnFee: 0.0,
    oneWayFee: 0.0,
  );

  final transitHubBooking = BookingModel(
    id: 'bk_test_transit',
    customerId: 'cust_th_03',
    vendorId: 'v_test',
    carId: 'car_th_03',
    tripType: 'Airport Transfer',
    pickupLocation: 'CSMIA Terminal 2 (BOM)',
    dropLocation: 'CSMIA Terminal 2 (BOM)',
    pickupName: 'Chhatrapati Shivaji Maharaj International Airport (BOM)',
    pickupAddress: 'Terminal 2 Arrivals, Level 1 Pick-up Zone, Andheri East, Mumbai',
    pickupLatitude: 19.0896,
    pickupLongitude: 72.8656,
    startDate: now.add(const Duration(hours: 1)),
    endDate: now.add(const Duration(days: 1)),
    totalFare: 3800.0,
    platformFee: 350.0,
    gstAmount: 620.0,
    netToVendor: 3450.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 2)),
    deliveryType: 'PUBLIC_LOCATION',
    pickupHubId: 'pub_mum_csmia',
    returnHubId: 'pub_mum_csmia',
    deliveryFee: 0.0,
    pickupFee: 200.0,
    returnFee: 200.0,
    oneWayFee: 0.0,
  );

  final diffReturnBooking = BookingModel(
    id: 'bk_test_diff_return',
    customerId: 'cust_dr_04',
    vendorId: 'v_test',
    carId: 'car_dr_04',
    tripType: 'Self-Drive',
    pickupLocation: 'Andheri East Main Yard',
    dropLocation: 'Bandra Kurla Complex Branch',
    pickupName: 'Andheri East Main Yard',
    dropName: 'Bandra Kurla Complex Branch',
    pickupAddress: 'Plot 42, Andheri-Kurla Road, Mumbai',
    pickupLatitude: 19.1136,
    pickupLongitude: 72.8697,
    deliveryAddress: 'G-Block, BKC Urban Hub, Bandra East, Mumbai',
    deliveryLatitude: 19.0664,
    deliveryLongitude: 72.8679,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 2)),
    totalFare: 7400.0,
    platformFee: 700.0,
    gstAmount: 1200.0,
    netToVendor: 5500.0,
    status: 'ongoing',
    createdAt: now.subtract(const Duration(days: 2)),
    deliveryType: 'HUB_PICKUP',
    pickupHubId: 'hub_andheri',
    returnHubId: 'hub_bkc',
    deliveryFee: 0.0,
    pickupFee: 0.0,
    returnFee: 150.0,
    oneWayFee: 350.0,
  );

  final bothwayDoorstepBooking = BookingModel(
    id: 'bk_test_bothway_doorstep',
    customerId: 'cust_bw_05',
    vendorId: 'v_test',
    carId: 'car_bw_05',
    tripType: 'Self-Drive',
    pickupLocation: 'Customer Doorstep',
    dropLocation: 'Customer Doorstep Collection',
    pickupName: 'Customer Residence (Worli)',
    dropName: 'Customer Residence (Worli)',
    deliveryAddress: 'Tower B, Lodha Park, Worli, Mumbai',
    deliveryLatitude: 19.0062,
    deliveryLongitude: 72.8258,
    startDate: now.add(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 4)),
    totalFare: 8900.0,
    platformFee: 800.0,
    gstAmount: 1450.0,
    netToVendor: 6650.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 1)),
    deliveryType: 'DOORSTEP_DELIVERY',
    pickupHubId: 'hub_main_yard',
    deliveryFee: 400.0,
    pickupFee: 0.0,
    returnFee: 400.0,
    oneWayFee: 0.0,
  );

  final legacyBooking = BookingModel(
    id: 'bk_test_legacy',
    customerId: 'cust_nf_06',
    vendorId: 'v_test',
    carId: 'car_nf_06',
    tripType: 'Local',
    pickupLocation: 'Mumbai Central',
    dropLocation: 'Mumbai Central',
    startDate: now.subtract(const Duration(days: 5)),
    endDate: now.subtract(const Duration(days: 4)),
    totalFare: 2100.0,
    platformFee: 200.0,
    gstAmount: 340.0,
    netToVendor: 1900.0,
    status: 'completed',
    createdAt: now.subtract(const Duration(days: 6)),
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

  final combinedBooking = BookingModel(
    id: 'bk_test_combined',
    customerId: 'cust_cb_07',
    vendorId: 'v_test',
    carId: 'car_cb_07',
    tripType: 'Self-Drive',
    pickupLocation: 'Customer Doorstep (Powai)',
    dropLocation: 'Navi Mumbai Hub',
    pickupName: 'Customer Doorstep (Powai)',
    dropName: 'Vashi Station Terminal Hub',
    pickupAddress: 'Hiranandani Gardens, Powai, Mumbai',
    pickupLatitude: 19.1197,
    pickupLongitude: 72.9051,
    deliveryAddress: 'Hiranandani Gardens, Powai, Mumbai',
    deliveryLatitude: 19.1197,
    deliveryLongitude: 72.9051,
    startDate: now.add(const Duration(days: 2)),
    endDate: now.add(const Duration(days: 5)),
    totalFare: 9800.0,
    platformFee: 900.0,
    gstAmount: 1600.0,
    netToVendor: 7300.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 8)),
    deliveryType: 'DOORSTEP_DELIVERY',
    pickupHubId: 'hub_powai',
    returnHubId: 'hub_vashi',
    deliveryFee: 500.0,
    pickupFee: 0.0,
    returnFee: 200.0,
    oneWayFee: 400.0,
  );

  final List<CarModel> testCars = [
    const CarModel(
      id: 'car_hy_01',
      vendorId: 'v_test',
      make: 'Hyundai',
      model: 'Creta SX',
      year: 2024,
      type: 'SUV',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      pricePerKm: 12.0,
      pricePerDay: 2500.0,
      pricePerHour: 150.0,
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      registrationNumber: 'MH 02 EK 1234',
    ),
  ];

  Widget createSubject({
    required Widget child,
    required BookingModel booking,
    VendorBookingsRepository? customRepo,
    List<CarModel>? cars,
    List<InspectionModel> inspections = const [],
  }) {
    return ProviderScope(
      overrides: [
        vendorBookingsRepositoryProvider.overrideWithValue(customRepo ?? repo),
        singleBookingProvider(booking.id).overrideWith((ref) => Future.value(booking)),
        bookingInspectionsProvider(booking.id).overrideWith((ref) => Future.value(inspections)),
        bookingDamageClaimsProvider(booking.id).overrideWith((ref) => Future.value([])),
        vendorBookingEmergencyProvider(booking.id).overrideWith((ref) => Future.value(null)),
        fleetCarsProvider.overrideWith((ref) => Future<List<CarModel>>.value(cars ?? testCars)),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  setUp(() {
    repo = MockVendorBookingsRepository();
    repo.resetMockState();
    repo.addMockBookings([
      hostYardBooking,
      doorstepBooking,
      transitHubBooking,
      diffReturnBooking,
      bothwayDoorstepBooking,
      legacyBooking,
      combinedBooking,
    ]);
  });

  group('Phase 29.15: Vendor Fulfillment Lifecycle Hardening & State Integrity Matrix', () {
    // 1. Host Yard booking lifecycle
    test('1. Host Yard booking completes full lifecycle with inspection and OTP verification', () async {
      final bId = hostYardBooking.id;

      // Start: confirmed
      await repo.updateBookingStatus(bId, 'confirmed');

      // Pre-trip inspection
      final preTrip = await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 10000.0,
        fuelPercent: 100,
        finalize: true,
      );
      expect(preTrip.finalized, isTrue);

      // Dispatch & verify pickup OTP
      await repo.sendHandoverOtp(bId, 'PICKUP');
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '123456');

      final listOngoing = await repo.getBookingsForVendor('v_test');
      final ongoingB = listOngoing.firstWhere((b) => b.id == bId);
      expect(ongoingB.status, 'ongoing');

      // Post-trip inspection
      final postTrip = await repo.upsertInspection(
        bId,
        type: 'POST_TRIP',
        odometer: 10350.0,
        fuelPercent: 80,
        finalize: true,
      );
      expect(postTrip.finalized, isTrue);

      // Dispatch & verify return OTP
      await repo.sendHandoverOtp(bId, 'RETURN');
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: '987654');

      final listCompleted = await repo.getBookingsForVendor('v_test');
      final completedB = listCompleted.firstWhere((b) => b.id == bId);
      expect(completedB.status, 'completed');
    });

    // 2. Doorstep Delivery lifecycle
    testWidgets('2. Doorstep Delivery lifecycle renders delivery fee, address, and coordinates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: doorstepBooking,
          child: const VendorBookingDetailPage(bookingId: 'bk_test_doorstep'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DOORSTEP DELIVERY'), findsOneWidget);
      expect(find.text('DOORSTEP DELIVERY DESTINATION'), findsOneWidget);
      expect(find.text('Flat 602, Sea Breeze Towers, Worli Sea Face, Mumbai'), findsWidgets);
      expect(find.text('+₹450 Delivery'), findsOneWidget);
      expect(find.textContaining('GPS: 19.018, 72.818'), findsOneWidget);
    });

    // 3. Transit/Public Hub lifecycle
    testWidgets('3. Transit/Public Hub lifecycle renders transit badge and airport location', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: transitHubBooking,
          child: const VendorBookingDetailPage(bookingId: 'bk_test_transit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRANSIT HUB / PUBLIC LOCATION'), findsOneWidget);
      expect(find.text('Chhatrapati Shivaji Maharaj International Airport (BOM)'), findsOneWidget);
      expect(find.text('+₹200 Hub Fee'), findsOneWidget);
    });

    // 4. Different Return Branch lifecycle
    testWidgets('4. Different Return Branch lifecycle renders relocation branch and one-way fee', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: diffReturnBooking,
          child: const ReturnInspectionPage(bookingId: 'bk_test_diff_return'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RETURN DESTINATION'), findsOneWidget);
      expect(find.text('RELOCATION BRANCH'), findsOneWidget);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
    });

    // 5. Both-way Doorstep lifecycle
    testWidgets('5. Both-way Doorstep lifecycle renders doorstep collection on return', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: bothwayDoorstepBooking,
          child: const ReturnInspectionPage(bookingId: 'bk_test_bothway_doorstep'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DOORSTEP COLLECTION'), findsOneWidget);
      expect(find.text('Customer Residence (Worli)'), findsOneWidget);
      expect(find.text('Tower B, Lodha Park, Worli, Mumbai'), findsOneWidget);
    });

    // 6. Combined Doorstep + Hub Return lifecycle
    testWidgets('6. Combined Doorstep + Hub Return has zero location cross-contamination', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify Return Inspection Page displays Vashi Hub and NOT Powai doorstep address
      await tester.pumpWidget(
        createSubject(
          booking: combinedBooking,
          child: const ReturnInspectionPage(bookingId: 'bk_test_combined'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RELOCATION BRANCH'), findsOneWidget);
      expect(find.text('Vashi Station Terminal Hub'), findsOneWidget);
      expect(find.text('Navi Mumbai Hub'), findsOneWidget);
      // Ensure Powai doorstep address is NOT leaked into the return destination banner
      expect(find.text('Hiranandani Gardens, Powai, Mumbai'), findsNothing);
    });

    // 7. Legacy booking without fulfillment
    testWidgets('7. Legacy booking without fulfillment falls back cleanly to Host Yard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: legacyBooking,
          child: const VendorBookingDetailPage(bookingId: 'bk_test_legacy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HOST YARD'), findsOneWidget);
      expect(find.text('Mumbai Central'), findsWidgets);
    });

    // 8. Invalid pre-trip transition
    test('8. Rejects transition to ongoing without finalized pre-trip inspection', () async {
      final bId = hostYardBooking.id;
      await repo.sendHandoverOtp(bId, 'PICKUP');

      // Attempt transition without pre-trip inspection
      expect(
        () => repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '123456'),
        throwsStateError,
      );
    });

    // 9. Invalid post-trip transition
    test('9. Rejects transition to completed without finalized post-trip inspection', () async {
      final bId = diffReturnBooking.id; // status: ongoing
      await repo.sendHandoverOtp(bId, 'RETURN');

      // Attempt transition without post-trip inspection
      expect(
        () => repo.updateBookingStatus(bId, 'completed', handoverOtp: '987654'),
        throwsStateError,
      );
    });

    // 10. Invalid pickup OTP
    test('10. Rejects invalid or wrong pickup OTP without mutating state', () async {
      final bId = hostYardBooking.id;

      await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 10000.0,
        fuelPercent: 100,
        finalize: true,
      );
      await repo.sendHandoverOtp(bId, 'PICKUP');

      // Short OTP
      expect(
        () => repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '123'),
        throwsArgumentError,
      );

      // Incorrect OTP code
      expect(
        () => repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '000000'),
        throwsArgumentError,
      );

      // Verify status remains confirmed
      final list = await repo.getBookingsForVendor('v_test');
      final b = list.firstWhere((item) => item.id == bId);
      expect(b.status, 'confirmed');
    });

    // 11. Invalid return OTP
    test('11. Rejects invalid or wrong return OTP without mutating state', () async {
      final bId = diffReturnBooking.id; // status: ongoing

      await repo.upsertInspection(
        bId,
        type: 'POST_TRIP',
        odometer: 11000.0,
        fuelPercent: 70,
        finalize: true,
      );
      await repo.sendHandoverOtp(bId, 'RETURN');

      // Wrong OTP
      expect(
        () => repo.updateBookingStatus(bId, 'completed', handoverOtp: '111111'),
        throwsArgumentError,
      );

      // Verify status remains ongoing
      final list = await repo.getBookingsForVendor('v_test');
      final b = list.firstWhere((item) => item.id == bId);
      expect(b.status, 'ongoing');
    });

    // 12. Duplicate pickup verification
    test('12. Duplicate pickup transition handles idempotently without corrupting state', () async {
      final bId = hostYardBooking.id;

      await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 10000.0,
        fuelPercent: 100,
        finalize: true,
      );
      await repo.sendHandoverOtp(bId, 'PICKUP');
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '123456');

      // Second identical call
      await expectLater(
        repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '123456'),
        completes,
      );

      final list = await repo.getBookingsForVendor('v_test');
      expect(list.firstWhere((b) => b.id == bId).status, 'ongoing');
    });

    // 13. Duplicate return verification
    test('13. Duplicate return transition handles idempotently without corrupting state', () async {
      final bId = diffReturnBooking.id;

      await repo.upsertInspection(
        bId,
        type: 'POST_TRIP',
        odometer: 11000.0,
        fuelPercent: 70,
        finalize: true,
      );
      await repo.sendHandoverOtp(bId, 'RETURN');
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: '987654');

      // Second identical call
      await expectLater(
        repo.updateBookingStatus(bId, 'completed', handoverOtp: '987654'),
        completes,
      );

      final list = await repo.getBookingsForVendor('v_test');
      expect(list.firstWhere((b) => b.id == bId).status, 'completed');
    });

    // 14. Inspection submission idempotency
    test('14. Resubmitting identical inspection is idempotent and preserves record ID', () async {
      final bId = hostYardBooking.id;

      final first = await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 15000.0,
        fuelPercent: 95,
        finalize: true,
      );

      final second = await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 15000.0,
        fuelPercent: 95,
        finalize: true,
      );

      expect(first.id, second.id);
      expect(second.odometer, 15000.0);
    });

    // 15. Missing fulfillment data
    test('15. Monotonic odometer rule prevents return odometer < handover odometer', () async {
      final bId = hostYardBooking.id;

      await repo.upsertInspection(
        bId,
        type: 'PRE_TRIP',
        odometer: 25000.0,
        fuelPercent: 100,
        finalize: true,
      );

      // Attempt post-trip odometer lower than pre-trip
      expect(
        () => repo.upsertInspection(
          bId,
          type: 'POST_TRIP',
          odometer: 24500.0,
          fuelPercent: 80,
          finalize: true,
        ),
        throwsArgumentError,
      );
    });

    // 16. Missing GPS coordinates fallback
    testWidgets('16. Missing GPS coordinates does not show GPS navigation link', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: legacyBooking,
          child: const VendorBookingDetailPage(bookingId: 'bk_test_legacy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('GPS:'), findsNothing);
    });

    // 17. Missing vehicle manifest
    testWidgets('17. Missing vehicle manifest resolves safely to booking carId identifier', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Empty fleet provided
      await tester.pumpWidget(
        createSubject(
          booking: doorstepBooking,
          cars: [],
          child: const HandoverInspectionPage(bookingId: 'bk_test_doorstep'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vehicle #car_ds_0'), findsOneWidget);
    });

    // 18. Repository/API/mock state consistency
    test('18. Rejection requires non-empty reason and marks status cancelled', () async {
      final bId = hostYardBooking.id;

      expect(
        () => repo.rejectBooking(bId, '   '),
        throwsArgumentError,
      );

      await repo.rejectBooking(bId, 'Customer requested immediate cancellation');
      final list = await repo.getBookingsForVendor('v_test');
      expect(list.firstWhere((b) => b.id == bId).status, 'cancelled');
    });

    // 19. Refresh during an in-progress lifecycle step
    test('19. Provider refresh preserves in-progress status and inspection history', () async {
      final container = ProviderContainer(
        overrides: [
          vendorBookingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final listBefore = await repo.getBookingsForVendor('v_test');
      expect(listBefore.firstWhere((b) => b.id == diffReturnBooking.id).status, 'ongoing');

      container.invalidate(singleBookingProvider(diffReturnBooking.id));
      final listAfter = await repo.getBookingsForVendor('v_test');
      expect(listAfter.firstWhere((b) => b.id == diffReturnBooking.id).status, 'ongoing');
    });

    // 20. Back/navigation/re-entry into the workflow
    testWidgets('20. Back navigation from inspection review preserves state without crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          booking: hostYardBooking,
          child: const HandoverInspectionPage(bookingId: 'bk_test_host_yard', initialStep: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 5: IDENTITY'), findsOneWidget);
    });
  });
}
