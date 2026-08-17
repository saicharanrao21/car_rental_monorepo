import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/loyalty/data/admin_loyalty_repository.dart';
import 'package:admin_panel/features/loyalty/presentation/pages/admin_loyalty_page.dart';
import 'package:admin_panel/features/loyalty/presentation/providers/admin_loyalty_providers.dart';

class MockAdminLoyaltyRepository implements AdminLoyaltyRepository {
  final LoyaltySummaryModel summary;
  final Map<String, dynamic> accountsData;

  MockAdminLoyaltyRepository({
    required this.summary,
    required this.accountsData,
  });

  @override
  Future<LoyaltySummaryModel> getSummary() async => summary;

  @override
  Future<Map<String, dynamic>> getAccounts({
    String? search,
    LoyaltyTierCode? tierCode,
    int page = 1,
    int limit = 20,
  }) async =>
      accountsData;

  @override
  Future<List<LoyaltyTransactionModel>> getAccountTransactions(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> adjustPoints({
    required String userId,
    required int points,
    required String reason,
    required String idempotencyKey,
  }) async =>
      {'success': true};
}

void main() {
  testWidgets('AdminLoyaltyManagementPage renders summary cards and member accounts table', (tester) async {
    final mockSummary = LoyaltySummaryModel(
      totalAccounts: 120,
      totalLifetimePoints: 85000,
      totalAvailablePoints: 30000,
      totalPointsRedeemed: 55000,
      outstandingLiabilityInr: 15000,
      tierBreakdown: const [
        LoyaltyTierBreakdownItem(code: LoyaltyTierCode.bronze, name: 'Bronze', minPoints: 0, multiplier: 1.0, accountCount: 80),
        LoyaltyTierBreakdownItem(code: LoyaltyTierCode.silver, name: 'Silver', minPoints: 500, multiplier: 1.25, accountCount: 25),
        LoyaltyTierBreakdownItem(code: LoyaltyTierCode.gold, name: 'Gold', minPoints: 2000, multiplier: 1.5, accountCount: 12),
        LoyaltyTierBreakdownItem(code: LoyaltyTierCode.platinum, name: 'Platinum', minPoints: 5000, multiplier: 2.0, accountCount: 3),
      ],
    );

    final mockAccountsData = {
      'accounts': [
        {
          'id': 'acc_1',
          'userId': 'user_1',
          'userName': 'Rahul Sharma',
          'userPhone': '+919876543210',
          'userEmail': 'rahul@example.com',
          'tierCode': 'GOLD',
          'tierName': 'Gold',
          'pointsBalance': 1200,
          'lifetimePoints': 2400,
          'walletEquivalent': 600,
        },
      ],
      'total': 1,
      'page': 1,
      'limit': 20,
      'totalPages': 1,
    };

    final mockRepo = MockAdminLoyaltyRepository(
      summary: mockSummary,
      accountsData: mockAccountsData,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminLoyaltyRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: AdminLoyaltyManagementPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Loyalty & Rewards Program'), findsOneWidget);
    expect(find.text('Total Members'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Points Issued'), findsOneWidget);
    expect(find.text('85000'), findsOneWidget);
    expect(find.text('Reward Liability'), findsOneWidget);
    expect(find.text('₹15000'), findsOneWidget);
    expect(find.text('Member Accounts'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('1200 pts'), findsOneWidget);
    expect(find.text('₹600'), findsOneWidget);
  });
}
