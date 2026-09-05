import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:customer_app/features/booking/presentation/widgets/fulfillment_selection_card.dart';
import 'package:customer_app/features/booking/presentation/widgets/booking_price_breakdown_card.dart';
import 'package:customer_app/features/booking/presentation/widgets/trip_details_step.dart';
import 'package:customer_app/features/booking/presentation/widgets/payment_step.dart';
import 'package:customer_app/features/booking/presentation/pages/booking_confirmation_page.dart';
import 'package:customer_app/features/location/presentation/widgets/location_selection_sheet.dart';
import 'package:customer_app/features/car_detail/presentation/pages/car_detail_page.dart';
import 'package:customer_app/features/car_detail/presentation/providers/car_detail_providers.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:customer_app/features/booking/domain/repositories/booking_repository.dart';

class MockFulfillmentCaptureRepository implements BookingRepository {
  @override
  Future<BookingModel> createBooking(BookingModel draft) async => draft.copyWith(id: 'BK_CONFIRMED_999');

  @override
  Future<BookingModel?> getBookingById(String id) async {
    return BookingModel(
      id: id,
      customerId: 'cust_123',
      vendorId: 'v1',
      carId: 'car_123',
      tripType: 'SELF_DRIVE',
      pickupLocation: 'Main Yard, Andheri East',
      dropLocation: 'CSMIA Terminal 2 Hub',
      startDate: DateTime(2026, 9, 10, 10, 0),
      endDate: DateTime(2026, 9, 13, 10, 0),
      totalFare: 5250.0,
      platformFee: 400.0,
      gstAmount: 850.0,
      netToVendor: 4000.0,
      status: 'confirmed',
      createdAt: DateTime.now(),
      pickupHubId: 'hub_yard_1',
      returnHubId: 'pub_mum_csmia',
      pickupName: 'Mumbai Central Hub (Andheri East)',
      dropName: 'CSMIA Terminal 2 Transit Hub',
      pickupAddress: 'Plot 42, Andheri-Kurla Road, Mumbai',
      deliveryAddress: 'CSMIA Terminal 2 Departure Gate 4',
      deliveryFee: 350.0,
      pickupFee: 100.0,
      returnFee: 150.0,
      oneWayFee: 250.0,
      deliveryType: 'DOORSTEP_DELIVERY',
    );
  }

  @override
  Future<List<BookingModel>> getBookingsForCustomer(String customerId) async => [];

  @override
  Future<BookingModel> cancelBooking(String bookingId) async => throw UnimplementedError();

  @override
  Future<CouponValidationResultModel> validateCoupon({
    required String code,
    String? carId,
    double? subtotal,
    String? city,
    String? tripType,
    String? carCategory,
  }) async => CouponValidationResultModel(
        valid: false,
        couponId: '',
        code: code,
        description: 'Invalid',
        discountType: 'PERCENTAGE',
        discountValue: 0,
        discountAmount: 0,
        finalPayableAmount: subtotal ?? 0,
      );

  @override
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  }) async {
    final isDiff = pickupLocationId != null && returnLocationId != null && pickupLocationId != returnLocationId;
    return {
      'isAvailable': true,
      'distanceKm': 12.5,
      'deliveryFee': deliveryAddress != null ? 350.0 : 0.0,
      'pickupFee': pickupLocationId == 'pub_mum_csmia' ? 150.0 : 0.0,
      'returnFee': returnLocationId == 'pub_mum_csmia' ? 150.0 : 0.0,
      'oneWayFee': isDiff ? 250.0 : 0.0,
      'oneWaySurcharge': isDiff ? 250.0 : 0.0,
      'totalFulfillmentFee': (deliveryAddress != null ? 350.0 : 0.0) + (isDiff ? 250.0 : 0.0),
    };
  }

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) => CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

  @override
  Future<VehicleAvailabilityResult> checkVehicleAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? hubId,
  }) async => VehicleAvailabilityResult(
        available: true,
        carId: carId,
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      );

  @override
  Future<VehicleHoldModel> createVehicleHold({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    int ttlSeconds = 900,
    String? idempotencyKey,
  }) async => VehicleHoldModel(
        id: 'hold_test_capture_1',
        carId: carId,
        customerId: 'cust_123',
        vendorId: 'v1',
        startDate: startDate,
        endDate: endDate,
        expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
        status: 'ACTIVE',
      );

  @override
  Future<bool> releaseVehicleHold(String holdId) async => true;
}

