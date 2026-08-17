class CoordinatesModel {
  final double latitude;
  final double longitude;

  const CoordinatesModel({
    required this.latitude,
    required this.longitude,
  });

  factory CoordinatesModel.fromJson(Map<String, dynamic> json) {
    return CoordinatesModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class LocationAddressModel {
  final String formattedAddress;
  final String locality;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;

  const LocationAddressModel({
    required this.formattedAddress,
    required this.locality,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });

  factory LocationAddressModel.fromJson(Map<String, dynamic> json) {
    return LocationAddressModel(
      formattedAddress: json['formattedAddress'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formattedAddress': formattedAddress,
      'locality': locality,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class RouteEstimateModel {
  final double distanceKm;
  final int estimatedMinutes;
  final String formattedDistance;
  final String formattedDuration;

  const RouteEstimateModel({
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.formattedDistance,
    required this.formattedDuration,
  });

  factory RouteEstimateModel.fromJson(Map<String, dynamic> json) {
    return RouteEstimateModel(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
      formattedDistance: json['formattedDistance'] as String? ?? '0 km',
      formattedDuration: json['formattedDuration'] as String? ?? '0 mins',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distanceKm': distanceKm,
      'estimatedMinutes': estimatedMinutes,
      'formattedDistance': formattedDistance,
      'formattedDuration': formattedDuration,
    };
  }
}

class VendorLocationItemModel {
  final String id;
  final String businessName;
  final String ownerName;
  final String city;
  final double latitude;
  final double longitude;

  const VendorLocationItemModel({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory VendorLocationItemModel.fromJson(Map<String, dynamic> json) {
    return VendorLocationItemModel(
      id: json['id'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessName': businessName,
      'ownerName': ownerName,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ActiveTripLocationItemModel {
  final String id;
  final String tripType;
  final String pickupLocation;
  final String? dropLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String status;
  final String customerName;
  final String customerPhone;
  final String carName;
  final String registrationNumber;

  const ActiveTripLocationItemModel({
    required this.id,
    required this.tripType,
    required this.pickupLocation,
    this.dropLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.carName,
    required this.registrationNumber,
  });

  factory ActiveTripLocationItemModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    final car = json['car'] as Map<String, dynamic>? ?? {};

    return ActiveTripLocationItemModel(
      id: json['id'] as String? ?? '',
      tripType: json['tripType'] as String? ?? 'SELF_DRIVE',
      pickupLocation: json['pickupLocation'] as String? ?? '',
      dropLocation: json['dropLocation'] as String?,
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'ONGOING',
      customerName: customer['name'] as String? ?? 'Customer',
      customerPhone: customer['phone'] as String? ?? 'N/A',
      carName: '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim(),
      registrationNumber: car['registrationNumber'] as String? ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripType': tripType,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'status': status,
      'customer': {'name': customerName, 'phone': customerPhone},
      'car': {'make': carName, 'model': '', 'registrationNumber': registrationNumber},
    };
  }
}

class EmergencyLocationItemModel {
  final String id;
  final String incidentType;
  final String status;
  final double latitude;
  final double longitude;
  final String locationAddress;
  final String customerName;
  final String customerPhone;

  const EmergencyLocationItemModel({
    required this.id,
    required this.incidentType,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.locationAddress,
    required this.customerName,
    required this.customerPhone,
  });

  factory EmergencyLocationItemModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    return EmergencyLocationItemModel(
      id: json['id'] as String? ?? '',
      incidentType: json['incidentType'] as String? ?? 'GENERAL',
      status: json['status'] as String? ?? 'REQUESTED',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationAddress: json['locationAddress'] as String? ?? 'Location Available',
      customerName: customer['name'] as String? ?? 'Customer',
      customerPhone: customer['phone'] as String? ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incidentType': incidentType,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'customer': {'name': customerName, 'phone': customerPhone},
    };
  }
}

class OperationalLocationOverviewModel {
  final List<VendorLocationItemModel> vendors;
  final List<ActiveTripLocationItemModel> activeBookings;
  final List<EmergencyLocationItemModel> activeEmergencies;
  final int totalHubs;
  final int totalActiveGarages;
  final int totalOnTripVehicles;
  final int totalActiveSosAlerts;

  const OperationalLocationOverviewModel({
    required this.vendors,
    required this.activeBookings,
    required this.activeEmergencies,
    required this.totalHubs,
    required this.totalActiveGarages,
    required this.totalOnTripVehicles,
    required this.totalActiveSosAlerts,
  });

  factory OperationalLocationOverviewModel.fromJson(Map<String, dynamic> json) {
    final rawVendors = json['vendors'] as List<dynamic>? ?? [];
    final rawBookings = json['activeBookings'] as List<dynamic>? ?? [];
    final rawEmergencies = json['activeEmergencies'] as List<dynamic>? ?? [];

    return OperationalLocationOverviewModel(
      vendors: rawVendors
          .map((e) => VendorLocationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeBookings: rawBookings
          .map((e) => ActiveTripLocationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeEmergencies: rawEmergencies
          .map((e) => EmergencyLocationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalHubs: (json['totalHubs'] as num?)?.toInt() ?? 0,
      totalActiveGarages: (json['totalActiveGarages'] as num?)?.toInt() ?? 0,
      totalOnTripVehicles: (json['totalOnTripVehicles'] as num?)?.toInt() ?? 0,
      totalActiveSosAlerts: (json['totalActiveSosAlerts'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendors': vendors.map((e) => e.toJson()).toList(),
      'activeBookings': activeBookings.map((e) => e.toJson()).toList(),
      'activeEmergencies': activeEmergencies.map((e) => e.toJson()).toList(),
      'totalHubs': totalHubs,
      'totalActiveGarages': totalActiveGarages,
      'totalOnTripVehicles': totalOnTripVehicles,
      'totalActiveSosAlerts': totalActiveSosAlerts,
    };
  }
}
