import 'package:core/core.dart';
import 'package:models/models.dart';
import 'wallet_repository.dart';

class ApiWalletRepository implements WalletRepository {
  final ApiClient apiClient;

  ApiWalletRepository({required this.apiClient});

  @override
  Future<WalletModel> getWallet() async {
    final response = await apiClient.dio.get('/wallet');
    return WalletModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<WalletLedgerEntryModel>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.dio.get(
      '/wallet/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['entries'] as List<dynamic>? ?? [];
    return list
        .map((e) => WalletLedgerEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createDepositOrder(double amount) async {
    final response = await apiClient.dio.post(
      '/wallet/deposit/create-order',
      data: {'amount': amount},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> verifyDeposit({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await apiClient.dio.post(
      '/wallet/deposit/verify',
      data: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
