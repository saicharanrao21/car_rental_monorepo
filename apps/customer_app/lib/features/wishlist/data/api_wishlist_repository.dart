import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/wishlist_repository.dart';

class ApiWishlistRepository implements WishlistRepository {
  final ApiClient apiClient;

  ApiWishlistRepository({required this.apiClient});

  @override
  Future<void> addToWishlist(String carId) async {
    await apiClient.dio.post('/wishlist', data: {'carId': carId});
  }

  @override
  Future<void> removeFromWishlist(String carId) async {
    await apiClient.dio.delete('/wishlist/$carId');
  }

  @override
  Future<List<CarModel>> getMyWishlist() async {
    final response = await apiClient.dio.get('/wishlist/me');
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => CarModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }
}
