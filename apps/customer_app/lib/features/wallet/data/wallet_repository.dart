import 'package:models/models.dart';

abstract class WalletRepository {
  Future<WalletModel> getWallet();
  Future<List<WalletLedgerEntryModel>> getTransactions({int page = 1, int limit = 20});
  Future<Map<String, dynamic>> createDepositOrder(double amount);
  Future<Map<String, dynamic>> verifyDeposit({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
