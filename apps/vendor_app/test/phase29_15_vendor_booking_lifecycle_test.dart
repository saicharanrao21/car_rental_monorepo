import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/data/mock_fleet_repository.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';

class FastSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  FastSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

class MockVendorBookingsNotifier extends VendorBookingsNotifier {
  final List<BookingModel> _items;
  MockVendorBookingsNotifier(this._items);

  @override
  Future<List<BookingModel>> build() async => _items;
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
  late FastVendorBookingsRepository repo;

  final now = DateTime.now();

  const testVendor = VendorModel(
    id: 'v_test',
    businessName: 'DriveGo Test Fleet',
    ownerName: 'Test Owner',
    email: 'test@example.com',
    phone: '+919876543210',
    city: 'Mumbai',
    verificationStatus: 'VERIFIED',
  );

  final baseHostYardBooking = BookingModel(
    id: 'bk_lifecycle_host_yard',
    customerId: 'cust_lc_01',
    vendorId: 'v_test',
    carId: 'car_lc_01',
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

  final combinedBooking = BookingModel(
    id: 'bk_lifecycle_combined',
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

  final legacyBooking = BookingModel(
    id: 'bk_lifecycle_legacy',
    customerId: 'cust_leg_06',
    vendorId: 'v_test',
    carId: 'car_leg_06',
    tripType: 'Local',
    pickupLocation: 'Mumbai Central',
    dropLocation: 'Mumbai Central',
    startDate: now.add(const Duration(hours: 2)),
    endDate: now.add(const Duration(days: 1)),
    totalFare: 2100.0,
    platformFee: 200.0,
    gstAmount: 340.0,
    netToVendor: 1900.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 6)),
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

  setUp(() {
    repo = FastVendorBookingsRepository();
    repo.resetMockState();
    // Ensure test cars exist in MockData.cars
    final testCars = [
      const CarModel(
        id: 'car_lc_01',
        vendorId: 'v_test',
        make: 'Hyundai',
        model: 'Creta',
        year: 2023,
        type: 'SUV',
        fuelType: 'Petrol',
        seating: 5,
        isAC: true,
        photos: [],
        pricePerKm: 16.0,
        pricePerDay: 2800.0,
        pricePerHour: 220.0,
        registrationNumber: 'MH 02 EE 9876',
        isAvailable: true,
      ),
      const CarModel(
        id: 'car_cb_07',
        vendorId: 'v_test',
        make: 'Kia',
        model: 'Seltos',
        year: 2023,
        type: 'SUV',
        fuelType: 'Diesel',
        seating: 5,
        isAC: true,
        photos: [],
        pricePerKm: 17.0,
        pricePerDay: 3000.0,
        pricePerHour: 240.0,
        registrationNumber: 'MH 02 KL 1122',
        isAvailable: true,
      ),
      const CarModel(
        id: 'car_leg_06',
        vendorId: 'v_test',
        make: 'Maruti Suzuki',
        model: 'Swift',
        year: 2022,
        type: 'Hatchback',
        fuelType: 'Petrol',
        seating: 5,
        isAC: true,
        photos: [],
        pricePerKm: 12.0,
        pricePerDay: 1800.0,
        pricePerHour: 150.0,
        registrationNumber: 'MH 01 SW 9988',
        isAvailable: true,
      ),
    ];
    for (final c in testCars) {
      final idx = MockData.cars.indexWhere((existing) => existing.id == c.id);
      if (idx != -1) {
        MockData.cars[idx] = c;
      } else {
        MockData.cars.add(c);
      }
    }
  });

  group('Phase 29.15: Operational State Machine Transitions (A - E)', () {
    test('A. Confirmed -> Handover Ready transition stages vehicle for handover', () async {
      repo.addMockBooking(baseHostYardBooking);

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'handover_ready');

      final list = await repo.getBookingsForVendor('v_test');
      final updated = list.firstWhere((b) => b.id == 'bk_lifecycle_host_yard');
      expect(updated.status, 'handover_ready');

      // Vehicle should be marked unavailable
      final car = MockData.cars.firstWhere((c) => c.id == 'car_lc_01');
      expect(car.isAvailable, false);
    });

    test('B. Handover Ready -> Ongoing enforces finalized pre-trip and 6-digit pickup OTP', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'handover_ready'));

      // Pre-trip inspection recorded
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        conditionNotes: 'All clear, clean vehicle',
        finalize: true,
      );

