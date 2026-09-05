import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';

class TestAvailabilityFleetRepository implements FleetRepository {
  final List<VehicleBlockModel> blocks = [];

  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async => [];

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {}

  @override
  Future<CarModel> addCar(CarModel car) async => car;

  @override
  Future<CarModel> updateCar(CarModel car) async => car;

  @override
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {}

  @override
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async => [];

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {}

  @override
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(
    String carId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return [
      AvailabilityTimelineEntry(
        type: 'MAINTENANCE',
        id: 'block-m1',
        status: 'MAINTENANCE',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3),
        reason: 'Periodic 20,000 km Brake Service',
      ),
      AvailabilityTimelineEntry(
        type: 'BOOKING',
        id: 'bk-test-99',
        status: 'CONFIRMED',
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 8),
      ),
    ];
  }

  @override
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId) async => blocks;

  @override
  Future<VehicleBlockModel> createVehicleBlock({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    required String blockType,
    String? reason,
  }) async {
    final b = VehicleBlockModel(
      id: 'block-${blocks.length + 1}',
      carId: carId,
      vendorId: 'vendor-1',
      startDate: startDate,
      endDate: endDate,
      blockType: blockType,
      reason: reason,
      actorId: 'user-vendor-1',
      actorRole: 'VENDOR',
      createdAt: DateTime.now(),
    );
    blocks.add(b);
    return b;
  }

  @override
  Future<bool> deleteVehicleBlock(String blockId) async {
    blocks.removeWhere((b) => b.id == blockId);
    return true;
  }
}

class FastSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  FastSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testVendor = VendorModel(
    id: 'vendor-1',
    businessName: 'DriveGo Bangalore Fleet',
    ownerName: 'Sunil Kumar',
    email: 'sunil@drivego.in',
    phone: '+919876543210',
    city: 'Bengaluru',
    verificationStatus: 'VERIFIED',
  );

  group('Phase 34 — Vendor Fleet Availability & Block Management Tests', () {
    test('1. VehicleBlockModel correctly serializes and deserializes', () {
      final json = {
        'id': 'block-101',
        'carId': 'car-202',
        'vendorId': 'vendor-303',
        'startDate': '2026-10-01T00:00:00.000Z',
        'endDate': '2026-10-03T00:00:00.000Z',
        'blockType': 'MAINTENANCE',
        'reason': 'Oil Change & Filter Replacement',
        'actorId': 'user-1',
        'actorRole': 'VENDOR',
        'createdAt': '2026-09-01T00:00:00.000Z',
      };

      final block = VehicleBlockModel.fromJson(json);

      expect(block.id, 'block-101');
      expect(block.carId, 'car-202');
      expect(block.blockType, 'MAINTENANCE');
      expect(block.reason, contains('Oil Change'));
      expect(block.actorRole, 'VENDOR');
    });

    test('2. AvailabilityTimelineEntry correctly parses timeline events', () {
      final json = {
        'type': 'MAINTENANCE',
        'id': 'maint-01',
        'status': 'MAINTENANCE',
        'startDate': '2026-10-05T10:00:00.000Z',
        'endDate': '2026-10-07T10:00:00.000Z',
        'reason': 'Tyre Replacement',
      };

      final entry = AvailabilityTimelineEntry.fromJson(json);

      expect(entry.type, 'MAINTENANCE');
      expect(entry.reason, 'Tyre Replacement');
      expect(entry.startDate.isBefore(entry.endDate), isTrue);
    });

    test('3. FleetController creates and deletes vehicle blocks with state updates', () async {
      final repo = TestAvailabilityFleetRepository();
      final container = ProviderContainer(
        overrides: [
          vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
          fleetRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final controller = container.read(fleetControllerProvider.notifier);

      final success = await controller.createBlock(
        carId: 'car-test-01',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 4),
        blockType: 'MAINTENANCE',
        reason: 'Transmission Servicing',
      );

      expect(success, isTrue);
      expect(repo.blocks.length, 1);
      expect(repo.blocks.first.reason, 'Transmission Servicing');

      final deleteSuccess = await controller.deleteBlock(
        blockId: repo.blocks.first.id,
        carId: 'car-test-01',
      );

      expect(deleteSuccess, isTrue);
      expect(repo.blocks, isEmpty);
    });

    testWidgets('4. Renders Availability Timeline entries in Vendor fleet widget', (tester) async {
      final timeline = [
        AvailabilityTimelineEntry(
          type: 'MAINTENANCE',
          id: 'block-m1',
          status: 'MAINTENANCE',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 3),
          reason: 'Periodic Brake Service',
        ),
        AvailabilityTimelineEntry(
          type: 'BOOKING',
          id: 'bk-99',
          status: 'CONFIRMED',
          startDate: DateTime(2026, 10, 5),
          endDate: DateTime(2026, 10, 8),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: timeline.length,
              itemBuilder: (ctx, i) {
                final entry = timeline[i];
                return ListTile(
                  leading: Icon(
                    entry.type == 'MAINTENANCE' ? Icons.build_circle : Icons.directions_car,
                    color: entry.type == 'MAINTENANCE' ? Colors.orange : Colors.green,
                  ),
                  title: Text(entry.type == 'MAINTENANCE' ? 'Maintenance Window' : 'Active Booking'),
                  subtitle: Text(entry.reason ?? 'Reserved Interval'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Maintenance Window'), findsOneWidget);
      expect(find.text('Active Booking'), findsOneWidget);
      expect(find.text('Periodic Brake Service'), findsOneWidget);
    });
  });
}
