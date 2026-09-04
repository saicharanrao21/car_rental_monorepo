import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/data/mock_fleet_repository.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:core/core.dart';

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

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase29-16-location-fulfillment');

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
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  late FastVendorBookingsRepository repo;

  const testVendor = VendorModel(
    id: 'v_test',
    businessName: 'DriveGo Test Fleet',
    ownerName: 'Test Owner',
    email: 'test@example.com',
    phone: '+919876543210',
    city: 'Mumbai',
    verificationStatus: 'VERIFIED',
  );

  setUp(() {
    repo = FastVendorBookingsRepository();
  });

  Widget createSubject({
    required Widget child,
    required GlobalKey key,
    required String bookingId,
  }) {
    return ProviderScope(
      overrides: [
        vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
        vendorBookingsRepositoryProvider.overrideWithValue(repo),
        fleetRepositoryProvider.overrideWithValue(FastFleetRepository()),
        dashboardRepositoryProvider.overrideWithValue(FastDashboardRepository()),
        bookingInspectionsProvider(bookingId).overrideWith((ref) => repo.getInspections(bookingId)),
        bookingDamageClaimsProvider(bookingId).overrideWith((ref) => repo.getDamageClaims(bookingId)),
        vendorBookingEmergencyProvider(bookingId).overrideWith((ref) => null),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Inter',
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

  testWidgets('01_host_yard_lifecycle.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_host_yard',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_host_yard'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '01_host_yard_lifecycle.png');
  });

  testWidgets('02_doorstep_dispatch.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_doorstep',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_doorstep'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '02_doorstep_dispatch.png');
  });

  testWidgets('03_doorstep_collection_return.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_host_pickup_doorstep_return',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_host_pickup_doorstep_return'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '03_doorstep_collection_return.png');
  });

  testWidgets('04_transit_hub_lifecycle.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_transit_hub',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_transit_hub'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '04_transit_hub_lifecycle.png');
  });

  testWidgets('05_branch_relocation_return.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_diff_return',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_diff_return'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '05_branch_relocation_return.png');
  });

  testWidgets('06_combined_doorstep_branch_return.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_combined',
        key: key,
        child: const VendorBookingDetailPage(bookingId: 'bk_mock_combined'),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '06_combined_doorstep_branch_return.png');
  });

  testWidgets('07_handover_location_banner.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_host_yard',
        key: key,
        child: const HandoverInspectionPage(bookingId: 'bk_mock_host_yard', initialStep: 0),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '07_handover_location_banner.png');
  });

  testWidgets('08_return_location_banner.png', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      createSubject(
        bookingId: 'bk_mock_diff_return',
        key: key,
        child: const ReturnInspectionPage(bookingId: 'bk_mock_diff_return', initialStep: 0),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, key, '08_return_location_banner.png');
  });
}
