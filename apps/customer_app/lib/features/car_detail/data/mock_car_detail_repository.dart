import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/car_detail_repository.dart';

class MockCarDetailRepository implements CarDetailRepository {
  final MockCarRepository _carRepository;
  final MockVendorRepository _vendorRepository;
  final MockReviewRepository _reviewRepository;

  MockCarDetailRepository({
    MockCarRepository? carRepository,
    MockVendorRepository? vendorRepository,
    MockReviewRepository? reviewRepository,
  })  : _carRepository = carRepository ?? MockCarRepository(),
        _vendorRepository = vendorRepository ?? MockVendorRepository(),
        _reviewRepository = reviewRepository ?? MockReviewRepository();

  @override
  Future<CarModel> getCarById(String id) async {
    final car = await _carRepository.getCarById(id);
    if (car == null) {
      throw Exception('Car not found with ID: $id');
    }
    return car;
  }

  @override
  Future<VendorModel> getVendorById(String vendorId) async {
    final vendor = await _vendorRepository.getVendorById(vendorId);
    if (vendor == null) {
      throw Exception('Vendor not found with ID: $vendorId');
    }
    return vendor;
  }

  @override
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId) {
    return _reviewRepository.getReviewsByVendor(vendorId);
  }
}
