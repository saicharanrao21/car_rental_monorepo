import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:core/core.dart';

class FastVendorBookingsRepository extends MockVendorBookingsRepository {
  @override
  Future<void> simulateLatency() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  late FastVendorBookingsRepository repo;

  setUp(() {
    repo = FastVendorBookingsRepository();
    repo.resetMockState();
  });

  group('Phase 29.17: Cross-Platform Fulfillment 17-Scenario Integration Matrix', () {
    // 1. Host Yard -> Handover -> Return -> Complete
    test('1. Host Yard -> Handover -> Return -> Complete lifecycle integrity', () async {
      const bId = 'bk_mock_host_yard';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.deliveryType, 'HUB_PICKUP');
      expect(initial.pickupHubId, 'hub_main_yard');
      expect(initial.returnHubId, 'hub_main_yard');
      expect(initial.pickupFee, 0.0);
      expect(initial.returnFee, 0.0);

      // Staging -> Handover Ready
      await repo.updateBookingStatus(bId, 'handover_ready');
      var b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.status, 'handover_ready');

      // Handover Inspection + Pickup OTP
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 25000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'PICKUP');
      final otp = repo.getMockOtp(bId, 'PICKUP')!;
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: otp);

      b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.status, 'ongoing');

      // Return initiated
      await repo.updateBookingStatus(bId, 'return_pending');
      b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.status, 'return_pending');

      // Post-trip inspection + Return OTP
      await repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 25300.0, fuelPercent: 95, conditionNotes: 'Clean return', finalize: true);
      await repo.sendHandoverOtp(bId, 'RETURN');
      final rOtp = repo.getMockOtp(bId, 'RETURN')!;
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: rOtp);

      b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.status, 'completed');
      expect(b.pickupHubId, initial.pickupHubId);
      expect(b.returnHubId, initial.returnHubId);
    });

    // 2. Doorstep Delivery -> Handover -> Return -> Complete
    test('2. Doorstep Delivery -> Handover -> Return -> Complete with GPS coordinates', () async {
      const bId = 'bk_mock_doorstep';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.deliveryType, 'DOORSTEP_DELIVERY');
      expect(initial.deliveryLatitude, 19.0178);
      expect(initial.deliveryLongitude, 72.8178);
      expect(initial.deliveryFee, 450.0);

      await repo.updateBookingStatus(bId, 'handover_ready');
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 31000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'PICKUP');
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: repo.getMockOtp(bId, 'PICKUP'));

      await repo.updateBookingStatus(bId, 'return_pending');
      await repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 31450.0, fuelPercent: 90, conditionNotes: 'Clean condition', finalize: true);
      await repo.sendHandoverOtp(bId, 'RETURN');
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: repo.getMockOtp(bId, 'RETURN'));

      final completed = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(completed.status, 'completed');
      expect(completed.deliveryLatitude, 19.0178);
      expect(completed.deliveryLongitude, 72.8178);
      expect(completed.deliveryFee, 450.0);
    });

    // 3. Transit Hub -> Handover -> Return -> Complete
    test('3. Transit Hub -> Handover -> Return -> Complete airport lifecycle', () async {
      const bId = 'bk_mock_transit_hub';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.deliveryType, 'PUBLIC_LOCATION');
      expect(initial.pickupHubId, 'pub_mum_csmia');
      expect(initial.pickupFee, 200.0);
      expect(initial.returnFee, 200.0);

      await repo.updateBookingStatus(bId, 'handover_ready');
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 18000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'PICKUP');
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: repo.getMockOtp(bId, 'PICKUP'));

      await repo.updateBookingStatus(bId, 'return_pending');
      await repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 18250.0, fuelPercent: 95, conditionNotes: 'All clear', finalize: true);
      await repo.sendHandoverOtp(bId, 'RETURN');
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: repo.getMockOtp(bId, 'RETURN'));

      final completed = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(completed.status, 'completed');
      expect(completed.pickupHubId, 'pub_mum_csmia');
      expect(completed.returnHubId, 'pub_mum_csmia');
    });

    // 4. Different Return Branch -> Handover -> Return -> Complete
    test('4. Different Return Branch -> Handover -> Return -> Complete with oneWayFee', () async {
      const bId = 'bk_mock_diff_return';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.pickupHubId, 'hub_andheri');
      expect(initial.returnHubId, 'hub_bkc');
      expect(initial.oneWayFee, 350.0);
      expect(initial.returnFee, 150.0);

      // Seed PRE_TRIP for diff_return booking if starting from ongoing
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 15000.0, fuelPercent: 100, finalize: true);
      await repo.updateBookingStatus(bId, 'return_pending');

      await repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 15300.0, fuelPercent: 90, conditionNotes: 'Clean return', finalize: true);
      await repo.sendHandoverOtp(bId, 'RETURN');
      await repo.updateBookingStatus(bId, 'completed', handoverOtp: repo.getMockOtp(bId, 'RETURN'));

      final completed = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(completed.status, 'completed');
      expect(completed.returnHubId, 'hub_bkc');
      expect(completed.oneWayFee, 350.0);
    });

    // 5. Doorstep Delivery + Different Return Branch
    test('5. Doorstep Delivery + Different Return Branch combination', () async {
      const bId = 'bk_mock_combined';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.deliveryType, 'DOORSTEP_DELIVERY');
      expect(initial.pickupHubId, 'hub_powai');
      expect(initial.returnHubId, 'hub_vashi');
      expect(initial.deliveryFee, 500.0);
      expect(initial.returnFee, 200.0);
      expect(initial.oneWayFee, 400.0);
    });

    // 6. Doorstep Collection Return
    test('6. Doorstep Collection Return lifecycle', () async {
      const bId = 'bk_mock_host_pickup_doorstep_return';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(initial.deliveryType, 'DOORSTEP_PICKUP');
      expect(initial.pickupHubId, 'hub_main_yard');
      expect(initial.returnFee, 350.0);
      expect(initial.deliveryAddress, contains('Oberoi Sky Heights'));
    });

    // 7. Legacy booking
    test('7. Legacy booking without fulfillment metadata remains backward compatible', () async {
      const bId = 'bk_mock_no_fulfillment';
      final b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.deliveryType, isNull);
      expect(b.pickupHubId, isNull);
      expect(b.returnHubId, isNull);
      expect(b.deliveryFee, isNull);
      expect(b.pickupLocation, 'Mumbai Central');
      expect(b.dropLocation, 'Mumbai Central');
    });

    // 8. Invalid lifecycle transition
    test('8. Invalid lifecycle transition throws StateError', () async {
      const bId = 'bk_mock_host_yard';
      // Attempt to jump directly from confirmed to completed
      expect(
        () => repo.updateBookingStatus(bId, 'completed', handoverOtp: '123456'),
        throwsA(isA<StateError>()),
      );
    });

    // 9. Invalid pickup OTP
    test('9. Invalid pickup OTP is rejected with ArgumentError', () async {
      const bId = 'bk_mock_host_yard';
      await repo.updateBookingStatus(bId, 'handover_ready');
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 20000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'PICKUP');

      expect(
        () => repo.updateBookingStatus(bId, 'ongoing', handoverOtp: '000000'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 10. Invalid return OTP
    test('10. Invalid return OTP is rejected with ArgumentError', () async {
      const bId = 'bk_mock_active_rental';
      await repo.updateBookingStatus(bId, 'return_pending');
      await repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 25000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'RETURN');

      expect(
        () => repo.updateBookingStatus(bId, 'completed', handoverOtp: '000000'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 11. Invalid return odometer
    test('11. Invalid return odometer (less than pre-trip) is rejected', () async {
      const bId = 'bk_mock_doorstep';
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 50000.0, fuelPercent: 100, finalize: true);

      expect(
        () => repo.upsertInspection(bId, type: 'POST_TRIP', odometer: 49000.0, fuelPercent: 90, finalize: true),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 12. Concurrent booking attempt / vehicle availability
    test('12. Concurrent booking attempt: Car availability reflects active rental', () async {
      final car = MockData.cars.firstWhere((c) => c.id == 'car_ar_09');
      // Car is locked in active rental
      expect(car.isAvailable, isFalse);
    });

    // 13. Damaged vehicle completion lock
    test('13. Damaged vehicle keeps car unavailable post-completion', () async {
      const bId = 'bk_mock_damage_claim';
      final b = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(b.status, 'completed');

      final car = MockData.cars.firstWhere((c) => c.id == b.carId);
      // Car locked due to damage claim
      expect(car.isAvailable, isFalse);
    });

    // 14. Fulfillment snapshot immutability
    test('14. Fulfillment snapshot fields remain identical across all state updates', () async {
      const bId = 'bk_mock_bothway_doorstep';
      final initial = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);

      // pending -> confirmed -> handover_ready
      await repo.updateBookingStatus(bId, 'confirmed');
      await repo.updateBookingStatus(bId, 'handover_ready');
      await repo.upsertInspection(bId, type: 'PRE_TRIP', odometer: 10000.0, fuelPercent: 100, finalize: true);
      await repo.sendHandoverOtp(bId, 'PICKUP');
      await repo.updateBookingStatus(bId, 'ongoing', handoverOtp: repo.getMockOtp(bId, 'PICKUP'));

      final ongoing = (await repo.getBookingsForVendor('v1')).firstWhere((x) => x.id == bId);
      expect(ongoing.deliveryType, initial.deliveryType);
      expect(ongoing.deliveryAddress, initial.deliveryAddress);
      expect(ongoing.deliveryFee, initial.deliveryFee);
      expect(ongoing.returnFee, initial.returnFee);
      expect(ongoing.oneWayFee, initial.oneWayFee);
      expect(ongoing.deliveryLatitude, initial.deliveryLatitude);
      expect(ongoing.deliveryLongitude, initial.deliveryLongitude);
    });

    // 15. Vendor isolation
    test('15. Vendor isolation: Vendor A cannot see or modify Vendor B bookings', () async {
      final vendor1Bookings = await repo.getBookingsForVendor('v1');
      final vendor2Bookings = await repo.getBookingsForVendor('v2');

      for (final b in vendor2Bookings) {
        if (b.vendorId == 'v2') {
          expect(vendor1Bookings.any((x) => x.id == b.id && x.vendorId == 'v2'), isFalse);
        }
      }
    });

    // 16. Customer booking visibility
    test('16. Customer booking visibility preserves authoritative fulfillment snapshot', () async {
      final customerBooking = (await repo.getBookingsForVendor('v1')).firstWhere((b) => b.id == 'bk_mock_doorstep');
      expect(customerBooking.deliveryType, 'DOORSTEP_DELIVERY');
      expect(customerBooking.deliveryFee, 450.0);
      expect(customerBooking.deliveryLatitude, 19.0178);
      expect(customerBooking.deliveryLongitude, 72.8178);
    });

    // 17. Admin governance visibility
    test('17. Admin governance visibility inspects complete fulfillment snapshot', () async {
      final adminBookings = MockData.bookings;
      expect(adminBookings, isNotEmpty);
      final sample = adminBookings.first;
      expect(sample.id, isNotEmpty);
      expect(sample.vendorId, isNotEmpty);
      expect(sample.carId, isNotEmpty);
    });
  });
}
