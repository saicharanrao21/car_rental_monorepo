import 'package:mock_data/mock_data.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/fleet/domain/repositories/admin_fleet_repository.dart';
class MockAdminFleetRepository implements AdminFleetRepository {
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 500));

  @override
  Future<List<CarModel>> getAllCars({
    String? city,
    String? carType,
    bool? isAvailable,
    String? vendorId,
  }) async {
    await _delay();

    return MockData.cars.where((car) {
      // Find owning vendor
      final vendor = MockData.vendors.firstWhere(
        (v) => v.id == car.vendorId,
        orElse: () => const VendorModel(
          id: '',
          businessName: '',
          ownerName: '',
          city: '',
          verificationStatus: '',
        ),
      );

      if (city != null && city.isNotEmpty && vendor.city.toLowerCase() != city.toLowerCase()) {
        return false;
      }
      if (carType != null && carType.isNotEmpty && car.type.toLowerCase() != carType.toLowerCase()) {
        return false;
      }
      if (isAvailable != null && car.isAvailable != isAvailable) {
        return false;
      }
      if (vendorId != null && vendorId.isNotEmpty && car.vendorId != vendorId) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Future<CarModel> getCarDetail(String carId) async {
    await _delay();
    return MockData.cars.firstWhere(
      (c) => c.id == carId,
      orElse: () => throw Exception('Car not found: $carId'),
    );
  }

  @override
  Future<void> deactivateCarListing(String carId) async {
    await _delay();
    final idx = MockData.cars.indexWhere((c) => c.id == carId);
    if (idx != -1) {
      final old = MockData.cars[idx];
      MockData.cars[idx] = old.copyWith(isAvailable: false);
    }
  }

  @override
  Future<void> toggleMileagePackageActive(String carId, String packageId, bool isActive) async {
    await _delay();
  }
}
