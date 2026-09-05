import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/features/notifications/domain/repositories/notifications_repository.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<NotificationModel> items;
  bool markAllReadCalled = false;
  String? markedReadId;
  int fetchCallCount = 0;

  MockNotificationsRepository(this.items);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    fetchCallCount++;
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

class _TestNotifier extends NotificationsListNotifier {
  final List<NotificationModel> initialData;
  int refreshCallCount = 0;

  _TestNotifier(this.initialData);

  @override
  Future<List<NotificationModel>> build() async {
    return List.from(initialData);
  }

  @override
  Future<void> refresh() async {
    refreshCallCount++;
    state = AsyncValue.data(List.from(initialData));
  }
}

void main() {
  group('Phase 32: Production Hardening & Realtime Notifications UI', () {
    testWidgets('Empty notification center allows pull-to-refresh reload', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = _TestNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty state is rendered
      expect(find.text('No Notifications Found'), findsOneWidget);
      expect(find.text('Any trip updates or operational notifications will appear here.'), findsOneWidget);

      // Verify RefreshIndicator exists
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Trigger pull to refresh on the empty scrollable
      await tester.fling(find.text('No Notifications Found'), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify notifier refresh was invoked
      expect(notifier.refreshCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('Filter tabs render horizontally and filter operational vs promotional', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        NotificationModel(
          id: 'notif-1',
          userId: 'usr-1',
          title: 'Booking Confirmed',
          body: 'Your ride is confirmed',
          category: 'BOOKING',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'notif-2',
          userId: 'usr-1',
          title: 'Weekend Offer',
          body: 'Get 20% off',
          category: 'PROMOTION',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final notifier = _TestNotifier(items);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially 'All' shows both
      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text('Weekend Offer'), findsOneWidget);

      // Tap 'Operational' filter
      await tester.tap(find.byKey(const Key('notifications_filter_operational')));
      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text('Weekend Offer'), findsNothing);

      // Tap 'Promotions' filter
      await tester.tap(find.byKey(const Key('notifications_filter_promotions')));
      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed'), findsNothing);
      expect(find.text('Weekend Offer'), findsOneWidget);
    });
  });
}
