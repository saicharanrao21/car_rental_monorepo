class MileagePackageModel {
  final String id;
  final String carId;
  final String tripType; // 'Self-Drive', 'Outstation', 'Local', 'Airport Transfer'
  final String name;
  final int? includedKmPerDay;
  final double basePricePerDay;
  final double extraKmRate;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MileagePackageModel({
    required this.id,
    required this.carId,
    required this.tripType,
    required this.name,
    this.includedKmPerDay,
    required this.basePricePerDay,
    this.extraKmRate = 0.0,
    this.isDefault = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isUnlimited => includedKmPerDay == null;

  int? totalIncludedKm(int days) {
    if (includedKmPerDay == null) return null;
    return includedKmPerDay! * (days < 1 ? 1 : days);
  }

  factory MileagePackageModel.fromJson(Map<String, dynamic> json) {
    String rawTripType = json['tripType']?.toString() ?? 'SELF_DRIVE';
    String normalizedTripType = 'Self-Drive';
    switch (rawTripType.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_')) {
      case 'SELF_DRIVE':
        normalizedTripType = 'Self-Drive';
        break;
      case 'OUTSTATION':
        normalizedTripType = 'Outstation';
        break;
      case 'LOCAL':
        normalizedTripType = 'Local';
        break;
      case 'AIRPORT':
      case 'AIRPORT_TRANSFER':
        normalizedTripType = 'Airport Transfer';
        break;
      default:
        normalizedTripType = rawTripType;
    }

    return MileagePackageModel(
      id: json['id']?.toString() ?? '',
      carId: json['carId']?.toString() ?? '',
      tripType: normalizedTripType,
      name: json['name']?.toString() ?? '',
      includedKmPerDay: json['includedKmPerDay'] != null
          ? int.tryParse(json['includedKmPerDay'].toString())
          : null,
      basePricePerDay:
          double.tryParse(json['basePricePerDay']?.toString() ?? '0') ?? 0.0,
      extraKmRate:
          double.tryParse(json['extraKmRate']?.toString() ?? '0') ?? 0.0,
      isDefault: json['isDefault'] == true,
      isActive: json['isActive'] != false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    String backendTripType =
        tripType.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    return {
      'id': id,
      'carId': carId,
      'tripType': backendTripType,
      'name': name,
      'includedKmPerDay': includedKmPerDay,
      'basePricePerDay': basePricePerDay,
      'extraKmRate': extraKmRate,
      'isDefault': isDefault,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  MileagePackageModel copyWith({
    String? id,
    String? carId,
    String? tripType,
    String? name,
    int? includedKmPerDay,
    bool setIncludedKmNull = false,
    double? basePricePerDay,
    double? extraKmRate,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MileagePackageModel(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      tripType: tripType ?? this.tripType,
      name: name ?? this.name,
      includedKmPerDay:
          setIncludedKmNull ? null : (includedKmPerDay ?? this.includedKmPerDay),
      basePricePerDay: basePricePerDay ?? this.basePricePerDay,
      extraKmRate: extraKmRate ?? this.extraKmRate,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
