import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';

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

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase29-15-vendor-fulfillment');

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.runAsync(() async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${evidenceDir.path}/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[EVIDENCE_CAPTURED] ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime.now();

  final hostYardBooking = BookingModel(
    id: 'bk_mock_host_yard',
    customerId: 'cust_hy_01',
    vendorId: 'v_test',
    carId: 'car_hy_01',
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

  final doorstepBooking = BookingModel(
    id: 'bk_mock_doorstep',
    customerId: 'cust_ds_02',
    vendorId: 'v_test',
    carId: 'car_hy_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Main Operating Yard, Andheri East',
    dropLocation: 'Main Operating Yard, Andheri East',
    pickupName: 'Customer Doorstep Address',
    deliveryAddress: 'Flat 602, Sea Breeze Towers, Worli Sea Face, Mumbai',
    deliveryLatitude: 19.0178,
    deliveryLongitude: 72.8178,
    startDate: now.add(const Duration(hours: 4)),
    endDate: now.add(const Duration(days: 3)),
    totalFare: 6850.0,
    platformFee: 600.0,
    gstAmount: 1100.0,
    netToVendor: 5250.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 5)),
    deliveryType: 'DOORSTEP_DELIVERY',
    pickupHubId: 'hub_main_yard',
    deliveryFee: 450.0,
    pickupFee: 0.0,
    returnFee: 0.0,
    oneWayFee: 0.0,
  );

  final transitHubBooking = BookingModel(
    id: 'bk_mock_transit_hub',
    customerId: 'cust_th_03',
    vendorId: 'v_test',
    carId: 'car_hy_01',
    tripType: 'Airport Transfer',
    pickupLocation: 'CSMIA Terminal 2 (BOM)',
    dropLocation: 'CSMIA Terminal 2 (BOM)',
    pickupName: 'Chhatrapati Shivaji Maharaj International Airport (BOM)',
    pickupAddress: 'Terminal 2 Arrivals, Level 1 Pick-up Zone, Andheri East, Mumbai',
    pickupLatitude: 19.0896,
    pickupLongitude: 72.8656,
    startDate: now.add(const Duration(hours: 1)),
    endDate: now.add(const Duration(days: 1)),
    totalFare: 3800.0,
    platformFee: 350.0,
    gstAmount: 620.0,
    netToVendor: 3450.0,
    status: 'confirmed',
    createdAt: now.subtract(const Duration(hours: 2)),
    deliveryType: 'PUBLIC_LOCATION',
    pickupHubId: 'pub_mum_csmia',
    returnHubId: 'pub_mum_csmia',
    deliveryFee: 0.0,
    pickupFee: 200.0,
    returnFee: 200.0,
    oneWayFee: 0.0,
  );

  final diffReturnBooking = BookingModel(
    id: 'bk_mock_diff_return',
    customerId: 'cust_dr_04',
    vendorId: 'v_test',
    carId: 'car_hy_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Andheri East Main Yard',
    dropLocation: 'Bandra Kurla Complex Branch',
    pickupName: 'Andheri East Main Yard',
    dropName: 'Bandra Kurla Complex Branch',
    pickupAddress: 'Plot 42, Andheri-Kurla Road, Mumbai',
    pickupLatitude: 19.1136,
    pickupLongitude: 72.8697,
    deliveryAddress: 'G-Block, BKC Urban Hub, Bandra East, Mumbai',
    deliveryLatitude: 19.0664,
    deliveryLongitude: 72.8679,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 2)),
    totalFare: 7400.0,
    platformFee: 700.0,
    gstAmount: 1200.0,
    netToVendor: 5500.0,
    status: 'ongoing',
    createdAt: now.subtract(const Duration(days: 2)),
    deliveryType: 'HUB_PICKUP',
    pickupHubId: 'hub_andheri',
    returnHubId: 'hub_bkc',
    deliveryFee: 0.0,
    pickupFee: 0.0,
    returnFee: 150.0,
    oneWayFee: 350.0,
  );

  final combinedBooking = BookingModel(
    id: 'bk_mock_combined',
    customerId: 'cust_cb_07',
    vendorId: 'v_test',
    carId: 'car_hy_01',
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
    status: 'ongoing',
    createdAt: now.subtract(const Duration(hours: 8)),
    deliveryType: 'DOORSTEP_DELIVERY',
    pickupHubId: 'hub_powai',
    returnHubId: 'hub_vashi',
    deliveryFee: 500.0,
    pickupFee: 0.0,
    returnFee: 200.0,
    oneWayFee: 400.0,
  );

  final testCars = [
    const CarModel(
      id: 'car_hy_01',
      vendorId: 'v_test',
      make: 'Hyundai',
      model: 'Creta SX',
      year: 2024,
      type: 'SUV',
      fuelType: 'Petrol',
      seating: 5,
      isAC: true,
      pricePerKm: 12.0,
      pricePerDay: 2500.0,
      pricePerHour: 150.0,
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      registrationNumber: 'MH 02 EK 1234',
    ),
  ];

  late MockVendorBookingsRepository mockRepo;

  setUp(() {
    mockRepo = MockVendorBookingsRepository();
    mockRepo.resetMockState();
    mockRepo.addMockBookings([
      hostYardBooking,
      doorstepBooking,
      transitHubBooking,
      diffReturnBooking,
      combinedBooking,
    ]);
  });

  Widget createSubject({
    required Widget child,
    required BookingModel booking,
    required GlobalKey key,
  }) {
    return ProviderScope(
      overrides: [
        vendorBookingsRepositoryProvider.overrideWithValue(mockRepo),
        vendorBookingsProvider.overrideWith(
          () => MockVendorBookingsNotifier([
            hostYardBooking,
            doorstepBooking,
            transitHubBooking,
            diffReturnBooking,
            combinedBooking,
          ]),
        ),
        singleBookingProvider(booking.id).overrideWith((ref) => Future.value(booking)),
        bookingInspectionsProvider(booking.id).overrideWith((ref) => Future.value([])),
        bookingDamageClaimsProvider(booking.id).overrideWith((ref) => Future.value([])),
        vendorBookingEmergencyProvider(booking.id).overrideWith((ref) => Future.value(null)),
        vendorSessionProvider.overrideWith(
          () => FastSessionNotifier(
            const VendorModel(
              id: 'v_test',
              businessName: 'Apex Fleet Hub',
              ownerName: 'Vikram',
              phone: '9876543210',
              city: 'Mumbai',
            ),
          ),
        ),
        fleetCarsProvider.overrideWith((ref) => Future<List<CarModel>>.value(testCars)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('01_host_yard_booking_detail.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: hostYardBooking,
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_host_yard'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '01_host_yard_booking_detail.png');
  });

  testWidgets('02_doorstep_booking_detail.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: doorstepBooking,
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_doorstep'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '02_doorstep_booking_detail.png');
  });

  testWidgets('03_transit_hub_booking_detail.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: transitHubBooking,
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_transit_hub'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '03_transit_hub_booking_detail.png');
  });

  testWidgets('04_relocation_return_detail.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: diffReturnBooking,
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_diff_return'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '04_relocation_return_detail.png');
  });

  testWidgets('05_handover_wizard_manifest.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: hostYardBooking,
        key: key,
        child: const HandoverInspectionPage(bookingId: 'bk_mock_host_yard', initialStep: 0),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '05_handover_wizard_manifest.png');
  });

  testWidgets('06_handover_wizard_review_otp.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: hostYardBooking,
        key: key,
        child: const HandoverInspectionPage(bookingId: 'bk_mock_host_yard', initialStep: 4),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '06_handover_wizard_review_otp.png');
  });

  testWidgets('07_return_wizard_review_otp.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: diffReturnBooking,
        key: key,
        child: const ReturnInspectionPage(bookingId: 'bk_mock_diff_return', initialStep: 3),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '07_return_wizard_review_otp.png');
  });

  testWidgets('08_combined_doorstep_and_branch_return.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        booking: combinedBooking,
        key: key,
        child: const ReturnInspectionPage(bookingId: 'bk_mock_combined', initialStep: 0),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '08_combined_doorstep_and_branch_return.png');
  });
}
