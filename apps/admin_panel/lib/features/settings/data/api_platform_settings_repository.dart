import 'package:core/core.dart';
import '../domain/repositories/platform_settings_repository.dart';

class ApiPlatformSettingsRepository implements PlatformSettingsRepository {
  final ApiClient _apiClient;

  ApiPlatformSettingsRepository(this._apiClient);

  @override
  Future<PlatformSettings> getSettings() async {
    final response = await _apiClient.dio.get('/admin/settings');
    final data = response.data;
    final enabledTripTypesRaw = data['enabledTripTypes'] as List?;
    final enabledTripTypes = enabledTripTypesRaw != null
        ? enabledTripTypesRaw.map((e) => e.toString()).toList()
        : const ['SELF_DRIVE', 'OUTSTATION'];

    return PlatformSettings(
      platformName: data['platformName'] ?? 'DriveGo',
      logoUrl: data['logoUrl'],
      gstNumber: data['gstNumber'] ?? '27AAAAA1111A1Z1',
      supportEmail: data['supportEmail'] ?? 'support@drivego.in',
      supportPhone: data['supportPhone'] ?? '+919876543210',
      appVersion: data['appVersion'] ?? '1.0.0',
      enabledTripTypes: enabledTripTypes,
    );
  }

  @override
  Future<void> updateSettings(PlatformSettings settings) async {
    await _apiClient.dio.patch(
      '/admin/settings',
      data: {
        'platformName': settings.platformName,
        'logoUrl': settings.logoUrl,
        'gstNumber': settings.gstNumber,
        'supportEmail': settings.supportEmail,
        'supportPhone': settings.supportPhone,
        'appVersion': settings.appVersion,
        'enabledTripTypes': settings.enabledTripTypes,
      },
    );
  }
}
