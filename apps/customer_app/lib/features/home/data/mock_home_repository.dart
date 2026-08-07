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
  Future<List<CarModel>> getCarsByCity(
    String city, {
    double? lat,
    double? lng,
    String sortBy = 'RECOMMENDED',
  }) {
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

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async {
    return const [
      SupportedCityModel(id: '1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
      SupportedCityModel(id: '2', name: 'Delhi', state: 'Delhi', latitude: 28.6139, longitude: 77.2090),
      SupportedCityModel(id: '3', name: 'Bangalore', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946),
      SupportedCityModel(id: '4', name: 'Chennai', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707),
      SupportedCityModel(id: '5', name: 'Hyderabad', state: 'Telangana', latitude: 17.3850, longitude: 78.4867),
    ];
  }

  @override
  Future<SupportedCityModel> getNearestCity(double lat, double lng) async {
    return const SupportedCityModel(id: '1', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777);
  }

  @override
  Future<PublicSettingsModel> getPublicSettings() async {
    return const PublicSettingsModel(
      platformName: 'DriveGo',
      supportEmail: 'support@drivego.in',
      supportPhone: '+919876543210',
      enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
    );
  }
}
