enum IncidentType {
  ACCIDENT,
  BREAKDOWN,
  FLAT_TYRE,
  BATTERY,
  LOCKOUT,
  FUEL_EMERGENCY,
  ENGINE_ISSUE,
  TOWING_REQUIRED,
  MEDICAL_EMERGENCY,
  OTHER;

  static IncidentType fromString(String? value) {
    if (value == null) return IncidentType.OTHER;
    return IncidentType.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => IncidentType.OTHER,
    );
  }

  String get label {
    switch (this) {
      case IncidentType.ACCIDENT:
        return 'Accident / Collision';
      case IncidentType.BREAKDOWN:
        return 'Mechanical Breakdown';
      case IncidentType.FLAT_TYRE:
        return 'Flat Tyre / Puncture';
      case IncidentType.BATTERY:
        return 'Battery Jumpstart Needed';
      case IncidentType.LOCKOUT:
        return 'Key Lockout / Lost Key';
      case IncidentType.FUEL_EMERGENCY:
        return 'Out of Fuel';
      case IncidentType.ENGINE_ISSUE:
        return 'Engine Overheating / Warning Light';
      case IncidentType.TOWING_REQUIRED:
        return 'Flatbed Towing Required';
      case IncidentType.MEDICAL_EMERGENCY:
        return 'Medical Emergency';
      case IncidentType.OTHER:
        return 'Other Roadside Issue';
    }
  }
}

enum EmergencyStatus {
  REQUESTED,
  ACKNOWLEDGED,
  ASSIGNED,
  PROVIDER_EN_ROUTE,
  CUSTOMER_CONTACTED,
  ON_SITE,
  RESOLVED,
  CANCELLED;

  static EmergencyStatus fromString(String? value) {
    if (value == null) return EmergencyStatus.REQUESTED;
    return EmergencyStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => EmergencyStatus.REQUESTED,
    );
  }

  String get label {
    switch (this) {
      case EmergencyStatus.REQUESTED:
        return 'SOS Requested';
      case EmergencyStatus.ACKNOWLEDGED:
        return 'Acknowledged by Dispatch';
      case EmergencyStatus.ASSIGNED:
        return 'Provider Assigned';
      case EmergencyStatus.PROVIDER_EN_ROUTE:
        return 'Technician En Route';
      case EmergencyStatus.CUSTOMER_CONTACTED:
        return 'Customer Contacted';
      case EmergencyStatus.ON_SITE:
        return 'Technician On Site';
      case EmergencyStatus.RESOLVED:
        return 'Resolved';
      case EmergencyStatus.CANCELLED:
        return 'Cancelled';
    }
  }
}

class EmergencyRequestModel {
  final String id;
  final String requestNumber;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String bookingId;
  final String carId;
  final String? carMake;
  final String? carModel;
  final String? carRegNumber;
  final String vendorId;
  final String? vendorBusinessName;
  final String city;
  final IncidentType incidentType;
  final String urgency;
  final EmergencyStatus status;
  final String? customerNotes;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? assignedProviderName;
  final String? assignedProviderPhone;
  final String? contactNotes;
  final String? resolutionNotes;
  final int? estimatedEtaMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const EmergencyRequestModel({
    required this.id,
    required this.requestNumber,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.bookingId,
    required this.carId,
    this.carMake,
    this.carModel,
    this.carRegNumber,
    required this.vendorId,
    this.vendorBusinessName,
    required this.city,
    required this.incidentType,
    this.urgency = 'URGENT',
    this.status = EmergencyStatus.REQUESTED,
    this.customerNotes,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.assignedProviderName,
    this.assignedProviderPhone,
    this.contactNotes,
    this.resolutionNotes,
    this.estimatedEtaMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) {
    return EmergencyRequestModel(
      id: json['id'] as String? ?? '',
      requestNumber: json['requestNumber'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customer']?['name'] as String?,
      customerPhone: json['customer']?['phone'] as String?,
      bookingId: json['bookingId'] as String? ?? '',
      carId: json['carId'] as String? ?? '',
      carMake: json['car']?['make'] as String?,
      carModel: json['car']?['model'] as String?,
      carRegNumber: json['car']?['registrationNumber'] as String?,
      vendorId: json['vendorId'] as String? ?? '',
      vendorBusinessName: json['vendor']?['businessName'] as String?,
      city: json['city'] as String? ?? '',
      incidentType: IncidentType.fromString(json['incidentType'] as String?),
      urgency: json['urgency'] as String? ?? 'URGENT',
      status: EmergencyStatus.fromString(json['status'] as String?),
      customerNotes: json['customerNotes'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['locationAddress'] as String?,
      assignedProviderName: json['assignedProviderName'] as String?,
      assignedProviderPhone: json['assignedProviderPhone'] as String?,
      contactNotes: json['contactNotes'] as String?,
      resolutionNotes: json['resolutionNotes'] as String?,
      estimatedEtaMinutes: json['estimatedEtaMinutes'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestNumber': requestNumber,
        'customerId': customerId,
        'bookingId': bookingId,
        'carId': carId,
        'vendorId': vendorId,
        'city': city,
        'incidentType': incidentType.name,
        'urgency': urgency,
        'status': status.name,
        'customerNotes': customerNotes,
        'latitude': latitude,
        'longitude': longitude,
        'locationAddress': locationAddress,
        'assignedProviderName': assignedProviderName,
        'assignedProviderPhone': assignedProviderPhone,
        'contactNotes': contactNotes,
        'resolutionNotes': resolutionNotes,
        'estimatedEtaMinutes': estimatedEtaMinutes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}
