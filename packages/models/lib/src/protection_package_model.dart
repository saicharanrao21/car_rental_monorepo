enum ProtectionPlanCode {
  BASIC,
  STANDARD,
  PREMIUM,
  ZERO_DEP;

  static ProtectionPlanCode fromString(String? value) {
    if (value == null) return ProtectionPlanCode.BASIC;
    return ProtectionPlanCode.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => ProtectionPlanCode.BASIC,
    );
  }
}

class ProtectionPackageModel {
  final String id;
  final String name;
  final ProtectionPlanCode code;
  final String description;
  final double dailyRate;
  final List<String> coverageSummary;
  final double deductibleAmount;
  final double maxCoverageAmount;
  final List<String> exclusions;
  final String? termsUrl;
  final String? city;
  final bool isActive;
  final int displayOrder;

  const ProtectionPackageModel({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.dailyRate,
    this.coverageSummary = const [],
    required this.deductibleAmount,
    required this.maxCoverageAmount,
    this.exclusions = const [],
    this.termsUrl,
    this.city,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory ProtectionPackageModel.fromJson(Map<String, dynamic> json) {
    return ProtectionPackageModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: ProtectionPlanCode.fromString(json['code'] as String?),
      description: json['description'] as String? ?? '',
      dailyRate: (json['dailyRate'] as num?)?.toDouble() ?? 0.0,
      coverageSummary: (json['coverageSummary'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deductibleAmount:
          (json['deductibleAmount'] as num?)?.toDouble() ?? 10000.0,
      maxCoverageAmount:
          (json['maxCoverageAmount'] as num?)?.toDouble() ?? 200000.0,
      exclusions: (json['exclusions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      termsUrl: json['termsUrl'] as String?,
      city: json['city'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code.name,
        'description': description,
        'dailyRate': dailyRate,
        'coverageSummary': coverageSummary,
        'deductibleAmount': deductibleAmount,
        'maxCoverageAmount': maxCoverageAmount,
        'exclusions': exclusions,
        'termsUrl': termsUrl,
        'city': city,
        'isActive': isActive,
        'displayOrder': displayOrder,
      };
}
