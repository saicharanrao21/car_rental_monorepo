import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/admin_banners_repository.dart';

class MockAdminBannersRepository implements AdminBannersRepository {
  @override
  Future<List<BannerModel>> getBanners() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final list = List<BannerModel>.from(MockData.banners);
    list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  @override
  Future<void> addBanner(BannerModel banner) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockData.banners.add(banner);
  }

  @override
  Future<void> updateBanner(BannerModel banner) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final idx = MockData.banners.indexWhere((b) => b.id == banner.id);
    if (idx != -1) {
      MockData.banners[idx] = banner;
    }
  }

  @override
  Future<void> deleteBanner(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    MockData.banners.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> toggleActive(String id, bool isActive) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = MockData.banners.indexWhere((b) => b.id == id);
    if (idx != -1) {
      MockData.banners[idx] = MockData.banners[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> reorderBanners(List<String> orderedIds) async {
    await Future.delayed(const Duration(milliseconds: 400));
    for (int i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final idx = MockData.banners.indexWhere((b) => b.id == id);
      if (idx != -1) {
        MockData.banners[idx] = MockData.banners[idx].copyWith(displayOrder: i + 1);
      }
    }
  }
}
