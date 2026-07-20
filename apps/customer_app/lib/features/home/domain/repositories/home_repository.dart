import 'package:models/models.dart';

abstract class HomeRepository {
  Future<List<CarModel>> getCarsByCity(String city);
  Future<List<VendorModel>> getTopVendorsByCity(String city);
  Future<List<BannerModel>> getBanners();
}
