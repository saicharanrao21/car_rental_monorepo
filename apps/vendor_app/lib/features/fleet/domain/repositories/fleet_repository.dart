import 'package:models/models.dart';

abstract class FleetRepository {
  Future<List<CarModel>> getCarsForVendor(String vendorId);
  Future<void> toggleCarAvailability(String carId, bool isAvailable);
  Future<CarModel> addCar(CarModel car);
  Future<CarModel> updateCar(CarModel car);
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates);
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  });
  Future<List<MileagePackageModel>> getMileagePackages(String carId);
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package);
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package);
  Future<void> deleteMileagePackage(String carId, String packageId);

  // Phase 34: Availability & Blocks
  Future<List<AvailabilityTimelineEntry>> getVehicleAvailabilityTimeline(
    String carId,
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<VehicleBlockModel>> getVehicleBlocks(String carId);
  Future<VehicleBlockModel> createVehicleBlock({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    required String blockType,
    String? reason,
  });
  Future<bool> deleteVehicleBlock(String blockId);
}
