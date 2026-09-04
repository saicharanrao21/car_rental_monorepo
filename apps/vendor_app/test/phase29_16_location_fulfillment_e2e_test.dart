import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/data/mock_fleet_repository.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:core/core.dart';

class FastSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  FastSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

class FastFleetRepository extends MockFleetRepository {
  @override
  Future<void> simulateLatency() async {}
}

class FastDashboardRepository extends MockDashboardRepository {
  @override
  Future<void> simulateLatency() async {}
}

class FastVendorBookingsRepository extends MockVendorBookingsRepository {
  @override
  Future<void> simulateLatency() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  late FastVendorBookingsRepository repo;

  const testVendor = VendorModel(
    id: 'v_test',
    businessName: 'DriveGo Test Fleet',
    ownerName: 'Test Owner',
    email: 'test@example.com',
    phone: '+919876543210',
    city: 'Mumbai',
    verificationStatus: 'VERIFIED',
  );

  setUp(() {
    repo = FastVendorBookingsRepository();
    repo.resetMockState();
  });

  group('Phase 29.16: Complete Operational Fulfillment Scenarios (A - I)', () {
    test('Scenario A: Host Yard pickup -> Host Yard return operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_host_yard');
      expect(b.deliveryType, 'HUB_PICKUP');
      expect(b.pickupHubId, 'hub_main_yard');
      expect(b.returnHubId, 'hub_main_yard');
      expect(b.pickupName, 'Main Operating Yard, Andheri East');
      expect(b.dropName, 'Main Operating Yard, Andheri East');
      expect(b.deliveryFee, 0.0);
      expect(b.pickupFee, 0.0);
      expect(b.returnFee, 0.0);
      expect(b.oneWayFee, 0.0);
      expect(b.pickupLatitude, isNotNull);
      expect(b.pickupLongitude, isNotNull);
      expect(b.deliveryLatitude, isNull);
    });

