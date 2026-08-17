import 'package:core/core.dart';
import 'package:models/models.dart';
import 'admin_loyalty_repository.dart';

class ApiAdminLoyaltyRepository implements AdminLoyaltyRepository {
  final ApiClient apiClient;

  ApiAdminLoyaltyRepository({required this.apiClient});

  @override
  Future<LoyaltySummaryModel> getSummary() async {
    final response = await apiClient.dio.get('/admin/loyalty/summary');
    return LoyaltySummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getAccounts({
    String? search,
    LoyaltyTierCode? tierCode,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      '/admin/loyalty/accounts',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (tierCode != null) 'tierCode': tierCode.toDbString(),
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<LoyaltyTransactionModel>> getAccountTransactions(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      '/admin/loyalty/accounts/$userId/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((e) => LoyaltyTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> adjustPoints({
    required String userId,
    required int points,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/admin/loyalty/adjust',
      data: {
        'userId': userId,
        'points': points,
        'reason': reason,
        'idempotencyKey': idempotencyKey,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
