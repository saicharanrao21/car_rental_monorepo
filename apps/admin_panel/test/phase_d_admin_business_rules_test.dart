import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_panel/features/business_rules/domain/models/system_config_detail.dart';
import 'package:admin_panel/features/business_rules/domain/repositories/business_rules_repository.dart';
import 'package:admin_panel/features/business_rules/data/mock_business_rules_repository.dart';
import 'package:admin_panel/features/business_rules/presentation/providers/business_rules_providers.dart';
import 'package:admin_panel/features/business_rules/presentation/pages/business_rules_dashboard_page.dart';
import 'package:admin_panel/features/business_rules/presentation/widgets/config_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase D — Admin Configuration Control Center Unit & Domain Tests', () {
    late MockBusinessRulesRepository repo;

    setUp(() {
      repo = MockBusinessRulesRepository();
    });

    test('1. Configuration list loads successfully with all seeded platform rules', () async {
      final configs = await repo.getAllConfigs();
      expect(configs.isNotEmpty, isTrue);
      expect(configs.length, greaterThanOrEqualTo(8));

      final keys = configs.map((c) => c.key).toList();
      expect(keys, contains('pricing.tax'));
      expect(keys, contains('pricing.quote'));
      expect(keys, contains('pricing.duration_discounts'));
      expect(keys, contains('booking.cancellation_matrix'));
      expect(keys, contains('pricing.commission'));
      expect(keys, contains('deposits.defaults'));
      expect(keys, contains('wallet.rules'));
    });

    test('2. Configuration detail loads correctly for a specific key', () async {
      final taxConfig = await repo.getConfigDetail('pricing.tax');
      expect(taxConfig.key, 'pricing.tax');
      expect(taxConfig.category, 'PRICING');
      expect(taxConfig.source, 'DEFAULT_FALLBACK');
      expect(taxConfig.isFallback, isTrue);
      expect(taxConfig.isDatabase, isFalse);
      expect(taxConfig.version, 1);
      expect(taxConfig.effectiveValue, isA<Map>());
      expect(taxConfig.effectiveValue['gstRate'], 18);
    });

    test('3. Database vs fallback status is distinguished accurately', () async {
      final initialTax = await repo.getConfigDetail('pricing.tax');
      expect(initialTax.source, 'DEFAULT_FALLBACK');
      expect(initialTax.isExplicitlyConfigured, isFalse);

      // Apply an update
      await repo.updateConfig(
        key: 'pricing.tax',
        value: {'gstRate': 12},
        expectedVersion: 1,
        reason: 'Government GST rationalization for mobility services',
      );

      final updatedTax = await repo.getConfigDetail('pricing.tax');
      expect(updatedTax.source, 'DATABASE');
      expect(updatedTax.isExplicitlyConfigured, isTrue);
      expect(updatedTax.isDatabase, isTrue);
      expect(updatedTax.isFallback, isFalse);
      expect(updatedTax.version, 2);
      expect(updatedTax.effectiveValue['gstRate'], 12);
    });

    test('4. Internal configuration boundary is protected and identified', () async {
      final commissionConfig = await repo.getConfigDetail('pricing.commission');
      expect(commissionConfig.isPublic, isFalse); // Confidential internal platform rule

      final taxConfig = await repo.getConfigDetail('pricing.tax');
      expect(taxConfig.isPublic, isTrue); // Public-safe customer-facing rule
    });

    test('5. Optimistic Concurrency Control (OCC 409) rejects stale version updates', () async {
      // First update brings version to 2
      await repo.updateConfig(
        key: 'pricing.quote',
        value: {'validityMinutes': 20},
        expectedVersion: 1,
        reason: 'Extend quote window for busy traffic hours',
      );

      final current = await repo.getConfigDetail('pricing.quote');
      expect(current.version, 2);

      // Another admin tries to save with stale expectedVersion 1
      expect(
        () async => await repo.updateConfig(
          key: 'pricing.quote',
          value: {'validityMinutes': 30},
          expectedVersion: 1, // Stale!
          reason: 'Conflicting save attempt',
        ),
        throwsA(isA<ConcurrencyConflictException>().having(
          (e) => e.currentServerVersion,
          'currentServerVersion',
          2,
        )),
      );

      // Verify that the conflicting save was aborted without corrupting server state
      final afterConflict = await repo.getConfigDetail('pricing.quote');
      expect(afterConflict.version, 2);
      expect(afterConflict.effectiveValue['validityMinutes'], 20);
    });

    test('6. Audit history logs every modification with diff and reason', () async {
      await repo.updateConfig(
        key: 'pricing.tax',
        value: {'gstRate': 5},
        expectedVersion: 1,
        reason: 'EV fleet promotion: reduced GST rate',
      );

      final history = await repo.getAuditHistory('pricing.tax');
      expect(history.isNotEmpty, isTrue);
      expect(history.first.key, 'pricing.tax');
      expect(history.first.reason, 'EV fleet promotion: reduced GST rate');
      expect(history.first.version, 2);
      expect(history.first.previousValue['gstRate'], 18);
      expect(history.first.newValue['gstRate'], 5);
    });

    test('7. Empty audit history is handled gracefully', () async {
      final history = await repo.getAuditHistory('non_existent_key');
      expect(history, isEmpty);
    });

    test('8. Atomic batch update updates multiple rules atomically', () async {
      final items = [
        const BatchConfigItem(
          key: 'pricing.tax',
          value: {'gstRate': 12},
          expectedVersion: 1,
        ),
        const BatchConfigItem(
          key: 'pricing.quote',
          value: {'validityMinutes': 25},
          expectedVersion: 1,
        ),
      ];

      await repo.batchUpdateConfigs(
        items: items,
        reason: 'Q4 2026 pricing harmonization bundle',
      );

      final tax = await repo.getConfigDetail('pricing.tax');
      final quote = await repo.getConfigDetail('pricing.quote');

      expect(tax.version, 2);
      expect(tax.effectiveValue['gstRate'], 12);
      expect(quote.version, 2);
      expect(quote.effectiveValue['validityMinutes'], 25);
    });

    test('9. Atomic batch update rejects entire transaction if any version conflicts', () async {
      // Advance tax to version 2 first
      await repo.updateConfig(
        key: 'pricing.tax',
        value: {'gstRate': 15},
        expectedVersion: 1,
        reason: 'Prior independent update',
      );

      final items = [
        const BatchConfigItem(
          key: 'pricing.tax',
          value: {'gstRate': 18},
          expectedVersion: 1, // Stale! Server is now at 2
        ),
        const BatchConfigItem(
          key: 'pricing.quote',
          value: {'validityMinutes': 30},
          expectedVersion: 1, // Valid
        ),
      ];

      // The entire batch must fail
      expect(
        () async => await repo.batchUpdateConfigs(
          items: items,
          reason: 'Should fail atomically',
        ),
        throwsA(isA<ConcurrencyConflictException>()),
      );

      // Verify that quote was NOT partially updated
      final quote = await repo.getConfigDetail('pricing.quote');
      expect(quote.version, 1);
      expect(quote.effectiveValue['validityMinutes'], 15);
    });

    test('10. SystemConfigDetail JSON serialization round-trip', () {
      final original = SystemConfigDetail(
        key: 'test.rule',
        effectiveValue: {'threshold': 500},
        source: 'DATABASE',
        isExplicitlyConfigured: true,
        version: 4,
        updatedAt: DateTime(2026, 9, 8, 12, 0),
        updatedBy: 'admin_test',
        category: 'PRICING',
        description: 'Test business rule for serialization',
        isPublic: true,
      );

      final json = original.toJson();
      final reconstructed = SystemConfigDetail.fromJson(json);

      expect(reconstructed.key, original.key);
      expect(reconstructed.effectiveValue, original.effectiveValue);
      expect(reconstructed.source, original.source);
      expect(reconstructed.isExplicitlyConfigured, original.isExplicitlyConfigured);
      expect(reconstructed.version, original.version);
      expect(reconstructed.updatedBy, original.updatedBy);
      expect(reconstructed.category, original.category);
      expect(reconstructed.description, original.description);
      expect(reconstructed.isPublic, original.isPublic);
    });
  });

  group('Phase D — Admin Business Rules UI Widget & UX Tests', () {
    late MockBusinessRulesRepository mockRepo;

    setUp(() {
      mockRepo = MockBusinessRulesRepository();
    });

    Widget createTestableWidget({
      required Widget child,
      bool canEdit = true,
    }) {
      return ProviderScope(
        overrides: [
          businessRulesRepositoryProvider.overrideWithValue(mockRepo),
          canEditConfigurationsProvider.overrideWithValue(canEdit),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('11. BusinessRulesDashboardPage renders metric cards and rules list', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestableWidget(child: const BusinessRulesDashboardPage()),
      );
      await tester.pumpAndSettle();

      // Verify Page Title
      expect(find.text('Business Rules Engine'), findsOneWidget);
      expect(find.text('OCC & REDIS INVALIDATION ACTIVE'), findsOneWidget);

      // Verify Metric Cards
      expect(find.text('TOTAL GOVERNED RULES'), findsOneWidget);
      expect(find.text('ACTIVE IN DATABASE'), findsOneWidget);
      expect(find.text('DEFAULT FALLBACKS'), findsOneWidget);
      expect(find.text('INTERNAL GOVERNANCE'), findsOneWidget);

      // Verify Rules in Grid
      expect(find.text('Goods & Services Tax (GST)'), findsOneWidget);
      expect(find.text('Booking Quote Validity Window'), findsOneWidget);
      expect(find.text('Vehicle Category Deposit Defaults'), findsOneWidget);
    });

    testWidgets('12. Category filter chips filter data grid appropriately', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestableWidget(child: const BusinessRulesDashboardPage()),
      );
      await tester.pumpAndSettle();

      // Filter by BOOKING
      final bookingChip = find.widgetWithText(ChoiceChip, 'Booking');
      expect(bookingChip, findsOneWidget);
      await tester.tap(bookingChip);
      await tester.pumpAndSettle();

      // Cancellation policy must be visible
      expect(find.text('Cancellation Fee Schedule & Tiers'), findsOneWidget);
      // Tax rule (PRICING) should not be visible
      expect(find.text('Goods & Services Tax (GST)'), findsNothing);
    });

    testWidgets('13. Search input filters configurations by key or name', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestableWidget(child: const BusinessRulesDashboardPage()),
      );
      await tester.pumpAndSettle();

      // Type in search bar
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'deposit');
      await tester.pumpAndSettle();

      // Deposits defaults rule matches
      expect(find.text('Vehicle Category Deposit Defaults'), findsOneWidget);
      // Tax rule does not match
      expect(find.text('Goods & Services Tax (GST)'), findsNothing);
    });

    testWidgets('14. ConfigDetailDrawer displays rule metadata and editor', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final taxConfig = await mockRepo.getConfigDetail('pricing.tax');

      await tester.pumpWidget(
        createTestableWidget(
          child: Scaffold(
            body: ConfigDetailDrawer(config: taxConfig),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Goods & Services Tax (GST)'), findsOneWidget);
      expect(find.text('pricing.tax'), findsOneWidget);
      expect(find.text('DEFAULT FALLBACK'), findsOneWidget);
      expect(find.text('Revision: v1'), findsOneWidget);
      expect(find.text('PUBLIC SAFE'), findsOneWidget);

      // Tabs
      expect(find.text('Configuration Editor'), findsOneWidget);
      expect(find.text('Audit Trail & History'), findsOneWidget);
    });

    testWidgets('15. Read-only admin mode disables editing and warns user', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final taxConfig = await mockRepo.getConfigDetail('pricing.tax');

      await tester.pumpWidget(
        createTestableWidget(
          child: Scaffold(
            body: ConfigDetailDrawer(config: taxConfig),
          ),
          canEdit: false, // Read-only mode!
        ),
      );
      await tester.pumpAndSettle();

      // Verify Read-only alert
      expect(find.textContaining('READ-ONLY MODE'), findsOneWidget);

      // Save button should be disabled
      final saveBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save Changes'));
      expect(saveBtn.enabled, isFalse);
    });
  });
}
