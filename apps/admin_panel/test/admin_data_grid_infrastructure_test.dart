import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/core/widgets/admin_data_grid.dart';
import 'package:admin_panel/core/widgets/admin_detail_drawer.dart';

class _TestRecord {
  final String id;
  final String name;
  final String status;
  final double amount;

  const _TestRecord({
    required this.id,
    required this.name,
    required this.status,
    required this.amount,
  });
}

void main() {
  group('AdminDataGrid & Responsive Infrastructure Tests', () {
    final sampleItems = [
      const _TestRecord(id: 'REC-001', name: 'Alpha Customer', status: 'ACTIVE', amount: 1500.0),
      const _TestRecord(id: 'REC-002', name: 'Beta Fleet Car', status: 'PENDING', amount: 2500.0),
      const _TestRecord(id: 'REC-003', name: 'Gamma Vendor Hub', status: 'SUSPENDED', amount: 3200.0),
    ];

    testWidgets('AdminDataGrid renders desktop table mode with columns and rows on large viewport', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      _TestRecord? tappedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDataGrid<_TestRecord>(
              items: sampleItems,
              onRowTap: (item) => tappedItem = item,
              columns: [
                AdminDataColumn<_TestRecord>(
                  title: 'ID',
                  builder: (item) => Text(item.id),
                ),
                AdminDataColumn<_TestRecord>(
                  title: 'NAME',
                  builder: (item) => Text(item.name),
                ),
                AdminDataColumn<_TestRecord>(
                  title: 'STATUS',
                  builder: (item) => AdminStatusBadge(status: item.status),
                ),
                AdminDataColumn<_TestRecord>(
                  title: 'AMOUNT',
                  numeric: true,
                  builder: (item) => Text('₹${item.amount.toStringAsFixed(0)}'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Column Headers
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('AMOUNT'), findsOneWidget);

      // Check Row Content
      expect(find.text('REC-001'), findsOneWidget);
      expect(find.text('Alpha Customer'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('₹1500'), findsOneWidget);

      expect(find.text('REC-002'), findsOneWidget);
      expect(find.text('Beta Fleet Car'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);

      expect(find.text('REC-003'), findsOneWidget);
      expect(find.text('Gamma Vendor Hub'), findsOneWidget);
      expect(find.text('SUSPENDED'), findsOneWidget);

      // Tap row
      await tester.tap(find.text('Alpha Customer'));
      await tester.pumpAndSettle();
      expect(tappedItem?.id, equals('REC-001'));
    });

    testWidgets('AdminDataGrid renders mobile card layout on mobile viewport width < 600px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDataGrid<_TestRecord>(
              items: sampleItems,
              columns: [
                AdminDataColumn<_TestRecord>(
                  title: 'ID',
                  builder: (item) => Text(item.id),
                ),
                AdminDataColumn<_TestRecord>(
                  title: 'NAME',
                  builder: (item) => Text(item.name),
                ),
              ],
              mobileCardBuilder: (context, item) {
                return Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text('Mobile ID: ${item.id}'),
                    trailing: AdminStatusBadge(status: item.status),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Mobile cards rendered
      expect(find.text('Mobile ID: REC-001'), findsOneWidget);
      expect(find.text('Mobile ID: REC-002'), findsOneWidget);
      expect(find.text('Mobile ID: REC-003'), findsOneWidget);
      expect(find.text('Alpha Customer'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('AdminDataGrid renders Empty and Error states correctly', (tester) async {
      bool retried = false;

      // Error state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDataGrid<_TestRecord>(
              items: const [],
              errorMessage: 'Network timeout occurred while fetching records',
              onRetry: () => retried = true,
              columns: const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Network timeout occurred while fetching records'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);

      // Empty state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDataGrid<_TestRecord>(
              items: [],
              emptyTitle: 'No Matching Fleet Assets',
              emptyMessage: 'Try clearing your active filters or search terms.',
              columns: [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No Matching Fleet Assets'), findsOneWidget);
      expect(find.text('Try clearing your active filters or search terms.'), findsOneWidget);
    });

    testWidgets('AdminTableToolbar renders search, count, filter, and triggers callbacks', (tester) async {
      String searched = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminTableToolbar(
              searchHint: 'Filter by plate number or model...',
              searchValue: '',
              onSearchChanged: (val) => searched = val,
              totalCount: 42,
              filters: const [
                Text('FilterDropdownWidget'),
              ],
              actions: [
                ElevatedButton(onPressed: () {}, child: const Text('Export CSV')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('FilterDropdownWidget'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('42 Records'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Toyota Fortuner');
      await tester.pumpAndSettle();
      expect(searched, equals('Toyota Fortuner'));
    });

    testWidgets('AdminPagination handles page navigation and count ranges', (tester) async {
      int currentPage = 1;
      int selectedPageSize = 25;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: AdminPagination(
                currentPage: currentPage,
                pageSize: selectedPageSize,
                totalItems: 85,
                onPageChanged: (p) => setState(() => currentPage = p),
                onPageSizeChanged: (s) => setState(() => selectedPageSize = s),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Showing 1–25 of 85 items'), findsOneWidget);
      expect(find.text('Page 1 of 4'), findsOneWidget);

      // Navigate to Next page
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(currentPage, equals(2));
      expect(find.text('Showing 26–50 of 85 items'), findsOneWidget);
      expect(find.text('Page 2 of 4'), findsOneWidget);
    });

    testWidgets('AdminDetailDrawer opens drawer with sections, fields and closes cleanly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AdminDetailDrawer.show(
                    context: context,
                    title: 'Car Asset Details',
                    subtitle: 'VIN: KA01AB1234',
                    actions: [
                      ElevatedButton(onPressed: () {}, child: const Text('Edit Car Details')),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AdminDrawerSection(
                          title: 'Engine & Telemetry',
                          icon: Icons.speed,
                        ),
                        AdminDrawerField(label: 'Odometer', value: '45,200 km'),
                        AdminDrawerField(label: 'Fuel Level', value: '88%'),
                      ],
                    ),
                  );
                },
                child: const Text('Open Detail Drawer'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open Detail Drawer'));
      await tester.pumpAndSettle();

      // Verify content in drawer
      expect(find.text('Car Asset Details'), findsOneWidget);
      expect(find.text('VIN: KA01AB1234'), findsOneWidget);
      expect(find.text('ENGINE & TELEMETRY'), findsOneWidget);
      expect(find.text('Odometer'), findsOneWidget);
      expect(find.text('45,200 km'), findsOneWidget);
      expect(find.text('Fuel Level'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('Edit Car Details'), findsOneWidget);

      // Close drawer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Car Asset Details'), findsNothing);
    });
  });
}
