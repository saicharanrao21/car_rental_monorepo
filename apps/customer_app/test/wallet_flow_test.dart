import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/wallet/data/wallet_repository.dart';

class MockWalletRepository implements WalletRepository {
  WalletModel wallet = WalletModel(
    id: 'wlt_test',
    userId: 'usr_test',
    currency: 'INR',
    availableBalance: 1500.0,
    lockedBalance: 0.0,
    realBalance: 1000.0,
    promoBalance: 500.0,
    status: WalletStatus.ACTIVE,
    createdAt: DateTime(2026, 8, 16),
    updatedAt: DateTime(2026, 8, 16),
  );

  final List<WalletLedgerEntryModel> transactions = [
    WalletLedgerEntryModel(
      id: 'tx_1',
      walletId: 'wlt_test',
      type: LedgerEntryType.CUSTOMER_DEPOSIT,
      direction: LedgerDirection.CREDIT,
      bucket: WalletBucketType.REAL_MONEY,
      amount: 1000.0,
      balanceBefore: 500.0,
      balanceAfter: 1500.0,
      referenceType: 'PAYMENT',
      referenceId: 'pay_123',
      idempotencyKey: 'wallet_deposit_pay_123',
      description: 'Deposit via Razorpay',
      createdAt: DateTime(2026, 8, 16),
    ),
  ];

  @override
  Future<WalletModel> getWallet() async => wallet;

  @override
  Future<List<WalletLedgerEntryModel>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async =>
      transactions;

  @override
  Future<Map<String, dynamic>> createDepositOrder(double amount) async {
    return {
      'orderId': 'order_test_123',
      'amount': amount,
      'currency': 'INR',
      'keyId': 'rzp_test_mockKey',
      'isMock': true,
    };
  }

  @override
  Future<Map<String, dynamic>> verifyDeposit({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    wallet = WalletModel(
      id: wallet.id,
      userId: wallet.userId,
      currency: wallet.currency,
      availableBalance: wallet.availableBalance + 1000.0,
      lockedBalance: wallet.lockedBalance,
      realBalance: wallet.realBalance + 1000.0,
      promoBalance: wallet.promoBalance,
      status: wallet.status,
      createdAt: wallet.createdAt,
      updatedAt: DateTime.now(),
    );
    return {'success': true, 'message': 'Wallet recharge successful.'};
  }
}

void main() {
  group('Customer Wallet Repository Tests', () {
    late MockWalletRepository repo;

    setUp(() {
      repo = MockWalletRepository();
    });

    test('getWallet returns correct active balance and bucket breakdown', () async {
      final wallet = await repo.getWallet();

      expect(wallet.id, 'wlt_test');
      expect(wallet.availableBalance, 1500.0);
      expect(wallet.realBalance, 1000.0);
      expect(wallet.promoBalance, 500.0);
      expect(wallet.status, WalletStatus.ACTIVE);
    });

    test('getTransactions returns ledger entries with directions', () async {
      final txs = await repo.getTransactions();

      expect(txs.length, 1);
      expect(txs.first.type, LedgerEntryType.CUSTOMER_DEPOSIT);
      expect(txs.first.direction, LedgerDirection.CREDIT);
      expect(txs.first.bucket, WalletBucketType.REAL_MONEY);
      expect(txs.first.amount, 1000.0);
    });

    test('createDepositOrder and verifyDeposit updates wallet balance', () async {
      final order = await repo.createDepositOrder(1000.0);
      expect(order['orderId'], 'order_test_123');
      expect(order['isMock'], true);

      final result = await repo.verifyDeposit(
        orderId: order['orderId'],
        paymentId: 'pay_test_456',
        signature: 'mock_sig',
      );

      expect(result['success'], true);
      final updatedWallet = await repo.getWallet();
      expect(updatedWallet.availableBalance, 2500.0);
      expect(updatedWallet.realBalance, 2000.0);
    });
  });
}
