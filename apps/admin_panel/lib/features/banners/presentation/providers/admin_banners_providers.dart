import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_banners_repository.dart';
import '../../data/mock_admin_banners_repository.dart';

final adminBannersRepositoryProvider = Provider<AdminBannersRepository>((ref) {
  return MockAdminBannersRepository();
});

class AdminBannersNotifier extends AsyncNotifier<List<BannerModel>> {
  @override
  Future<List<BannerModel>> build() {
    return ref.read(adminBannersRepositoryProvider).getBanners();
  }

  Future<void> addBanner(BannerModel banner) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminBannersRepositoryProvider).addBanner(banner);
      final list = await ref.read(adminBannersRepositoryProvider).getBanners();
      state = AsyncData(list);
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }

  Future<void> updateBanner(BannerModel banner) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminBannersRepositoryProvider).updateBanner(banner);
      final list = await ref.read(adminBannersRepositoryProvider).getBanners();
      state = AsyncData(list);
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }

  Future<void> deleteBanner(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminBannersRepositoryProvider).deleteBanner(id);
      final list = await ref.read(adminBannersRepositoryProvider).getBanners();
      state = AsyncData(list);
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final previousState = state;
    if (state.hasValue) {
      final list = state.value!;
      final updated = list.map((b) => b.id == id ? b.copyWith(isActive: isActive) : b).toList();
      state = AsyncData(updated);
    }

    try {
      await ref.read(adminBannersRepositoryProvider).toggleActive(id, isActive);
      final list = await ref.read(adminBannersRepositoryProvider).getBanners();
      state = AsyncData(list);
    } catch (err) {
      state = previousState;
    }
  }

  Future<void> reorderBanners(List<String> orderedIds) async {
    final previousState = state;
    if (state.hasValue) {
      final list = List<BannerModel>.from(state.value!);
      final reordered = <BannerModel>[];
      for (int i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        final match = list.firstWhere((b) => b.id == id);
        reordered.add(match.copyWith(displayOrder: i + 1));
      }
      state = AsyncData(reordered);
    }

    try {
      await ref.read(adminBannersRepositoryProvider).reorderBanners(orderedIds);
      final list = await ref.read(adminBannersRepositoryProvider).getBanners();
      state = AsyncData(list);
    } catch (err) {
      state = previousState;
    }
  }
}

final adminBannersProvider =
    AsyncNotifierProvider<AdminBannersNotifier, List<BannerModel>>(() {
  return AdminBannersNotifier();
});
