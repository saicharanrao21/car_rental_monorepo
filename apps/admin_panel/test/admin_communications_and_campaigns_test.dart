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
import 'package:admin_panel/features/campaigns/presentation/providers/admin_campaigns_providers.dart';
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
        adminCampaignsProvider.overrideWith(() => MockCampaignsNotifier()),
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
    expect(find.text('14,829'), findsOneWidget);
    expect(find.text('99.79%'), findsOneWidget);
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
    expect(find.text('Total Campaigns'), findsOneWidget);
    expect(find.text('Attributed GMV'), findsOneWidget);

    // Verify Table items
    expect(find.text('BLR_ESCAPE_20', skipOffstage: false), findsOneWidget);
    expect(find.text('HYD_WELCOME_500', skipOffstage: false), findsOneWidget);

    // Verify Create Campaign button
    expect(find.text('Create Campaign'), findsOneWidget);
  });
}

class MockCampaignsNotifier extends AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>
    implements AdminCampaignsNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return [
      {
        'id': 'cmp_101',
        'code': 'BLR_ESCAPE_20',
        'name': 'Bangalore Monsoon Getaway 20% OFF',
        'type': 'WEEKEND',
        'city': 'Bangalore',
        'carCategory': 'SUV',
        'discountType': 'PERCENTAGE',
        'discountValue': 20.0,
        'maxDiscountAmount': 1500.0,
        'minBookingAmount': 3500.0,
        'budget': 50000.0,
        'spent': 28400.0,
        'redemptions': 142,
        'maxRedemptions': 250,
        'startDate': DateTime.now().subtract(const Duration(days: 10)),
        'endDate': DateTime.now().add(const Duration(days: 20)),
        'status': 'ACTIVE',
        'channels': ['WHATSAPP', 'PUSH', 'BANNER'],
        'audience': 'Weekend Travelers (Bangalore)',
        'attributedGmv': 624000.0,
        'isDemo': false,
      },
      {
        'id': 'cmp_102',
        'code': 'HYD_WELCOME_500',
        'name': 'Hyderabad First Ride Welcome Bonus',
        'type': 'FIRST_BOOKING',
        'city': 'Hyderabad',
        'carCategory': 'ANY',
        'discountType': 'FLAT',
        'discountValue': 500.0,
        'maxDiscountAmount': 500.0,
        'minBookingAmount': 2000.0,
        'budget': 75000.0,
        'spent': 34500.0,
        'redemptions': 69,
        'maxRedemptions': 150,
        'startDate': DateTime.now().subtract(const Duration(days: 25)),
        'endDate': DateTime.now().add(const Duration(days: 35)),
        'status': 'ACTIVE',
        'channels': ['PUSH', 'SMS'],
        'audience': 'New Verified Customers (0 Bookings)',
        'attributedGmv': 289000.0,
        'isDemo': false,
      },
    ];
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> createCampaign(Map<String, dynamic> data) async {}

  @override
  Future<void> toggleCampaign(String id, bool isActive) async {}
}

class MockDeliveriesNotifier extends AutoDisposeAsyncNotifier<List<NotificationDeliveryModel>> implements AdminDeliveriesNotifier {
  @override
  Future<List<NotificationDeliveryModel>> build() async {
    return [
      NotificationDeliveryModel(
        id: 'del_test_101',
        notificationId: 'notif_901',
        channel: 'WHATSAPP',
        status: 'DELIVERED',
        provider: 'meta',
        recipientTarget: '+91 98765 43210',
        notificationTitle: 'Booking Confirmed - Mahindra Thar',
        eventType: 'BOOKING_CONFIRMED',
        attemptCount: 1,
        maxRetries: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> retry(String deliveryId) async {}
}
