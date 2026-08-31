import 'package:models/models.dart';

abstract class SearchRepository {
  Future<List<CarModel>> searchCars({
    required String city,
    double? lat,
    double? lng,
    String? tripType,
    DateTime? startDate,
    DateTime? endDate,
    String? carType,
    bool? isAC,
    String? fuelType,
    int? seating,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  });
}
