class InspectionModel {
  final String id;
  final String bookingId;
  final String type; // 'PRE_TRIP' or 'POST_TRIP'
  final String performedById;
  final double odometer;
  final int fuelPercent;
  final String? conditionNotes;
  final List<String> damagePhotos;
  final bool finalized;
  final DateTime? finalizedAt;
  final DateTime createdAt;

  const InspectionModel({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.performedById,
    required this.odometer,
    required this.fuelPercent,
    this.conditionNotes,
    this.damagePhotos = const [],
    this.finalized = false,
    this.finalizedAt,
    required this.createdAt,
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      type: json['type'] as String? ?? 'PRE_TRIP',
      performedById: json['performedById'] as String? ?? '',
      odometer: json['odometer'] != null
          ? double.tryParse(json['odometer'].toString()) ?? 0.0
          : 0.0,
      fuelPercent: json['fuelPercent'] as int? ?? 0,
      conditionNotes: json['conditionNotes'] as String?,
      damagePhotos: json['damagePhotos'] != null
          ? List<String>.from(json['damagePhotos'] as List)
          : const [],
      finalized: json['finalized'] as bool? ?? false,
      finalizedAt: json['finalizedAt'] != null
          ? DateTime.tryParse(json['finalizedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'type': type,
      'performedById': performedById,
      'odometer': odometer,
      'fuelPercent': fuelPercent,
      'conditionNotes': conditionNotes,
      'damagePhotos': damagePhotos,
      'finalized': finalized,
      'finalizedAt': finalizedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  InspectionModel copyWith({
    String? id,
    String? bookingId,
    String? type,
    String? performedById,
    double? odometer,
    int? fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool? finalized,
    DateTime? finalizedAt,
    DateTime? createdAt,
  }) {
    return InspectionModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      type: type ?? this.type,
      performedById: performedById ?? this.performedById,
      odometer: odometer ?? this.odometer,
      fuelPercent: fuelPercent ?? this.fuelPercent,
      conditionNotes: conditionNotes ?? this.conditionNotes,
      damagePhotos: damagePhotos ?? this.damagePhotos,
      finalized: finalized ?? this.finalized,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
