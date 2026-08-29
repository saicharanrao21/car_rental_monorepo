import 'package:freezed_annotation/freezed_annotation.dart';

part 'car_model.freezed.dart';
part 'car_model.g.dart';

@freezed
@JsonSerializable()
class CarModel with _$CarModel {
  const factory CarModel({
    required String id,
    required String vendorId,
    required String make,
    required String model,
    required int year,
    required String type, // Hatchback, Sedan, SUV, Luxury, etc.
    required String fuelType,
    required int seating,
    required bool isAC,
    required List<String> photos,
    required double pricePerKm,
    required double pricePerDay,
    required double pricePerHour,
    @Default('') String registrationNumber,
    @Default(true) bool isAvailable,
    @Default(0.0) double rating,
    @Default(['Local', 'Outstation', 'Airport Transfer', 'Self-Drive']) List<String> availableTripTypes,
    @Default([]) List<DateTime> blockedDates,
    double? distanceKm,
    @Default(false) bool isSponsored,
    Map<String, dynamic>? vendor,
  }) = _CarModel;

  factory CarModel.fromJson(Map<String, dynamic> json) {
    json['registrationNumber'] ??= '';
    json['isAvailable'] ??= true;
    json['rating'] ??= 0.0;
    json['pricePerKm'] ??= 0.0;
    json['pricePerDay'] ??= 0.0;
    json['pricePerHour'] ??= 0.0;
    json['availableTripTypes'] ??= ['LOCAL', 'OUTSTATION', 'AIRPORT_TRANSFER', 'SELF_DRIVE'];
    json['blockedDates'] ??= [];
    json['isSponsored'] ??= false;

    if (json['availableTripTypes'] != null) {
      final list = List<dynamic>.from(json['availableTripTypes']);
      json['availableTripTypes'] = list.map((t) {
        switch (t.toString().toUpperCase()) {
          case 'LOCAL': return 'Local';
          case 'OUTSTATION': return 'Outstation';
          case 'AIRPORT_TRANSFER': return 'Airport Transfer';
          case 'SELF_DRIVE': return 'Self-Drive';
          default: return t.toString();
        }
      }).toList();
    }
    if (json['vendor'] != null && (json['isSponsored'] == null || json['isSponsored'] == false)) {
      json['isSponsored'] = json['vendor']['isSponsored'] ?? false;
    }
    if (json['mileagePackages'] != null) {
      json['vendor'] ??= <String, dynamic>{};
      json['vendor']['mileagePackages'] = json['mileagePackages'];
    }
    return _$CarModelFromJson(json);
  }
}

extension CarModelDiscountX on CarModel {
  double? get weeklyDiscountPercent => (vendor != null && vendor!['weeklyDiscountPercent'] != null)
      ? (vendor!['weeklyDiscountPercent'] as num).toDouble()
      : 10.0;
  double? get monthlyDiscountPercent => (vendor != null && vendor!['monthlyDiscountPercent'] != null)
      ? (vendor!['monthlyDiscountPercent'] as num).toDouble()
      : 20.0;
}

extension CarModelMileagePackagesX on CarModel {
  List<dynamic> get rawMileagePackages {
    if (vendor != null && vendor!['mileagePackages'] != null) {
      return vendor!['mileagePackages'] as List;
    }
    return [];
  }

  String? get pickupLocationName {
    if (vendor != null && vendor!['pickupHub'] != null && vendor!['pickupHub']['name'] != null) {
      return vendor!['pickupHub']['name'] as String;
    }
    if (vendor != null && vendor!['locality'] != null) {
      return '${vendor!['locality']}, ${vendor!['city']}';
    }
    if (vendor != null && vendor!['city'] != null) {
      return '${vendor!['city']} Hub';
    }
    return null;
  }
}
