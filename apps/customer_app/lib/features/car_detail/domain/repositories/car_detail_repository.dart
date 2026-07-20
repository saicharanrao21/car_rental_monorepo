import 'package:models/models.dart';

abstract class CarDetailRepository {
  Future<CarModel> getCarById(String id);
  Future<VendorModel> getVendorById(String vendorId);
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId);
}
