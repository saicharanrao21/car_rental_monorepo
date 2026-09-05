import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:vendor_app/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:vendor_app/features/notifications/domain/repositories/vendor_notifications_repository.dart';

class FakeVendorNotificationsRepository implements VendorNotificationsRepository {
  final List<NotificationModel> items;
  bool markAllReadCalled = false;
  String? markedReadId;

  FakeVendorNotificationsRepository(this.items);

  @override
  Future<List<NotificationModel>> getNotifications(String vendorUserId) async {
    return items;
  }

  @override
  Future<void> markAllRead(String vendorUserId) async {
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

class _MockVendorNotifier extends VendorNotificationsNotifier {
  final List<NotificationModel> initialData;
  final FakeVendorNotificationsRepository? repo;

  _MockVendorNotifier(this.initialData, {this.repo});

  @override
  Future<List<NotificationModel>> build() async {
    return List.from(initialData);
  }

  @override
  Future<void> markAllAsRead() async {
    if (repo != null) {
      await repo!.markAllRead('vnd_test_01');
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

void main() {
  group('Phase 31: Vendor App Operational Notifications Platform', () {
    final sampleAlerts = [
      NotificationModel(
        id: 'vn-01',
        userId: 'vnd_01',
        title: 'New Booking Assigned: Mahindra Thar (TS09EA1234)',
        body: 'Booking BK_VND_881 has been confirmed. Prepare vehicle.',
        category: 'BOOKING',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK_VND_881',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NotificationModel(
        id: 'vn-02',
        userId: 'vnd_01',
        title: 'Handover Ready: Customer Arriving',
        body: 'Customer Rajesh Kumar is arriving in 15 mins.',
        category: 'FULFILLMENT',
        eventType: 'HANDOVER_READY',
        entityType: 'BOOKING',
        entityId: 'BK_VND_881',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      NotificationModel(
        id: 'vn-03',
        userId: 'vnd_01',
        title: 'Escrow Settlement Released: ₹18,500.00',
        body: 'Trip completed without claims. Payout funds settled.',
        category: 'PAYMENT',
        eventType: 'SETTLEMENT_ELIGIBLE',
        entityType: 'PAYMENT',
        entityId: 'pay_vnd_870',
        priority: 'NORMAL',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      NotificationModel(
        id: 'vn-04',
        userId: 'vnd_01',
        title: 'Damage Claim Dispute Notice',
        body: 'Dispute opened on booking BK_VND_860. ₹5,000 security deposit quarantined.',
        category: 'SECURITY',
        eventType: 'ESCROW_HOLD_DISPUTED',
        entityType: 'BOOKING',
        entityId: 'BK_VND_860',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    testWidgets('Renders operational alerts list with unread counter and action required tags', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeVendorNotificationsRepository(sampleAlerts);

      final notifier = _MockVendorNotifier(sampleAlerts, repo: fakeRepo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            vendorNotificationsProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: VendorNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and titles
      expect(find.text('Operational Alerts'), findsOneWidget);
      expect(find.text('3 NEW'), findsOneWidget); // vn-01, vn-02, vn-04 are unread
      expect(find.text('New Booking Assigned: Mahindra Thar (TS09EA1234)'), findsOneWidget);
      expect(find.text('Handover Ready: Customer Arriving'), findsOneWidget);
      expect(find.text('Escrow Settlement Released: ₹18,500.00'), findsOneWidget);
      expect(find.text('Damage Claim Dispute Notice'), findsOneWidget);

      // Badges
      expect(find.text('BOOKING'), findsOneWidget);
      expect(find.text('FULFILLMENT'), findsOneWidget);
      expect(find.text('PAYMENT'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('ACTION REQUIRED'), findsNWidgets(2)); // vn-02 and vn-04 have HIGH priority
    });

    testWidgets('Filter chips isolate operational vs payout vs dispute alerts', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeVendorNotificationsRepository(sampleAlerts);
      final notifier = _MockVendorNotifier(sampleAlerts, repo: fakeRepo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            vendorNotificationsProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: VendorNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Payouts & Escrow"
      await tester.tap(find.byKey(const Key('vendor_filter_payouts')));
      await tester.pumpAndSettle();

      expect(find.text('Escrow Settlement Released: ₹18,500.00'), findsOneWidget);
      expect(find.text('New Booking Assigned: Mahindra Thar (TS09EA1234)'), findsNothing);

      // Tap "Disputes & Security"
      await tester.tap(find.byKey(const Key('vendor_filter_alerts')));
      await tester.pumpAndSettle();

      expect(find.text('Damage Claim Dispute Notice'), findsOneWidget);
      expect(find.text('Escrow Settlement Released: ₹18,500.00'), findsNothing);
    });

    testWidgets('Mark all read triggers repository update', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeVendorNotificationsRepository(sampleAlerts);

      final notifier = _MockVendorNotifier(sampleAlerts, repo: fakeRepo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsRepositoryProvider.overrideWithValue(fakeRepo),
            vendorNotificationsProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: VendorNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vendor_mark_all_read')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vendor_mark_all_read')));
      await tester.pumpAndSettle();

      expect(fakeRepo.markAllReadCalled, isTrue);
    });
  });
}
