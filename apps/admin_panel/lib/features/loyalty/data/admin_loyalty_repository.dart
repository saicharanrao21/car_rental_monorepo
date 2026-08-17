import 'package:models/models.dart';

abstract class AdminLoyaltyRepository {
  Future<LoyaltySummaryModel> getSummary();
  Future<Map<String, dynamic>> getAccounts({
    String? search,
    LoyaltyTierCode? tierCode,
    int page = 1,
    int limit = 20,
  });
  Future<List<LoyaltyTransactionModel>> getAccountTransactions(
    String userId, {
    int page = 1,
    int limit = 20,
  });
  Future<Map<String, dynamic>> adjustPoints({
    required String userId,
    required int points,
    required String reason,
    required String idempotencyKey,
  });
}
