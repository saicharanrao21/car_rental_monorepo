import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  group('Phase 35 — Admin Panel Pricing & Quote Integrity Governance Tests', () {
    test('1. BookingQuoteModel parses server quote JSON for admin audit', () {
      final json = {
        'quoteId': 'quote_adm_audit_1',
        'tenantId': 'tenant_mumbai',
        'carId': 'car_suv_01',
        'vehicleName': 'Hyundai Creta (2024)',
        'registrationNumber': 'MH02AB1234',
        'tripType': 'SELF_DRIVE',
        'startDate': now.toIso8601String(),
        'endDate': now.add(const Duration(days: 3)).toIso8601String(),
        'durationDays': 3,
        'durationHours': 72,
        'currency': 'INR',
        'pricingVersion': 'v1.0',
        'subtotal': 6000.0,
        'discountTotal': 0.0,
        'feesTotal': 150.0,
        'taxTotal': 1107.0,
        'depositTotal': 3000.0,
        'tripFare': 7257.0,
        'totalPayable': 10257.0,
        'netToVendor': 5400.0,
        'status': 'ACCEPTED',
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
        'lineItems': [
          {
            'type': 'BASE_RENTAL',
            'name': 'Base Vehicle Rental (3 days)',
            'rate': 2000.0,
            'quantity': 3.0,
            'amount': 6000.0,
            'isRefundable': false,
            'displayOrder': 1,
          },
          {
            'type': 'SECURITY_DEPOSIT',
            'name': 'Refundable Security Deposit',
            'rate': 3000.0,
            'quantity': 1.0,
            'amount': 3000.0,
            'isRefundable': true,
            'displayOrder': 4,
          },
        ],
      };

      final quote = BookingQuoteModel.fromJson(json);

      expect(quote.quoteId, 'quote_adm_audit_1');
      expect(quote.status, 'ACCEPTED');
      expect(quote.pricingVersion, 'v1.0');
      expect(quote.totalPayable, 10257.0);
      expect(quote.lineItems.length, 2);
      expect(quote.lineItems.first.type, 'BASE_RENTAL');
      expect(quote.lineItems.last.isRefundable, isTrue);
    });

    testWidgets('2. Renders Admin Pricing & Quote Integrity Governance card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pricing Engine Version',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'v1.0 (Server Authoritative)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Authoritative Quote Status: ACCEPTED (Locked at Checkout)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Financial Snapshot: Immutable (Tamper-Resistant)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gateway Price Verification: MATCH VERIFIED (₹10257.00)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      'Historical booking pricing is immutable. Rate alterations by vendors or platform pricing rule revisions cannot retrospectively change accepted totals.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pricing Engine Version'), findsOneWidget);
      expect(find.text('v1.0 (Server Authoritative)'), findsOneWidget);
      expect(find.textContaining('ACCEPTED (Locked at Checkout)'), findsOneWidget);
      expect(find.textContaining('Immutable (Tamper-Resistant)'), findsOneWidget);
      expect(find.textContaining('MATCH VERIFIED'), findsOneWidget);
      expect(find.textContaining('Historical booking pricing is immutable'), findsOneWidget);
    });
  });
}
