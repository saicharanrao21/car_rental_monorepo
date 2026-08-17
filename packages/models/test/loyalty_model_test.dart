import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Loyalty Models Tests', () {
    test('LoyaltyTierModel.fromJson parses tier correctly', () {
      final json = {
        'id': 'tier_silver_1',
        'code': 'SILVER',
        'name': 'Silver',
        'minPointsRequired': 500,
        'pointsMultiplier': 1.25,
        'cashbackPercent': 1.25,
        'prioritySupport': false,
        'freeCancellationCount': 1,
      };

      final tier = LoyaltyTierModel.fromJson(json);
      expect(tier.id, 'tier_silver_1');
      expect(tier.code, LoyaltyTierCode.silver);
      expect(tier.name, 'Silver');
      expect(tier.minPointsRequired, 500);
      expect(tier.pointsMultiplier, 1.25);
      expect(tier.freeCancellationCount, 1);
    });

    test('LoyaltyAccountModel.fromJson parses account and tier progression correctly', () {
      final json = {
        'id': 'acc_101',
        'userId': 'user_cust_1',
        'tierCode': 'GOLD',
        'tierName': 'Gold',
        'pointsMultiplier': 1.5,
        'pointsBalance': 2400,
        'lifetimePoints': 2400,
        'walletEquivalent': 1200,
        'currentTier': {
          'id': 'tier_gold',
          'code': 'GOLD',
          'name': 'Gold',
          'minPointsRequired': 2000,
          'pointsMultiplier': 1.5,
          'prioritySupport': true,
        },
        'nextTier': {
          'code': 'PLATINUM',
          'name': 'Platinum',
          'minPointsRequired': 5000,
          'pointsMultiplier': 2.0,
          'pointsToNextTier': 2600,
          'progressPercent': 13.3,
        },
        'updatedAt': '2026-08-17T10:00:00.000Z',
      };

      final account = LoyaltyAccountModel.fromJson(json);
      expect(account.id, 'acc_101');
      expect(account.tierCode, LoyaltyTierCode.gold);
      expect(account.pointsBalance, 2400);
      expect(account.lifetimePoints, 2400);
      expect(account.walletEquivalent, 1200);
      expect(account.currentTier.prioritySupport, true);
      expect(account.nextTier?.code, LoyaltyTierCode.platinum);
      expect(account.nextTier?.pointsToNextTier, 2600);
    });

    test('LoyaltyTransactionModel.fromJson parses transaction correctly', () {
      final json = {
        'id': 'ltx_101',
        'type': 'TRIP_COMPLETION_EARNED',
        'points': 150,
        'balanceBefore': 0,
        'balanceAfter': 150,
        'referenceType': 'BOOKING',
        'referenceId': 'book_999',
        'idempotencyKey': 'loyalty_booking_book_999',
        'description': 'Earned 150 points for completed rental',
        'createdAt': '2026-08-17T11:00:00.000Z',
      };

      final tx = LoyaltyTransactionModel.fromJson(json);
      expect(tx.id, 'ltx_101');
      expect(tx.type, LoyaltyTransactionType.tripCompletionEarned);
      expect(tx.points, 150);
      expect(tx.balanceAfter, 150);
      expect(tx.type.isCredit, true);
      expect(tx.type.displayName, 'Trip Completed');
    });

    test('LoyaltySummaryModel.fromJson parses admin summary correctly', () {
      final json = {
        'totalAccounts': 150,
        'totalLifetimePoints': 100000,
        'totalAvailablePoints': 35000,
        'totalPointsRedeemed': 65000,
        'outstandingLiabilityInr': 17500,
        'tierBreakdown': [
          {
            'code': 'BRONZE',
            'name': 'Bronze',
            'minPoints': 0,
            'multiplier': 1.0,
            'accountCount': 100,
          },
          {
            'code': 'SILVER',
            'name': 'Silver',
            'minPoints': 500,
            'multiplier': 1.25,
            'accountCount': 35,
          },
          {
            'code': 'GOLD',
            'name': 'Gold',
            'minPoints': 2000,
            'multiplier': 1.5,
            'accountCount': 12,
          },
          {
            'code': 'PLATINUM',
            'name': 'Platinum',
            'minPoints': 5000,
            'multiplier': 2.0,
            'accountCount': 3,
          },
        ],
      };

      final summary = LoyaltySummaryModel.fromJson(json);
      expect(summary.totalAccounts, 150);
      expect(summary.totalAvailablePoints, 35000);
      expect(summary.outstandingLiabilityInr, 17500);
      expect(summary.tierBreakdown, hasLength(4));
      expect(summary.tierBreakdown[1].code, LoyaltyTierCode.silver);
    });
  });
}
