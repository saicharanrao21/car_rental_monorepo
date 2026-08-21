import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/search_repository.dart';

class ApiSearchRepository implements SearchRepository {
  final ApiClient apiClient;

  ApiSearchRepository({required this.apiClient});

  @override
  Future<List<CarModel>> searchCars({
    required String city,
    double? lat,
    double? lng,
    String? tripType,
    DateTime? startDate,
    DateTime? endDate,
    String? carType,
    bool? isAC,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async {
    // Map sortBy from UI string to Backend SortByOption enum
    String backendSortBy;
    if (sortBy == 'Nearest') {
      backendSortBy = 'NEAREST';
    } else if (sortBy == 'Recommended') {
      backendSortBy = 'RECOMMENDED';
    } else if (sortBy == 'Price Low-High') {
      backendSortBy = 'PRICE_ASC';
    } else if (sortBy == 'Price High-Low') {
      backendSortBy = 'PRICE_DESC';
    } else if (sortBy == 'Rating') {
      backendSortBy = 'RATING';
    } else {
      backendSortBy = 'RECOMMENDED';
    }

    // Fall back to RATING when location permission is denied (lat/lng is null)
    if (lat == null && backendSortBy == 'RECOMMENDED') {
      backendSortBy = 'RATING';
    }

    // Map carType from UI to uppercase backend enum (e.g. Sedan -> SEDAN)
    String? backendCarType;
    if (carType != null && carType.isNotEmpty) {
      backendCarType = carType.toUpperCase();
    }

    String? backendTripType;
    if (tripType != null && tripType.isNotEmpty) {
      final norm = tripType.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
      if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
        backendTripType = 'AIRPORT_TRANSFER';
      } else {
        backendTripType = norm;
      }
    }

    final queryParams = <String, dynamic>{
      'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (backendTripType != null) 'tripType': backendTripType,
      if (backendCarType != null) 'carType': backendCarType,
      if (isAC != null) 'isAC': isAC,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minRating != null) 'minRating': minRating,
      'sortBy': backendSortBy,
      'page': 1,
      'limit': 50,
    };

    debugPrint('[API Search] GET /cars params: $queryParams');
    try {
      final response = await apiClient.dio.get(
        '/cars',
        queryParameters: queryParams,
      );

      final data = response.data['data'] as List<dynamic>;
      return data.map((json) => CarModel.fromJson(Map<String, dynamic>.from(json))).toList();
    } on DioException catch (e, st) {
      debugPrint('[API Search] FAILED with DioException: status=${e.response?.statusCode}, data=${e.response?.data}');
      debugPrint('[API Search] StackTrace: $st');
      rethrow;
    } catch (e, st) {
      debugPrint('[API Search] FAILED with error: $e');
      debugPrint('[API Search] StackTrace: $st');
      rethrow;
    }
  }
}
