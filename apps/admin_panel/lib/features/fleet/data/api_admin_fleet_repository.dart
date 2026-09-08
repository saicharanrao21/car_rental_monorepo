import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_fleet_repository.dart';
import '../domain/models/vendor_fleet_models.dart';

class ApiAdminFleetRepository implements AdminFleetRepository {
  final ApiClient apiClient;

  ApiAdminFleetRepository({required this.apiClient});

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Map<String, dynamic> _normalizeCarJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in ['pricePerKm', 'pricePerDay', 'pricePerHour', 'rating']) {
      if (copy[field] != null) {
        copy[field] = _toDouble(copy[field]);
      } else if (field == 'rating') {
        copy[field] = 5.0;
      }
    }
    return copy;
  }

  @override
  Future<List<CarModel>> getAllCars({
    String? city,
    String? carType,
    bool? isAvailable,
    String? vendorId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (city != null && city.isNotEmpty) queryParams['city'] = city;
    if (carType != null && carType.isNotEmpty) queryParams['carType'] = carType.toUpperCase();
    if (isAvailable != null) queryParams['isAvailable'] = isAvailable;
    if (vendorId != null && vendorId.isNotEmpty) queryParams['vendorId'] = vendorId;

    final res = await apiClient.dio.get('/admin/cars', queryParameters: queryParams);
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);

    return list.map((item) => CarModel.fromJson(_normalizeCarJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<CarModel> getCarDetail(String carId) async {
    final res = await apiClient.dio.get('/cars/$carId');
    return CarModel.fromJson(_normalizeCarJson(res.data as Map<String, dynamic>));
  }

  @override
  Future<void> deactivateCarListing(String carId) async {
    await apiClient.dio.patch('/admin/cars/$carId/deactivate');
  }

  @override
  Future<void> toggleMileagePackageActive(String carId, String packageId, bool isActive) async {
    await apiClient.dio.patch(
      '/admin/cars/$carId/mileage-packages/$packageId/toggle-active',
      data: {'isActive': isActive},
    );
  }

  // --- Phase H Implementation ---

  @override
  Future<FleetKpisModel> getFleetKPIs() async {
    final res = await apiClient.dio.get('/admin/fleet/kpis');
    return FleetKpisModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<AdminFleetVehicleModel>> getFleetVehicles({
    int page = 1,
    int limit = 50,
    String? search,
    String? city,
    String? vendorId,
    String? serviceAreaId,
    String? operationalStatus,
    String? verificationStatus,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (city != null && city.isNotEmpty && city != 'All') queryParams['city'] = city;
    if (vendorId != null && vendorId.isNotEmpty && vendorId != 'All') queryParams['vendorId'] = vendorId;
    if (serviceAreaId != null && serviceAreaId.isNotEmpty && serviceAreaId != 'All') {
      queryParams['serviceAreaId'] = serviceAreaId;
    }
    if (operationalStatus != null && operationalStatus.isNotEmpty && operationalStatus != 'All') {
      queryParams['operationalStatus'] = operationalStatus;
    }
    if (verificationStatus != null && verificationStatus.isNotEmpty && verificationStatus != 'All') {
      queryParams['verificationStatus'] = verificationStatus;
    }

    final res = await apiClient.dio.get('/admin/fleet', queryParameters: queryParams);
    final raw = res.data;
    final List list = raw is Map ? (raw['data'] as List? ?? []) : (raw as List);

    return list.map((item) => AdminFleetVehicleModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<VehicleReadinessModel> getVehicleReadiness(String carId) async {
    final res = await apiClient.dio.get('/admin/fleet/$carId/readiness');
    return VehicleReadinessModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<VehicleAuditLogModel>> getVehicleAuditLogs(String carId) async {
    final res = await apiClient.dio.get('/admin/fleet/$carId/audit-logs');
    final List list = res.data as List? ?? [];
    return list.map((item) => VehicleAuditLogModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> verifyVehicle(String carId, {String? notes, bool? autoActivate}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/verify',
      data: {
        if (notes != null) 'notes': notes,
        if (autoActivate != null) 'autoActivate': autoActivate,
      },
    );
  }

  @override
  Future<void> rejectVehicle(String carId, {required String reason}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/reject',
      data: {'reason': reason},
    );
  }

  @override
  Future<void> activateVehicle(String carId, {String? reason}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/activate',
      data: {'reason': reason ?? 'Administrative operational activation'},
    );
  }

  @override
  Future<void> deactivateVehicle(String carId, {String? reason}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/deactivate',
      data: {'reason': reason ?? 'Administrative operational deactivation'},
    );
  }

  @override
  Future<void> suspendVehicle(String carId, {required String reason}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/suspend',
      data: {'reason': reason},
    );
  }

  @override
  Future<void> retireVehicle(String carId, {required String reason}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/retire',
      data: {'reason': reason},
    );
  }

  @override
  Future<void> startMaintenance(
    String carId, {
    required String reason,
    String? expectedReturnDate,
    bool? overrideConflictingBookings,
  }) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/maintenance/start',
      data: {
        'reason': reason,
        if (expectedReturnDate != null) 'expectedReturnDate': expectedReturnDate,
        if (overrideConflictingBookings != null) 'overrideConflictingBookings': overrideConflictingBookings,
      },
    );
  }

  @override
  Future<void> completeMaintenance(String carId, {String? notes}) async {
    await apiClient.dio.post(
      '/admin/fleet/$carId/maintenance/complete',
      data: {if (notes != null) 'notes': notes},
    );
  }
}
