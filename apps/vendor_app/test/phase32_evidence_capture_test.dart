import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:vendor_app/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:vendor_app/features/notifications/domain/repositories/vendor_notifications_repository.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase32');

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${evidenceDir.path}/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[PHASE_32_EVIDENCE] Saved ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

class FakeVendorRepo implements VendorNotificationsRepository {
  final List<NotificationModel> items;
  FakeVendorRepo(this.items);
  @override
  Future<List<NotificationModel>> getNotifications(String vendorUserId) async => items;
  @override
  Future<void> markAllRead(String vendorUserId) async {}
  @override
  Future<void> markAsRead(String notificationId) async {}
}

class _MockVendorNotifier extends VendorNotificationsNotifier {
  final List<NotificationModel> initialData;
  _MockVendorNotifier(this.initialData);
  @override
  Future<List<NotificationModel>> build() async => initialData;
}

void main() {
  setUpAll(() async {
    DDSTypography.useSystemFallbackInTests = true;
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }
  });

  group('Phase 32 Vendor Visual Evidence Capture Suite', () {
    final vendorItems = [
      NotificationModel(
        id: 'vnd-notif-p32-01',
        userId: 'vnd_01',
        title: 'New Booking Assigned: Mahindra Thar 4x4 (TS09EA1234)',
        body: 'Booking BK_8902 has been confirmed by customer. Prepare vehicle for handover at City Hub.',
        type: 'booking',
        category: 'BOOKING',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK_8902',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NotificationModel(
        id: 'vnd-notif-p32-02',
        userId: 'vnd_01',
        title: 'Handover Ready: Customer Arriving (OTP Required)',
        body: 'Customer Rajesh Kumar arriving in 15 mins. Check-in inspection checklist ready for digital sign-off.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'HANDOVER_READY',
        entityType: 'BOOKING',
        entityId: 'BK_8902',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      NotificationModel(
        id: 'vnd-notif-p32-03',
        userId: 'vnd_01',
        title: 'Return Inspection Pending: Hyundai Creta (KA01MJ4921)',
        body: 'Trip for BK_8801 concluding at Bangalore Airport. Conduct 360 return inspection before refund clearance.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'RETURN_PENDING',
        entityType: 'BOOKING',
        entityId: 'BK_8801',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        id: 'vnd-notif-p32-04',
        userId: 'vnd_01',
        title: 'Escrow Settlement Released: ₹18,500.00 Credited',
        body: 'Rental period concluded for booking BK_8801. Escrow quarantine lifted and funds moved to payout balance.',
        type: 'payout',
        category: 'PAYMENT',
        eventType: 'SETTLEMENT_ELIGIBLE',
        entityType: 'PAYMENT',
        entityId: 'pay_vnd_8801',
        priority: 'NORMAL',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];

    testWidgets('Capture 05 & 06: Vendor Alert Center and Payout/Escrow Filter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = GlobalKey();
      final fakeRepo = FakeVendorRepo(vendorItems);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            vendorNotificationsProvider.overrideWith(() => _MockVendorNotifier(vendorItems)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const VendorNotificationsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 05: Vendor alert center
      await saveScreenshot(tester, boundaryKey, '05_vendor_notifications_realtime_center.png');

      // Tap 'Payouts & Escrow' filter
      await tester.tap(find.byKey(const Key('vendor_filter_payouts')));
      await tester.pumpAndSettle();

      // 06: Payouts filter
      await saveScreenshot(tester, boundaryKey, '06_vendor_notifications_payout_escrow.png');
    });

    testWidgets('Capture 07: Vendor Empty State Refreshable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = GlobalKey();
      final fakeRepo = FakeVendorRepo([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            vendorNotificationsProvider.overrideWith(() => _MockVendorNotifier([])),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const VendorNotificationsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 07: Empty refreshable
      await saveScreenshot(tester, boundaryKey, '07_vendor_notifications_empty_refreshable.png');
    });
  });
}
