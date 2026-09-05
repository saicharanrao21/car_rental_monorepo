import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:vendor_app/features/notifications/presentation/providers/vendor_notifications_providers.dart';

class _TestVendorNotifier extends VendorNotificationsNotifier {
  final List<NotificationModel> initialData;
  int refreshCallCount = 0;

  _TestVendorNotifier(this.initialData);

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
  group('Phase 32: Vendor Realtime Notifications Hardening', () {
    testWidgets('Empty vendor alerts screen supports pull-to-refresh with RefreshIndicator', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = _TestVendorNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorNotificationsProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: VendorNotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check empty state
      expect(find.text('No Alerts in This Category'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Pull to refresh
      await tester.fling(find.text('No Alerts in This Category'), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(notifier.refreshCallCount, greaterThanOrEqualTo(1));
    });
  });
}
