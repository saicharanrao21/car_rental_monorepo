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
  }) = _CarModel;

  factory CarModel.fromJson(Map<String, dynamic> json) {
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
    return _$CarModelFromJson(json);
  }
}
