import 'package:models/models.dart';

class CityServiceAreaModel {
  final String id;
  final String cityId;
  final String name;
  final String status; // 'ACTIVE', 'COMING_SOON', 'INACTIVE'
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int priority;
  final int vendorCount;
  final int carCount;

  const CityServiceAreaModel({
    required this.id,
    required this.cityId,
    required this.name,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.priority = 0,
    this.vendorCount = 0,
    this.carCount = 0,
  });

  factory CityServiceAreaModel.fromJson(Map<String, dynamic> json, [String defaultCityId = '']) {
    final count = json['_count'] as Map<String, dynamic>?;
    return CityServiceAreaModel(
      id: json['id'] as String? ?? '',
      cityId: json['cityId'] as String? ?? defaultCityId,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 5000.0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      vendorCount: (count?['vendorAssignments'] as num?)?.toInt() ?? (json['vendorCount'] as num?)?.toInt() ?? 0,
      carCount: (count?['cars'] as num?)?.toInt() ?? (json['carCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReadinessCheckItem {
  final String criterion;
  final String label;
  final bool passed;
  final String description;

  const ReadinessCheckItem({
    required this.criterion,
    required this.label,
    required this.passed,
    required this.description,
  });

  factory ReadinessCheckItem.fromJson(Map<String, dynamic> json) {
    return ReadinessCheckItem(
      criterion: json['criterion'] as String? ?? '',
      label: json['label'] as String? ?? '',
      passed: json['passed'] as bool? ?? false,
      description: json['description'] as String? ?? '',
    );
  }
}

class ReadinessReport {
  final String targetId;
  final String targetName;
  final bool isReadyToLaunch;
  final List<ReadinessCheckItem> checklist;
  final String? currentStatus;
  final Map<String, dynamic>? counts;

  const ReadinessReport({
    required this.targetId,
    required this.targetName,
    required this.isReadyToLaunch,
    required this.checklist,
    this.currentStatus,
    this.counts,
  });

  factory ReadinessReport.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'] as List<dynamic>? ?? [];
    return ReadinessReport(
      targetId: json['serviceAreaId'] as String? ?? json['cityId'] as String? ?? '',
      targetName: json['name'] as String? ?? json['cityName'] as String? ?? '',
      isReadyToLaunch: json['isReadyToLaunch'] as bool? ?? false,
      checklist: rawChecklist
          .map((item) => ReadinessCheckItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentStatus: json['currentStatus'] as String? ?? json['status'] as String?,
      counts: json['counts'] as Map<String, dynamic>?,
    );
  }
}

class ImpactReport {
  final String targetId;
  final String targetName;
  final int affectedVendorsCount;
  final int affectedVehiclesCount;
  final int upcomingBookingsCount;
  final int activeRentalsCount;
  final bool safeToDeactivate;
  final List<String> recommendations;
  final List<Map<String, dynamic>> affectedVendors;
  final List<Map<String, dynamic>> affectedVehicles;

  const ImpactReport({
    required this.targetId,
    required this.targetName,
    required this.affectedVendorsCount,
    required this.affectedVehiclesCount,
    required this.upcomingBookingsCount,
    required this.activeRentalsCount,
    required this.safeToDeactivate,
    required this.recommendations,
    this.affectedVendors = const [],
    this.affectedVehicles = const [],
  });

  factory ImpactReport.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final vendors = (json['affectedVendors'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];
    final vehicles = (json['affectedVehicles'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];

    return ImpactReport(
      targetId: json['serviceAreaId'] as String? ?? json['cityId'] as String? ?? '',
      targetName: json['name'] as String? ?? json['cityName'] as String? ?? '',
      affectedVendorsCount: (json['affectedVendorsCount'] as num?)?.toInt() ?? 0,
      affectedVehiclesCount: (json['affectedVehiclesCount'] as num?)?.toInt() ?? 0,
      upcomingBookingsCount: (json['upcomingBookingsCount'] as num?)?.toInt() ?? 0,
      activeRentalsCount: (json['activeRentalsCount'] as num?)?.toInt() ?? 0,
      safeToDeactivate: json['safeToDeactivate'] as bool? ?? true,
      recommendations: recs,
      affectedVendors: vendors,
      affectedVehicles: vehicles,
    );
  }
}

class EnrichedSupportedCity {
  final SupportedCityModel city;
  final List<CityServiceAreaModel> serviceAreas;
  final int totalVendors;
  final int totalCars;

  const EnrichedSupportedCity({
    required this.city,
    required this.serviceAreas,
    this.totalVendors = 0,
    this.totalCars = 0,
  });

  factory EnrichedSupportedCity.fromJson(Map<String, dynamic> json) {
    final city = SupportedCityModel.fromJson(json);
    final rawAreas = json['serviceAreas'] as List<dynamic>? ?? [];
    final areas = rawAreas
        .map((a) => CityServiceAreaModel.fromJson(a as Map<String, dynamic>, city.id))
        .toList();

    int vendors = 0;
    int cars = 0;
    for (final a in areas) {
      vendors += a.vendorCount;
      cars += a.carCount;
    }

    return EnrichedSupportedCity(
      city: city,
      serviceAreas: areas,
      totalVendors: vendors,
      totalCars: cars,
    );
  }
}

