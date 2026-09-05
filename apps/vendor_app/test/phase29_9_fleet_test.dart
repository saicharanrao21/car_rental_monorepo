import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/features/dashboard/domain/models/operations_models.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:vendor_app/features/fleet/presentation/pages/fleet_list_page.dart';
import 'package:vendor_app/features/fleet/presentation/pages/fleet_car_detail_page.dart';
import 'package:vendor_app/features/fleet/presentation/pages/add_edit_car_page.dart';
import 'package:vendor_app/features/fleet/presentation/pages/csv_bulk_upload_page.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';

class MockFleetRepository implements FleetRepository {
  List<CarModel> cars = [
    const CarModel(
      id: 'car_1',
      vendorId: 'vendor_1',
      make: 'Maruti Suzuki',
      model: 'Swift',
      year: 2023,
      type: 'Hatchback',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: 12.0,
      pricePerDay: 2000.0,
      pricePerHour: 150.0,
      registrationNumber: 'MH 12 AB 1234',
      isAvailable: true,
      blockedDates: [],
      availableTripTypes: ['Local', 'Outstation'],
    ),
    CarModel(
      id: 'car_2',
      vendorId: 'vendor_1',
      make: 'Hyundai',
      model: 'Creta',
      year: 2024,
      type: 'SUV',
      fuelType: 'Diesel',
      seating: 5,
      isAC: true,
      photos: const ['https://images.unsplash.com/photo-1552519507-da3b142c6e3d'],
      pricePerKm: 16.0,
      pricePerDay: 3200.0,
      pricePerHour: 250.0,
      registrationNumber: 'MH 12 CD 5678',
      isAvailable: true,
      blockedDates: [DateTime(2026, 9, 15)],
      availableTripTypes: const ['Local', 'Outstation', 'Airport Transfer'],
    ),
    const CarModel(
      id: 'car_3',
      vendorId: 'vendor_1',
      make: 'Tata',
      model: 'Nexon EV',
      year: 2024,
      type: 'SUV',
      fuelType: 'Electric',
      seating: 5,
      isAC: true,
      photos: ['https://images.unsplash.com/photo-1503376780353-7e6692767b70'],
      pricePerKm: 15.0,
      pricePerDay: 3500.0,
      pricePerHour: 280.0,
      registrationNumber: 'MH 12 EV 9999',
      isAvailable: false,
      blockedDates: [],
      availableTripTypes: ['Local', 'Self-Drive'],
    ),
  ];

  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async {
    return List.from(cars);
  }

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {
    final idx = cars.indexWhere((c) => c.id == carId);
    if (idx != -1) {
      cars[idx] = cars[idx].copyWith(isAvailable: isAvailable);
    }
  }

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
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {
    final idx = cars.indexWhere((c) => c.id == carId);
    if (idx != -1) {
      cars[idx] = cars[idx].copyWith(blockedDates: blockedDates);
    }
  }

  @override
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async {
    return [];
  }

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async {
    return package;
  }

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async {
    return package;
  }

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {}

  @override
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(
    String carId,
    DateTime startDate,
    DateTime endDate,
  ) async => [];

