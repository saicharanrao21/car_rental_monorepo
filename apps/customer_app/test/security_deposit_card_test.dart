import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('SecurityDepositModel & Status Parsing', () {
    test('parses HELD security deposit correctly', () {
      final json = {
        'id': 'dep_1',
        'bookingId': 'book_100',
        'amount': 5000.0,
        'refundedAmount': 0.0,
        'deductedAmount': 0.0,
        'status': 'HELD',
        'createdAt': '2026-08-14T12:00:00Z',
      };

      final deposit = SecurityDepositModel.fromJson(json);

      expect(deposit.id, 'dep_1');
      expect(deposit.bookingId, 'book_100');
      expect(deposit.amount, 5000.0);
      expect(deposit.status, SecurityDepositStatus.HELD);
      expect(deposit.refundedAmount, 0.0);
      expect(deposit.deductedAmount, 0.0);
    });

    test('parses PARTIALLY_REFUNDED deposit with deductions', () {
      final json = {
        'id': 'dep_2',
        'bookingId': 'book_101',
        'amount': 5000.0,
        'refundedAmount': 3000.0,
        'deductedAmount': 2000.0,
        'status': 'PARTIALLY_REFUNDED',
        'releasedAt': '2026-08-14T14:30:00Z',
        'createdAt': '2026-08-14T12:00:00Z',
      };

      final deposit = SecurityDepositModel.fromJson(json);

      expect(deposit.status, SecurityDepositStatus.PARTIALLY_REFUNDED);
      expect(deposit.amount, 5000.0);
      expect(deposit.deductedAmount, 2000.0);
      expect(deposit.refundedAmount, 3000.0);
      expect(deposit.releasedAt, isNotNull);
    });

    test('parses REFUNDED deposit', () {
      final json = {
        'id': 'dep_3',
        'bookingId': 'book_102',
        'amount': 5000.0,
        'refundedAmount': 5000.0,
        'deductedAmount': 0.0,
        'status': 'REFUNDED',
        'releasedAt': '2026-08-14T15:00:00Z',
        'createdAt': '2026-08-14T12:00:00Z',
      };

      final deposit = SecurityDepositModel.fromJson(json);

      expect(deposit.status, SecurityDepositStatus.REFUNDED);
      expect(deposit.amount, 5000.0);
      expect(deposit.refundedAmount, 5000.0);
    });
  });
}
