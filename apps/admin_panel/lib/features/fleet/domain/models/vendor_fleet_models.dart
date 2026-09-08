class FleetKpisModel {
  final int total;
  final int active;
  final int pendingVerification;
  final int maintenance;
  final int suspended;
  final int inactive;
  final int retired;
  final int verifiedCount;
  final int unverifiedCount;
  final double operationalReadinessRate;

  const FleetKpisModel({
    required this.total,
    required this.active,
    required this.pendingVerification,
    required this.maintenance,
    required this.suspended,
    required this.inactive,
    required this.retired,
    required this.verifiedCount,
    required this.unverifiedCount,
    required this.operationalReadinessRate,
  });

  factory FleetKpisModel.fromJson(Map<String, dynamic> json) {
    return FleetKpisModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      pendingVerification: (json['pendingVerification'] as num?)?.toInt() ?? 0,
      maintenance: (json['maintenance'] as num?)?.toInt() ?? 0,
      suspended: (json['suspended'] as num?)?.toInt() ?? 0,
      inactive: (json['inactive'] as num?)?.toInt() ?? 0,
      retired: (json['retired'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verifiedCount'] as num?)?.toInt() ?? 0,
      unverifiedCount: (json['unverifiedCount'] as num?)?.toInt() ?? 0,
      operationalReadinessRate: (json['operationalReadinessRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VehicleBlockerModel {
  final String code;
  final String message;
  final String severity; // BLOCKER or WARNING

  const VehicleBlockerModel({
    required this.code,
    required this.message,
    required this.severity,
  });

  factory VehicleBlockerModel.fromJson(Map<String, dynamic> json) {
    return VehicleBlockerModel(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'BLOCKER',
    );
  }
}

class VehicleReadinessModel {
  final bool eligible;
  final String carId;
  final String operationalStatus;
  final String verificationStatus;
  final List<VehicleBlockerModel> blockers;
  final List<String> requiredActions;
  final String? serviceAreaId;
  final String? serviceAreaName;
  final String vendorId;
  final String vendorBusinessName;
  final String evaluatedAt;

  const VehicleReadinessModel({
    required this.eligible,
    required this.carId,
    required this.operationalStatus,
    required this.verificationStatus,
    required this.blockers,
    required this.requiredActions,
    this.serviceAreaId,
    this.serviceAreaName,
    required this.vendorId,
    required this.vendorBusinessName,
    required this.evaluatedAt,
  });

  factory VehicleReadinessModel.fromJson(Map<String, dynamic> json) {
    final rawBlockers = json['blockers'] as List? ?? [];
    final rawActions = json['requiredActions'] as List? ?? [];

    return VehicleReadinessModel(
      eligible: json['eligible'] as bool? ?? false,
      carId: json['carId'] as String? ?? '',
      operationalStatus: json['operationalStatus'] as String? ?? 'DRAFT',
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      blockers: rawBlockers.map((b) => VehicleBlockerModel.fromJson(b as Map<String, dynamic>)).toList(),
      requiredActions: rawActions.map((a) => a.toString()).toList(),
      serviceAreaId: json['serviceAreaId'] as String?,
      serviceAreaName: json['serviceAreaName'] as String?,
      vendorId: json['vendorId'] as String? ?? '',
      vendorBusinessName: json['vendorBusinessName'] as String? ?? '',
      evaluatedAt: json['evaluatedAt'] as String? ?? '',
    );
  }
}

class VehicleAuditLogModel {
  final String id;
  final String carId;
  final String actorId;
  final String actorRole;
  final String action;
  final String? fromStatus;
  final String toStatus;
  final String? reason;
  final DateTime createdAt;

  const VehicleAuditLogModel({
    required this.id,
    required this.carId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    this.fromStatus,
    required this.toStatus,
    this.reason,
    required this.createdAt,
  });

  factory VehicleAuditLogModel.fromJson(Map<String, dynamic> json) {
    return VehicleAuditLogModel(
      id: json['id'] as String? ?? '',
      carId: json['carId'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      actorRole: json['actorRole'] as String? ?? 'VENDOR',
      action: json['action'] as String? ?? '',
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String? ?? '',
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AdminFleetVehicleModel {
  final String id;
  final String vendorId;
  final String make;
  final String model;
  final int year;
  final String type;
  final String fuelType;
  final int seating;
  final bool isAC;
  final String registrationNumber;
  final List<String> photos;
  final double pricePerKm;
  final double pricePerDay;
  final double pricePerHour;
  final bool isAvailable;
  final String operationalStatus; // DRAFT, PENDING_VERIFICATION, ACTIVE, INACTIVE, MAINTENANCE, SUSPENDED, RETIRED
  final String verificationStatus; // PENDING, VERIFIED, REJECTED
  final String? serviceAreaId;
  final String? serviceAreaName;
  final String? rejectionReason;
  final String? maintenanceReason;
  final DateTime? maintenanceStartedAt;
  final DateTime? expectedReturnDate;
  final String? vendorBusinessName;
  final String? vendorOwnerName;
  final String? vendorCity;
  final String? vendorVerificationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminFleetVehicleModel({
    required this.id,
    required this.vendorId,
    required this.make,
    required this.model,
    required this.year,
    required this.type,
    required this.fuelType,
    required this.seating,
    required this.isAC,
    required this.registrationNumber,
    required this.photos,
    required this.pricePerKm,
    required this.pricePerDay,
    required this.pricePerHour,
    required this.isAvailable,
    required this.operationalStatus,
    required this.verificationStatus,
    this.serviceAreaId,
    this.serviceAreaName,
    this.rejectionReason,
    this.maintenanceReason,
    this.maintenanceStartedAt,
    this.expectedReturnDate,
    this.vendorBusinessName,
    this.vendorOwnerName,
    this.vendorCity,
    this.vendorVerificationStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminFleetVehicleModel.fromJson(Map<String, dynamic> json) {
    final vendorMap = json['vendor'] is Map<String, dynamic> ? json['vendor'] as Map<String, dynamic> : null;
    final saMap = json['serviceArea'] is Map<String, dynamic> ? json['serviceArea'] as Map<String, dynamic> : null;

    final rawPhotos = json['photos'] as List? ?? [];

    return AdminFleetVehicleModel(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 2023,
      type: json['type'] as String? ?? 'SEDAN',
      fuelType: json['fuelType'] as String? ?? 'PETROL',
      seating: (json['seating'] as num?)?.toInt() ?? 5,
      isAC: json['isAC'] as bool? ?? true,
      registrationNumber: json['registrationNumber'] as String? ?? '',
      photos: rawPhotos.map((p) => p.toString()).toList(),
      pricePerKm: (json['pricePerKm'] as num?)?.toDouble() ?? 0.0,
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      operationalStatus: json['operationalStatus'] as String? ?? 'DRAFT',
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      serviceAreaId: json['serviceAreaId'] as String?,
      serviceAreaName: saMap?['name'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      maintenanceReason: json['maintenanceReason'] as String?,
      maintenanceStartedAt: json['maintenanceStartedAt'] != null
          ? DateTime.tryParse(json['maintenanceStartedAt'].toString())
          : null,
      expectedReturnDate: json['expectedReturnDate'] != null
          ? DateTime.tryParse(json['expectedReturnDate'].toString())
          : null,
      vendorBusinessName: vendorMap?['businessName'] as String?,
      vendorOwnerName: vendorMap?['ownerName'] as String?,
      vendorCity: vendorMap?['city'] as String?,
      vendorVerificationStatus: vendorMap?['verificationStatus'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
