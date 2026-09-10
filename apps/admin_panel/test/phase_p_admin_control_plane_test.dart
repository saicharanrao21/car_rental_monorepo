import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:core/core.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/payouts/presentation/pages/admin_payouts_page.dart';
import 'package:admin_panel/features/corporate/presentation/pages/admin_corporate_accounts_page.dart';
import 'package:admin_panel/features/reconciliation/presentation/pages/admin_reconciliation_page.dart';
import 'package:admin_panel/features/operations_center/presentation/pages/admin_operations_command_center_page.dart';

ApiClient createMockApiClient() {
  final testDio = Dio();
  testDio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/payouts/admin/summary')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'pendingAmount': 425000,
              'completedThisMonth': 1850000,
              'escrowHeld': 310000,
              'pendingCount': 2,
              'completedCount': 15,
            },
          ));
        }
        if (options.path.contains('/admin/payouts')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {
                  'id': 'payout_1',
                  'vendorName': 'Royal Fleet Solutions',
                  'vendor': {'businessName': 'Royal Fleet Solutions'},
                  'vendorId': 'v_royal',
                  'amount': 150000,
                  'status': 'PENDING',
                  'createdAt': '2026-09-08T10:00:00Z',
                  'payoutPeriodStart': '2026-09-01T00:00:00Z',
                  'payoutPeriodEnd': '2026-09-07T23:59:59Z',
                  'bookingCount': 12,
                },
                {
                  'id': 'payout_2',
                  'vendorName': 'Apex Mobility Network',
                  'vendor': {'businessName': 'Apex Mobility Network'},
                  'vendorId': 'v_apex',
                  'amount': 275000,
                  'status': 'APPROVED',
                  'createdAt': '2026-09-07T12:00:00Z',
                  'payoutPeriodStart': '2026-09-01T00:00:00Z',
                  'payoutPeriodEnd': '2026-09-07T23:59:59Z',
                  'bookingCount': 25,
                },
              ],
              'totalPages': 1,
              'total': 2,
            },
          ));
        }
        if (options.path.contains('/corporate-accounts')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: [
              {
                'id': 'corp_1',
                'companyName': 'Infosys Enterprise Travel',
                'corporateCode': 'CORP-INFY-2026',
                'creditLimit': 5000000,
                'usedCredit': 1200000,
                'isActive': true,
                'contactEmail': 'fleet-admin@infosys.com',
                'billingCycle': 'MONTHLY',
              },
              {
                'id': 'corp_2',
                'companyName': 'Tata Consultancy Services',
                'corporateCode': 'CORP-TCS-BLR',
                'creditLimit': 10000000,
                'usedCredit': 4500000,
                'isActive': true,
                'contactEmail': 'mobility@tcs.com',
                'billingCycle': 'MONTHLY',
              },
            ],
          ));
        }
        if (options.path.contains('/reconciliation/exceptions')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: [
              {
                'id': 'ex_1',
                'exceptionType': 'GATEWAY_TXN_MISSING_IN_DB',
                'description': 'Missing Razorpay gateway transaction',
                'expectedAmount': 12500,
                'actualAmount': 0,
                'discrepancyAmount': 12500,
                'status': 'OPEN',
                'referenceId': 'pay_mock_123',
                'createdAt': '2026-09-09T08:00:00Z',
              },
              {
                'id': 'ex_2',
                'exceptionType': 'REFUND_AMOUNT_MISMATCH',
                'description': 'Customer partial refund variance',
                'expectedAmount': 5000,
                'actualAmount': 4000,
                'discrepancyAmount': 1000,
                'status': 'OPEN',
                'referenceId': 'rfnd_mock_456',
                'createdAt': '2026-09-08T14:30:00Z',
              },
            ],
          ));
        }
        if (options.path.contains('/operations/admin/command-center')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'activeRentals': 34,
              'pickupsToday': 8,
              'returnsToday': 12,
              'unallocatedCount': 0,
              'slaBreachesCount': 2,
              'maintenanceVehicles': 3,
              'activeCars': 45,
              'totalCars': 50,
              'substitutionsCount': 1,
              'recentIncidents': [
                {
                  'id': 'inc_1',
                  'breachType': 'OVERDUE_RETURN',
                  'severity': 'HIGH',
                  'bookingId': 'bk_live_01',
                  'incidentType': 'OVERDUE RETURN SLA BREACH',
                  'description': 'Customer 2.5 hours overdue at Indiranagar Hub',
                  'createdAt': '2026-09-10T04:00:00Z',
                },
              ],
            },
          ));
        }
        return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
      },
    ),
  );

  return ApiClient(tokenStorage: TokenStorage(), dio: testDio);
}

void main() {
  group('Phase P: Admin Control-Plane Integrity Tests (GAP-06)', () {
    testWidgets('renders AdminPayoutsPage with KPIs, filter chips, and payout items', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = createMockApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: const MaterialApp(
            home: AdminPayoutsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Vendor Payouts & General Ledger Settlement'), findsOneWidget);

      // Check Metric cards
      expect(find.text('Pending Payouts'), findsOneWidget);
      expect(find.text('Settled Payouts'), findsOneWidget);
      expect(find.text('Escrow Deposits'), findsOneWidget);

      // Check payout records
      expect(find.textContaining('Royal Fleet Solutions'), findsOneWidget);
      expect(find.textContaining('Apex Mobility Network'), findsOneWidget);
    });

    testWidgets('renders AdminCorporateAccountsPage with credit lines and accounts list', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = createMockApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: const MaterialApp(
            home: AdminCorporateAccountsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Corporate Accounts & Credit Governance'), findsOneWidget);
      expect(find.text('New Account'), findsOneWidget);

      // Check Corporate Accounts
      expect(find.text('Infosys Enterprise Travel'), findsOneWidget);
      expect(find.text('Tata Consultancy Services'), findsOneWidget);
    });

    testWidgets('renders AdminReconciliationPage with exceptions and sweep action', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = createMockApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: const MaterialApp(
            home: AdminReconciliationPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Financial Reconciliation & Exceptions'), findsOneWidget);
      expect(find.text('Run Sweep'), findsOneWidget);

      // Check Discrepancy Items
      expect(find.text('GATEWAY_TXN_MISSING_IN_DB'), findsOneWidget);
      expect(find.text('REFUND_AMOUNT_MISMATCH'), findsOneWidget);
    });

    testWidgets('renders AdminOperationsCommandCenterPage with real-time operations telemetry', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = createMockApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
          ],
          child: const MaterialApp(
            home: AdminOperationsCommandCenterPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Operations Command Center & SLA Watch'), findsOneWidget);
      expect(find.text('Evaluate SLAs'), findsOneWidget);

      // Check Operational KPIs
      expect(find.text('Active Rentals'), findsOneWidget);
      expect(find.text('Pickups Today'), findsOneWidget);
      expect(find.text('SLA Breaches'), findsOneWidget);

      // Check Incidents
      expect(find.textContaining('OVERDUE_RETURN'), findsOneWidget);
    });
  });
}
