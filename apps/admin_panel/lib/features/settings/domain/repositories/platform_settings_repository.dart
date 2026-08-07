class PlatformSettings {
  final String platformName;
  final String? logoUrl;
  final String gstNumber;
  final String supportEmail;
  final String supportPhone;
  final String appVersion;
  final List<String> enabledTripTypes;

  const PlatformSettings({
    required this.platformName,
    this.logoUrl,
    required this.gstNumber,
    required this.supportEmail,
    required this.supportPhone,
    required this.appVersion,
    this.enabledTripTypes = const ['SELF_DRIVE', 'OUTSTATION'],
  });

  PlatformSettings copyWith({
    String? platformName,
    String? logoUrl,
    String? gstNumber,
    String? supportEmail,
    String? supportPhone,
    String? appVersion,
    List<String>? enabledTripTypes,
  }) {
    return PlatformSettings(
      platformName: platformName ?? this.platformName,
      logoUrl: logoUrl ?? this.logoUrl,
      gstNumber: gstNumber ?? this.gstNumber,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      appVersion: appVersion ?? this.appVersion,
      enabledTripTypes: enabledTripTypes ?? this.enabledTripTypes,
    );
  }
}

abstract class PlatformSettingsRepository {
  Future<PlatformSettings> getSettings();
  Future<void> updateSettings(PlatformSettings settings);
}
