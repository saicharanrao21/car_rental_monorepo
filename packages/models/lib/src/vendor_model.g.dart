// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VendorModelImpl _$$VendorModelImplFromJson(Map<String, dynamic> json) =>
    _$VendorModelImpl(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      ownerName: json['ownerName'] as String,
      city: json['city'] as String,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      businessType: json['businessType'] as String?,
      gstNumber: json['gstNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      bankDetails: json['bankDetails'] as String?,
      verificationStatus: json['verificationStatus'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      displayName: json['displayName'] as String?,
      locality: json['locality'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      subscriptionTier: json['subscriptionTier'] as String? ?? 'BASIC',
      isSponsored: json['isSponsored'] as bool? ?? false,
    );

Map<String, dynamic> _$$VendorModelImplToJson(_$VendorModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessName': instance.businessName,
      'ownerName': instance.ownerName,
      'city': instance.city,
      'phone': instance.phone,
      'email': instance.email,
      'businessType': instance.businessType,
      'gstNumber': instance.gstNumber,
      'panNumber': instance.panNumber,
      'bankDetails': instance.bankDetails,
      'verificationStatus': instance.verificationStatus,
      'rating': instance.rating,
      'totalTrips': instance.totalTrips,
      'displayName': instance.displayName,
      'locality': instance.locality,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'subscriptionTier': instance.subscriptionTier,
      'isSponsored': instance.isSponsored,
    };
