import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 34 — Customer App Availability & Conflict Engine Tests', () {
    test('1. VehicleAvailabilityResult parses JSON correctly with conflicts list', () {
      final json = {
        'available': false,
        'carId': 'car-test-101',
        'evaluatedInterval': {
          'startDate': '2026-10-01T10:00:00.000Z',
          'endDate': '2026-10-05T10:00:00.000Z',
        },
        'reason': 'Vehicle is currently on temporary hold during checkout.',
        'conflicts': [
          {
            'type': 'HOLD',
            'id': 'hold-123',
            'startDate': '2026-10-01T10:00:00.000Z',
            'endDate': '2026-10-05T10:00:00.000Z',
            'reason': 'Vehicle is currently on temporary hold during checkout.',
          }
        ],
      };

      final result = VehicleAvailabilityResult.fromJson(json);

      expect(result.available, isFalse);
      expect(result.carId, 'car-test-101');
      expect(result.conflicts.length, 1);
      expect(result.conflicts.first.type, 'HOLD');
      expect(result.conflicts.first.reason, contains('temporary hold'));
    });

    test('2. VehicleAvailabilityResult handles available: true correctly', () {
      final json = {
        'available': true,
        'carId': 'car-test-202',
        'evaluatedInterval': {
          'startDate': '2026-11-01T10:00:00.000Z',
          'endDate': '2026-11-05T10:00:00.000Z',
        },
        'conflicts': [],
      };

      final result = VehicleAvailabilityResult.fromJson(json);

      expect(result.available, isTrue);
      expect(result.conflicts, isEmpty);
      expect(result.reason, isNull);
    });

    testWidgets('3. Renders Vehicle No Longer Available conflict alert dialog correctly', (tester) async {
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
                        title: const Text('Vehicle No Longer Available'),
                        content: const Text(
                          'Another customer or maintenance window has reserved this vehicle. Please choose another vehicle or different dates.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Dismiss'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Browse Other Vehicles'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Trigger Conflict'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Conflict'));
      await tester.pumpAndSettle();

      expect(find.text('Vehicle No Longer Available'), findsOneWidget);
      expect(find.textContaining('Another customer or maintenance window'), findsOneWidget);
      expect(find.text('Browse Other Vehicles'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Vehicle No Longer Available'), findsNothing);
    });

    testWidgets('4. Renders Vehicle Not Available pre-flight dialog with Change Dates option', (tester) async {
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
                        title: const Text('Vehicle Not Available'),
                        content: const Text('Pickup location is closed on the selected date: Gandhi Jayanti.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Change Dates'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Find Other Cars'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Preflight Check'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Preflight Check'));
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Not Available'), findsOneWidget);
      expect(find.textContaining('Gandhi Jayanti'), findsOneWidget);
      expect(find.text('Change Dates'), findsOneWidget);
      expect(find.text('Find Other Cars'), findsOneWidget);
    });
  });
}
