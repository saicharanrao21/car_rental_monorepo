// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookingModelImpl _$$BookingModelImplFromJson(Map<String, dynamic> json) =>
    _$BookingModelImpl(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      carId: json['carId'] as String,
      tripType: json['tripType'] as String,
      pickupLocation: json['pickupLocation'] as String,
      dropLocation: json['dropLocation'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalFare: (json['totalFare'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      gstAmount: (json['gstAmount'] as num).toDouble(),
      netToVendor: (json['netToVendor'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      disputeFlag: json['disputeFlag'] as bool? ?? false,
      disputeNote: json['disputeNote'] as String?,
    );

Map<String, dynamic> _$$BookingModelImplToJson(_$BookingModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerId': instance.customerId,
      'vendorId': instance.vendorId,
      'carId': instance.carId,
      'tripType': instance.tripType,
      'pickupLocation': instance.pickupLocation,
      'dropLocation': instance.dropLocation,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'totalFare': instance.totalFare,
      'platformFee': instance.platformFee,
      'gstAmount': instance.gstAmount,
      'netToVendor': instance.netToVendor,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'disputeFlag': instance.disputeFlag,
      'disputeNote': instance.disputeNote,
    };
