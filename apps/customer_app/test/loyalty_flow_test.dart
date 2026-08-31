import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_app/features/loyalty/presentation/pages/loyalty_page.dart';
import 'package:customer_app/features/loyalty/presentation/providers/loyalty_providers.dart';

class MockLoyaltyRepository implements LoyaltyRepository {
  final LoyaltyAccountModel account;
  final List<LoyaltyTransactionModel> transactions;

  MockLoyaltyRepository({
    required this.account,
    required this.transactions,
  });

  @override
  Future<LoyaltyAccountModel> getLoyaltyAccount() async => account;

  @override
  Future<List<LoyaltyTransactionModel>> getLoyaltyTransactions({
    int page = 1,
    int limit = 20,
  }) async =>
      transactions;

  @override
  Future<List<LoyaltyTierModel>> getLoyaltyTiers() async => [];

  @override
  Future<Map<String, dynamic>> redeemPointsToWallet(
    int points, {
    String? idempotencyKey,
  }) async {
    return {
      'success': true,
      'redeemedPoints': points,
      'walletCreditAmount': (points / 2).floor(),
    };
  }
}

void main() {
  testWidgets('LoyaltyPage renders tier card, available points, and transaction history', (tester) async {
    final mockAccount = LoyaltyAccountModel(
      id: 'acc_test_1',
      userId: 'user_test_1',
      tierCode: LoyaltyTierCode.gold,
      tierName: 'Gold',
      pointsMultiplier: 1.5,
      pointsBalance: 1200,
      lifetimePoints: 2400,
      walletEquivalent: 600,
      currentTier: const LoyaltyTierModel(
        id: 'tier_gold',
        code: LoyaltyTierCode.gold,
        name: 'Gold',
        minPointsRequired: 2000,
        pointsMultiplier: 1.5,
        prioritySupport: true,
      ),
      nextTier: const LoyaltyNextTierModel(
        code: LoyaltyTierCode.platinum,
        name: 'Platinum',
        minPointsRequired: 5000,
        pointsMultiplier: 2.0,
        pointsToNextTier: 2600,
        progressPercent: 13.3,
      ),
      updatedAt: DateTime.now(),
    );

    final mockTransactions = [
      LoyaltyTransactionModel(
        id: 'ltx_1',
        type: LoyaltyTransactionType.tripCompletionEarned,
        points: 200,
        balanceBefore: 1000,
        balanceAfter: 1200,
        referenceType: 'BOOKING',
        referenceId: 'book_1001',
        idempotencyKey: 'idemp_1',
        description: 'Earned 200 points for completed rental',
        createdAt: DateTime.now(),
      ),
    ];

    final mockRepo = MockLoyaltyRepository(
      account: mockAccount,
      transactions: mockTransactions,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loyaltyRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: LoyaltyPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('DriveGo Rewards Club'), findsOneWidget);
    expect(find.text('GOLD MEMBER'), findsOneWidget);
    expect(find.text('1.5x Points Multiplier'), findsOneWidget);
    expect(find.text('2400 Lifetime Pts'), findsOneWidget);
    expect(find.text('Next Tier: Platinum'), findsOneWidget);
    expect(find.text('1200 Pts'), findsOneWidget);
    expect(find.text('₹600'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);
    expect(find.text('Points History'), findsOneWidget);
    expect(find.text('Trip Completed'), findsOneWidget);
  });
}
