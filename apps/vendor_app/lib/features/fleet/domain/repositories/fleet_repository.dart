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
}
