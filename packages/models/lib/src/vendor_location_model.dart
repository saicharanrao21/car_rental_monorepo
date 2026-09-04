enum VendorLocationType {
  vendorYard,
  branch,
  office,
  airport,
  railwayStation,
  busTerminal,
  publicPoint,
  hotel,
  customPoint,
}

extension VendorLocationTypeExt on VendorLocationType {
  String get displayName {
    switch (this) {
      case VendorLocationType.vendorYard:
        return 'Vendor Yard / Garage';
      case VendorLocationType.branch:
        return 'Branch Hub';
      case VendorLocationType.office:
        return 'Commercial Office';
      case VendorLocationType.airport:
        return 'Airport Terminal';
      case VendorLocationType.railwayStation:
        return 'Railway Station';
      case VendorLocationType.busTerminal:
        return 'Bus Terminal';
      case VendorLocationType.publicPoint:
        return 'Public Meeting Point';
      case VendorLocationType.hotel:
        return 'Hotel / Resort Point';
      case VendorLocationType.customPoint:
        return 'Custom Approved Point';
    }
  }

  String toApiString() {
    switch (this) {
      case VendorLocationType.vendorYard:
        return 'VENDOR_YARD';
      case VendorLocationType.branch:
        return 'BRANCH';
      case VendorLocationType.office:
        return 'OFFICE';
      case VendorLocationType.airport:
        return 'AIRPORT';
      case VendorLocationType.railwayStation:
        return 'RAILWAY_STATION';
      case VendorLocationType.busTerminal:
        return 'BUS_TERMINAL';
      case VendorLocationType.publicPoint:
        return 'PUBLIC_POINT';
      case VendorLocationType.hotel:
        return 'HOTEL';
      case VendorLocationType.customPoint:
        return 'CUSTOM_POINT';
    }
  }

  static VendorLocationType fromString(String? val) {
    if (val == null) return VendorLocationType.vendorYard;
    final upper = val.toUpperCase().replaceAll('-', '_');
    switch (upper) {
      case 'VENDOR_YARD':
      case 'YARD':
        return VendorLocationType.vendorYard;
      case 'BRANCH':
        return VendorLocationType.branch;
      case 'OFFICE':
        return VendorLocationType.office;
      case 'AIRPORT':
        return VendorLocationType.airport;
      case 'RAILWAY_STATION':
      case 'RAILWAY':
        return VendorLocationType.railwayStation;
      case 'BUS_TERMINAL':
      case 'BUS':
        return VendorLocationType.busTerminal;
      case 'PUBLIC_POINT':
      case 'PUBLIC':
        return VendorLocationType.publicPoint;
      case 'HOTEL':
        return VendorLocationType.hotel;
      case 'CUSTOM_POINT':
      case 'CUSTOM':
        return VendorLocationType.customPoint;
      default:
        return VendorLocationType.vendorYard;
    }
  }

  static VendorLocationType fromApiString(String? val) => fromString(val);
}

enum VendorLocationStatus {
  active,
  inactive,
  temporarilyClosed,
  pendingApproval,
  suspended,
}

extension VendorLocationStatusExt on VendorLocationStatus {
  String toApiString() {
    switch (this) {
      case VendorLocationStatus.active:
        return 'ACTIVE';
      case VendorLocationStatus.inactive:
        return 'INACTIVE';
      case VendorLocationStatus.temporarilyClosed:
        return 'TEMPORARILY_CLOSED';
      case VendorLocationStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case VendorLocationStatus.suspended:
        return 'SUSPENDED';
    }
  }

  static VendorLocationStatus fromString(String? val) {
    if (val == null) return VendorLocationStatus.active;
    final upper = val.toUpperCase().replaceAll('-', '_');
    switch (upper) {
      case 'ACTIVE':
        return VendorLocationStatus.active;
      case 'INACTIVE':
      case 'ARCHIVED':
        return VendorLocationStatus.inactive;
      case 'TEMPORARILY_CLOSED':
      case 'PAUSED':
        return VendorLocationStatus.temporarilyClosed;
      case 'PENDING_APPROVAL':
      case 'PENDING_REVIEW':
      case 'DRAFT':
        return VendorLocationStatus.pendingApproval;
      case 'SUSPENDED':
        return VendorLocationStatus.suspended;
      default:
        return VendorLocationStatus.active;
    }
  }

