import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_banners_repository.dart';

class ApiAdminBannersRepository implements AdminBannersRepository {
  final ApiClient _apiClient;

  ApiAdminBannersRepository(this._apiClient);

  @override
  Future<List<BannerModel>> getBanners() async {
    final response = await _apiClient.dio.get('/admin/banners');
    final data = response.data as List;
    return data.map((json) => BannerModel.fromJson(json)).toList();
  }

  @override
  Future<void> addBanner(BannerModel banner) async {
    await _apiClient.dio.post(
      '/admin/banners',
      data: {
        'imageUrl': banner.imageUrl,
        'title': banner.title,
        'ctaLink': banner.ctaLink,
        'displayOrder': banner.displayOrder,
      },
    );
  }

  @override
  Future<void> updateBanner(BannerModel banner) async {
    await _apiClient.dio.patch(
      '/admin/banners/${banner.id}',
      data: {
        'imageUrl': banner.imageUrl,
        'title': banner.title,
        'ctaLink': banner.ctaLink,
        'displayOrder': banner.displayOrder,
        'isActive': banner.isActive,
      },
    );
  }

  @override
  Future<void> deleteBanner(String id) async {
    await _apiClient.dio.delete('/admin/banners/$id');
  }

  @override
  Future<void> toggleActive(String id, bool isActive) async {
    await _apiClient.dio.patch(
      '/admin/banners/$id/active',
      data: {'isActive': isActive},
    );
  }

  @override
  Future<void> reorderBanners(List<String> orderedIds) async {
    await _apiClient.dio.post(
      '/admin/banners/reorder',
      data: {'orderedIds': orderedIds},
    );
  }
}
