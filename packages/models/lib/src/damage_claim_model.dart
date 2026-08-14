enum DamageClaimStatus {
  SUBMITTED,
  UNDER_REVIEW,
  APPROVED,
  PARTIALLY_APPROVED,
  REJECTED,
  SETTLED;

  static DamageClaimStatus fromString(String? value) {
    if (value == null) return DamageClaimStatus.SUBMITTED;
    return DamageClaimStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => DamageClaimStatus.SUBMITTED,
    );
  }
}

class DamageClaimModel {
  final String id;
  final String bookingId;
  final String vendorId;
  final double claimedAmount;
  final double? approvedAmount;
  final DamageClaimStatus status;
  final String description;
  final List<String> damagePhotos;
  final String? vendorNotes;
  final String? adminNotes;
  final String? customerDispute;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DamageClaimModel({
    required this.id,
    required this.bookingId,
    required this.vendorId,
    required this.claimedAmount,
    this.approvedAmount,
    this.status = DamageClaimStatus.SUBMITTED,
    required this.description,
    this.damagePhotos = const [],
    this.vendorNotes,
    this.adminNotes,
    this.customerDispute,
    required this.createdAt,
    this.resolvedAt,
  });

  factory DamageClaimModel.fromJson(Map<String, dynamic> json) {
    return DamageClaimModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      claimedAmount: (json['claimedAmount'] as num?)?.toDouble() ?? 0.0,
      approvedAmount: (json['approvedAmount'] as num?)?.toDouble(),
      status: DamageClaimStatus.fromString(json['status'] as String?),
      description: json['description'] as String? ?? '',
      damagePhotos: (json['damagePhotos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      vendorNotes: json['vendorNotes'] as String?,
      adminNotes: json['adminNotes'] as String?,
      customerDispute: json['customerDispute'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'vendorId': vendorId,
      'claimedAmount': claimedAmount,
      'approvedAmount': approvedAmount,
      'status': status.name,
      'description': description,
      'damagePhotos': damagePhotos,
      'vendorNotes': vendorNotes,
      'adminNotes': adminNotes,
      'customerDispute': customerDispute,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}