  static VendorLocationStatus fromApiString(String? val) => fromString(val);
}

enum DeliveryPricingModel {
  free,
  fixed,
  distanceBased,
}

extension DeliveryPricingModelExt on DeliveryPricingModel {
  String toApiString() {
    switch (this) {
      case DeliveryPricingModel.free:
        return 'FREE';
      case DeliveryPricingModel.fixed:
        return 'FIXED';
      case DeliveryPricingModel.distanceBased:
        return 'DISTANCE_BASED';
    }
  }

  static DeliveryPricingModel fromString(String? val) {
    if (val == null) return DeliveryPricingModel.fixed;
    final upper = val.toUpperCase().replaceAll('-', '_');
    switch (upper) {
      case 'FREE':
        return DeliveryPricingModel.free;
      case 'FIXED':
        return DeliveryPricingModel.fixed;
      case 'DISTANCE_BASED':
      case 'PER_KM':
        return DeliveryPricingModel.distanceBased;
      default:
        return DeliveryPricingModel.fixed;
    }
  }

  static DeliveryPricingModel fromApiString(String? val) => fromString(val);
}

class VendorLocationModel {
  final String id;
  final String vendorId;
  final String name;
  final VendorLocationType type;
  final String address;
  final String? locality;
  final String city;
  final String? state;
  final String? pincode;
  final double latitude;
  final double longitude;
  final String? contactPerson;
  final String? contactPhone;
  final VendorLocationStatus status;
  final bool allowsPickup;
  final bool allowsReturn;
  final bool allowsDelivery;
  final double pickupFee;
  final double returnFee;
  final double oneWayFee;
  final String openingTime;
  final String closingTime;
  final bool is24x7;
  final double serviceRadiusKm;
  final int assignedCarCount;
  final List<String> assignedCarIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get scheduleDisplay => is24x7 ? 'Open 24x7' : '$openingTime - $closingTime';

