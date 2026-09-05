import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
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

  late FastVendorBookingsRepository repo;

  const testVendor = VendorModel(
    id: 'vendor-p33-test',
    businessName: 'DriveGo Bangalore Fleet',
    ownerName: 'Sunil Kumar',
    email: 'sunil@drivego.in',
    phone: '+919876543210',
    city: 'Bengaluru',
    verificationStatus: 'VERIFIED',
  );

  final testBooking = BookingModel(
    id: 'bk_p33_vendor_001',
    customerId: 'cust_001',
    vendorId: 'vendor-p33-test',
    carId: 'car_001',
    tripType: 'Self-Drive',
    pickupLocation: 'Koramangala Hub',
    startDate: DateTime(2026, 9, 10, 10),
    endDate: DateTime(2026, 9, 15, 10),
    totalFare: 15000,
    platformFee: 1500,
    gstAmount: 2700,
    netToVendor: 10800,
    status: 'pending',
    createdAt: DateTime(2026, 9, 5),
  );

  setUp(() {
    repo = FastVendorBookingsRepository();
    repo.addMockBooking(testBooking);
  });

  Widget buildVendorDetailWidget(String bookingId, {List<BookingModel>? initialList}) {
    return ProviderScope(
      overrides: [
        vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
        vendorBookingsRepositoryProvider.overrideWithValue(repo),
        fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
        dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
        if (initialList != null)
          vendorBookingsProvider.overrideWith(() => _PreloadedNotifier(initialList)),
      ],
      child: MaterialApp(
        home: VendorBookingDetailPage(bookingId: bookingId),
      ),
    );
  }

  group('Phase 33 — Vendor Booking Lifecycle Orchestration Tests', () {
    test('1. Repository: Transitioning PENDING -> CONFIRMED updates authoritative booking status', () async {
      await repo.updateBookingStatus(testBooking.id, 'confirmed');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'confirmed');
    });

    test('2. Repository: Transitioning CONFIRMED -> HANDOVER_READY sets status', () async {
      await repo.updateBookingStatus(testBooking.id, 'confirmed');
      await repo.updateBookingStatus(testBooking.id, 'handover_ready');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'handover_ready');
    });

    test('3. Repository: Transitioning HANDOVER_READY -> ONGOING requires pickup OTP', () async {
      await repo.updateBookingStatus(testBooking.id, 'confirmed');
      repo.addMockInspection(InspectionModel(
        id: 'insp_pre_01',
        bookingId: 'bk_p33_vendor_001',
        performedById: 'vendor-p33-test',
        type: 'PRE_TRIP',
        odometer: 15000,
        fuelPercent: 100,
        finalized: true,
        createdAt: DateTime(2026, 9, 10),
      ));
      await repo.updateBookingStatus(testBooking.id, 'handover_ready');
      await repo.updateBookingStatus(testBooking.id, 'ongoing', handoverOtp: '123456');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'ongoing');
    });

    test('4. Repository: Transitioning ONGOING -> RETURN_PENDING sets return stage', () async {
      await repo.updateBookingStatus(testBooking.id, 'confirmed');
      repo.addMockInspection(InspectionModel(
        id: 'insp_pre_01',
        bookingId: 'bk_p33_vendor_001',
        performedById: 'vendor-p33-test',
        type: 'PRE_TRIP',
        odometer: 15000,
        fuelPercent: 100,
        finalized: true,
        createdAt: DateTime(2026, 9, 10),
      ));
      await repo.updateBookingStatus(testBooking.id, 'handover_ready');
      await repo.updateBookingStatus(testBooking.id, 'ongoing', handoverOtp: '123456');
      await repo.updateBookingStatus(testBooking.id, 'return_pending');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'return_pending');
    });

    test('5. Repository: Transitioning RETURN_PENDING -> COMPLETED requires return OTP and post-trip inspection', () async {
      await repo.updateBookingStatus(testBooking.id, 'confirmed');
      repo.addMockInspection(InspectionModel(
        id: 'insp_pre_01',
        bookingId: 'bk_p33_vendor_001',
        performedById: 'vendor-p33-test',
        type: 'PRE_TRIP',
        odometer: 15000,
        fuelPercent: 100,
        finalized: true,
        createdAt: DateTime(2026, 9, 10),
      ));
      await repo.updateBookingStatus(testBooking.id, 'handover_ready');
      await repo.updateBookingStatus(testBooking.id, 'ongoing', handoverOtp: '123456');
      await repo.updateBookingStatus(testBooking.id, 'return_pending');
      repo.addMockInspection(InspectionModel(
        id: 'insp_post_01',
        bookingId: 'bk_p33_vendor_001',
        performedById: 'vendor-p33-test',
        type: 'POST_TRIP',
        odometer: 15450,
        fuelPercent: 95,
        finalized: true,
        createdAt: DateTime(2026, 9, 10),
      ));
      await repo.updateBookingStatus(testBooking.id, 'completed', handoverOtp: '987654');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'completed');
    });

    test('6. Repository: Rejecting booking transitions to CANCELLED with reason', () async {
      await repo.rejectBooking(testBooking.id, 'Vehicle undergoing unexpected maintenance');
      final list = await repo.getBookingsForVendor(testVendor.id);
      final updated = list.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, 'cancelled');
    });

    testWidgets('7. UI: Vendor booking detail page renders authoritative details and actions', (tester) async {
      await tester.pumpWidget(buildVendorDetailWidget(
        testBooking.id,
        initialList: [testBooking.copyWith(status: 'confirmed')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Booking ${testBooking.id}'), findsOneWidget);
    });
  });
}

class _PreloadedNotifier extends VendorBookingsNotifier {
  final List<BookingModel> _items;
  _PreloadedNotifier(this._items);

  @override
  Future<List<BookingModel>> build() async => _items;
}