class MockSessionNotifier extends SessionNotifier {
  final UserModel? initialUser;
  MockSessionNotifier(this.initialUser);

  @override
  AuthState build() {
    if (initialUser != null) {
      return AuthState.authenticated(initialUser!);
    }
    return AuthState.unauthenticated();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('razorpay_flutter'),
      (MethodCall methodCall) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    DDSTypography.useSystemFallbackInTests = true;
  });

  tearDownAll(() {
    DDSTypography.useSystemFallbackInTests = false;
  });

  const testUser = UserModel(
    id: 'user_test_1',
    phone: '+91 98765 43210',
    name: 'Aarav Sharma',
    email: 'aarav.sharma@drivego.in',
    role: 'CUSTOMER',
    banned: false,
  );

  const testCar = CarModel(
    id: 'car_123',
    vendorId: 'v1',
    make: 'Hyundai',
    model: 'Creta AT',
    year: 2024,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 5,
    isAC: true,
    registrationNumber: 'MH02XY9999',
    photos: ['https://example.com/car.jpg'],
    pricePerKm: 15.0,
    pricePerDay: 2500.0,
    pricePerHour: 200.0,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'LOCAL', 'OUTSTATION'],
    blockedDates: [],
  );

  const testVendor = VendorModel(
    id: 'v1',
    businessName: 'DriveGo Premium Mumbai',
    ownerName: 'Rajesh Sharma',
    city: 'Mumbai',
    phone: '+91 98200 12345',
    rating: 4.8,
  );

  final sampleCarDetail = CarDetailData(
    car: testCar,
    vendor: testVendor,
    reviews: [],
  );

  final testWallet = WalletModel(
    id: 'wlt_test_1',
    userId: 'user_test_1',
    currency: 'INR',
    availableBalance: 4750.0,
    lockedBalance: 0.0,
    realBalance: 3500.0,
    promoBalance: 1250.0,
    status: WalletStatus.ACTIVE,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  const outDir = 'test/screenshots';

  Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String fileName) async {
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.75);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file1 = File('$outDir/$fileName');
      await file1.parent.create(recursive: true);
      await file1.writeAsBytes(bytes);

      final file2 = File('C:/Users/pidep/.gemini/antigravity-ide/brain/b71310ab-8fe6-46d2-ad66-6424328ab811/screenshots/$fileName');
      await file2.parent.create(recursive: true);
      await file2.writeAsBytes(bytes);
    });
    // Drain any debounce timers gracefully
    await tester.pump(const Duration(seconds: 1));
  }

  Widget createSubject({
    required Widget child,
    required GlobalKey key,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => MockSessionNotifier(testUser)),
        bookingRepositoryProvider.overrideWithValue(MockFulfillmentCaptureRepository()),
        carDetailDataProvider('car_123').overrideWith((ref) => Future.value(sampleCarDetail)),
        customerWalletProvider.overrideWith((ref) => Future.value(testWallet)),
        publicTransportCatalogProvider('Mumbai').overrideWith((ref) => Future.value([
          {
            'id': 'pub_csmia',
            'name': 'Chhatrapati Shivaji Maharaj Int Airport (BOM)',
            'category': 'International Airport',
            'type': 'AIRPORT',
            'locality': 'Terminal 2, Sahar Road',
          },
          {
            'id': 'pub_csmt',
            'name': 'Chhatrapati Shivaji Maharaj Terminus (CSMT)',
            'category': 'Central Railway Station',
            'type': 'RAILWAY_STATION',
            'locality': 'Fort, South Mumbai',
          },
        ])),
        vendorPickupHubsProvider('v1').overrideWith((ref) => Future.value([
          {
            'id': 'hub_1',
            'name': 'Andheri East Main Yard',
            'address': 'Plot 42, Andheri-Kurla Road, Mumbai',
            'operatingHours': '08:00 - 22:00',
            'pickupFee': 0.0,
            'is24x7': false,
            'type': 'YARD',
          },
          {
            'id': 'hub_2',
            'name': 'Bandra Kurla Complex Branch',
            'address': 'G Block, BKC, Bandra East, Mumbai',
            'operatingHours': '24x7 Open',
            'pickupFee': 100.0,
            'is24x7': true,
            'type': 'BRANCH',
          },
        ])),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: DDSColors.bgCanvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: DDSColors.primaryBlue,
            surface: DDSColors.surfaceCard,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 393,
                height: 852,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('DriveGo Phase 29 Customer Booking Fulfillment Visual Evidence Capture', () {
    testWidgets('01_vehicle_detail_book_now.png', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        createSubject(
          key: key,
          child: const CarDetailPage(carId: 'car_123'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '01_vehicle_detail_book_now.png');
    });

    testWidgets('02_trip_details_schedule_fulfillment.png', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Trip Details & Handover')),
            body: SingleChildScrollView(
              child: TripDetailsStep(
                car: testCar,
                vendor: testVendor,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '02_trip_details_schedule_fulfillment.png');
    });

    testWidgets('03_fulfillment_host_yard_free.png', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Fulfillment Selection')),
            body: const SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: FulfillmentSelectionCard(car: testCar, vendor: testVendor),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '03_fulfillment_host_yard_free.png');
    });

    testWidgets('04_location_sheet_host_branches.png', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        createSubject(
          key: key,
          overrides: [
            vendorPickupHubsProvider('v1').overrideWith((ref) => Future.value([
              {
                'id': 'hub_1',
                'name': 'Andheri East Main Yard',
                'address': 'Plot 42, Andheri-Kurla Road, Mumbai',
                'operatingHours': '08:00 - 22:00',
                'pickupFee': 0.0,
                'is24x7': false,
                'type': 'YARD',
              },
              {
                'id': 'hub_2',
                'name': 'Bandra Kurla Complex Branch',
                'address': 'G Block, BKC, Bandra East, Mumbai',
                'operatingHours': '24x7 Open',
                'pickupFee': 100.0,
                'is24x7': true,
                'type': 'BRANCH',
              },
            ])),
          ],
          child: Scaffold(
            body: LocationSelectionSheet(
              title: 'Select Host Yard / Branch',
              city: 'Mumbai',
              vendorId: 'v1',
              onLocationSelected: (_, {lat, lng}) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '04_location_sheet_host_branches.png');
    });

    testWidgets('05_location_sheet_popular_hubs.png', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        createSubject(
          key: key,
          overrides: [
            publicTransportCatalogProvider('Mumbai').overrideWith((ref) => Future.value([
              {
                'id': 'pub_csmia',
                'name': 'Chhatrapati Shivaji Maharaj Int Airport (BOM)',
                'category': 'International Airport',
                'type': 'AIRPORT',
                'locality': 'Terminal 2, Sahar Road',
              },
              {
                'id': 'pub_csmt',
                'name': 'Chhatrapati Shivaji Maharaj Terminus (CSMT)',
                'category': 'Central Railway Station',
                'type': 'RAILWAY_STATION',
                'locality': 'Fort, South Mumbai',
              },
            ])),
          ],
          child: Scaffold(
            body: LocationSelectionSheet(
              title: 'Select Transit Point',
              city: 'Mumbai',
              onLocationSelected: (_, {lat, lng}) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '05_location_sheet_popular_hubs.png');
    });

    testWidgets('06_fulfillment_airport_transit_point.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Airport Pickup Selected')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: FulfillmentSelectionCard(car: testCar, vendor: testVendor),
                ),
              );
            },
          ),
        ),
      );

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            pickupName: 'Chhatrapati Shivaji Int Airport (BOM T2)',
            pickupAddress: 'CSMIA Terminal 2 Arrivals, Sahar Road',
            pickupHubId: 'pub_mum_csmia',
            pickupFee: 150.0,
            deliveryType: 'PUBLIC_LOCATION',
          ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '06_fulfillment_airport_transit_point.png');
    });

    testWidgets('07_fulfillment_doorstep_delivery.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Doorstep Delivery Configured')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: FulfillmentSelectionCard(car: testCar, vendor: testVendor),
                ),
              );
            },
          ),
        ),
      );

      // Tap Doorstep chip
      await tester.tap(find.text('Doorstep'));
      await tester.pump(const Duration(milliseconds: 200));

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            hasDoorstepDelivery: true,
            deliveryAddress: 'Flat 402, Sea Green Apts, Worli Sea Face, Mumbai',
            deliveryFee: 350.0,
            quoteDistanceKm: 12.5,
          ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '07_fulfillment_doorstep_delivery.png');
    });

    testWidgets('08_fulfillment_different_return_branch.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Different Return Branch')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: FulfillmentSelectionCard(car: testCar, vendor: testVendor),
                ),
              );
            },
          ),
        ),
      );

      // Uncheck same location toggle
      await tester.tap(find.text('Return to same location as pickup (Free)'));
      await tester.pump(const Duration(milliseconds: 200));

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            isDifferentReturnLocation: true,
            dropName: 'Bandra Kurla Complex Branch',
            returnHubId: 'hub_bkc_branch',
            deliveryAddress: 'G Block, BKC, Bandra East, Mumbai',
            oneWayFee: 250.0,
          ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '08_fulfillment_different_return_branch.png');
    });

    testWidgets('09_fulfillment_bothway_doorstep.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Both-Way Doorstep Handover')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: FulfillmentSelectionCard(car: testCar, vendor: testVendor),
                ),
              );
            },
          ),
        ),
      );

      // Tap Doorstep for pickup
      await tester.tap(find.text('Doorstep'));
      await tester.pump(const Duration(milliseconds: 200));

      // Uncheck same location
      await tester.tap(find.text('Return to same location as pickup (Free)'));
      await tester.pump(const Duration(milliseconds: 200));

      // Select Collection
      await tester.tap(find.text('Collection'));
      await tester.pump(const Duration(milliseconds: 200));

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            hasDoorstepDelivery: true,
            hasDoorstepPickup: true,
            deliveryAddress: 'Flat 402, Sea Green Apts, Worli, Mumbai',
            returnPickupAddress: 'Villa 12, Palm Meadows, Powai, Mumbai',
            deliveryFee: 350.0,
            returnPickupFee: 350.0,
            quoteDistanceKm: 14.0,
          ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '09_fulfillment_bothway_doorstep.png');
    });

    testWidgets('10_fare_breakdown_itemized_fulfillment.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      const fareResult = FareCalculatorResult(
        baseFare: 3000.0,
        platformFee: 300.0,
        gst: 594.0,
        total: 3894.0,
        netToVendor: 2700.0,
      );

      final config = CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Itemized Fare Breakdown')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: BookingPriceBreakdownCard(
                    car: testCar,
                    vendor: testVendor,
                    originalRentalFare: 3000.0,
                    discountPercent: 10.0,
                    discountLabel: '10% Multi-day Discount',
                    discountAmount: 300.0,
                    result: fareResult,
                    finalPayable: 4894.0,
                    config: config,
                  ),
                ),
              );
            },
          ),
        ),
      );

      container.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            deliveryFee: 350.0,
            returnPickupFee: 250.0,
            pickupFee: 100.0,
            returnFee: 150.0,
            oneWayFee: 200.0,
          ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '10_fare_breakdown_itemized_fulfillment.png');
    });

    testWidgets('11_payment_step_locked_pricing.png', (tester) async {
      final key = GlobalKey();
      late ProviderContainer container;

      await tester.pumpWidget(
        createSubject(
          key: key,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                appBar: AppBar(title: const Text('Payment Confirmation')),
                body: PaymentStep(
                  onBack: () {},
                  onSuccess: (_) {},
                ),
              );
            },
          ),
        ),
      );

      container.read(bookingDraftProvider.notifier).init(
            car: testCar,
            vendorId: 'v1',
            tripType: 'Self-Drive',
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '11_payment_step_locked_pricing.png');
    });

    testWidgets('12_booking_confirmation_immutable_snapshot.png', (tester) async {
      final key = GlobalKey();
      final mockRepo = MockFulfillmentCaptureRepository();
      final mockBooking = await mockRepo.getBookingById('BK_CONFIRMED_999');

      await tester.pumpWidget(
        createSubject(
          key: key,
          overrides: [
            bookingWithDetailsProvider('BK_CONFIRMED_999').overrideWith(
              (ref) => BookingWithDetails(
                booking: mockBooking!,
                car: testCar,
                vendor: testVendor,
              ),
            ),
          ],
          child: const BookingConfirmationPage(bookingId: 'BK_CONFIRMED_999'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, key, '12_booking_confirmation_immutable_snapshot.png');
    });
  });
}
