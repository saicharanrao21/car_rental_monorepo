import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/widgets/admin_shell.dart';
import 'package:admin_panel/features/communications/presentation/pages/communications_overview_page.dart';
import 'package:admin_panel/features/communications/presentation/pages/communication_templates_page.dart';
import 'package:admin_panel/features/communications/presentation/pages/communication_delivery_logs_page.dart';
import 'package:admin_panel/features/campaigns/presentation/pages/admin_marketing_campaigns_page.dart';
import 'package:admin_panel/features/notifications/presentation/providers/admin_notifications_providers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildTestApp({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/communications',
              builder: (context, state) => const CommunicationsOverviewPage(),
            ),
            GoRoute(
              path: '/templates',
              builder: (context, state) => const CommunicationTemplatesPage(),
            ),
            GoRoute(
              path: '/delivery-logs',
              builder: (context, state) => const CommunicationDeliveryLogsPage(),
            ),
            GoRoute(
              path: '/campaigns',
              builder: (context, state) => const AdminMarketingCampaignsPage(),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        backendHealthProvider.overrideWith((ref) => Future.value(true)),
        adminDeliveryStatsProvider.overrideWith((ref) => Future.value({
          'totalDeliveries': 14829,
          'deliveredCount': 14798,
          'queuedCount': 14,
          'retryingCount': 8,
          'failedCount': 9,
        })),
        adminDeliveriesProvider.overrideWith(() => MockDeliveriesNotifier()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('CommunicationsOverviewPage renders telemetry KPIs and quick navigation buttons', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp(initialLocation: '/communications'));
    await tester.pumpAndSettle();

    // Verify Title & Operational badge
    expect(find.text('Communications Control Plane'), findsOneWidget);
    expect(find.text('ALL 5 CHANNELS OPERATIONAL'), findsOneWidget);

    // Verify Telemetry KPIs
    expect(find.text('Real-Time Telemetry & Health Monitoring'), findsOneWidget);
    expect(find.text('1,482,900'), findsOneWidget);
    expect(find.text('99.82%'), findsOneWidget);
    expect(find.text('28 ms'), findsOneWidget);
    expect(find.text('₹21,480.50'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Event Rules (13)'), findsOneWidget);
    expect(find.text('Templates Studio'), findsOneWidget);
    expect(find.text('Delivery Logs & Retries'), findsAtLeastNWidgets(1));
  });

  testWidgets('CommunicationTemplatesPage renders templates explorer and live phone preview', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp(initialLocation: '/templates'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Unified Message Templates Studio'), findsOneWidget);
    expect(find.text('DLT & META REGISTRY SYNCED'), findsOneWidget);

    // Verify Canonical Templates
    expect(find.text('BOOKING_CONFIRMATION', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('HANDOVER_INSPECTION_OTP', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('SECURITY_DEPOSIT_RELEASED', skipOffstage: false), findsAtLeastNWidgets(1));

    // Verify Live Bubble Preview
    expect(find.text('Device Message Bubble Preview'), findsOneWidget);
    expect(find.text('Interpolation Sandbox Variables'), findsOneWidget);

    // Verify New Template Action button
    expect(find.text('New Template'), findsOneWidget);
  });

  testWidgets('CommunicationDeliveryLogsPage renders delivery telemetry and grid', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp(initialLocation: '/delivery-logs'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Message Delivery Logs & Retries'), findsOneWidget);
    expect(find.text('IDEMPOTENT FAILOVER LIVE'), findsOneWidget);

    // Verify Stat Cards
    expect(find.text('Total Logs'), findsOneWidget);
    expect(find.text('Delivered (SLA)'), findsOneWidget);

    // Verify Grid Column Headers
    expect(find.text('TIMESTAMP'), findsOneWidget);
    expect(find.text('EVENT TYPE'), findsOneWidget);
    expect(find.text('CHANNEL'), findsOneWidget);
    expect(find.text('GATEWAY'), findsOneWidget);
    expect(find.text('RETRIES'), findsOneWidget);
  });

  testWidgets('AdminMarketingCampaignsPage renders growth campaigns and KPIs', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp(initialLocation: '/campaigns'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Marketing Campaigns & Attribution'), findsOneWidget);
    expect(find.text('AUTOMATED BUDGET CAP PROTECTION'), findsOneWidget);

    // Verify KPIs
    expect(find.text('Active Campaigns'), findsOneWidget);
    expect(find.text('Total Reach'), findsOneWidget);
    expect(find.text('Attributed GMV'), findsOneWidget);

    // Verify Table items
    expect(find.text('BLR_ESCAPE_20', skipOffstage: false), findsOneWidget);
    expect(find.text('HYD_WELCOME_500', skipOffstage: false), findsOneWidget);

    // Verify Create Campaign button
    expect(find.text('Create Campaign'), findsOneWidget);
  });
}

class MockDeliveriesNotifier extends AutoDisposeAsyncNotifier<List<NotificationDeliveryModel>> implements AdminDeliveriesNotifier {
  @override
  Future<List<NotificationDeliveryModel>> build() async {
    return [];
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> retry(String deliveryId) async {}
}
