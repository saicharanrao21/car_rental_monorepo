import 'package:equatable/equatable.dart';

class VehicleAvailabilityConflict extends Equatable {
  final String type; // BOOKING, BLOCK, HOLD, MAINTENANCE, LOCATION_CLOSURE
  final String? id;
  final DateTime startDate;
  final DateTime endDate;
  final String? status;
  final String? reason;

  const VehicleAvailabilityConflict({
    required this.type,
    this.id,
    required this.startDate,
    required this.endDate,
    this.status,
    this.reason,
  });

  factory VehicleAvailabilityConflict.fromJson(Map<String, dynamic> json) {
    return VehicleAvailabilityConflict(
      type: (json['type'] as String?) ?? 'BLOCK',
      id: json['id'] as String?,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] as String?,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    if (status != null) 'status': status,
    if (reason != null) 'reason': reason,
  };

  @override
  List<Object?> get props => [type, id, startDate, endDate, status, reason];
}

class VehicleAvailabilityResult extends Equatable {
  final bool available;
  final String carId;
  final String startDate;
  final String endDate;
  final String? reason;
  final List<VehicleAvailabilityConflict> conflicts;

  const VehicleAvailabilityResult({
    required this.available,
    required this.carId,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.conflicts = const [],
  });

  factory VehicleAvailabilityResult.fromJson(Map<String, dynamic> json) {
    final interval = json['evaluatedInterval'] as Map<String, dynamic>?;
    final conflictsList = (json['conflicts'] as List<dynamic>?)
            ?.map((e) => VehicleAvailabilityConflict.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return VehicleAvailabilityResult(
      available: json['available'] == true,
      carId: (json['carId'] as String?) ?? '',
      startDate: interval?['startDate']?.toString() ?? '',
      endDate: interval?['endDate']?.toString() ?? '',
      reason: json['reason'] as String?,
      conflicts: conflictsList,
    );
  }

  @override
  List<Object?> get props => [available, carId, startDate, endDate, reason, conflicts];
}

class VehicleBlockModel extends Equatable {
  final String id;
  final String carId;
  final String vendorId;
  final DateTime startDate;
  final DateTime endDate;
  final String blockType; // MAINTENANCE, VENDOR_BLACKOUT, ADMIN_HOLD, ACCIDENT_REPAIR, DETAILING
  final String? reason;
  final String actorId;
  final String actorRole;
  final DateTime createdAt;

  const VehicleBlockModel({
    required this.id,
    required this.carId,
    required this.vendorId,
    required this.startDate,
    required this.endDate,
    required this.blockType,
    this.reason,
    required this.actorId,
    required this.actorRole,
    required this.createdAt,
  });

  factory VehicleBlockModel.fromJson(Map<String, dynamic> json) {
    return VehicleBlockModel(
      id: (json['id'] as String?) ?? '',
      carId: (json['carId'] as String?) ?? '',
      vendorId: (json['vendorId'] as String?) ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      blockType: (json['blockType'] as String?) ?? 'VENDOR_BLACKOUT',
      reason: json['reason'] as String?,
      actorId: (json['actorId'] as String?) ?? '',
      actorRole: (json['actorRole'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'carId': carId,
    'vendorId': vendorId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'blockType': blockType,
    if (reason != null) 'reason': reason,
    'actorId': actorId,
    'actorRole': actorRole,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, carId, vendorId, startDate, endDate, blockType, reason];
}

class VehicleHoldModel extends Equatable {
  final String id;
  final String carId;
  final String customerId;
  final String vendorId;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime expiresAt;
  final String status; // ACTIVE, CONVERTED, RELEASED, EXPIRED
  final String? idempotencyKey;

  const VehicleHoldModel({
    required this.id,
    required this.carId,
    required this.customerId,
    required this.vendorId,
    required this.startDate,
    required this.endDate,
    required this.expiresAt,
    required this.status,
    this.idempotencyKey,
  });

  factory VehicleHoldModel.fromJson(Map<String, dynamic> json) {
    return VehicleHoldModel(
      id: (json['id'] as String?) ?? '',
      carId: (json['carId'] as String?) ?? '',
      customerId: (json['customerId'] as String?) ?? '',
      vendorId: (json['vendorId'] as String?) ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'ACTIVE',
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, carId, customerId, vendorId, startDate, endDate, expiresAt, status];
}

class AvailabilityTimelineEntry extends Equatable {
  final String type; // BOOKING, BLOCK, HOLD, MAINTENANCE
  final String id;
  final String? status;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final Map<String, dynamic>? metadata;

  const AvailabilityTimelineEntry({
    required this.type,
    required this.id,
    this.status,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.metadata,
  });

  factory AvailabilityTimelineEntry.fromJson(Map<String, dynamic> json) {
    return AvailabilityTimelineEntry(
      type: (json['type'] as String?) ?? 'BOOKING',
      id: (json['id'] as String?) ?? '',
      status: json['status'] as String?,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [type, id, status, startDate, endDate, reason];
}
