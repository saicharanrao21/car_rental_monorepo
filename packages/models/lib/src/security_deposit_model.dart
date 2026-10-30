enum SecurityDepositStatus {
  REQUIRED,
  HELD,
  REFUND_PENDING,
  REFUNDED,
  PARTIALLY_REFUNDED,
  FORFEITED,
  CANCELLED;

  static SecurityDepositStatus fromString(String? value) {
    if (value == null) return SecurityDepositStatus.REQUIRED;
    final upper = value.toUpperCase();
    return SecurityDepositStatus.values.firstWhere(
      (e) => e.name == upper,
      orElse: () => SecurityDepositStatus.REQUIRED,
    );
  }
}

enum CollateralType {
  monetaryOnline,
  physicalVehicle,
  originalDocument,
  digilockerHighTrust;

  static CollateralType fromString(String? value) {
    if (value == null) return CollateralType.monetaryOnline;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'PHYSICAL_VEHICLE':
      case 'PHYSICALVEHICLE':
        return CollateralType.physicalVehicle;
      case 'ORIGINAL_DOCUMENT':
      case 'ORIGINALDOCUMENT':
        return CollateralType.originalDocument;
      case 'DIGILOCKER_HIGH_TRUST':
      case 'DIGILOCKERHIGHTRUST':
        return CollateralType.digilockerHighTrust;
      case 'MONETARY_ONLINE':
      case 'MONETARYONLINE':
      default:
        return CollateralType.monetaryOnline;
    }
  }

  String toBackendString() {
    switch (this) {
      case CollateralType.physicalVehicle:
        return 'PHYSICAL_VEHICLE';
      case CollateralType.originalDocument:
        return 'ORIGINAL_DOCUMENT';
      case CollateralType.digilockerHighTrust:
        return 'DIGILOCKER_HIGH_TRUST';
      case CollateralType.monetaryOnline:
        return 'MONETARY_ONLINE';
    }
  }
}

class SecurityDepositModel {
  final String id;
  final String bookingId;
  final double amount;
  final double refundedAmount;
  final double deductedAmount;
  final String? razorpayPaymentId;
  final String? razorpayRefundId;
  final SecurityDepositStatus status;
  final CollateralType collateralType;
  final String? vehicleRegistrationNumber;
  final String? vehicleMakeModel;
  final bool? vehicleKeyCollected;
  final String? documentType;
  final String? documentIdentifier;
  final String? physicalStorageLocation;
  final String? notes;
  final DateTime? heldAt;
  final DateTime? releasedAt;
  final DateTime createdAt;

  const SecurityDepositModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.refundedAmount = 0.0,
    this.deductedAmount = 0.0,
    this.razorpayPaymentId,
    this.razorpayRefundId,
    this.status = SecurityDepositStatus.REQUIRED,
    this.collateralType = CollateralType.monetaryOnline,
    this.vehicleRegistrationNumber,
    this.vehicleMakeModel,
    this.vehicleKeyCollected,
    this.documentType,
    this.documentIdentifier,
    this.physicalStorageLocation,
    this.notes,
    this.heldAt,
    this.releasedAt,
    required this.createdAt,
  });

  factory SecurityDepositModel.fromJson(Map<String, dynamic> json) {
    return SecurityDepositModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0.0,
      deductedAmount: (json['deductedAmount'] as num?)?.toDouble() ?? 0.0,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      razorpayRefundId: json['razorpayRefundId'] as String?,
      status: SecurityDepositStatus.fromString(json['status'] as String?),
      collateralType: CollateralType.fromString(
        (json['collateralType'] as String?) ??
            ((json['collateralDetails'] is Map)
                ? (json['collateralDetails']['type'] as String?)
                : null),
      ),
      vehicleRegistrationNumber: json['vehicleRegistrationNumber'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['vehicleRegistrationNumber'] as String?
              : null),
      vehicleMakeModel: json['vehicleMakeModel'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['vehicleMakeModel'] as String?
              : null),
      vehicleKeyCollected: json['vehicleKeyCollected'] as bool? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['vehicleKeyCollected'] as bool?
              : null),
      documentType: json['documentType'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['documentType'] as String?
              : null),
      documentIdentifier: json['documentIdentifier'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['documentIdentifier'] as String?
              : null),
      physicalStorageLocation: json['physicalStorageLocation'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['physicalStorageLocation'] as String?
              : null),
      notes: json['notes'] as String? ??
          (json['collateralDetails'] is Map
              ? json['collateralDetails']['notes'] as String?
              : null),
      heldAt: json['heldAt'] != null
          ? DateTime.tryParse(json['heldAt'] as String)
          : null,
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'amount': amount,
      'refundedAmount': refundedAmount,
      'deductedAmount': deductedAmount,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayRefundId': razorpayRefundId,
      'status': status.name,
      'collateralType': collateralType.toBackendString(),
      if (vehicleRegistrationNumber != null) 'vehicleRegistrationNumber': vehicleRegistrationNumber,
      if (vehicleMakeModel != null) 'vehicleMakeModel': vehicleMakeModel,
      if (vehicleKeyCollected != null) 'vehicleKeyCollected': vehicleKeyCollected,
      if (documentType != null) 'documentType': documentType,
      if (documentIdentifier != null) 'documentIdentifier': documentIdentifier,
      if (physicalStorageLocation != null) 'physicalStorageLocation': physicalStorageLocation,
      if (notes != null) 'notes': notes,
      'heldAt': heldAt?.toIso8601String(),
      'releasedAt': releasedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
