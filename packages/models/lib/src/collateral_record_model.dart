import 'security_deposit_model.dart' show CollateralType;

enum CollateralRecordStatus {
  HELD,
  RETURNED,
  FORFEITED;

  static CollateralRecordStatus fromString(String? value) {
    if (value == null) return CollateralRecordStatus.HELD;
    final upper = value.trim().toUpperCase();
    return CollateralRecordStatus.values.firstWhere(
      (e) => e.name == upper,
      orElse: () => CollateralRecordStatus.HELD,
    );
  }
}

class CollateralRecordModel {
  final String id;
  final String bookingId;
  final CollateralType collateralType;
  final CollateralRecordStatus status;

  // Physical vehicle details
  final String? vehicleRegistrationNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? yardSlotNumber;
  final bool keysCollected;

  // Original document details
  final String? documentType;
  final String? documentNumberMasked;
  final String? vaultLockerNumber;
  final bool verifiedPhysically;

  // Common metadata
  final String? notes;
  final List<String> photoUrls;
  final String? customerAcknowledgementUrl;
  final DateTime heldAt;
  final DateTime? releasedAt;
  final String? recordedByUserId;
  final String? releasedByUserId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CollateralRecordModel({
    required this.id,
    required this.bookingId,
    required this.collateralType,
    this.status = CollateralRecordStatus.HELD,
    this.vehicleRegistrationNumber,
    this.vehicleMake,
    this.vehicleModel,
    this.yardSlotNumber,
    this.keysCollected = false,
    this.documentType,
    this.documentNumberMasked,
    this.vaultLockerNumber,
    this.verifiedPhysically = false,
    this.notes,
    this.photoUrls = const [],
    this.customerAcknowledgementUrl,
    required this.heldAt,
    this.releasedAt,
    this.recordedByUserId,
    this.releasedByUserId,
    required this.createdAt,
    this.updatedAt,
  });

  factory CollateralRecordModel.fromJson(Map<String, dynamic> json) {
    return CollateralRecordModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      collateralType: CollateralType.fromString(json['collateralType'] as String?),
      status: CollateralRecordStatus.fromString(json['status'] as String?),
      vehicleRegistrationNumber: json['vehicleRegistrationNumber'] as String?,
      vehicleMake: json['vehicleMake'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      yardSlotNumber: json['yardSlotNumber'] as String?,
      keysCollected: json['keysCollected'] as bool? ?? false,
      documentType: json['documentType'] as String?,
      documentNumberMasked: json['documentNumberMasked'] as String?,
      vaultLockerNumber: json['vaultLockerNumber'] as String?,
      verifiedPhysically: json['verifiedPhysically'] as bool? ?? false,
      notes: json['notes'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      customerAcknowledgementUrl: json['customerAcknowledgementUrl'] as String?,
      heldAt: json['heldAt'] != null
          ? DateTime.tryParse(json['heldAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'] as String)
          : null,
      recordedByUserId: json['recordedByUserId'] as String?,
      releasedByUserId: json['releasedByUserId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'collateralType': collateralType.toBackendString(),
      'status': status.name,
      if (vehicleRegistrationNumber != null)
        'vehicleRegistrationNumber': vehicleRegistrationNumber,
      if (vehicleMake != null) 'vehicleMake': vehicleMake,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (yardSlotNumber != null) 'yardSlotNumber': yardSlotNumber,
      'keysCollected': keysCollected,
      if (documentType != null) 'documentType': documentType,
      if (documentNumberMasked != null)
        'documentNumberMasked': documentNumberMasked,
      if (vaultLockerNumber != null) 'vaultLockerNumber': vaultLockerNumber,
      'verifiedPhysically': verifiedPhysically,
      if (notes != null) 'notes': notes,
      'photoUrls': photoUrls,
      if (customerAcknowledgementUrl != null)
        'customerAcknowledgementUrl': customerAcknowledgementUrl,
      'heldAt': heldAt.toIso8601String(),
      if (releasedAt != null) 'releasedAt': releasedAt?.toIso8601String(),
      if (recordedByUserId != null) 'recordedByUserId': recordedByUserId,
      if (releasedByUserId != null) 'releasedByUserId': releasedByUserId,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  CollateralRecordModel copyWith({
    String? id,
    String? bookingId,
    CollateralType? collateralType,
    CollateralRecordStatus? status,
    String? vehicleRegistrationNumber,
    String? vehicleMake,
    String? vehicleModel,
    String? yardSlotNumber,
    bool? keysCollected,
    String? documentType,
    String? documentNumberMasked,
    String? vaultLockerNumber,
    bool? verifiedPhysically,
    String? notes,
    List<String>? photoUrls,
    String? customerAcknowledgementUrl,
    DateTime? heldAt,
    DateTime? releasedAt,
    String? recordedByUserId,
    String? releasedByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollateralRecordModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      collateralType: collateralType ?? this.collateralType,
      status: status ?? this.status,
      vehicleRegistrationNumber:
          vehicleRegistrationNumber ?? this.vehicleRegistrationNumber,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      yardSlotNumber: yardSlotNumber ?? this.yardSlotNumber,
      keysCollected: keysCollected ?? this.keysCollected,
      documentType: documentType ?? this.documentType,
      documentNumberMasked: documentNumberMasked ?? this.documentNumberMasked,
      vaultLockerNumber: vaultLockerNumber ?? this.vaultLockerNumber,
      verifiedPhysically: verifiedPhysically ?? this.verifiedPhysically,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      customerAcknowledgementUrl:
          customerAcknowledgementUrl ?? this.customerAcknowledgementUrl,
      heldAt: heldAt ?? this.heldAt,
      releasedAt: releasedAt ?? this.releasedAt,
      recordedByUserId: recordedByUserId ?? this.recordedByUserId,
      releasedByUserId: releasedByUserId ?? this.releasedByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

