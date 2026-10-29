import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_panel/features/audit_log/presentation/pages/admin_audit_log_page.dart';
import 'package:admin_panel/features/audit_log/presentation/providers/admin_audit_log_providers.dart';
import 'package:admin_panel/features/audit_log/domain/audit_log_model.dart';
import 'package:admin_panel/features/audit_log/domain/repositories/admin_audit_log_repository.dart';

class MockAuditLogRepository implements AdminAuditLogRepository {
  final List<AuditLogEntry> entries = [
    AuditLogEntry(
      id: 'log-101',
      adminUserId: 'usr-1',
      adminUserName: 'Sunita Rao',
      action: 'COMMISSION_UPDATE',
      targetType: 'CommissionTier',
      targetId: 'tier-bangalore-prime',
      metadata: {'previousRate': 15, 'newRate': 18, 'reason': 'City expansion'},
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    AuditLogEntry(
      id: 'log-102',
      adminUserId: 'usr-2',
      adminUserName: 'Vikram Mehta',
      action: 'VENDOR_SUSPENSION',
      targetType: 'Vendor',
      targetId: 'vnd-hyd-09',
      metadata: {'violation': 'Repeated cancellation of confirmed bookings'},
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<List<AuditLogEntry>> getAuditLogs({
    String? adminUserId,
    String? action,
    String? targetType,
  }) async {
    return entries.where((e) {
      if (adminUserId != null && e.adminUserId != adminUserId) return false;
      if (action != null && action != 'ALL' && e.action != action) return false;
      if (targetType != null && targetType != 'ALL' && e.targetType != targetType) return false;
      return true;
    }).toList();
  }
}

void main() {
  testWidgets('AdminAuditLogPage renders title, toolbar, and data grid', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockRepo = MockAuditLogRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: AdminAuditLogPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Admin Audit Trail & System Logs'), findsOneWidget);
    expect(
      find.text('Immutable record of all administrative overrides, security events, and platform state changes.'),
      findsOneWidget,
    );

    // Verify Audit Entries rendered in DataGrid
    expect(find.text('Sunita Rao'), findsOneWidget);
    expect(find.text('COMMISSION_UPDATE'), findsOneWidget);
    expect(find.text('Vikram Mehta'), findsOneWidget);
    expect(find.text('VENDOR_SUSPENSION'), findsOneWidget);
  });

  testWidgets('AdminAuditLogPage filters records and renders metadata chips', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockRepo = MockAuditLogRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: AdminAuditLogPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify metadata formatted chips
    expect(find.text('previousRate: 15'), findsOneWidget);
    expect(find.text('newRate: 18'), findsOneWidget);
    expect(find.text('violation: Repeated cancellation of confirmed bookings'), findsOneWidget);

    // Verify search input filters
    final searchInput = find.byType(TextField);
    expect(searchInput, findsOneWidget);
    await tester.enterText(searchInput, 'Vikram');
    await tester.pumpAndSettle();

    // Only Vikram's log should be displayed
    expect(find.text('Vikram Mehta'), findsOneWidget);
    expect(find.text('Sunita Rao'), findsNothing);
  });
}
