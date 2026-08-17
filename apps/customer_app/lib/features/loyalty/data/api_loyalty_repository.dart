import 'package:core/core.dart';
import 'package:models/models.dart';
import 'loyalty_repository.dart';

class ApiLoyaltyRepository implements LoyaltyRepository {
  final ApiClient _apiClient;

  ApiLoyaltyRepository(this._apiClient);

  @override
  Future<LoyaltyAccountModel> getLoyaltyAccount() async {
    final response = await _apiClient.dio.get('/loyalty/account');
    return LoyaltyAccountModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<LoyaltyTransactionModel>> getLoyaltyTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/loyalty/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((e) => LoyaltyTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<LoyaltyTierModel>> getLoyaltyTiers() async {
    final response = await _apiClient.dio.get('/loyalty/tiers');
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => LoyaltyTierModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> redeemPointsToWallet(
    int points, {
    String? idempotencyKey,
  }) async {
    final payload = {
      'points': points,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
    final response = await _apiClient.dio.post(
      '/loyalty/redeem-to-wallet',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }
}
