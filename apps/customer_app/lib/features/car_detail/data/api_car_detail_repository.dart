import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/car_detail_repository.dart';

class ApiCarDetailRepository implements CarDetailRepository {
  final ApiClient apiClient;

  ApiCarDetailRepository({required this.apiClient});

  @override
  Future<CarModel> getCarById(String id) async {
    final response = await apiClient.dio.get('/cars/$id');
    return CarModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<VendorModel> getVendorById(String vendorId) async {
    final response = await apiClient.dio.get('/vendors/$vendorId');
    return VendorModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId) async {
    final response = await apiClient.dio.get(
      '/vendors/$vendorId/reviews',
      queryParameters: {'page': 1, 'limit': 50},
    );
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => ReviewModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }
}
