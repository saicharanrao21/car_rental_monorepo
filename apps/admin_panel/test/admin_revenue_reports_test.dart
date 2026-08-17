import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_panel/features/revenue/presentation/pages/revenue_reports_page.dart';
import 'package:admin_panel/features/revenue/presentation/providers/revenue_providers.dart';
import 'package:admin_panel/features/revenue/data/mock_revenue_repository.dart';

void main() {
  testWidgets('RevenueReportsPage renders executive KPIs, operational metrics, and charts', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          revenueRepositoryProvider.overrideWithValue(MockRevenueRepository()),
        ],
        child: const MaterialApp(
          home: RevenueReportsPage(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow FutureProviders to complete
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify main page elements
    expect(find.text('Analytics & Financial Reports'), findsOneWidget);
    expect(find.text('Export to CSV'), findsOneWidget);
    expect(find.text('Filter Range:'), findsOneWidget);

    // Verify Executive Summary Cards
    expect(find.text('Gross Booking Value (GMV)'), findsOneWidget);
    expect(find.text('Platform Fee (Commission)'), findsOneWidget);
    expect(find.text('Net Platform Revenue'), findsOneWidget);
    expect(find.text('GST Collected (18%)'), findsOneWidget);
    expect(find.text('Wallet Liability (All Wallets)'), findsOneWidget);
    expect(find.text('Loyalty Liability (Points / 2)'), findsOneWidget);

    // Verify Operational Metric Cards
    expect(find.text('Booking Lifecycle'), findsOneWidget);
    expect(find.text('Fleet Utilization'), findsOneWidget);
    expect(find.text('Customer Growth'), findsOneWidget);
    expect(find.text('Add-on Adoption'), findsOneWidget);

    // Verify Charts
    expect(find.text('Platform Commission Trend (Daily)'), findsOneWidget);
    expect(find.text('Gross Revenue by City (₹)'), findsOneWidget);
    expect(find.text('Trip Type Distribution'), findsOneWidget);
    expect(find.text('Top Performing Partners'), findsOneWidget);
  });

  testWidgets('RevenueReportsPage handles CSV export dialog', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          revenueRepositoryProvider.overrideWithValue(MockRevenueRepository()),
        ],
        child: const MaterialApp(
          home: RevenueReportsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Export to CSV
    await tester.tap(find.text('Export to CSV'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify CSV export ready dialog
    expect(find.text('CSV Export Ready'), findsOneWidget);
    expect(find.text('Authoritative revenue dataset generated successfully.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('CSV Export Ready'), findsNothing);
  });
}
