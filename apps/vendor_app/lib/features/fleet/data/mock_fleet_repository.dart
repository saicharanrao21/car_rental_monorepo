import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/fleet_repository.dart';

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
}
