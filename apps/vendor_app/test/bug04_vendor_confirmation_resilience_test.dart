import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';

class MockSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  MockSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

class MockFailingVendorBookingsRepository implements VendorBookingsRepository {
  bool shouldFail = true;
  String failureMessage = 'Cannot confirm booking: Payment has not been captured (Payment status: FAILED). The customer must complete payment before vendor confirmation.';
  String? lastUpdatedStatus;

  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    return [];
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {
    if (shouldFail) {
      throw Exception(failureMessage);
    }
    lastUpdatedStatus = newStatus;
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    if (shouldFail) {
      throw Exception(failureMessage);
    }
    lastUpdatedStatus = 'CANCELLED';
  }

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async => [];

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
    throw UnimplementedError();
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
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testVendor = VendorModel(
    id: 'vendor_test_101',
    businessName: 'DriveGo Test Fleet',
    ownerName: 'Test Owner',
    city: 'Hyderabad',
    verificationStatus: 'verified',
  );

  group('BUG-04 Regression: Vendor Booking Confirmation & Riverpod Resilience', () {
    late MockFailingVendorBookingsRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockFailingVendorBookingsRepository();
      container = ProviderContainer(
        overrides: [
          vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
          vendorBookingsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('DashboardController.respondToBooking handles rejection without Future already completed error',
        () async {
      final controller = container.read(dashboardControllerProvider.notifier);

      // 1. Initial build has completed synchronously
      expect(container.read(dashboardControllerProvider).isLoading, isFalse);

      // 2. Trigger confirmation on unpaid booking (repository throws)
      mockRepo.shouldFail = true;
      final result = await controller.respondToBooking('booking_unpaid_123', true);

      // Verify clean error handling
      expect(result, isFalse);
      expect(controller.lastErrorMessage, contains('Cannot confirm booking: Payment has not been captured'));

      // Verify notifier state is healthy (data(null), NOT dead or corrupted with Future already completed)
      final state = container.read(dashboardControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isFalse);

      // 3. Verify controller can recover and execute subsequent successful transitions
      mockRepo.shouldFail = false;
      final retryResult = await controller.respondToBooking('booking_paid_456', true);
      expect(retryResult, isTrue);
      expect(controller.lastErrorMessage, isNull);
      expect(mockRepo.lastUpdatedStatus, equals('confirmed'));
    });

    test('VendorBookingsNotifier.updateStatus captures clean error message on rejection',
        () async {
      final notifier = container.read(vendorBookingsProvider.notifier);

      mockRepo.shouldFail = true;
      final result = await notifier.updateStatus('booking_unpaid_123', 'confirmed');

      expect(result, isFalse);
      expect(notifier.lastErrorMessage, contains('Cannot confirm booking: Payment has not been captured'));

      // Test subsequent success
      mockRepo.shouldFail = false;
      final successResult = await notifier.updateStatus('booking_paid_456', 'confirmed');
      expect(successResult, isTrue);
      expect(notifier.lastErrorMessage, isNull);
    });
  });
}
