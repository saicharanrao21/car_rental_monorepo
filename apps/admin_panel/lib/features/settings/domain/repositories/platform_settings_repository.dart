class PlatformSettings {
  final String platformName;
  final String? logoUrl;
  final String gstNumber;
  final String supportEmail;
  final String supportPhone;
  final String appVersion;

  const PlatformSettings({
    required this.platformName,
    this.logoUrl,
    required this.gstNumber,
    required this.supportEmail,
    required this.supportPhone,
    required this.appVersion,
  });

  PlatformSettings copyWith({
    String? platformName,
    String? logoUrl,
    String? gstNumber,
    String? supportEmail,
    String? supportPhone,
    String? appVersion,
  }) {
    return PlatformSettings(
      platformName: platformName ?? this.platformName,
      logoUrl: logoUrl ?? this.logoUrl,
      gstNumber: gstNumber ?? this.gstNumber,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

abstract class PlatformSettingsRepository {
  Future<PlatformSettings> getSettings();
  Future<void> updateSettings(PlatformSettings settings);
}
