import 'package:models/models.dart';

abstract class AdminFleetRepository {
  Future<List<CarModel>> getAllCars({
    String? city,
    String? carType,
    bool? isAvailable,
    String? vendorId,
  });

  Future<CarModel> getCarDetail(String carId);

  Future<void> deactivateCarListing(String carId);
}
