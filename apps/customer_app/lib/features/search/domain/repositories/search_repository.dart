import 'package:models/models.dart';

abstract class SearchRepository {
  Future<List<CarModel>> searchCars({
    required String city,
    String? carType,
    bool? isAC,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  });
}
