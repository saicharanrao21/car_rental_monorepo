// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EarningsModelImpl _$$EarningsModelImplFromJson(Map<String, dynamic> json) =>
    _$EarningsModelImpl(
      vendorId: json['vendorId'] as String,
      date: DateTime.parse(json['date'] as String),
      grossAmount: (json['grossAmount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      gstAmount: (json['gstAmount'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
    );

Map<String, dynamic> _$$EarningsModelImplToJson(_$EarningsModelImpl instance) =>
    <String, dynamic>{
      'vendorId': instance.vendorId,
      'date': instance.date.toIso8601String(),
      'grossAmount': instance.grossAmount,
      'platformFee': instance.platformFee,
      'gstAmount': instance.gstAmount,
      'netAmount': instance.netAmount,
    };
