import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/home_repository.dart';

class ApiHomeRepository implements HomeRepository {
  final ApiClient apiClient;

  ApiHomeRepository({required this.apiClient});

  @override
  Future<List<CarModel>> getCarsByCity(String city) async {
    final response = await apiClient.dio.get(
      '/cars',
      queryParameters: {'city': city},
    );
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => CarModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<List<VendorModel>> getTopVendorsByCity(String city) async {
    final response = await apiClient.dio.get(
      '/vendors',
      queryParameters: {
        'city': city,
        'verificationStatus': 'VERIFIED',
      },
    );
    final data = response.data['data'] as List<dynamic>;
    final vendors = data.map((json) => VendorModel.fromJson(Map<String, dynamic>.from(json))).toList();
    
    // Sort client-side descending by rating as backend doesn't support sortBy query param
    vendors.sort((a, b) => b.rating.compareTo(a.rating));
    return vendors;
  }

  @override
  Future<List<BannerModel>> getBanners() async {
    final response = await apiClient.dio.get('/banners');
    final data = response.data as List<dynamic>;
    return data.map((json) => BannerModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }
}
