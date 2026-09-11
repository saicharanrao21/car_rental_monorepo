import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';
import 'package:vendor_app/features/fleet/domain/models/vendor_fleet_models.dart';

class MockFleetRepository with LatencySimulator implements FleetRepository {
  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async {
    await simulateLatency();
    return MockData.cars.where((c) => c.vendorId == vendorId).toList();
  }

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {
    await simulateLatency();
    final index = MockData.cars.indexWhere((c) => c.id == carId);
    if (index != -1) {
      final oldCar = MockData.cars[index];
      MockData.cars[index] = oldCar.copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<CarModel> addCar(CarModel car) async {
    await simulateLatency();
    MockData.cars.add(car);
    return car;
  }

  @override
  Future<CarModel> updateCar(CarModel car) async {
    await simulateLatency();
    final index = MockData.cars.indexWhere((c) => c.id == car.id);
    if (index != -1) {
      MockData.cars[index] = car;
    }
    return car;
  }

  @override
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {
    await simulateLatency();
    final index = MockData.cars.indexWhere((c) => c.id == carId);
    if (index != -1) {
      final oldCar = MockData.cars[index];
      MockData.cars[index] = oldCar.copyWith(blockedDates: blockedDates);
    }
  }

  @override
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {
    await simulateLatency();
  }

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async {
    await simulateLatency();
    return [];
  }

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async {
    await simulateLatency();
    return package;
  }

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async {
    await simulateLatency();
    return package;
  }

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {
    await simulateLatency();
  }

  @override
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(
    String carId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await simulateLatency();
    return [];
  }

  @override
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId) async {
    await simulateLatency();
    return [];
  }

  @override
  Future<VehicleBlockModel> createVehicleBlock({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    required String blockType,
    String? reason,
  }) async {
    await simulateLatency();
    return VehicleBlockModel(
      id: 'mock_block_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      vendorId: 'mock_vendor',
      startDate: startDate,
      endDate: endDate,
      blockType: blockType,
      reason: reason,
      actorId: 'mock_vendor_user',
      actorRole: 'VENDOR',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<bool> deleteVehicleBlock(String blockId) async {
    await simulateLatency();
    return true;
  }

  @override
  Future<VehicleReadinessModel> getVehicleReadiness(String carId) async {
    await simulateLatency();
    return VehicleReadinessModel(
      eligible: true,
      carId: carId,
      operationalStatus: 'ACTIVE',
      verificationStatus: 'VERIFIED',
      blockers: [],
      requiredActions: [],
      vendorId: 'mock_vendor',
      vendorBusinessName: 'Apex Mobility',
      evaluatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> submitForVerification(String carId) async {
    await simulateLatency();
  }

  @override
  Future<void> activateVehicle(String carId) async {
    await simulateLatency();
  }

  @override
  Future<void> deactivateVehicle(String carId, {String? reason}) async {
    await simulateLatency();
  }

  @override
  Future<void> startMaintenance(String carId, {required String reason, String? expectedReturnDate}) async {
    await simulateLatency();
  }

  @override
  Future<void> completeMaintenance(String carId, {String? notes}) async {
    await simulateLatency();
  }

  @override
  Future<void> assignServiceArea(String carId, String serviceAreaId) async {
    await simulateLatency();
  }

  @override
  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId) async {
    await simulateLatency();
    return [];
  }
}
