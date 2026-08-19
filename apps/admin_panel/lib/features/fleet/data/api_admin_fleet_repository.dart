import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_fleet_repository.dart';

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
}
