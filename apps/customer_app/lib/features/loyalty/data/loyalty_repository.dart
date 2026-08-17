import 'package:models/models.dart';

abstract class LoyaltyRepository {
  Future<LoyaltyAccountModel> getLoyaltyAccount();
  Future<List<LoyaltyTransactionModel>> getLoyaltyTransactions({int page = 1, int limit = 20});
  Future<List<LoyaltyTierModel>> getLoyaltyTiers();
  Future<Map<String, dynamic>> redeemPointsToWallet(int points, {String? idempotencyKey});
}
