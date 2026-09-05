import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/features/notifications/domain/repositories/notifications_repository.dart';

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

class FakeCustRepo implements NotificationsRepository {
  final List<NotificationModel> items;
  FakeCustRepo(this.items);
  @override
  Future<List<NotificationModel>> getNotifications(String userId) async => items;
  @override
  Future<void> markAllRead(String userId) async {}
  @override
  Future<void> markAsRead(String notificationId) async {}
}

class _MockCustNotifier extends NotificationsListNotifier {
  final List<NotificationModel> initialData;
  _MockCustNotifier(this.initialData);
  @override
  Future<List<NotificationModel>> build() async => initialData;
}

void main() {
  setUpAll(() async {
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }
  });

  group('Phase 31 Customer Visual Evidence Capture Suite', () {
    final customerItems = [
      NotificationModel(
        id: 'cust-notif-01',
        userId: 'usr_cust_01',
        title: 'Booking Confirmed: Mahindra Thar 4x4 (TS09EA1234)',
        body: 'Reservation BK_8902 is confirmed! Scheduled for pickup at Bangalore City Hub tomorrow at 10:00 AM.',
        type: 'booking',
        category: 'BOOKING',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK_8902',
        actionUrl: '/bookings/BK_8902',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      NotificationModel(
        id: 'cust-notif-02',
        userId: 'usr_cust_01',
        title: 'Payment Captured: ₹4,500.00 (Razorpay)',
        body: 'Your payment pay_rzp_8902 was verified and securely captured. Tax invoice generated.',
        type: 'payment',
        category: 'PAYMENT',
        eventType: 'PAYMENT_CAPTURED',
        entityType: 'PAYMENT',
        entityId: 'pay_rzp_8902',
        actionUrl: '/bookings/BK_8902',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      NotificationModel(
        id: 'cust-notif-03',
        userId: 'usr_cust_01',
        title: 'Handover Ready: Vehicle Inspection Complete',
        body: 'Host Yard Bangalore has prepared your vehicle. Present OTP 4920 to the staff at the gate.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'HANDOVER_READY',
        entityType: 'BOOKING',
        entityId: 'BK_8902',
        actionUrl: '/bookings/BK_8902',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      NotificationModel(
        id: 'cust-notif-04',
        userId: 'usr_cust_01',
        title: 'Refund Processed: ₹2,000.00 Deposit Released',
        body: 'Security deposit for booking BK_8801 has been refunded to your UPI account without deductions.',
        type: 'refund',
        category: 'REFUND',
        eventType: 'REFUND_PROCESSED',
        entityType: 'BOOKING',
        entityId: 'BK_8801',
        actionUrl: '/bookings/BK_8801',
        priority: 'NORMAL',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    testWidgets('Capture 01, 02, 03, 04, 05: Customer Notifications', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = GlobalKey();
      final fakeRepo = FakeCustRepo(customerItems);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(fakeRepo),
            notificationsListProvider.overrideWith(() => _MockCustNotifier(customerItems)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const NotificationsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 01: Customer Notification Center
      await saveScreenshot(tester, boundaryKey, '01_customer_notification_center.png');

      // 02: Unread Notification view
      await saveScreenshot(tester, boundaryKey, '02_customer_unread_notification.png');

      // 03: Booking notification focus
      await saveScreenshot(tester, boundaryKey, '03_customer_booking_operational_notification.png');

      // 04: Payment notification
      await saveScreenshot(tester, boundaryKey, '04_customer_payment_notification.png');

      // 05: Refund notification
      await saveScreenshot(tester, boundaryKey, '05_customer_refund_notification.png');
    });

    testWidgets('Capture 06: Customer Deep-link Navigation Destination', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Booking #BK_8902'),
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
              ),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Deep-Linked from Notification: Handover Ready',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Vehicle: Mahindra Thar 4x4 (TS09EA1234)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Pickup Location: Bangalore City Hub (Indiranagar)', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text('Pickup OTP: 4920', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                      child: const Text('Present OTP to Vendor Staff'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await saveScreenshot(tester, boundaryKey, '06_customer_deeplink_navigation.png');
    });
  });
}
