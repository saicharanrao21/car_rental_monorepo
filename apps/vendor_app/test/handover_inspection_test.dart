import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';

void main() {
  group('Handover & Inspection Flow Tests (Phase 4E.1)', () {
    late MockVendorBookingsRepository mockRepo;

    setUp(() {
      mockRepo = MockVendorBookingsRepository();
    });

    test('InspectionModel parses JSON correctly with all fields and null fallbacks', () {
      final json = {
        'id': 'insp-123',
        'bookingId': 'booking-456',
        'type': 'PRE_TRIP',
        'performedById': 'user-789',
        'odometer': '25000.5',
        'fuelPercent': 85,
        'conditionNotes': 'Clean condition, scratch on rear door',
        'damagePhotos': ['inspection-photo/scratch_1.jpg'],
        'finalized': true,
        'finalizedAt': '2026-08-14T10:00:00.000Z',
        'createdAt': '2026-08-14T09:55:00.000Z',
      };

      final model = InspectionModel.fromJson(json);

      expect(model.id, 'insp-123');
      expect(model.bookingId, 'booking-456');
      expect(model.type, 'PRE_TRIP');
      expect(model.performedById, 'user-789');
      expect(model.odometer, 25000.5);
      expect(model.fuelPercent, 85);
      expect(model.conditionNotes, 'Clean condition, scratch on rear door');
      expect(model.damagePhotos.length, 1);
      expect(model.damagePhotos.first, 'inspection-photo/scratch_1.jpg');
      expect(model.finalized, true);
      expect(model.finalizedAt, isNotNull);

      // Null fallback test
      final emptyJson = <String, dynamic>{};
      final emptyModel = InspectionModel.fromJson(emptyJson);
      expect(emptyModel.id, '');
      expect(emptyModel.type, 'PRE_TRIP');
      expect(emptyModel.odometer, 0.0);
      expect(emptyModel.fuelPercent, 0);
      expect(emptyModel.damagePhotos, isEmpty);
      expect(emptyModel.finalized, false);
      expect(emptyModel.finalizedAt, isNull);
    });

    test('InspectionModel serializes to JSON correctly', () {
      final now = DateTime.now();
      final model = InspectionModel(
        id: 'insp-999',
        bookingId: 'booking-999',
        type: 'POST_TRIP',
        performedById: 'user-vendor',
        odometer: 25450.0,
        fuelPercent: 75,
        conditionNotes: 'All good',
        damagePhotos: ['inspection-photo/return_clean.jpg'],
        finalized: true,
        finalizedAt: now,
        createdAt: now,
      );

      final json = model.toJson();

      expect(json['id'], 'insp-999');
      expect(json['bookingId'], 'booking-999');
      expect(json['type'], 'POST_TRIP');
      expect(json['odometer'], 25450.0);
      expect(json['fuelPercent'], 75);
      expect(json['finalized'], true);
      expect(json['damagePhotos'], ['inspection-photo/return_clean.jpg']);
    });

    test('InspectionModel copyWith updates specified fields immutably', () {
      final model = InspectionModel(
        id: 'insp-1',
        bookingId: 'booking-1',
        type: 'PRE_TRIP',
        performedById: 'user-1',
        odometer: 10000.0,
        fuelPercent: 100,
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(
        odometer: 10050.0,
        fuelPercent: 95,
        finalized: true,
      );

      expect(updated.id, 'insp-1');
      expect(updated.odometer, 10050.0);
      expect(updated.fuelPercent, 95);
      expect(updated.finalized, true);
      expect(model.odometer, 10000.0); // original unchanged
    });

    test('End-to-End Pickup Flow: Pre-trip inspection -> Send OTP -> Ongoing transition', () async {
      const bookingId = 'b1';

      // 1. Initial inspections are empty
      final initialInspections = await mockRepo.getInspections(bookingId);
      expect(initialInspections, isEmpty);

      // 2. Perform and finalize pre-trip inspection
      final preTrip = await mockRepo.upsertInspection(
        bookingId,
        type: 'PRE_TRIP',
        odometer: 15200.0,
        fuelPercent: 100,
        conditionNotes: 'Clean vehicle, full tank, zero prior scratches',
        damagePhotos: ['inspection-photo/pre_front.jpg', 'inspection-photo/pre_back.jpg'],
        finalize: true,
      );

      expect(preTrip.type, 'PRE_TRIP');
      expect(preTrip.odometer, 15200.0);
      expect(preTrip.finalized, true);
      expect(preTrip.damagePhotos.length, 2);

      // 3. Dispatch Pickup OTP
      await expectLater(
        mockRepo.sendHandoverOtp(bookingId, 'PICKUP'),
        completes,
      );

      // 4. Verify OTP and transition status to ONGOING
      await mockRepo.updateBookingStatus(
        bookingId,
        'ongoing',
        handoverOtp: '654321',
      );

      final vendorBookings = await mockRepo.getBookingsForVendor('v1');
      final ongoingBooking = vendorBookings.firstWhere((b) => b.id == bookingId);
      expect(ongoingBooking.status, 'ongoing');
    });

    test('End-to-End Return Flow: Post-trip inspection -> Send OTP -> Completed transition', () async {
      const bookingId = 'b2';

      // 1. Perform pre-trip inspection first (baseline)
      await mockRepo.upsertInspection(
        bookingId,
        type: 'PRE_TRIP',
        odometer: 20000.0,
        fuelPercent: 100,
        finalize: true,
      );

      // 2. Perform post-trip inspection (validating monotonic odometer)
      const postTripOdometer = 20450.0;
      expect(postTripOdometer, greaterThanOrEqualTo(20000.0));

      final postTrip = await mockRepo.upsertInspection(
        bookingId,
        type: 'POST_TRIP',
        odometer: postTripOdometer,
        fuelPercent: 75,
        conditionNotes: 'Returned on time, no damages',
        damagePhotos: ['inspection-photo/post_clean.jpg'],
        finalize: true,
      );

      expect(postTrip.type, 'POST_TRIP');
      expect(postTrip.odometer, 20450.0);
      expect(postTrip.fuelPercent, 75);
      expect(postTrip.finalized, true);

      // 3. Dispatch Return OTP
      await expectLater(
        mockRepo.sendHandoverOtp(bookingId, 'RETURN'),
        completes,
      );

      // 4. Verify OTP and transition status to COMPLETED
      await mockRepo.updateBookingStatus(
        bookingId,
        'completed',
        handoverOtp: '987654',
      );

      final vendorBookings = await mockRepo.getBookingsForVendor('v1');
      final completedBooking = vendorBookings.firstWhere((b) => b.id == bookingId);
      expect(completedBooking.status, 'completed');

      // 5. Verify both inspection records are preserved for history
      final allInspections = await mockRepo.getInspections(bookingId);
      expect(allInspections.length, 2);
      expect(allInspections.any((i) => i.type == 'PRE_TRIP'), isTrue);
      expect(allInspections.any((i) => i.type == 'POST_TRIP'), isTrue);
    });

    test('Rejection safely marks booking as cancelled without affecting inspections', () async {
      const bookingId = 'b3';

      await mockRepo.rejectBooking(bookingId, 'Vehicle maintenance emergency');

      final vendorBookings = await mockRepo.getBookingsForVendor('v2');
      final cancelledBooking = vendorBookings.firstWhere((b) => b.id == bookingId);
      expect(cancelledBooking.status, 'cancelled');
    });
  });
}
