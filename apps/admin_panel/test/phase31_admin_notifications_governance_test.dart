import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/notifications/presentation/pages/push_notifications_page.dart';
import 'package:admin_panel/features/notifications/presentation/providers/admin_notifications_providers.dart';
import 'package:admin_panel/features/notifications/domain/repositories/admin_notifications_repository.dart';

class FakeAdminNotificationsRepo implements AdminNotificationsRepository {
  final List<NotificationDeliveryModel> deliveries;
  final Map<String, dynamic> stats;
  bool retryCalled = false;
  String? retriedId;

  FakeAdminNotificationsRepo({
    required this.deliveries,
    required this.stats,
  });

  @override
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  }) async {}

  @override
  Future<List<SentNotification>> getSentHistory() async => [];

  @override
  Future<List<NotificationDeliveryModel>> getDeliveries({
    String? status,
    String? channel,
    int limit = 50,
    int offset = 0,
  }) async {
    return deliveries.where((d) {
      if (status != null && status != 'ALL' && d.status != status) return false;
      if (channel != null && channel != 'ALL' && d.channel != channel) return false;
      return true;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryStats() async => stats;

  @override
  Future<void> retryDelivery(String deliveryId) async {
    retryCalled = true;
    retriedId = deliveryId;
  }
}

class _MockAdminDeliveriesNotifier extends AdminDeliveriesNotifier {
  final FakeAdminNotificationsRepo repo;

  _MockAdminDeliveriesNotifier(this.repo);

  @override
  Future<List<NotificationDeliveryModel>> build() async {
    final status = ref.watch(notificationDeliveryStatusFilterProvider);
    final channel = ref.watch(notificationDeliveryChannelFilterProvider);
    return repo.getDeliveries(status: status, channel: channel);
  }

  @override
  Future<void> retry(String deliveryId) async {
    await repo.retryDelivery(deliveryId);
    ref.invalidateSelf();
  }
}

void main() {
  group('Phase 31: Admin Notification Governance & Telemetry Control Tower', () {
    final sampleDeliveries = [
      NotificationDeliveryModel(
        id: 'del-01',
        notificationId: 'notif-101',
        channel: 'PUSH',
        status: 'DELIVERED',
        provider: 'FIREBASE_FCM',
        providerMessageId: 'fcm_msg_101',
        recipientTarget: 'token_cust_01',
        recipientName: 'Arjun Mehta',
        notificationTitle: 'Booking Confirmed: Mahindra Thar',
        eventType: 'BOOKING_CONFIRMED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      NotificationDeliveryModel(
        id: 'del-02',
        notificationId: 'notif-102',
        channel: 'SMS',
        status: 'FAILED',
        provider: 'TWILIO_REST',
        recipientTarget: '+919876543210',
        recipientName: 'Vikram Rao',
        notificationTitle: 'Urgent Handover Ready',
        eventType: 'HANDOVER_READY',
        attemptCount: 2,
        maxRetries: 3,
        lastError: 'HTTP 504: Gateway Timeout',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      NotificationDeliveryModel(
        id: 'del-03',
        notificationId: 'notif-103',
        channel: 'PUSH',
        status: 'DEAD_LETTER',
        provider: 'FIREBASE_FCM',
        recipientTarget: 'token_expired_99',
        recipientName: 'Pooja Sharma',
        notificationTitle: 'Refund Processed',
        eventType: 'REFUND_PROCESSED',
        attemptCount: 3,
        maxRetries: 3,
        lastError: 'messaging/registration-token-not-registered',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final sampleStats = {
      'total': 150,
      'delivered': 142,
      'failed': 5,
      'deadLetter': 3,
      'successRate': 94.67,
    };

    testWidgets('Renders KPI metrics cards and delivery telemetry table with status badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeAdminNotificationsRepo(
        deliveries: sampleDeliveries,
        stats: sampleStats,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            adminDeliveryStatsProvider.overrideWith((ref) => Future.value(sampleStats)),
            adminDeliveriesProvider.overrideWith(() => _MockAdminDeliveriesNotifier(fakeRepo)),
          ],
          child: const MaterialApp(
            home: PushNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Notification Operations & Control Tower'), findsOneWidget);
      expect(find.text('Delivery Telemetry & Governance'), findsOneWidget);

      // KPI Metric Cards
      expect(find.text('150'), findsOneWidget); // Total
      expect(find.text('142'), findsOneWidget); // Delivered
      expect(find.text('5'), findsOneWidget); // Failed
      expect(find.text('3'), findsOneWidget); // Dead letter
      expect(find.text('94.7%'), findsOneWidget); // Success rate rounded

      // Delivery items
      expect(find.text('Booking Confirmed: Mahindra Thar'), findsOneWidget);
      expect(find.text('Urgent Handover Ready'), findsOneWidget);
      expect(find.text('Refund Processed'), findsOneWidget);
      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('DEAD_LETTER'), findsOneWidget);
    });

    testWidgets('Allows admin to retry failed delivery directly from governance dashboard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeAdminNotificationsRepo(
        deliveries: sampleDeliveries,
        stats: sampleStats,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            adminDeliveryStatsProvider.overrideWith((ref) => Future.value(sampleStats)),
            adminDeliveriesProvider.overrideWith(() => _MockAdminDeliveriesNotifier(fakeRepo)),
          ],
          child: const MaterialApp(
            home: PushNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final retryBtn = find.byKey(const Key('retry_btn_del-02'));
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.retryCalled, isTrue);
      expect(fakeRepo.retriedId, 'del-02');
    });
  });
}
