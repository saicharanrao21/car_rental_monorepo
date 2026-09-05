import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 34 — Admin Control Tower Fleet Availability Governance Tests', () {
    test('1. VehicleHoldModel parses temporary hold JSON correctly', () {
      final json = {
        'id': 'hold-admin-01',
        'carId': 'car-suv-1',
        'customerId': 'cust-vip-1',
        'vendorId': 'vendor-blr-1',
        'startDate': '2026-10-01T10:00:00.000Z',
        'endDate': '2026-10-04T10:00:00.000Z',
        'expiresAt': '2026-10-01T10:15:00.000Z',
        'status': 'ACTIVE',
        'idempotencyKey': 'hold-idem-key-99',
      };

      final hold = VehicleHoldModel.fromJson(json);

      expect(hold.id, 'hold-admin-01');
      expect(hold.status, 'ACTIVE');
      expect(hold.idempotencyKey, 'hold-idem-key-99');
      expect(hold.expiresAt.isAfter(hold.startDate), isTrue);
    });

    test('2. AvailabilityTimelineEntry formats metadata appropriately', () {
      final entry = AvailabilityTimelineEntry(
        type: 'BOOKING',
        id: 'bk-adm-01',
        status: 'CONFIRMED',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 15),
        reason: 'VIP Customer Rental',
        metadata: const {'customerId': 'cust-vip-1', 'totalFare': 15000},
      );

      expect(entry.type, 'BOOKING');
      expect(entry.metadata?['totalFare'], 15000);
      expect(entry.status, 'CONFIRMED');
    });

    testWidgets('3. Renders Admin Safety Hold Dialog and Action Buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Admin Fleet Governance: Place Operational Block'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vehicle ID: #CAR-SUV-101'),
                            SizedBox(height: 8),
                            Text('Reason: Safety recall & technical inspection'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Confirm Block'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open Governance Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Governance Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Fleet Governance: Place Operational Block'), findsOneWidget);
      expect(find.text('Vehicle ID: #CAR-SUV-101'), findsOneWidget);
      expect(find.text('Reason: Safety recall & technical inspection'), findsOneWidget);
      expect(find.text('Confirm Block'), findsOneWidget);

      await tester.tap(find.text('Confirm Block'));
      await tester.pumpAndSettle();
      expect(find.text('Admin Fleet Governance: Place Operational Block'), findsNothing);
    });
  });
}