  const VendorLocationModel({
    required this.id,
    required this.vendorId,
    required this.name,
    this.type = VendorLocationType.vendorYard,
    required this.address,
    this.locality,
    required this.city,
    this.state,
    this.pincode,
    required this.latitude,
    required this.longitude,
    this.contactPerson,
    this.contactPhone,
    this.status = VendorLocationStatus.active,
    this.allowsPickup = true,
    this.allowsReturn = true,
    this.allowsDelivery = false,
    this.pickupFee = 0.0,
    this.returnFee = 0.0,
    this.oneWayFee = 0.0,
    this.openingTime = '08:00',
    this.closingTime = '22:00',
    this.is24x7 = false,
    this.serviceRadiusKm = 25.0,
    this.assignedCarCount = 0,
    this.assignedCarIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  VendorLocationModel copyWith({
    String? id,
    String? vendorId,
    String? name,
    VendorLocationType? type,
    String? address,
    String? locality,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? contactPerson,
    String? contactPhone,
    VendorLocationStatus? status,
    bool? allowsPickup,
    bool? allowsReturn,
    bool? allowsDelivery,
    double? pickupFee,
    double? returnFee,
    double? oneWayFee,
    String? openingTime,
    String? closingTime,
    bool? is24x7,
    double? serviceRadiusKm,
    int? assignedCarCount,
    List<String>? assignedCarIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorLocationModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      allowsPickup: allowsPickup ?? this.allowsPickup,
      allowsReturn: allowsReturn ?? this.allowsReturn,
      allowsDelivery: allowsDelivery ?? this.allowsDelivery,
      pickupFee: pickupFee ?? this.pickupFee,
      returnFee: returnFee ?? this.returnFee,
      oneWayFee: oneWayFee ?? this.oneWayFee,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      is24x7: is24x7 ?? this.is24x7,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      assignedCarCount: assignedCarCount ?? this.assignedCarCount,
      assignedCarIds: assignedCarIds ?? this.assignedCarIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory VendorLocationModel.fromJson(Map<String, dynamic> json) {
    final rawCarIds = json['assignedCarIds'] as List<dynamic>? ?? [];
    return VendorLocationModel(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: VendorLocationTypeExt.fromString(json['type'] as String?),
      address: json['address'] as String? ?? '',
      locality: json['locality'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      contactPerson: json['contactPerson'] as String?,
      contactPhone: json['contactPhone'] as String?,
      status: VendorLocationStatusExt.fromString(json['status'] as String?),
      allowsPickup: json['allowsPickup'] as bool? ?? true,
      allowsReturn: json['allowsReturn'] as bool? ?? true,
      allowsDelivery: json['allowsDelivery'] as bool? ?? false,
      pickupFee: (json['pickupFee'] as num?)?.toDouble() ?? 0.0,
      returnFee: (json['returnFee'] as num?)?.toDouble() ?? 0.0,
      oneWayFee: (json['oneWayFee'] as num?)?.toDouble() ?? 0.0,
      openingTime: json['openingTime'] as String? ?? '08:00',
      closingTime: json['closingTime'] as String? ?? '22:00',
      is24x7: json['is24x7'] as bool? ?? false,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble() ?? 25.0,
      assignedCarCount: (json['assignedCarCount'] as num?)?.toInt() ?? rawCarIds.length,
      assignedCarIds: rawCarIds.map((e) => e.toString()).toList(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendorId': vendorId,
      'name': name,
      'type': type.toApiString(),
      'address': address,
      'locality': locality,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'status': status.toApiString(),
      'allowsPickup': allowsPickup,
      'allowsReturn': allowsReturn,
      'allowsDelivery': allowsDelivery,
      'pickupFee': pickupFee,
      'returnFee': returnFee,
      'oneWayFee': oneWayFee,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'is24x7': is24x7,
      'serviceRadiusKm': serviceRadiusKm,
      'assignedCarCount': assignedCarCount,
      'assignedCarIds': assignedCarIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class VendorDeliveryPolicyModel {
  final String vendorId;
  final bool deliveryEnabled;
  final double maxDeliveryRadiusKm;
  final DeliveryPricingModel pricingModel;
  final double baseDeliveryFee;
  final double perKmDeliveryFee;
  final double freeDeliveryWithinKm;

  const VendorDeliveryPolicyModel({
    required this.vendorId,
    this.deliveryEnabled = true,
    this.maxDeliveryRadiusKm = 15.0,
    this.pricingModel = DeliveryPricingModel.fixed,
    this.baseDeliveryFee = 300.0,
    this.perKmDeliveryFee = 20.0,
    this.freeDeliveryWithinKm = 5.0,
  });

  VendorDeliveryPolicyModel copyWith({
    String? vendorId,
    bool? deliveryEnabled,
    double? maxDeliveryRadiusKm,
    DeliveryPricingModel? pricingModel,
    double? baseDeliveryFee,
    double? perKmDeliveryFee,
    double? freeDeliveryWithinKm,
  }) {
    return VendorDeliveryPolicyModel(
      vendorId: vendorId ?? this.vendorId,
      deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
      maxDeliveryRadiusKm: maxDeliveryRadiusKm ?? this.maxDeliveryRadiusKm,
      pricingModel: pricingModel ?? this.pricingModel,
      baseDeliveryFee: baseDeliveryFee ?? this.baseDeliveryFee,
      perKmDeliveryFee: perKmDeliveryFee ?? this.perKmDeliveryFee,
      freeDeliveryWithinKm: freeDeliveryWithinKm ?? this.freeDeliveryWithinKm,
    );
  }

  factory VendorDeliveryPolicyModel.fromJson(Map<String, dynamic> json) {
    return VendorDeliveryPolicyModel(
      vendorId: json['vendorId'] as String? ?? '',
      deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
      maxDeliveryRadiusKm: (json['maxDeliveryRadiusKm'] as num?)?.toDouble() ?? 15.0,
      pricingModel: DeliveryPricingModelExt.fromString(json['pricingModel'] as String?),
      baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 300.0,
      perKmDeliveryFee: (json['perKmDeliveryFee'] as num?)?.toDouble() ?? 20.0,
      freeDeliveryWithinKm: (json['freeDeliveryWithinKm'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'deliveryEnabled': deliveryEnabled,
      'maxDeliveryRadiusKm': maxDeliveryRadiusKm,
      'pricingModel': pricingModel.toApiString(),
      'baseDeliveryFee': baseDeliveryFee,
      'perKmDeliveryFee': perKmDeliveryFee,
      'freeDeliveryWithinKm': freeDeliveryWithinKm,
    };
  }
}

class LocationMatrixItemModel {
  final String pickupLocationId;
  final String returnLocationId;
  final String pickupLocationName;
  final String returnLocationName;
  final bool isSupported;
  final double oneWaySurcharge;

  const LocationMatrixItemModel({
    required this.pickupLocationId,
    required this.returnLocationId,
    required this.pickupLocationName,
    required this.returnLocationName,
    this.isSupported = true,
    this.oneWaySurcharge = 0.0,
  });

  factory LocationMatrixItemModel.fromJson(Map<String, dynamic> json) {
    return LocationMatrixItemModel(
      pickupLocationId: json['pickupLocationId'] as String? ?? '',
      returnLocationId: json['returnLocationId'] as String? ?? '',
      pickupLocationName: json['pickupLocationName'] as String? ?? '',
      returnLocationName: json['returnLocationName'] as String? ?? '',
      isSupported: json['isSupported'] as bool? ?? true,
      oneWaySurcharge: (json['oneWaySurcharge'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pickupLocationId': pickupLocationId,
      'returnLocationId': returnLocationId,
      'pickupLocationName': pickupLocationName,
      'returnLocationName': returnLocationName,
      'isSupported': isSupported,
      'oneWaySurcharge': oneWaySurcharge,
    };
  }
}

class LocationOperationsItemSummary {
  final String locationId;
  final String locationName;
  final String locationType;
  final int todayPickups;
  final int todayReturns;
  final int activeVehicles;

  const LocationOperationsItemSummary({
    required this.locationId,
    required this.locationName,
    required this.locationType,
    required this.todayPickups,
    required this.todayReturns,
    required this.activeVehicles,
  });

  factory LocationOperationsItemSummary.fromJson(Map<String, dynamic> json) {
    return LocationOperationsItemSummary(
      locationId: json['locationId'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      locationType: json['locationType'] as String? ?? 'YARD',
      todayPickups: (json['todayPickups'] as num?)?.toInt() ?? 0,
      todayReturns: (json['todayReturns'] as num?)?.toInt() ?? 0,
      activeVehicles: (json['activeVehicles'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'locationName': locationName,
      'locationType': locationType,
      'todayPickups': todayPickups,
      'todayReturns': todayReturns,
      'activeVehicles': activeVehicles,
    };
  }
}

class LocationOperationsSummaryModel {
  final List<LocationOperationsItemSummary> locations;
  final int totalTodayPickups;
  final int totalTodayReturns;
  final int totalDeliveryRequests;

  const LocationOperationsSummaryModel({
    required this.locations,
    required this.totalTodayPickups,
    required this.totalTodayReturns,
    required this.totalDeliveryRequests,
  });

  factory LocationOperationsSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawLocs = json['locations'] as List<dynamic>? ?? [];
    return LocationOperationsSummaryModel(
      locations: rawLocs
          .map((e) => LocationOperationsItemSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalTodayPickups: (json['totalTodayPickups'] as num?)?.toInt() ?? 0,
      totalTodayReturns: (json['totalTodayReturns'] as num?)?.toInt() ?? 0,
      totalDeliveryRequests: (json['totalDeliveryRequests'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locations': locations.map((e) => e.toJson()).toList(),
      'totalTodayPickups': totalTodayPickups,
      'totalTodayReturns': totalTodayReturns,
      'totalDeliveryRequests': totalDeliveryRequests,
    };
  }
}

class BookingLocationSnapshotModel {
  final String pickupLocationId;
  final String pickupLocationName;
  final String pickupLocationType;
  final String pickupAddress;
  final String? pickupLocality;
  final String pickupCity;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double pickupFee;

  final String returnLocationId;
  final String returnLocationName;
  final String returnLocationType;
  final String returnAddress;
  final String? returnLocality;
  final String returnCity;
  final double? returnLatitude;
  final double? returnLongitude;
  final double returnFee;
  final double oneWayFee;

  final bool isCustomerAddressDelivery;
  final String? deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double deliveryFee;

  const BookingLocationSnapshotModel({
    required this.pickupLocationId,
    required this.pickupLocationName,
    required this.pickupLocationType,
    required this.pickupAddress,
    this.pickupLocality,
    required this.pickupCity,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupFee = 0.0,
    required this.returnLocationId,
    required this.returnLocationName,
    required this.returnLocationType,
    required this.returnAddress,
    this.returnLocality,
    required this.returnCity,
    this.returnLatitude,
    this.returnLongitude,
    this.returnFee = 0.0,
    this.oneWayFee = 0.0,
    this.isCustomerAddressDelivery = false,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryFee = 0.0,
  });

  factory BookingLocationSnapshotModel.fromJson(Map<String, dynamic> json) {
    return BookingLocationSnapshotModel(
      pickupLocationId: json['pickupLocationId'] as String? ?? '',
      pickupLocationName: json['pickupLocationName'] as String? ?? 'Primary Yard',
      pickupLocationType: json['pickupLocationType'] as String? ?? 'VENDOR_YARD',
      pickupAddress: json['pickupAddress'] as String? ?? '',
      pickupLocality: json['pickupLocality'] as String?,
      pickupCity: json['pickupCity'] as String? ?? '',
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      pickupFee: (json['pickupFee'] as num?)?.toDouble() ?? 0.0,
      returnLocationId: json['returnLocationId'] as String? ?? '',
      returnLocationName: json['returnLocationName'] as String? ?? 'Primary Yard',
      returnLocationType: json['returnLocationType'] as String? ?? 'VENDOR_YARD',
      returnAddress: json['returnAddress'] as String? ?? '',
      returnLocality: json['returnLocality'] as String?,
      returnCity: json['returnCity'] as String? ?? '',
      returnLatitude: (json['returnLatitude'] as num?)?.toDouble(),
      returnLongitude: (json['returnLongitude'] as num?)?.toDouble(),
      returnFee: (json['returnFee'] as num?)?.toDouble() ?? 0.0,
      oneWayFee: (json['oneWayFee'] as num?)?.toDouble() ?? 0.0,
      isCustomerAddressDelivery: json['isCustomerAddressDelivery'] as bool? ?? false,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pickupLocationId': pickupLocationId,
      'pickupLocationName': pickupLocationName,
      'pickupLocationType': pickupLocationType,
      'pickupAddress': pickupAddress,
      'pickupLocality': pickupLocality,
      'pickupCity': pickupCity,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'pickupFee': pickupFee,
      'returnLocationId': returnLocationId,
      'returnLocationName': returnLocationName,
      'returnLocationType': returnLocationType,
      'returnAddress': returnAddress,
      'returnLocality': returnLocality,
      'returnCity': returnCity,
      'returnLatitude': returnLatitude,
      'returnLongitude': returnLongitude,
      'returnFee': returnFee,
      'oneWayFee': oneWayFee,
      'isCustomerAddressDelivery': isCustomerAddressDelivery,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryFee': deliveryFee,
    };
  }
}

enum LocationExceptionType {
  holiday,
  temporaryClosure,
  emergencyClosure,
  customHours,
}

extension LocationExceptionTypeExt on LocationExceptionType {
  String get displayName {
    switch (this) {
      case LocationExceptionType.holiday:
        return 'Holiday';
      case LocationExceptionType.temporaryClosure:
        return 'Temporary Closure';
      case LocationExceptionType.emergencyClosure:
        return 'Emergency Closure';
      case LocationExceptionType.customHours:
        return 'Custom Hours';
    }
  }

  String toApiString() {
    switch (this) {
      case LocationExceptionType.holiday:
        return 'HOLIDAY';
      case LocationExceptionType.temporaryClosure:
        return 'TEMPORARY_CLOSURE';
      case LocationExceptionType.emergencyClosure:
        return 'EMERGENCY_CLOSURE';
      case LocationExceptionType.customHours:
        return 'CUSTOM_HOURS';
    }
  }

  static LocationExceptionType fromString(String? val) {
    if (val == null) return LocationExceptionType.holiday;
    final upper = val.toUpperCase().replaceAll('-', '_');
    switch (upper) {
      case 'HOLIDAY':
        return LocationExceptionType.holiday;
      case 'TEMPORARY_CLOSURE':
      case 'TEMPORARY':
        return LocationExceptionType.temporaryClosure;
      case 'EMERGENCY_CLOSURE':
      case 'EMERGENCY':
        return LocationExceptionType.emergencyClosure;
      case 'CUSTOM_HOURS':
      case 'CUSTOM':
        return LocationExceptionType.customHours;
      default:
        return LocationExceptionType.holiday;
    }
  }

  static LocationExceptionType fromApiString(String? val) => fromString(val);
}

class LocationExceptionModel {
  final String id;
  final String locationId;
  final DateTime date;
  final LocationExceptionType exceptionType;
  final bool isClosed;
  final String? specialOpeningTime;
  final String? specialClosingTime;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LocationExceptionModel({
    required this.id,
    required this.locationId,
    required this.date,
    this.exceptionType = LocationExceptionType.holiday,
    this.isClosed = true,
    this.specialOpeningTime,
    this.specialClosingTime,
    this.reason,
    this.createdAt,
    this.updatedAt,
  });

  String get dateString =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String? get customOpeningTime => specialOpeningTime;
  String? get customClosingTime => specialClosingTime;
  LocationExceptionType get type => exceptionType;

  String get displaySummary {
    if (isClosed) {
      return '$dateString: Closed (${reason ?? exceptionType.displayName})';
    }
    return '$dateString: $specialOpeningTime - $specialClosingTime (${reason ?? exceptionType.displayName})';
  }

  LocationExceptionModel copyWith({
    String? id,
    String? locationId,
    DateTime? date,
    LocationExceptionType? exceptionType,
    bool? isClosed,
    String? specialOpeningTime,
    String? specialClosingTime,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocationExceptionModel(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      date: date ?? this.date,
      exceptionType: exceptionType ?? this.exceptionType,
      isClosed: isClosed ?? this.isClosed,
      specialOpeningTime: specialOpeningTime ?? this.specialOpeningTime,
      specialClosingTime: specialClosingTime ?? this.specialClosingTime,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LocationExceptionModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] is String) {
      parsedDate = DateTime.tryParse(json['date'] as String) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    return LocationExceptionModel(
      id: json['id'] as String? ?? '',
      locationId: json['locationId'] as String? ?? '',
      date: parsedDate,
      exceptionType: LocationExceptionTypeExt.fromString(json['exceptionType'] as String?),
      isClosed: json['isClosed'] as bool? ?? true,
      specialOpeningTime: json['customOpeningTime'] as String? ?? json['specialOpeningTime'] as String?,
      specialClosingTime: json['customClosingTime'] as String? ?? json['specialClosingTime'] as String?,
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'locationId': locationId,
      'date': date.toIso8601String(),
      'exceptionType': exceptionType.toApiString(),
      'isClosed': isClosed,
      'customOpeningTime': specialOpeningTime,
      'specialOpeningTime': specialOpeningTime,
      'customClosingTime': specialClosingTime,
      'specialClosingTime': specialClosingTime,
      'reason': reason,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

