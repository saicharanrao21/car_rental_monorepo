import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:vendor_app/features/fleet/domain/models/vendor_fleet_models.dart';
import 'package:vendor_app/features/fleet/presentation/pages/add_edit_car_page.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/features/dashboard/domain/models/operations_models.dart';

class MockFleetRepository implements FleetRepository {
  List<CarModel> cars = [];

  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async => List.from(cars);

  @override
  Future<CarModel> addCar(CarModel car) async {
    final newCar = car.copyWith(id: 'car_${cars.length + 1}');
    cars.add(newCar);
    return newCar;
  }

  @override
  Future<CarModel> updateCar(CarModel car) async {
    final idx = cars.indexWhere((c) => c.id == car.id);
    if (idx != -1) {
      cars[idx] = car;
      return car;
    }
    cars.add(car);
    return car;
  }

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {}

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
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(String carId, DateTime start, DateTime end) async => [];

  @override
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId) async => [];

  @override
  Future<VehicleBlockModel> createVehicleBlock({required String carId, required DateTime startDate, required DateTime endDate, required String blockType, String? reason}) async => VehicleBlockModel(
    id: 'block_1',
    carId: carId,
    vendorId: 'vendor_1',
    startDate: startDate,
    endDate: endDate,
    blockType: blockType,
    actorId: 'vendor_user_1',
    actorRole: 'VENDOR',
    createdAt: DateTime.now(),
  );

  @override
  Future<bool> deleteVehicleBlock(String blockId) async => true;

  @override
  Future<VehicleReadinessModel> getVehicleReadiness(String carId) async => VehicleReadinessModel(
    eligible: true,
    carId: carId,
    operationalStatus: 'ACTIVE',
    verificationStatus: 'VERIFIED',
    blockers: [],
    requiredActions: [],
    vendorId: 'vendor_1',
    vendorBusinessName: 'Mock Fleet',
    evaluatedAt: DateTime.now().toIso8601String(),
  );

  @override
  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId) async => [];

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
}

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> getStats(String vendorId) async => const DashboardStats(
        todaysBookings: 3,
        pendingRequests: 1,
        thisMonthEarnings: 45000.0,
        activeCars: 8,
        inactiveCars: 2,
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
        todayCount: 3,
        pendingCount: 1,
        upcomingCount: 4,
        completedCount: 18,
        activeCount: 2,
      );

  @override
  Future<FleetSummary> getFleetSummary(String vendorId) async => const FleetSummary(
        totalCars: 3,
        availableCars: 2,
        onTripCars: 0,
        unavailableCars: 1,
      );

  @override
  Future<EarningsSnapshot> getEarningsSnapshot(String vendorId) async => const EarningsSnapshot(
        thisMonthEarnings: 45000.0,
        availableBalance: 32000.0,
        heldEarnings: 8500.0,
        totalEarnings: 185000.0,
        totalPaidOut: 144500.0,
      );

  @override
  Future<Map<String, dynamic>?> getVendorOperationsCenter(String vendorId) async => null;
}

class MockSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  MockSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentPng = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();
  DDSTypography.useSystemFallbackInTests = true;

  late MockFleetRepository mockRepo;
  const testVendor = VendorModel(
    id: 'vendor_1',
    businessName: 'Royal Fleet Operations',
    phone: '+919876543210',
    email: 'ops@royalfleet.com',
    ownerName: 'Vendor Admin',
    city: 'Hyderabad',
  );

  setUp(() {
    mockRepo = MockFleetRepository();
  });

  Widget buildTestApp(Widget child, {List<Map<String, dynamic>>? hubs}) {
    return ProviderScope(
      overrides: [
        fleetRepositoryProvider.overrideWithValue(mockRepo),
        dashboardRepositoryProvider.overrideWithValue(MockDashboardRepository()),
        vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
        vendorPickupHubsProvider.overrideWith((ref) => hubs ?? [
          {'id': 'yard_madhapur_01', 'name': 'Madhapur Fleet Yard', 'city': 'Hyderabad'},
          {'id': 'yard_gachibowli_02', 'name': 'Gachibowli Service Hub', 'city': 'Hyderabad'},
        ]),
        supportedCitiesProvider.overrideWith((ref) => ['Hyderabad', 'Bengaluru', 'Mumbai', 'Pune']),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1080, 2400)),
          child: child,
        ),
      ),
    );
  }

  group('DriveGo Marketplace — Authentic Vehicle Photo & Publishing Tests', () {
    testWidgets('1. Fast Add defaults to zero stock photos and requires authentic photos', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const AddEditCarPage()));
      await tester.pumpAndSettle();

      // Step 1: Identity
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Maruti Suzuki, Hyundai, Tata'), 'Tata');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Swift, Creta, Nexon, Thar'), 'Nexon');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. MH 12 AB 1234'), 'TS 09 AB 1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Specifications
      expect(find.text('STEP 2 OF 6: SPECIFICATIONS'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Pricing
      expect(find.text('STEP 3 OF 6: COMMERCIAL & PRICING'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Media & Photos
      expect(find.text('STEP 4 OF 6: MEDIA & PHOTOS'), findsOneWidget);
      expect(find.text('Tap to Upload Real Vehicle Photos'), findsOneWidget);
      expect(find.text('Stock photos and sample placeholders are strictly rejected by Admin verification. The first photo will be used as the listing cover.'), findsOneWidget);

      // Verify validation blocks without photos
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please upload at least 1 authentic vehicle photo before continuing.'), findsOneWidget);
    });

    testWidgets('2. Wizard validates operating yard assignment and binds pickupHubId upon publishing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const AddEditCarPage(
        initialPhotos: ['https://storage.drivego.in/car-photo/real_nexon_front.jpg'],
        initialHubId: 'yard_madhapur_01',
      )));
      await tester.pumpAndSettle();

      // Fill Identity
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Maruti Suzuki, Hyundai, Tata'), 'Tata');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Swift, Creta, Nexon, Thar'), 'Nexon');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. MH 12 AB 1234'), 'TS 09 AB 9999');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 -> Step 4
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Has authentic photo
      expect(find.text('STEP 4 OF 6: MEDIA & PHOTOS'), findsOneWidget);
      expect(find.text('COVER'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 5: Pickup & Operations
      expect(find.text('STEP 5 OF 6: PICKUP & OPERATIONS'), findsOneWidget);
      expect(find.text('Madhapur Fleet Yard (Hyderabad)'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 6: Review & Publish
      expect(find.text('STEP 6 OF 6: REVIEW & PUBLISH'), findsOneWidget);
      expect(find.text('Madhapur Fleet Yard'), findsOneWidget);
      expect(find.text('1 uploaded'), findsOneWidget);

      await tester.tap(find.text('Publish Vehicle'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Verify CarModel saved with authentic photos and pickupHubId
      expect(mockRepo.cars.length, 1);
      final publishedCar = mockRepo.cars.first;
      expect(publishedCar.make, 'Tata');
      expect(publishedCar.model, 'Nexon');
      expect(publishedCar.registrationNumber, 'TS 09 AB 9999');
      expect(publishedCar.photos, ['https://storage.drivego.in/car-photo/real_nexon_front.jpg']);
      expect(publishedCar.pickupHubId, 'yard_madhapur_01');
    });

    testWidgets('3. Empty hubs view displays clear prompt to register genuine operating yard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        const AddEditCarPage(
          initialPhotos: ['https://storage.drivego.in/car-photo/real_car.jpg'],
        ),
        hubs: [], // No registered hubs
      ));
      await tester.pumpAndSettle();

      // Advance through steps 1-4
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Maruti Suzuki, Hyundai, Tata'), 'Hyundai');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Swift, Creta, Nexon, Thar'), 'Verna');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. MH 12 AB 1234'), 'TS 07 CD 5678');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 5: Pickup & Operations empty state
      expect(find.text('STEP 5 OF 6: PICKUP & OPERATIONS'), findsOneWidget);
      expect(find.text('No Operating Yards Found'), findsOneWidget);
      expect(find.text('Register First Operating Yard'), findsOneWidget);

      // Attempting to continue without hub fails validation
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please select or register an operating yard for vehicle pickup.'), findsOneWidget);
    });
  });
}
