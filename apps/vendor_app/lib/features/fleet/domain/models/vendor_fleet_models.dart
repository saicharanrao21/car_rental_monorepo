class VehicleBlockerModel {
  final String code;
  final String message;
  final String severity;

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
