import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/features/notifications/domain/repositories/notifications_repository.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  final List<NotificationModel> items;
  bool markAllReadCalled = false;
  String? markedReadId;

  FakeNotificationsRepository(this.items);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    return items;
  }

  @override
  Future<void> markAllRead(String userId) async {
    markAllReadCalled = true;
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markedReadId = notificationId;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == notificationId) {
        items[i] = items[i].copyWith(isRead: true);
        break;
      }
    }
  }
}

void main() {
  group('Phase 31: Customer Multi-Channel Operational Notifications', () {
    test('NotificationModel parses operational metadata correctly', () {
      final json = {
        'id': 'notif-p31-01',
        'userId': 'usr_cust_01',
        'title': 'Booking Confirmed: Mahindra Thar',
        'body': 'Your booking BK_1001 is confirmed.',
        'type': 'booking',
        'category': 'BOOKING',
        'eventType': 'BOOKING_CONFIRMED',
        'entityType': 'BOOKING',
        'entityId': 'BK_1001',
        'actionUrl': '/my-bookings/BK_1001',
        'priority': 'NORMAL',
        'isRead': false,
        'createdAt': '2026-09-05T10:00:00.000Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.id, 'notif-p31-01');
      expect(model.category, 'BOOKING');
      expect(model.eventType, 'BOOKING_CONFIRMED');
      expect(model.entityType, 'BOOKING');
      expect(model.entityId, 'BK_1001');
      expect(model.actionUrl, '/my-bookings/BK_1001');
      expect(model.priority, 'NORMAL');
      expect(model.isRead, false);
    });

    testWidgets('Renders operational notification cards with category badges and urgent tags', (tester) async {
      final sampleItems = [
        NotificationModel(
          id: 'n1',
          userId: 'usr_cust_01',
          title: 'Booking Confirmed: Mahindra Thar',
          body: 'Your reservation BK_1001 is confirmed.',
          category: 'BOOKING',
          eventType: 'BOOKING_CONFIRMED',
          entityType: 'BOOKING',
          entityId: 'BK_1001',
          priority: 'NORMAL',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'n2',
          userId: 'usr_cust_01',
          title: 'Handover Ready: Vehicle Inspection',
          body: 'Vehicle is ready at Hub. Urgent pick-up required.',
          category: 'FULFILLMENT',
          eventType: 'HANDOVER_READY',
          entityType: 'BOOKING',
          entityId: 'BK_1001',
          priority: 'HIGH',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'n3',
          userId: 'usr_cust_01',
          title: '15% Off Monsoon Trip',
          body: 'Use code MONSOON15 at checkout.',
          category: 'PROMOTION',
          priority: 'LOW',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final fakeRepo = FakeNotificationsRepository(sampleItems);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(fakeRepo),
            notificationsListProvider.overrideWith(() => _MockNotifier(sampleItems)),
          ],
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check operational headers and badges
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Booking Confirmed: Mahindra Thar'), findsOneWidget);
      expect(find.text('Handover Ready: Vehicle Inspection'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('BOOKING'), findsOneWidget);
      expect(find.text('FULFILLMENT'), findsOneWidget);
      expect(find.text('PROMOTION'), findsOneWidget);

      // Tap filter chip "Operational"
      await tester.tap(find.byKey(const Key('notifications_filter_operational')));
      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed: Mahindra Thar'), findsOneWidget);
      expect(find.text('Handover Ready: Vehicle Inspection'), findsOneWidget);
      expect(find.text('15% Off Monsoon Trip'), findsNothing);

      // Tap filter chip "Promotions"
      await tester.tap(find.byKey(const Key('notifications_filter_promotions')));
      await tester.pumpAndSettle();

      expect(find.text('15% Off Monsoon Trip'), findsOneWidget);
      expect(find.text('Booking Confirmed: Mahindra Thar'), findsNothing);
    });

    testWidgets('Mark all read invokes repository method', (tester) async {
      final sampleItems = [
        NotificationModel(
          id: 'n1',
          userId: 'usr_cust_01',
          title: 'Payment Captured: ₹4,500.00',
          body: 'Payment for booking BK_1001 was successful.',
          category: 'PAYMENT',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final fakeRepo = FakeNotificationsRepository(sampleItems);
      final notifier = _MockNotifier(sampleItems, repo: fakeRepo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(fakeRepo),
            notificationsListProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification_mark_all_read')), findsOneWidget);

      await tester.tap(find.byKey(const Key('notification_mark_all_read')));
      await tester.pumpAndSettle();

      expect(fakeRepo.markAllReadCalled, isTrue);
    });
  });
}

class _MockNotifier extends NotificationsListNotifier {
  final List<NotificationModel> initialData;
  final FakeNotificationsRepository? repo;

  _MockNotifier(this.initialData, {this.repo});

  @override
  Future<List<NotificationModel>> build() async {
    return List.from(initialData);
  }

  @override
  Future<void> markAllAsRead() async {
    if (repo != null) {
      await repo!.markAllRead('usr_cust_01');
    }
    state = AsyncValue.data(state.value?.map((n) => n.copyWith(isRead: true)).toList() ?? []);
  }

  @override
  Future<void> markAsRead(String id) async {
    if (repo != null) {
      await repo!.markAsRead(id);
    }
    state = AsyncValue.data(state.value?.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList() ?? []);
  }
}
