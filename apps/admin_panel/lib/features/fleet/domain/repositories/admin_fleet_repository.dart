import 'package:models/models.dart';
import '../models/vendor_fleet_models.dart';

abstract class AdminFleetRepository {
  Future<List<CarModel>> getAllCars({
    String? city,
    String? carType,
    bool? isAvailable,
    String? vendorId,
  });

  Future<CarModel> getCarDetail(String carId);

  Future<void> deactivateCarListing(String carId);

  Future<void> toggleMileagePackageActive(String carId, String packageId, bool isActive);

  // --- Phase H Vendor Fleet Operations ---
  Future<FleetKpisModel> getFleetKPIs();

  Future<List<AdminFleetVehicleModel>> getFleetVehicles({
    int page = 1,
    int limit = 20,
    String? search,
    String? city,
    String? vendorId,
    String? serviceAreaId,
    String? operationalStatus,
    String? verificationStatus,
  });

  Future<VehicleReadinessModel> getVehicleReadiness(String carId);

  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId);

  Future<void> verifyVehicle(String carId, {String? notes, bool? autoActivate});

  Future<void> rejectVehicle(String carId, {required String reason});

  Future<void> activateVehicle(String carId, {String? reason});

  Future<void> deactivateVehicle(String carId, {String? reason});

  Future<void> suspendVehicle(String carId, {required String reason});

  Future<void> retireVehicle(String carId, {required String reason});

  Future<void> startMaintenance(
    String carId, {
    required String reason,
    String? expectedReturnDate,
    bool? overrideConflictingBookings,
  });

  Future<void> completeMaintenance(String carId, {String? notes});
}