      // Verify OTP and transition to ongoing
      await repo.updateBookingStatus(
        'bk_lifecycle_host_yard',
        'ongoing',
        handoverOtp: '123456',
      );

      final list = await repo.getBookingsForVendor('v_test');
      final ongoingBooking = list.firstWhere((b) => b.id == 'bk_lifecycle_host_yard');
      expect(ongoingBooking.status, 'ongoing');

      final car = MockData.cars.firstWhere((c) => c.id == 'car_lc_01');
      expect(car.isAvailable, false);
    });

    test('C. Active Ongoing Rental -> Return Pending transition via initiateReturn', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'ongoing'));

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'return_pending');

      final list = await repo.getBookingsForVendor('v_test');
      final pendingReturn = list.firstWhere((b) => b.id == 'bk_lifecycle_host_yard');
      expect(pendingReturn.status, 'return_pending');

      final car = MockData.cars.firstWhere((c) => c.id == 'car_lc_01');
      expect(car.isAvailable, false);
    });

    test('D. Return Pending allows recording post-trip inspection with monotonic odometer', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'return_pending'));

      // Seed pre-trip inspection
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        finalize: true,
      );

      // Post-trip inspection
      final postTrip = await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'POST_TRIP',
        odometer: 15550.0,
        fuelPercent: 90,
        conditionNotes: 'Clean return, no new damage',
        finalize: true,
      );

      expect(postTrip.odometer, 15550.0);
      expect(postTrip.finalized, true);
    });

    test('E. Return Inspection -> Completed transition with return OTP completes booking', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'return_pending'));

      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        finalize: true,
      );

      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'POST_TRIP',
        odometer: 15550.0,
        fuelPercent: 90,
        conditionNotes: 'Clean return',
        finalize: true,
      );

      await repo.updateBookingStatus(
        'bk_lifecycle_host_yard',
        'completed',
        handoverOtp: '987654',
      );

      final list = await repo.getBookingsForVendor('v_test');
      final completed = list.firstWhere((b) => b.id == 'bk_lifecycle_host_yard');
      expect(completed.status, 'completed');

      // Vehicle returned clean -> restored to isAvailable = true
      final car = MockData.cars.firstWhere((c) => c.id == 'car_lc_01');
      expect(car.isAvailable, true);
    });
  });

  group('Phase 29.15: State Integrity & Invariant Enforcement (F - J)', () {
    test('F. Rejects invalid state transitions with StateError', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'pending'));

      // pending -> ongoing directly is invalid
      expect(
        () => repo.updateBookingStatus('bk_lifecycle_host_yard', 'ongoing', handoverOtp: '123456'),
        throwsA(isA<StateError>()),
      );

      // confirmed -> return_pending without ongoing is invalid
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'confirmed'));
      expect(
        () => repo.updateBookingStatus('bk_lifecycle_host_yard', 'return_pending'),
        throwsA(isA<StateError>()),
      );

      // completed -> ongoing is invalid
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'completed'));
      expect(
        () => repo.updateBookingStatus('bk_lifecycle_host_yard', 'ongoing', handoverOtp: '123456'),
        throwsA(isA<StateError>()),
      );
    });

    test('G. Duplicate transition protection is idempotent', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'confirmed'));

      // Repeating confirmed status is a no-op
      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'confirmed');
      final list = await repo.getBookingsForVendor('v_test');
      expect(list.firstWhere((b) => b.id == 'bk_lifecycle_host_yard').status, 'confirmed');
    });

    test('H. Fulfillment snapshot fields are 100% immutable across complete lifecycle', () async {
      repo.addMockBooking(combinedBooking);

      // 1. Mark handover_ready
      await repo.updateBookingStatus('bk_lifecycle_combined', 'handover_ready');
      var b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.deliveryFee, 500.0);
      expect(b.returnFee, 200.0);
      expect(b.oneWayFee, 400.0);
      expect(b.deliveryLatitude, 19.1197);
      expect(b.pickupName, 'Customer Doorstep (Powai)');
      expect(b.dropName, 'Vashi Station Terminal Hub');

      // 2. Start ongoing rental
      await repo.upsertInspection('bk_lifecycle_combined', type: 'PRE_TRIP', odometer: 20000.0, fuelPercent: 100, finalize: true);
      await repo.updateBookingStatus('bk_lifecycle_combined', 'ongoing', handoverOtp: '123456');
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');
      expect(b.status, 'ongoing');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.deliveryFee, 500.0);
      expect(b.oneWayFee, 400.0);
      expect(b.dropName, 'Vashi Station Terminal Hub');

      // 3. Initiate return
      await repo.updateBookingStatus('bk_lifecycle_combined', 'return_pending');
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');
      expect(b.status, 'return_pending');
      expect(b.deliveryFee, 500.0);
      expect(b.oneWayFee, 400.0);

      // 4. Complete rental
      await repo.upsertInspection('bk_lifecycle_combined', type: 'POST_TRIP', odometer: 20400.0, fuelPercent: 95, finalize: true);
      await repo.updateBookingStatus('bk_lifecycle_combined', 'completed', handoverOtp: '987654');
      b = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');
      expect(b.status, 'completed');
      expect(b.deliveryType, 'DOORSTEP_DELIVERY');
      expect(b.pickupAddress, 'Hiranandani Gardens, Powai, Mumbai');
      expect(b.dropName, 'Vashi Station Terminal Hub');
      expect(b.dropLocation, 'Navi Mumbai Hub');
      expect(b.totalFare, 9800.0);
    });

    test('I. Handover location and GPS coordinates remain authoritative throughout', () async {
      repo.addMockBooking(combinedBooking);
      final booking = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');

      expect(booking.pickupAddress, 'Hiranandani Gardens, Powai, Mumbai');
      expect(booking.pickupLatitude, 19.1197);
      expect(booking.pickupLongitude, 72.9051);
    });

    test('J. Return destination decouples from pickup doorstep address', () async {
      repo.addMockBooking(combinedBooking);
      final booking = (await repo.getBookingsForVendor('v_test')).firstWhere((x) => x.id == 'bk_lifecycle_combined');

      // Return destination is Vashi Station Terminal Hub, NOT Powai doorstep
      expect(booking.dropName, 'Vashi Station Terminal Hub');
      expect(booking.dropLocation, 'Navi Mumbai Hub');
      expect(booking.oneWayFee, 400.0);
    });
  });

  group('Phase 29.15: Vehicle Operational State Synchronization (K)', () {
    test('K1. Vehicle availability is false during active rental and return pending', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'confirmed'));

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'handover_ready');
      expect(MockData.cars.firstWhere((c) => c.id == 'car_lc_01').isAvailable, false);

      await repo.upsertInspection('bk_lifecycle_host_yard', type: 'PRE_TRIP', odometer: 15200.0, fuelPercent: 100, finalize: true);
      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'ongoing', handoverOtp: '123456');
      expect(MockData.cars.firstWhere((c) => c.id == 'car_lc_01').isAvailable, false);

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'return_pending');
      expect(MockData.cars.firstWhere((c) => c.id == 'car_lc_01').isAvailable, false);
    });

    test('K2. Vehicle remains unavailable after completion if damage is recorded', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'return_pending'));

      await repo.upsertInspection('bk_lifecycle_host_yard', type: 'PRE_TRIP', odometer: 15200.0, fuelPercent: 100, finalize: true);
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'POST_TRIP',
        odometer: 15550.0,
        fuelPercent: 85,
        conditionNotes: 'Deep dent and scratch on front bumper',
        damagePhotos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
        finalize: true,
      );

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'completed', handoverOtp: '987654');

      // Due to damage in post-trip inspection, vehicle remains unavailable for maintenance
      expect(MockData.cars.firstWhere((c) => c.id == 'car_lc_01').isAvailable, false);
    });

    test('K3. Vehicle is restored to available after completion when returned in clean condition', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'return_pending'));

      await repo.upsertInspection('bk_lifecycle_host_yard', type: 'PRE_TRIP', odometer: 15200.0, fuelPercent: 100, finalize: true);
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'POST_TRIP',
        odometer: 15550.0,
        fuelPercent: 95,
        conditionNotes: 'Vehicle returned in clean condition. No new damage.',
        damagePhotos: [],
        finalize: true,
      );

      await repo.updateBookingStatus('bk_lifecycle_host_yard', 'completed', handoverOtp: '987654');

      // Vehicle returned clean -> restored to isAvailable = true
      expect(MockData.cars.firstWhere((c) => c.id == 'car_lc_01').isAvailable, true);
    });
  });

  group('Phase 29.15: Provider and Error Integrity (L - M)', () {
    test('L. Provider mutations properly update state and refresh dependent caches', () async {
      final container = ProviderContainer(
        overrides: [
          vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
          vendorBookingsRepositoryProvider.overrideWithValue(repo),
          fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
          dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(singleBookingProvider('bk_lifecycle_host_yard'), (_, __) {});
      addTearDown(sub.close);

      repo.addMockBooking(baseHostYardBooking);

      // markHandoverReady via notifier
      final readyOk = await container
          .read(vendorBookingsProvider.notifier)
          .markHandoverReady('bk_lifecycle_host_yard');
      expect(readyOk, true);

      var updatedBooking = await container.read(singleBookingProvider('bk_lifecycle_host_yard').future);
      expect(updatedBooking?.status, 'handover_ready');

      var repoList = await repo.getBookingsForVendor('v_test');
      expect(repoList.firstWhere((b) => b.id == 'bk_lifecycle_host_yard').status, 'handover_ready');

      // initiateReturn via notifier
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'ongoing'));
      final returnOk = await container
          .read(vendorBookingsProvider.notifier)
          .initiateReturn('bk_lifecycle_host_yard');
      expect(returnOk, true);

      updatedBooking = await container.read(singleBookingProvider('bk_lifecycle_host_yard').future);
      expect(updatedBooking?.status, 'return_pending');

      repoList = await repo.getBookingsForVendor('v_test');
      expect(repoList.firstWhere((b) => b.id == 'bk_lifecycle_host_yard').status, 'return_pending');
    });

    test('M. Error recovery leaves booking in current state when OTP verification fails', () async {
      repo.addMockBooking(baseHostYardBooking.copyWith(status: 'handover_ready'));
      await repo.upsertInspection('bk_lifecycle_host_yard', type: 'PRE_TRIP', odometer: 15200.0, fuelPercent: 100, finalize: true);

      // Invalid OTP
      expect(
        () => repo.updateBookingStatus('bk_lifecycle_host_yard', 'ongoing', handoverOtp: '000000'),
        throwsA(isA<ArgumentError>()),
      );

      // Booking remains in handover_ready
      final booking = (await repo.getBookingsForVendor('v_test')).firstWhere((b) => b.id == 'bk_lifecycle_host_yard');
      expect(booking.status, 'handover_ready');
    });
  });

  group('Phase 29.15: Fulfillment Scenarios & Legacy Compatibility (N - O)', () {
    test('N. Legacy booking without fulfillment fields navigates operational lifecycle cleanly', () async {
      repo.addMockBooking(legacyBooking);

      await repo.updateBookingStatus('bk_lifecycle_legacy', 'handover_ready');
      expect((await repo.getBookingsForVendor('v_test')).firstWhere((b) => b.id == 'bk_lifecycle_legacy').status, 'handover_ready');

      await repo.upsertInspection('bk_lifecycle_legacy', type: 'PRE_TRIP', odometer: 45000.0, fuelPercent: 100, finalize: true);
      await repo.updateBookingStatus('bk_lifecycle_legacy', 'ongoing', handoverOtp: '123456');
      expect((await repo.getBookingsForVendor('v_test')).firstWhere((b) => b.id == 'bk_lifecycle_legacy').status, 'ongoing');

      await repo.updateBookingStatus('bk_lifecycle_legacy', 'return_pending');
      expect((await repo.getBookingsForVendor('v_test')).firstWhere((b) => b.id == 'bk_lifecycle_legacy').status, 'return_pending');

      await repo.upsertInspection('bk_lifecycle_legacy', type: 'POST_TRIP', odometer: 45150.0, fuelPercent: 90, finalize: true);
      await repo.updateBookingStatus('bk_lifecycle_legacy', 'completed', handoverOtp: '987654');
      expect((await repo.getBookingsForVendor('v_test')).firstWhere((b) => b.id == 'bk_lifecycle_legacy').status, 'completed');
    });

    test('O. Default mock repository contains all 12 operational scenarios', () async {
      final bookings = await repo.getBookingsForVendor('');
      final ids = bookings.map((b) => b.id).toSet();

      expect(ids.contains('bk_mock_host_yard'), true);
      expect(ids.contains('bk_mock_doorstep'), true);
      expect(ids.contains('bk_mock_transit_hub'), true);
      expect(ids.contains('bk_mock_diff_return'), true);
      expect(ids.contains('bk_mock_bothway_doorstep'), true);
      expect(ids.contains('bk_mock_no_fulfillment'), true);
      expect(ids.contains('bk_mock_combined'), true);
      expect(ids.contains('bk_mock_handover_ready'), true);
      expect(ids.contains('bk_mock_active_rental'), true);
      expect(ids.contains('bk_mock_return_pending'), true);
      expect(ids.contains('bk_mock_return_inspected'), true);
      expect(ids.contains('bk_mock_damage_claim'), true);
    });
  });

  group('Phase 29.15: Widget Level Operational UI Verification', () {
    testWidgets('Renders Handover Ready banner and staging card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stagedBooking = baseHostYardBooking.copyWith(status: 'handover_ready');
      repo.addMockBooking(stagedBooking);
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        finalize: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
            vendorBookingsRepositoryProvider.overrideWithValue(repo),
            fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
            dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
            bookingInspectionsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getInspections('bk_lifecycle_host_yard')),
            bookingDamageClaimsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getDamageClaims('bk_lifecycle_host_yard')),
            vendorBookingEmergencyProvider('bk_lifecycle_host_yard').overrideWith((ref) => null),
            singleBookingProvider('bk_lifecycle_host_yard').overrideWith((ref) => Future.value(stagedBooking)),
          ],
          child: const MaterialApp(
            home: VendorBookingDetailPage(bookingId: 'bk_lifecycle_host_yard'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('HANDOVER READY / STAGED'), findsOneWidget);
      expect(find.text('Verify OTP & Start Trip'), findsOneWidget);
    });

    testWidgets('Renders Active Rental operations card and Initiate Return button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final activeBooking = baseHostYardBooking.copyWith(status: 'ongoing');
      repo.addMockBooking(activeBooking);
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        finalize: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
            vendorBookingsRepositoryProvider.overrideWithValue(repo),
            fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
            dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
            bookingInspectionsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getInspections('bk_lifecycle_host_yard')),
            bookingDamageClaimsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getDamageClaims('bk_lifecycle_host_yard')),
            vendorBookingEmergencyProvider('bk_lifecycle_host_yard').overrideWith((ref) => null),
            singleBookingProvider('bk_lifecycle_host_yard').overrideWith((ref) => Future.value(activeBooking)),
          ],
          child: const MaterialApp(
            home: VendorBookingDetailPage(bookingId: 'bk_lifecycle_host_yard'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Active Rental Operations'), findsOneWidget);
      expect(find.text('TRIP IN PROGRESS (ACTIVE RENTAL)'), findsOneWidget);
      expect(find.text('Initiate Vehicle Return'), findsOneWidget);
    });

    testWidgets('Renders Return Pending banner and Post-Trip inspection prompt', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final returnPendingBooking = baseHostYardBooking.copyWith(status: 'return_pending');
      repo.addMockBooking(returnPendingBooking);
      await repo.upsertInspection(
        'bk_lifecycle_host_yard',
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        finalize: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
            vendorBookingsRepositoryProvider.overrideWithValue(repo),
            fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
            dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
            bookingInspectionsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getInspections('bk_lifecycle_host_yard')),
            bookingDamageClaimsProvider('bk_lifecycle_host_yard').overrideWith((ref) => repo.getDamageClaims('bk_lifecycle_host_yard')),
            vendorBookingEmergencyProvider('bk_lifecycle_host_yard').overrideWith((ref) => null),
            singleBookingProvider('bk_lifecycle_host_yard').overrideWith((ref) => Future.value(returnPendingBooking)),
          ],
          child: const MaterialApp(
            home: VendorBookingDetailPage(bookingId: 'bk_lifecycle_host_yard'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vehicle Return & Handover Flow'), findsOneWidget);
      expect(find.text('Start 60s Return Inspection'), findsOneWidget);
    });
  });
}
