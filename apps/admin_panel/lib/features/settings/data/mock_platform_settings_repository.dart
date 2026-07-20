import '../domain/repositories/platform_settings_repository.dart';

class MockPlatformSettingsRepository implements PlatformSettingsRepository {
  PlatformSettings _settings = const PlatformSettings(
    platformName: 'DriveGo Car Rental',
    logoUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=120&q=80',
    gstNumber: '27AAAAA1111A1Z1',
    supportEmail: 'support@drivego.com',
    supportPhone: '+919876543210',
    appVersion: '1.0.0',
  );

  @override
  Future<PlatformSettings> getSettings() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _settings;
  }

  @override
  Future<void> updateSettings(PlatformSettings settings) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _settings = settings;
  }
}
