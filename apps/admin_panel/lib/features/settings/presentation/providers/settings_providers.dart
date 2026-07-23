import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import '../../domain/repositories/platform_settings_repository.dart';
import '../../data/api_platform_settings_repository.dart';

final platformSettingsRepositoryProvider = Provider<PlatformSettingsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiPlatformSettingsRepository(apiClient);
});

class PlatformSettingsNotifier extends AsyncNotifier<PlatformSettings> {
  @override
  Future<PlatformSettings> build() {
    return ref.read(platformSettingsRepositoryProvider).getSettings();
  }

  Future<void> updateSettings(PlatformSettings settings) async {
    state = const AsyncLoading();
    try {
      await ref.read(platformSettingsRepositoryProvider).updateSettings(settings);
      final newSettings = await ref.read(platformSettingsRepositoryProvider).getSettings();
      state = AsyncData(newSettings);
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }
}

final platformSettingsProvider =
    AsyncNotifierProvider<PlatformSettingsNotifier, PlatformSettings>(() {
  return PlatformSettingsNotifier();
});
