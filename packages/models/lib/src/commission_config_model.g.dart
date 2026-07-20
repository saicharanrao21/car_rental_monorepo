// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commission_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CommissionConfigModelImpl _$$CommissionConfigModelImplFromJson(
        Map<String, dynamic> json) =>
    _$CommissionConfigModelImpl(
      id: json['id'] as String,
      tripType: json['tripType'] as String,
      city: json['city'] as String,
      carCategory: json['carCategory'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
    );

Map<String, dynamic> _$$CommissionConfigModelImplToJson(
        _$CommissionConfigModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tripType': instance.tripType,
      'city': instance.city,
      'carCategory': instance.carCategory,
      'percentage': instance.percentage,
      'effectiveFrom': instance.effectiveFrom.toIso8601String(),
    };
