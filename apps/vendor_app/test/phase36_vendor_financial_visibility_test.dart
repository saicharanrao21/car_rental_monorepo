import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Phase 36 Vendor App: Financial Visibility & Settlement Integrity Tests', () {
    test('1. VendorPaymentSummaryModel parses sanitized server financial payload correctly', () {
      final json = {
        'bookingId': 'BK_P36_VND_01',
        'paymentStatus': 'PAID',
        'isPaid': true,
        'currency': 'INR',
        'tripFare': 12000.0,
        'netVendorEarnings': 10200.0,
        'platformCommission': 1800.0,
        'securityDepositHeld': 3000.0,
        'refundStatus': 'NONE',
        'refundAmount': 0.0,
        'settlementStatus': 'ELIGIBLE_FOR_SETTLEMENT',
      };

      final summary = VendorPaymentSummaryModel.fromJson(json);

      expect(summary.bookingId, 'BK_P36_VND_01');
      expect(summary.isPaid, true);
      expect(summary.paymentStatus, 'PAID');
      expect(summary.netVendorEarnings, 10200.0);
      expect(summary.platformCommission, 1800.0);
      expect(summary.settlementStatus, 'ELIGIBLE_FOR_SETTLEMENT');
    });

    testWidgets('2. Displays sanitized vendor financial card with net earnings & settlement eligibility',
        (tester) async {
      const summary = VendorPaymentSummaryModel(
        bookingId: 'BK_P36_VND_02',
        paymentStatus: 'PAID',
        isPaid: true,
        currency: 'INR',
        tripFare: 8000.0,
        netVendorEarnings: 6800.0,
        platformCommission: 1200.0,
        securityDepositHeld: 2000.0,
        refundStatus: 'NONE',
        refundAmount: 0.0,
        settlementStatus: 'ELIGIBLE_FOR_SETTLEMENT',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _VendorFinancialCard(summary: summary),
            ),
          ),
        ),
      );

      expect(find.text('Net Vendor Earnings: ₹6800'), findsOneWidget);
      expect(find.text('Platform Commission: ₹1200'), findsOneWidget);
      expect(find.text('Customer Fare: ₹8000'), findsOneWidget);
      expect(find.text('ELIGIBLE FOR SETTLEMENT'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
    });

    testWidgets('3. Displays refund deduction notice when booking is cancelled/refunded',
        (tester) async {
      const summary = VendorPaymentSummaryModel(
        bookingId: 'BK_P36_VND_03',
        paymentStatus: 'REFUNDED',
        isPaid: false,
        currency: 'INR',
        tripFare: 8000.0,
        netVendorEarnings: 0.0,
        platformCommission: 0.0,
        securityDepositHeld: 0.0,
        refundStatus: 'PROCESSED',
        refundAmount: 8000.0,
        settlementStatus: 'CANCELLED_REFUNDED',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _VendorFinancialCard(summary: summary),
            ),
          ),
        ),
      );

      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text('Customer Refund Credited: ₹8000'), findsOneWidget);
      expect(find.text('SETTLEMENT CLOSED'), findsOneWidget);
    });
  });
}

class _VendorFinancialCard extends StatelessWidget {
  final VendorPaymentSummaryModel summary;
  const _VendorFinancialCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Booking #${summary.bookingId}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: summary.isPaid
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    summary.paymentStatus,
                    style: TextStyle(
                      color: summary.isPaid ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Customer Fare: ₹${summary.tripFare.toStringAsFixed(0)}'),
            Text('Platform Commission: ₹${summary.platformCommission.toStringAsFixed(0)}'),
            Text(
              'Net Vendor Earnings: ₹${summary.netVendorEarnings.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (summary.refundAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Customer Refund Credited: ₹${summary.refundAmount.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Chip(
              label: Text(
                summary.settlementStatus == 'ELIGIBLE_FOR_SETTLEMENT'
                    ? 'ELIGIBLE FOR SETTLEMENT'
                    : 'SETTLEMENT CLOSED',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
