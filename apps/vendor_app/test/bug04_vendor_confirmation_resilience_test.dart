import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/features/dashboard/domain/models/operations_models.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:vendor_app/features/fleet/domain/models/vendor_fleet_models.dart';

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

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> getStats(String vendorId) async => const DashboardStats(
        todaysBookings: 0,
        pendingRequests: 0,
        thisMonthEarnings: 0,
        activeCars: 0,
        inactiveCars: 0,
      );

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async => [];

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {}

  @override
  Future<List<TriageItem>> getOperationsTriage(String vendorId) async => [];

  @override
  Future<List<TodayTimelineItem>> getTodayOperations(String vendorId) async => [];

  @override
  Future<BookingMatrix> getBookingMatrix(String vendorId) async => const BookingMatrix(
        todayCount: 0,
        pendingCount: 0,
        upcomingCount: 0,
        completedCount: 0,
        activeCount: 0,
      );

  @override
  Future<FleetSummary> getFleetSummary(String vendorId) async => const FleetSummary(
        totalCars: 0,
        availableCars: 0,
        onTripCars: 0,
        unavailableCars: 0,
      );

  @override
  Future<EarningsSnapshot> getEarningsSnapshot(String vendorId) async => const EarningsSnapshot(
        thisMonthEarnings: 0,
        availableBalance: 0,
        heldEarnings: 0,
        totalEarnings: 0,
        totalPaidOut: 0,
      );

  @override
  Future<Map<String, dynamic>?> getVendorOperationsCenter(String vendorId) async => null;
}

class MockFleetRepository implements FleetRepository {
  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async => [];

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {}

  @override
  Future<CarModel> addCar(CarModel car) async => car;

  @override
  Future<CarModel> updateCar(CarModel car) async => car;

  @override
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {}

  @override
  Future<void> uploadCarDocument({required String carId, required String type, required String fileUrl, DateTime? expiresAt}) async {}

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async => [];

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {}

  @override
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(String carId, DateTime startDate, DateTime endDate) async => [];

  @override
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId) async => [];

  @override
  Future<VehicleBlockModel> createVehicleBlock({required String carId, required DateTime startDate, required DateTime endDate, required String blockType, String? reason}) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteVehicleBlock(String blockId) async => true;

  @override
  Future<VehicleReadinessModel> getVehicleReadiness(String carId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> submitForVerification(String carId) async {}

  @override
  Future<void> activateVehicle(String carId) async {}

  @override
  Future<void> deactivateVehicle(String carId, {String? reason}) async {}

  @override
  Future<void> startMaintenance(String carId, {required String reason, String? expectedReturnDate}) async {}

  @override
  Future<void> completeMaintenance(String carId, {String? notes}) async {}

  @override
  Future<void> assignServiceArea(String carId, String serviceAreaId) async {}

  @override
  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

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
          dashboardRepositoryProvider.overrideWithValue(MockDashboardRepository()),
          fleetRepositoryProvider.overrideWithValue(MockFleetRepository()),
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
