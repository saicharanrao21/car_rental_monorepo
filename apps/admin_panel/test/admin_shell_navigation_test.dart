import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_panel/core/widgets/admin_shell.dart';

void main() {
  testWidgets('AdminShell renders 6 domain categories, brand, and top header bar', (tester) async {
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
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Brand
    expect(find.text('DRIVEGO CONTROL'), findsOneWidget);

    // Verify Domain Headers (allowing offstage search if needed)
    expect(find.text('EXECUTIVE', skipOffstage: false), findsOneWidget);
    expect(find.text('OPERATIONS & FLEET', skipOffstage: false), findsOneWidget);
    expect(find.text('CUSTOMER CARE', skipOffstage: false), findsOneWidget);
    expect(find.text('FINANCE & SETTLEMENTS', skipOffstage: false), findsOneWidget);
    expect(find.text('GROWTH & MARKETING', skipOffstage: false), findsOneWidget);
    expect(find.text('SECURITY & GOVERNANCE', skipOffstage: false), findsOneWidget);

    // Verify Operational Status chip
    expect(find.text('CONTROL TOWER LIVE'), findsOneWidget);

    // Verify Breadcrumbs and sidebar labels (Command Center appears in both sidebar & top bar)
    expect(find.text('Executive'), findsOneWidget);
    expect(find.text('Command Center'), findsNWidgets(2));

    // Navigate to Location Governance
    await tester.tap(find.text('Location Governance', skipOffstage: false).first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Route change & Breadcrumbs update
    expect(find.text('Operations & Fleet'), findsOneWidget);
    expect(find.text('Location Governance', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('Location Governance Screen'), findsOneWidget);
  });
}
