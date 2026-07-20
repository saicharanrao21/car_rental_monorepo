import 'package:models/models.dart';

abstract class FleetRepository {
  Future<List<CarModel>> getCarsForVendor(String vendorId);
  Future<void> toggleCarAvailability(String carId, bool isAvailable);
  Future<CarModel> addCar(CarModel car);
  Future<CarModel> updateCar(CarModel car);
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates);
}
