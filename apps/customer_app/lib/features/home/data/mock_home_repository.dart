import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/home_repository.dart';

class MockHomeRepository implements HomeRepository {
  final MockCarRepository _carRepository;
  final MockVendorRepository _vendorRepository;
  final MockBannerRepository _bannerRepository;

  MockHomeRepository({
    MockCarRepository? carRepository,
    MockVendorRepository? vendorRepository,
    MockBannerRepository? bannerRepository,
  })  : _carRepository = carRepository ?? MockCarRepository(),
        _vendorRepository = vendorRepository ?? MockVendorRepository(),
        _bannerRepository = bannerRepository ?? MockBannerRepository();

  @override
  Future<List<CarModel>> getCarsByCity(String city) {
    return _carRepository.getCarsByCity(city);
  }

  @override
  Future<List<VendorModel>> getTopVendorsByCity(String city) {
    return _vendorRepository.getVendorsByCity(city);
  }

  @override
  Future<List<BannerModel>> getBanners() {
    return _bannerRepository.getActiveBanners();
  }
}
