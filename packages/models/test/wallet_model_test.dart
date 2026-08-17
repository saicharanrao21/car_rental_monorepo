import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('WalletModel Tests', () {
    test('WalletModel.fromJson parses wallet payload correctly', () {
      final json = {
        'id': 'wlt_123',
        'userId': 'usr_456',
        'currency': 'INR',
        'availableBalance': 2500.50,
        'lockedBalance': 500.0,
        'realBalance': 2000.50,
        'promoBalance': 500.0,
        'status': 'ACTIVE',
        'createdAt': '2026-08-16T12:00:00.000Z',
        'updatedAt': '2026-08-16T12:00:00.000Z',
      };

      final wallet = WalletModel.fromJson(json);

      expect(wallet.id, 'wlt_123');
      expect(wallet.userId, 'usr_456');
      expect(wallet.currency, 'INR');
      expect(wallet.availableBalance, 2500.50);
      expect(wallet.lockedBalance, 500.0);
      expect(wallet.realBalance, 2000.50);
      expect(wallet.promoBalance, 500.0);
      expect(wallet.status, WalletStatus.ACTIVE);
    });

    test('WalletLedgerEntryModel.fromJson parses ledger transaction correctly', () {
      final json = {
        'id': 'led_789',
        'walletId': 'wlt_123',
        'type': 'CUSTOMER_DEPOSIT',
        'direction': 'CREDIT',
        'bucket': 'REAL_MONEY',
        'amount': 1000.0,
        'balanceBefore': 1500.50,
        'balanceAfter': 2500.50,
        'referenceType': 'PAYMENT',
        'referenceId': 'pay_abc',
        'idempotencyKey': 'wallet_deposit_pay_abc',
        'description': 'Added funds via Razorpay',
        'createdAt': '2026-08-16T12:00:00.000Z',
      };

      final entry = WalletLedgerEntryModel.fromJson(json);

      expect(entry.id, 'led_789');
      expect(entry.walletId, 'wlt_123');
      expect(entry.type, LedgerEntryType.CUSTOMER_DEPOSIT);
      expect(entry.direction, LedgerDirection.CREDIT);
      expect(entry.bucket, WalletBucketType.REAL_MONEY);
      expect(entry.amount, 1000.0);
      expect(entry.balanceBefore, 1500.50);
      expect(entry.balanceAfter, 2500.50);
      expect(entry.idempotencyKey, 'wallet_deposit_pay_abc');
    });
  });
}
