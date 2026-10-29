import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_panel/core/widgets/admin_shell.dart';

void main() {
  testWidgets('AdminShell renders 7 domain categories, brand, and top header bar', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Text('Dashboard Content Screen'),
            ),
            GoRoute(
              path: '/locations/governance',
              builder: (context, state) => const Text('Location Governance Screen'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendHealthProvider.overrideWith((ref) => Future.value(true)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Brand
    expect(find.text('DRIVEGO CONTROL'), findsOneWidget);

    // Verify Domain Headers (allowing offstage search if needed)
    expect(find.text('COMMAND CENTER', skipOffstage: false), findsOneWidget);
    expect(find.text('OPERATIONS', skipOffstage: false), findsOneWidget);
    expect(find.text('CUSTOMERS & SUPPORT', skipOffstage: false), findsOneWidget);
    expect(find.text('FINANCE', skipOffstage: false), findsOneWidget);
    expect(find.text('GROWTH & CAMPAIGNS', skipOffstage: false), findsOneWidget);
    expect(find.text('COMMUNICATIONS & INTEGRATIONS', skipOffstage: false), findsOneWidget);
    expect(find.text('SECURITY & PLATFORM', skipOffstage: false), findsOneWidget);

    // Verify Operational Status chip
    expect(find.text('CONTROL TOWER LIVE'), findsOneWidget);

    // Verify Breadcrumbs and sidebar labels
    expect(find.text('Command Center'), findsOneWidget);
    expect(find.text('Executive Overview'), findsNWidgets(2));

    // Navigate to Locations & Service Areas
    await tester.tap(find.text('Locations & Service Areas', skipOffstage: false).first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Route change & Breadcrumbs update
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Locations & Service Areas', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('Location Governance Screen'), findsOneWidget);
  });
}
