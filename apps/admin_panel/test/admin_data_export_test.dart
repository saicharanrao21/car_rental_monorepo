import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/features/settings/presentation/widgets/admin_data_export_card.dart';

void main() {
  testWidgets('AdminDataExportCard selects entity, triggers export, and displays ready banner', (tester) async {
    String? exportedEntity;
    DateTime? exportedStart;
    DateTime? exportedEnd;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AdminDataExportCard(
                  onExport: ({required String entity, DateTime? startDate, DateTime? endDate}) async {
                    exportedEntity = entity;
                    exportedStart = startDate;
                    exportedEnd = endDate;
                    return {
                      'filename': 'drivego_payments_2026-09-19.csv',
                      'rowCount': 350,
                    };
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial renders
    expect(find.text('Self-Serve Data Export Center'), findsOneWidget);
    expect(find.byKey(const Key('admin_data_export_card')), findsOneWidget);
    expect(find.byKey(const Key('export_entity_selector')), findsOneWidget);
    expect(find.text('Export BOOKINGS as CSV'), findsOneWidget);

    // Switch to PAYMENTS
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.text('Export PAYMENTS as CSV'), findsOneWidget);

    // Tap Export button
    await tester.tap(find.byKey(const Key('export_generate_btn')));
    await tester.pumpAndSettle();

    // Verify callback arguments
    expect(exportedEntity, equals('PAYMENTS'));
    expect(exportedStart, isNotNull);
    expect(exportedEnd, isNotNull);

    // Verify download ready banner
    expect(find.byKey(const Key('export_success_banner')), findsOneWidget);
    expect(find.text('Export Ready: drivego_payments_2026-09-19.csv'), findsOneWidget);
    expect(find.text('350 records exported successfully'), findsOneWidget);
  });

  testWidgets('AdminDataExportCard hides date range for VENDORS entity', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdminDataExportCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // By default (BOOKINGS), start and end date buttons are present
    expect(find.byKey(const Key('export_start_date_btn')), findsOneWidget);
    expect(find.byKey(const Key('export_end_date_btn')), findsOneWidget);

    // Switch to VENDORS
    await tester.tap(find.text('Vendors'));
    await tester.pumpAndSettle();

    // Date range buttons should not be rendered for vendors
    expect(find.byKey(const Key('export_start_date_btn')), findsNothing);
    expect(find.byKey(const Key('export_end_date_btn')), findsNothing);
    expect(find.text('Export VENDORS as CSV'), findsOneWidget);
  });
}
