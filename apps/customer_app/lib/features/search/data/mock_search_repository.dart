import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/search_repository.dart';

class MockSearchRepository with LatencySimulator implements SearchRepository {
  final MockCarRepository _carRepository;

  MockSearchRepository({
    MockCarRepository? carRepository,
  }) : _carRepository = carRepository ?? MockCarRepository();

  @override
  Future<List<CarModel>> searchCars({
    required String city,
    double? lat,
    double? lng,
    String? tripType,
    String? carType,
    bool? isAC,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async {
    await simulateLatency();

    final cars = await _carRepository.getCarsByCity(city);

    var filteredCars = cars.where((car) {
      if (carType != null && car.type.toLowerCase() != carType.toLowerCase()) {
        return false;
      }
      if (isAC != null && car.isAC != isAC) {
        return false;
      }
      if (minPrice != null && car.pricePerDay < minPrice) {
        return false;
      }
      if (maxPrice != null && car.pricePerDay > maxPrice) {
        return false;
      }
      if (minRating != null && car.rating < minRating) {
        return false;
      }
      return true;
    }).toList();

    if (sortBy == 'Price Low-High') {
      filteredCars.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
    } else if (sortBy == 'Price High-Low') {
      filteredCars.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
    } else if (sortBy == 'Rating') {
      filteredCars.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      filteredCars.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        return a.pricePerDay.compareTo(b.pricePerDay);
      });
    }

    return filteredCars;
  }
}
