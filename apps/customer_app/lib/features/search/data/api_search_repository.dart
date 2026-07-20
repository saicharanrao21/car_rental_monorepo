import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/search_repository.dart';

class ApiSearchRepository implements SearchRepository {
  final ApiClient apiClient;

  ApiSearchRepository({required this.apiClient});

  @override
  Future<List<CarModel>> searchCars({
    required String city,
    String? carType,
    bool? isAC,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async {
    // Map sortBy from UI string to Backend SortByOption enum
    String backendSortBy;
    if (sortBy == 'Price Low-High') {
      backendSortBy = 'PRICE_ASC';
    } else if (sortBy == 'Price High-Low') {
      backendSortBy = 'PRICE_DESC';
    } else if (sortBy == 'Rating') {
      backendSortBy = 'RATING';
    } else {
      backendSortBy = 'RELEVANCE';
    }

    // Map carType from UI to uppercase backend enum (e.g. Sedan -> SEDAN)
    String? backendCarType;
    if (carType != null && carType.isNotEmpty) {
      backendCarType = carType.toUpperCase();
    }

    final queryParams = {
      'city': city,
      if (backendCarType != null) 'carType': backendCarType,
      if (isAC != null) 'isAC': isAC,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minRating != null) 'minRating': minRating,
      'sortBy': backendSortBy,
      'page': 1,
      'limit': 50, // Fetch a large enough limit for the screen
    };

    final response = await apiClient.dio.get(
      '/cars',
      queryParameters: queryParams,
    );

    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => CarModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }
}