  @override
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId) async => [];

  @override
  Future<VehicleBlockModel> createVehicleBlock({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    required String blockType,
    String? reason,
  }) async => VehicleBlockModel(
        id: 'mock_b2',
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
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
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
  late MockDashboardRepository mockDashboardRepo;
  const testVendor = VendorModel(
    id: 'vendor_1',
    businessName: 'DriveGo Prime Fleet',
    ownerName: 'Rajesh Sharma',
    city: 'Pune',
    phone: '9876543001',
    verificationStatus: 'VERIFIED',
    subscriptionTier: 'PRO',
  );

  setUp(() {
    mockRepo = MockFleetRepository();
    mockDashboardRepo = MockDashboardRepository();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        fleetRepositoryProvider.overrideWithValue(mockRepo),
        dashboardRepositoryProvider.overrideWithValue(mockDashboardRepo),
        vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1080, 2400)),
          child: child,
        ),
      ),
    );
  }

  group('DriveGo Phase 29.9 — Vendor Fleet Management Tests', () {
    testWidgets('1. Fleet Overview renders header, summary health cards, and vehicles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const FleetListPage()));
      await tester.pumpAndSettle();

      expect(find.text('My Fleet'), findsOneWidget);
      expect(find.text('Total Fleet'), findsOneWidget);
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Maruti Suzuki Swift'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Tata Nexon EV'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsOneWidget);
    });

    testWidgets('2. Real-time Search filters fleet by make, model, and registration plate', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const FleetListPage()));
      await tester.pumpAndSettle();

      // Tap search icon in app bar
      await tester.tap(find.byTooltip('Search Vehicles'));
      await tester.pumpAndSettle();

      // Enter search query "Creta"
      await tester.enterText(find.byType(TextField), 'Creta');
      await tester.pumpAndSettle();

      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('Maruti Suzuki Swift'), findsNothing);
      expect(find.text('Tata Nexon EV'), findsNothing);

      // Search by registration number "EV 9999"
      await tester.enterText(find.byType(TextField), 'EV 9999');
      await tester.pumpAndSettle();

      expect(find.text('Tata Nexon EV'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
    });

    testWidgets('3. Filter Drawer filters fleet by operational status and fuel type', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const FleetListPage()));
      await tester.pumpAndSettle();

      // Open filter modal
      await tester.tap(find.byTooltip('Filter Fleet'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Fleet'), findsOneWidget);
      expect(find.text('Operational Status'), findsOneWidget);
      expect(find.text('Fuel Type'), findsOneWidget);

      // Select Petrol
      await tester.tap(find.text('Petrol'));
      await tester.pumpAndSettle();

      // Apply filter
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Maruti Suzuki Swift'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsNothing);
      expect(find.text('Tata Nexon EV'), findsNothing);
    });

    testWidgets('4. Vehicle Details renders specifications, pricing breakdown, and availability switch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const FleetCarDetailPage(carId: 'car_1')));
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Maruti Suzuki Swift'), findsOneWidget);
      expect(find.text('MH 12 AB 1234'), findsOneWidget);
      expect(find.text('Vehicle Specifications'), findsOneWidget);
      expect(find.text('5 Passengers'), findsOneWidget);
      expect(find.text('Air Conditioned'), findsOneWidget);
      expect(find.text('Commercial Rates & Pricing'), findsOneWidget);
      expect(find.text('Daily Rental Rate'), findsOneWidget);
      expect(find.text('Blocked Dates Management'), findsOneWidget);
      expect(find.text('Edit Vehicle Specifications'), findsOneWidget);
    });

    testWidgets('5. Availability switch triggers safety confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const FleetCarDetailPage(carId: 'car_1')));
      await tester.pumpAndSettle();

      // Toggle switch to turn offline
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Take Vehicle Offline?'), findsOneWidget);
      expect(find.text('Confirm Offline'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm Offline'));
      await tester.pumpAndSettle();

      expect(mockRepo.cars.first.isAvailable, false);
    });

    testWidgets('6. Fast Add 6-step wizard navigates through all steps with validation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const AddEditCarPage()));
      await tester.pumpAndSettle();

      expect(find.text('Fast Add Vehicle'), findsOneWidget);
      expect(find.text('STEP 1 OF 6: VEHICLE IDENTITY'), findsOneWidget);

      // Step 1: Fill Identity
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Maruti Suzuki, Hyundai, Tata'), 'Kia');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Swift, Creta, Nexon, Thar'), 'Seltos');
      await tester.enterText(find.widgetWithText(TextField, 'e.g. MH 12 AB 1234'), 'MH 14 GT 7777');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Specifications
      expect(find.text('STEP 2 OF 6: SPECIFICATIONS'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Commercial & Pricing
      expect(find.text('STEP 3 OF 6: COMMERCIAL & PRICING'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Media & Photos
      expect(find.text('STEP 4 OF 6: MEDIA & PHOTOS'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 5: Pickup & Operations
      expect(find.text('STEP 5 OF 6: PICKUP & OPERATIONS'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 6: Review & Publish
      expect(find.text('STEP 6 OF 6: REVIEW & PUBLISH'), findsOneWidget);
      expect(find.text('Review Vehicle Details'), findsOneWidget);
      expect(find.text('Publish Vehicle'), findsOneWidget);

      await tester.tap(find.text('Publish Vehicle'));
      await tester.pumpAndSettle();

      expect(mockRepo.cars.any((c) => c.make == 'Kia' && c.model == 'Seltos'), true);
    });

    testWidgets('7. Bulk CSV Upload parses and validates rows with actionable rejection errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const CsvBulkUploadPage()));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Vehicle Import (CSV)'), findsOneWidget);
      expect(find.text('Load Demo Fleet CSV Data (Instant Preview)'), findsOneWidget);

      // Load sample CSV data
      await tester.tap(find.text('Load Demo Fleet CSV Data (Instant Preview)'));
      await tester.pumpAndSettle();

      // Verify metrics
      expect(find.text('Valid Vehicles'), findsOneWidget);
      expect(find.text('Invalid Rows'), findsOneWidget);
      expect(find.text('Actionable Validation Errors'), findsOneWidget);

      final importBtn = find.textContaining('Confirm & Import');
      await tester.ensureVisible(importBtn);
      await tester.pumpAndSettle();

      // Confirm upload
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      expect(find.text('Import Completed'), findsOneWidget);
      expect(find.text('Go to My Fleet'), findsOneWidget);
    });
  });
}
