// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarModel _$CarModelFromJson(Map<String, dynamic> json) => CarModel(
      id: json['id'] as String,
      vendorId: json['vendorId'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: (json['year'] as num).toInt(),
      type: json['type'] as String,
      fuelType: json['fuelType'] as String,
      seating: (json['seating'] as num).toInt(),
      isAC: json['isAC'] as bool,
      photos:
          (json['photos'] as List<dynamic>).map((e) => e as String).toList(),
      pricePerKm: (json['pricePerKm'] as num).toDouble(),
      pricePerDay: (json['pricePerDay'] as num).toDouble(),
      pricePerHour: (json['pricePerHour'] as num).toDouble(),
      registrationNumber: json['registrationNumber'] as String,
      isAvailable: json['isAvailable'] as bool,
      rating: (json['rating'] as num).toDouble(),
      availableTripTypes: (json['availableTripTypes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      blockedDates: (json['blockedDates'] as List<dynamic>)
          .map((e) => DateTime.parse(e as String))
          .toList(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      isSponsored: json['isSponsored'] as bool,
      vendor: json['vendor'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CarModelToJson(CarModel instance) => <String, dynamic>{
      'id': instance.id,
      'vendorId': instance.vendorId,
      'make': instance.make,
      'model': instance.model,
      'year': instance.year,
      'type': instance.type,
      'fuelType': instance.fuelType,
      'seating': instance.seating,
      'isAC': instance.isAC,
      'photos': instance.photos,
      'pricePerKm': instance.pricePerKm,
      'pricePerDay': instance.pricePerDay,
      'pricePerHour': instance.pricePerHour,
      'registrationNumber': instance.registrationNumber,
      'isAvailable': instance.isAvailable,
      'rating': instance.rating,
      'availableTripTypes': instance.availableTripTypes,
      'blockedDates':
          instance.blockedDates.map((e) => e.toIso8601String()).toList(),
      'distanceKm': instance.distanceKm,
      'isSponsored': instance.isSponsored,
      'vendor': instance.vendor,
    };
