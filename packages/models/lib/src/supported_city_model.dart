class SupportedCityModel {
  final String id;
  final String name;
  final String state;
  final double latitude;
  final double longitude;
  final bool isActive;
  final List<String> enabledTripTypes;

  const SupportedCityModel({
    required this.id,
    required this.name,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
    this.enabledTripTypes = const [],
  });

  factory SupportedCityModel.fromJson(Map<String, dynamic> json) {
    return SupportedCityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? true,
      enabledTripTypes: (json['enabledTripTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'enabledTripTypes': enabledTripTypes,
    };
  }

  SupportedCityModel copyWith({
    String? id,
    String? name,
    String? state,
    double? latitude,
    double? longitude,
    bool? isActive,
    List<String>? enabledTripTypes,
  }) {
    return SupportedCityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      enabledTripTypes: enabledTripTypes ?? this.enabledTripTypes,
    );
  }
}
