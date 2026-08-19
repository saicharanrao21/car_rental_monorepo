import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/fleet_repository.dart';

class ApiFleetRepository implements FleetRepository {
  final ApiClient apiClient;

  ApiFleetRepository({required this.apiClient});

  Map<String, dynamic> _mapCarToBackendJson(CarModel car, {bool isUpdate = false}) {
    final typeUpper = car.type.toUpperCase().replaceAll(' ', '_');
    final fuelUpper = car.fuelType.toUpperCase().replaceAll(' ', '_');
    final tripTypesUpper = car.availableTripTypes.map((t) {
      return t.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    }).toList();

    return {
      'make': car.make,
      'model': car.model,
      'year': car.year,
      'type': typeUpper,
      'fuelType': fuelUpper,
      'seating': car.seating,
      'isAC': car.isAC,
      'registrationNumber': car.registrationNumber,
      'photos': car.photos,
      'pricePerKm': car.pricePerKm,
      'pricePerDay': car.pricePerDay,
      'pricePerHour': car.pricePerHour,
      if (!isUpdate) 'isAvailable': car.isAvailable,
      'availableTripTypes': tripTypesUpper,
    };
  }

  Map<String, dynamic> _normalizeCarJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    // Normalize prices to double
    for (final field in ['pricePerKm', 'pricePerDay', 'pricePerHour', 'rating']) {
      if (copy[field] != null) {
        copy[field] = double.tryParse(copy[field].toString()) ?? 0.0;
      } else if (field == 'rating') {
        copy[field] = 5.0;
      }
    }

    // Normalize blockedDates to List<DateTime> or strings
    if (copy['blockedDates'] != null) {
      final list = List<dynamic>.from(copy['blockedDates']);
      copy['blockedDates'] = list.map((d) => DateTime.parse(d.toString()).toIso8601String()).toList();
    }

    return copy;
  }

  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async {
    final response = await apiClient.dio.get('/vendors/me/cars');
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) {
      final normalized = _normalizeCarJson(Map<String, dynamic>.from(json));
      return CarModel.fromJson(normalized);
    }).toList();
  }

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {
    await apiClient.dio.patch(
      '/vendors/me/cars/$carId/availability',
      data: {
        'isAvailable': isAvailable,
      },
    );
  }

  @override
  Future<CarModel> addCar(CarModel car) async {
    final response = await apiClient.dio.post(
      '/vendors/me/cars',
      data: _mapCarToBackendJson(car, isUpdate: false),
    );
    final normalized = _normalizeCarJson(Map<String, dynamic>.from(response.data));
    return CarModel.fromJson(normalized);
  }

  @override
  Future<CarModel> updateCar(CarModel car) async {
    final response = await apiClient.dio.patch(
      '/vendors/me/cars/${car.id}',
      data: _mapCarToBackendJson(car, isUpdate: true),
    );
    final normalized = _normalizeCarJson(Map<String, dynamic>.from(response.data));
    return CarModel.fromJson(normalized);
  }

  @override
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {
    await apiClient.dio.patch(
      '/vendors/me/cars/$carId/blocked-dates',
      data: {
        'blockedDates': blockedDates.map((d) => d.toUtc().toIso8601String()).toList(),
      },
    );
  }

  @override
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {
    await apiClient.dio.post(
      '/vendors/me/documents',
      data: {
        'carId': carId,
        'type': type,
        'fileUrl': fileUrl,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async {
    final response = await apiClient.dio.get('/vendors/me/cars/$carId/mileage-packages');
    final List<dynamic> list = response.data is List ? response.data : [];
    return list.map((e) => MileagePackageModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async {
    final response = await apiClient.dio.post(
      '/vendors/me/cars/$carId/mileage-packages',
      data: package.toJson(),
    );
    return MileagePackageModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async {
    final response = await apiClient.dio.patch(
      '/vendors/me/cars/$carId/mileage-packages/${package.id}',
      data: package.toJson(),
    );
    return MileagePackageModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {
    await apiClient.dio.delete('/vendors/me/cars/$carId/mileage-packages/$packageId');
  }
}
