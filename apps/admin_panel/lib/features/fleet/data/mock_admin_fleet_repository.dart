import 'package:mock_data/mock_data.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/fleet/domain/repositories/admin_fleet_repository.dart';
import '../domain/models/vendor_fleet_models.dart';

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

  @override
  Future<FleetKpisModel> getFleetKPIs() async {
    await _delay();
    return const FleetKpisModel(
      total: 10,
      active: 8,
      pendingVerification: 1,
      maintenance: 1,
      suspended: 0,
      inactive: 0,
      retired: 0,
      verifiedCount: 9,
      unverifiedCount: 1,
      operationalReadinessRate: 80.0,
    );
  }

  @override
  Future<List<AdminFleetVehicleModel>> getFleetVehicles({
    int page = 1,
    int limit = 20,
    String? search,
    String? city,
    String? vendorId,
    String? serviceAreaId,
    String? operationalStatus,
    String? verificationStatus,
  }) async {
    await _delay();
    return [];
  }

  @override
  Future<VehicleReadinessModel> getVehicleReadiness(String carId) async {
    await _delay();
    return VehicleReadinessModel(
      eligible: true,
      carId: carId,
      operationalStatus: 'ACTIVE',
      verificationStatus: 'VERIFIED',
      blockers: [],
      requiredActions: [],
      vendorId: 'vendor-1',
      vendorBusinessName: 'Apex Mobility',
      evaluatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId) async {
    await _delay();
    return [];
  }

  @override
  Future<void> verifyVehicle(String carId, {String? notes, bool? autoActivate}) async {
    await _delay();
  }

  @override
  Future<void> rejectVehicle(String carId, {required String reason}) async {
    await _delay();
  }

  @override
  Future<void> activateVehicle(String carId, {String? reason}) async {
    await _delay();
  }

  @override
  Future<void> deactivateVehicle(String carId, {String? reason}) async {
    await _delay();
  }

  @override
  Future<void> suspendVehicle(String carId, {required String reason}) async {
    await _delay();
  }

  @override
  Future<void> retireVehicle(String carId, {required String reason}) async {
    await _delay();
  }

  @override
  Future<void> startMaintenance(
    String carId, {
    required String reason,
    String? expectedReturnDate,
    bool? overrideConflictingBookings,
  }) async {
    await _delay();
  }

  @override
  Future<void> completeMaintenance(String carId, {String? notes}) async {
    await _delay();
  }
}
