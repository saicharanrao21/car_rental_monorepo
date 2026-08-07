class PublicSettingsModel {
  final String platformName;
  final String supportEmail;
  final String supportPhone;
  final List<String> enabledTripTypes;

  const PublicSettingsModel({
    required this.platformName,
    required this.supportEmail,
    required this.supportPhone,
    required this.enabledTripTypes,
  });

  factory PublicSettingsModel.fromJson(Map<String, dynamic> json) {
    return PublicSettingsModel(
      platformName: json['platformName'] as String? ?? 'DriveGo',
      supportEmail: json['supportEmail'] as String? ?? '',
      supportPhone: json['supportPhone'] as String? ?? '',
      enabledTripTypes: (json['enabledTripTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['SELF_DRIVE', 'OUTSTATION'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platformName': platformName,
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
      'enabledTripTypes': enabledTripTypes,
    };
  }
}
