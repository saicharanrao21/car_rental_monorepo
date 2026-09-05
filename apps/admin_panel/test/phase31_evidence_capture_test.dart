import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/notifications/presentation/pages/push_notifications_page.dart';
import 'package:admin_panel/features/notifications/presentation/providers/admin_notifications_providers.dart';
import 'package:admin_panel/features/notifications/domain/repositories/admin_notifications_repository.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase31');

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
      print('[PHASE_31_EVIDENCE] Saved ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

class FakeAdminRepo implements AdminNotificationsRepository {
  final List<NotificationDeliveryModel> deliveries;
  final Map<String, dynamic> stats;
  FakeAdminRepo(this.deliveries, this.stats);
  @override
  Future<void> sendNotification({required String target, required String title, required String body}) async {}
  @override
  Future<List<SentNotification>> getSentHistory() async => [];
  @override
  Future<List<NotificationDeliveryModel>> getDeliveries({String? status, String? channel, int limit = 50, int offset = 0}) async => deliveries;
  @override
  Future<Map<String, dynamic>> getDeliveryStats() async => stats;
  @override
  Future<void> retryDelivery(String deliveryId) async {}
}

class _MockAdminDeliveriesNotifier extends AdminDeliveriesNotifier {
  final List<NotificationDeliveryModel> initialData;
  _MockAdminDeliveriesNotifier(this.initialData);
  @override
  Future<List<NotificationDeliveryModel>> build() async => initialData;
}

void main() {
  setUpAll(() async {
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }
  });

  group('Phase 31 Admin Visual Evidence Capture Suite', () {
    final adminDeliveries = [
      NotificationDeliveryModel(
        id: 'del-01',
        notificationId: 'notif-101',
        channel: 'PUSH',
        status: 'DELIVERED',
        provider: 'FIREBASE_FCM',
        providerMessageId: 'fcm_msg_proj_89201a',
        recipientTarget: 'token_cust_android_8902',
        recipientName: 'Arjun Mehta',
        notificationTitle: 'Booking Confirmed: Mahindra Thar',
        eventType: 'BOOKING_CONFIRMED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 9)),
        deliveredAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
      NotificationDeliveryModel(
        id: 'del-02',
        notificationId: 'notif-101',
        channel: 'SMS',
        status: 'DELIVERED',
        provider: 'TWILIO_REST',
        providerMessageId: 'SM9283719028301293',
        recipientTarget: '+919876543210',
        recipientName: 'Arjun Mehta',
        notificationTitle: 'Booking Confirmed: Mahindra Thar',
        eventType: 'BOOKING_CONFIRMED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 9)),
        deliveredAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
      NotificationDeliveryModel(
        id: 'del-03',
        notificationId: 'notif-101',
        channel: 'WHATSAPP',
        status: 'DELIVERED',
        provider: 'META_CLOUD_API',
        providerMessageId: 'wamid.HBgMOTE5ODc2NTQzMjEwFQIA',
        recipientTarget: '+919876543210',
        recipientName: 'Arjun Mehta',
        notificationTitle: 'Booking Confirmed: Mahindra Thar',
        eventType: 'BOOKING_CONFIRMED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 9)),
        deliveredAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
      NotificationDeliveryModel(
        id: 'del-04',
        notificationId: 'notif-102',
        channel: 'EMAIL',
        status: 'DELIVERED',
        provider: 'AWS_SES_SMTP',
        providerMessageId: '01000189a-f9e4210a-000000',
        recipientTarget: 'arjun.mehta@drivego.in',
        recipientName: 'Arjun Mehta',
        notificationTitle: 'Payment Receipt: ₹4,500.00',
        eventType: 'PAYMENT_CAPTURED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 29)),
        deliveredAt: DateTime.now().subtract(const Duration(minutes: 29)),
      ),
      NotificationDeliveryModel(
        id: 'del-05',
        notificationId: 'notif-103',
        channel: 'SMS',
        status: 'FAILED',
        provider: 'TWILIO_REST',
        recipientTarget: '+919123456780',
        recipientName: 'Vikram Rao (Vendor)',
        notificationTitle: 'Urgent Handover Ready',
        eventType: 'HANDOVER_READY',
        attemptCount: 2,
        maxRetries: 3,
        lastError: 'HTTP 504: Gateway Timeout from Carrier Relay',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 50)),
        failedAt: DateTime.now().subtract(const Duration(minutes: 50)),
      ),
      NotificationDeliveryModel(
        id: 'del-06',
        notificationId: 'notif-104',
        channel: 'PUSH',
        status: 'DEAD_LETTER',
        provider: 'FIREBASE_FCM',
        recipientTarget: 'token_unregistered_vendor_99',
        recipientName: 'Pooja Sharma',
        notificationTitle: 'Refund Processed: ₹2,000.00',
        eventType: 'REFUND_PROCESSED',
        attemptCount: 3,
        maxRetries: 3,
        lastError: 'messaging/registration-token-not-registered: Revoked device',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        failedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    final adminStats = {
      'total': 248,
      'delivered': 234,
      'failed': 8,
      'deadLetter': 4,
      'successRate': 94.35,
    };

    testWidgets('Capture 10: Admin Notification Delivery Governance Control Tower', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = GlobalKey();
      final fakeRepo = FakeAdminRepo(adminDeliveries, adminStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            adminDeliveryStatsProvider.overrideWith((ref) => Future.value(adminStats)),
            adminDeliveriesProvider.overrideWith(() => _MockAdminDeliveriesNotifier(adminDeliveries)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const PushNotificationsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 10: Admin Notification Delivery Governance
      await saveScreenshot(tester, boundaryKey, '10_admin_notification_governance.png');
    });
  });
}
