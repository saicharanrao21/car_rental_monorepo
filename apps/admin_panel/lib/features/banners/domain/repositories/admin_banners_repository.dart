import 'package:models/models.dart';

abstract class AdminBannersRepository {
  Future<List<BannerModel>> getBanners();
  Future<void> addBanner(BannerModel banner);
  Future<void> updateBanner(BannerModel banner);
  Future<void> deleteBanner(String id);
  Future<void> toggleActive(String id, bool isActive);
  Future<void> reorderBanners(List<String> orderedIds);
}