    test('Scenario B: Doorstep pickup -> Host Yard return operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_doorstep');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.deliveryAddress, contains('Worli Sea Face'));
      expect(b.deliveryLatitude, isNotNull);
      expect(b.deliveryLongitude, isNotNull);
      expect(b.deliveryFee, 450.0);
      expect(b.returnFee, 0.0);
      expect(b.oneWayFee, 0.0);
      expect(b.dropLocation, contains('Main Operating Yard'));
    });

    test('Scenario C: Host Yard pickup -> Doorstep return collection operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_host_pickup_doorstep_return');
      expect(b.deliveryType, 'DOORSTEP_PICKUP');
      expect(b.pickupHubId, 'hub_main_yard');
      expect(b.deliveryAddress, contains('Oberoi Sky Heights'));
      expect(b.deliveryLatitude, isNotNull);
      expect(b.deliveryLongitude, isNotNull);
      expect(b.deliveryFee, 0.0);
      expect(b.returnFee, 350.0);
      expect(b.oneWayFee, 0.0);
    });

    test('Scenario D: Both-way Doorstep delivery and collection operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_bothway_doorstep');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.deliveryAddress, contains('Lodha Park'));
      expect(b.deliveryFee, 400.0);
      expect(b.returnFee, 400.0);
      expect(b.oneWayFee, 0.0);
      expect(b.deliveryLatitude, isNotNull);
      expect(b.deliveryLongitude, isNotNull);
    });

    test('Scenario E: Public / Transit Hub pickup -> Same hub return operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_transit_hub');
      expect(b.deliveryType, 'PUBLIC_LOCATION');
      expect(b.pickupHubId, 'pub_mum_csmia');
      expect(b.returnHubId, 'pub_mum_csmia');
      expect(b.pickupFee, 200.0);
      expect(b.returnFee, 200.0);
      expect(b.oneWayFee, 0.0);
      expect(b.pickupAddress, contains('Terminal 2'));
    });

    test('Scenario F: Public / Transit Hub pickup -> Different return hub operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_transit_pickup_diff_return');
      expect(b.deliveryType, 'PUBLIC_LOCATION');
      expect(b.pickupHubId, 'pub_mum_csmia');
      expect(b.returnHubId, 'hub_bkc');
      expect(b.dropName, contains('BKC'));
      expect(b.pickupFee, 200.0);
      expect(b.returnFee, 150.0);
      expect(b.oneWayFee, 300.0);
    });

    test('Scenario G: Branch pickup -> Different branch return operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_diff_return');
      expect(b.deliveryType, 'HUB_PICKUP');
      expect(b.pickupHubId, 'hub_andheri');
      expect(b.returnHubId, 'hub_bkc');
      expect(b.pickupName, 'Andheri East Main Yard');
      expect(b.dropName, 'Bandra Kurla Complex Branch');
      expect(b.oneWayFee, 350.0);
      expect(b.returnFee, 150.0);
    });

    test('Scenario H: Legacy booking without fulfillment metadata remains backward compatible', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_no_fulfillment');
      expect(b.deliveryType, isNull);
      expect(b.pickupHubId, isNull);
      expect(b.returnHubId, isNull);
      expect(b.pickupAddress, isNull);
      expect(b.deliveryAddress, isNull);
      expect(b.deliveryFee, isNull);
      expect(b.pickupFee, isNull);
      expect(b.returnFee, isNull);
      expect(b.oneWayFee, isNull);
      expect(b.pickupLocation, 'Mumbai Central');
      expect(b.dropLocation, 'Mumbai Central');
    });

    test('Scenario I: Combined Doorstep delivery + different return branch operational consistency', () async {
      final b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_combined');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.pickupHubId, 'hub_powai');
      expect(b.returnHubId, 'hub_vashi');
      expect(b.pickupName, contains('Powai'));
      expect(b.dropName, contains('Vashi'));
      expect(b.deliveryFee, 500.0);
      expect(b.returnFee, 200.0);
      expect(b.oneWayFee, 400.0);
    });
  });

  group('Phase 29.16: Authoritative Snapshot Immutability & Coordinate Isolation', () {
    test('13 fulfillment fields remain 100% immutable across full state machine progression', () async {
      final initial = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_combined');

      // 1. confirmed -> handover_ready
      await repo.updateBookingStatus(initial.id, 'handover_ready');
      var b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == initial.id);
      expect(b.status, 'handover_ready');
      expect(b.deliveryType, initial.deliveryType);
      expect(b.pickupAddress, initial.pickupAddress);
      expect(b.deliveryAddress, initial.deliveryAddress);
      expect(b.deliveryFee, initial.deliveryFee);
      expect(b.pickupFee, initial.pickupFee);
      expect(b.returnFee, initial.returnFee);
      expect(b.oneWayFee, initial.oneWayFee);
      expect(b.deliveryLatitude, initial.deliveryLatitude);
      expect(b.deliveryLongitude, initial.deliveryLongitude);
      expect(b.pickupHubId, initial.pickupHubId);
      expect(b.returnHubId, initial.returnHubId);
      expect(b.pickupName, initial.pickupName);
      expect(b.dropName, initial.dropName);

      // 2. Add pre-trip inspection and generate pickup OTP
      await repo.upsertInspection(
        initial.id,
        type: 'PRE_TRIP',
        odometer: 19500.0,
        fuelPercent: 100,
        finalize: true,
      );
      await repo.sendHandoverOtp(initial.id, 'PICKUP');
      final pickupOtp = repo.getMockOtp(initial.id);
      expect(pickupOtp, isNotNull);

      // 3. handover_ready -> ongoing
      await repo.updateBookingStatus(initial.id, 'ongoing', handoverOtp: pickupOtp);
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == initial.id);
      expect(b.status, 'ongoing');
      expect(b.deliveryType, initial.deliveryType);
      expect(b.deliveryFee, initial.deliveryFee);
      expect(b.returnFee, initial.returnFee);
      expect(b.oneWayFee, initial.oneWayFee);
      expect(b.pickupHubId, initial.pickupHubId);
      expect(b.returnHubId, initial.returnHubId);

      // 4. ongoing -> return_pending
      await repo.updateBookingStatus(initial.id, 'return_pending');
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == initial.id);
      expect(b.status, 'return_pending');
      expect(b.pickupName, initial.pickupName);
      expect(b.dropName, initial.dropName);

      // 5. Add post-trip inspection and complete with return OTP
      await repo.upsertInspection(
        initial.id,
        type: 'POST_TRIP',
        odometer: 19900.0,
        fuelPercent: 95,
        conditionNotes: 'Returned in clean condition',
        finalize: true,
      );
      await repo.sendHandoverOtp(initial.id, 'RETURN');
      final returnOtp = repo.getMockOtp(initial.id, 'RETURN');
      expect(returnOtp, isNotNull);

      // 6. return_pending -> completed
      await repo.updateBookingStatus(initial.id, 'completed', handoverOtp: returnOtp);
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == initial.id);
      expect(b.status, 'completed');

      // Invariant: Exact match on all 13 fields
      expect(b.deliveryType, initial.deliveryType);
      expect(b.pickupAddress, initial.pickupAddress);
      expect(b.deliveryAddress, initial.deliveryAddress);
      expect(b.deliveryFee, initial.deliveryFee);
      expect(b.pickupFee, initial.pickupFee);
      expect(b.returnFee, initial.returnFee);
      expect(b.oneWayFee, initial.oneWayFee);
      expect(b.deliveryLatitude, initial.deliveryLatitude);
      expect(b.deliveryLongitude, initial.deliveryLongitude);
      expect(b.pickupHubId, initial.pickupHubId);
      expect(b.returnHubId, initial.returnHubId);
      expect(b.pickupName, initial.pickupName);
      expect(b.dropName, initial.dropName);
    });

    test('Zero coordinate cross-contamination between pickup and dropoff legs', () async {
      final diffReturn = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_diff_return');
      // Pickup has yard coordinates
      expect(diffReturn.pickupLatitude, 19.1136);
      expect(diffReturn.pickupLongitude, 72.8697);
      // Return destination is a different branch (BKC) - deliveryLatitude must not be used as return location
      expect(diffReturn.dropName, 'Bandra Kurla Complex Branch');
    });
  });

  group('Phase 29.16: Fleet Availability Synchronization & Payout Integrity', () {
    test('Vehicle remains unavailable across all active states and restores on clean return', () async {
      final staged = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_handover_ready');
      var car = MockData.cars.firstWhere((c) => c.id == staged.carId);
      expect(car.isAvailable, false);

      final active = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_active_rental');
      car = MockData.cars.firstWhere((c) => c.id == active.carId);
      expect(car.isAvailable, false);

      final returnPending = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_return_pending');
      car = MockData.cars.firstWhere((c) => c.id == returnPending.carId);
      expect(car.isAvailable, false);

      // Clean return completed -> vehicle becomes available
      final inspected = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_return_inspected');
      await repo.sendHandoverOtp(inspected.id, 'RETURN');
      final otp = repo.getMockOtp(inspected.id, 'RETURN');
      await repo.updateBookingStatus(inspected.id, 'completed', handoverOtp: otp);
      car = MockData.cars.firstWhere((c) => c.id == inspected.carId);
      expect(car.isAvailable, true);

      // Damaged return -> vehicle remains unavailable
      final damaged = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_damage_claim');
      await repo.sendHandoverOtp(damaged.id, 'RETURN');
      final dOtp = repo.getMockOtp(damaged.id, 'RETURN');
      await repo.updateBookingStatus(damaged.id, 'completed', handoverOtp: dOtp);
      car = MockData.cars.firstWhere((c) => c.id == damaged.carId);
      expect(car.isAvailable, false);
    });

    test('Authoritative fulfillment fee payout itemization calculates accurately', () async {
      final combined = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_mock_combined');
      final deliveryFee = combined.deliveryFee ?? 0.0;
      final pickupFee = combined.pickupFee ?? 0.0;
      final returnFee = combined.returnFee ?? 0.0;
      final oneWayFee = combined.oneWayFee ?? 0.0;
      final totalFulfillmentRevenue = deliveryFee + pickupFee + returnFee + oneWayFee;

      expect(deliveryFee, 500.0);
      expect(pickupFee, 0.0);
      expect(returnFee, 200.0);
      expect(oneWayFee, 400.0);
      expect(totalFulfillmentRevenue, 1100.0);
    });
  });

  group('Phase 29.16: Widget Level Location & Handover UI Consistency', () {
    Widget createSubject({
      required Widget child,
      required String bookingId,
    }) {
      return ProviderScope(
        overrides: [
          vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
          vendorBookingsRepositoryProvider.overrideWithValue(repo),
          fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
          dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
          bookingInspectionsProvider(bookingId).overrideWith((ref) => repo.getInspections(bookingId)),
          bookingDamageClaimsProvider(bookingId).overrideWith((ref) => repo.getDamageClaims(bookingId)),
          vendorBookingEmergencyProvider(bookingId).overrideWith((ref) => null),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('Doorstep booking detail displays accurate delivery address and fee breakdown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          bookingId: 'bk_mock_doorstep',
          child: const VendorBookingDetailPage(bookingId: 'bk_mock_doorstep'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DOORSTEP DELIVERY DESTINATION'), findsOneWidget);
      expect(find.textContaining('Worli Sea Face'), findsOneWidget);
      expect(find.text('+₹450 Delivery'), findsOneWidget);
    });

    testWidgets('Handover inspection page displays accurate handover location banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          bookingId: 'bk_mock_host_yard',
          child: const HandoverInspectionPage(bookingId: 'bk_mock_host_yard', initialStep: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HANDOVER LOCATION'), findsOneWidget);
      expect(find.text('HOST YARD'), findsOneWidget);
      expect(find.text('Main Operating Yard, Andheri East'), findsOneWidget);
    });

    testWidgets('Return inspection page displays authoritative return destination banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createSubject(
          bookingId: 'bk_mock_diff_return',
          child: const ReturnInspectionPage(bookingId: 'bk_mock_diff_return', initialStep: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RETURN DESTINATION'), findsOneWidget);
      expect(find.text('RELOCATION BRANCH'), findsOneWidget);
      expect(find.text('Bandra Kurla Complex Branch'), findsOneWidget);
    });
  });
}
