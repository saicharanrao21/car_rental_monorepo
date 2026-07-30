// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VendorModel _$VendorModelFromJson(Map<String, dynamic> json) => VendorModel(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      displayName: json['displayName'] as String?,
      ownerName: json['ownerName'] as String,
      city: json['city'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      businessType: json['businessType'] as String?,
      yearsInOperation: (json['yearsInOperation'] as num?)?.toInt(),
      verificationStatus: json['verificationStatus'] as String,
      rating: (json['rating'] as num).toDouble(),
      totalTrips: (json['totalTrips'] as num).toInt(),
      logoUrl: json['logoUrl'] as String?,
      gstNumber: json['gstNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      bankDetails: json['bankDetails'] as String?,
      addressLine: json['addressLine'] as String?,
      locality: json['locality'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      subscriptionTier: json['subscriptionTier'] as String?,
      isSponsored: json['isSponsored'] as bool,
      branchOfId: json['branchOfId'] as String?,
      parentBusinessName: json['parentBusinessName'] as String?,
      boostExpiresAt: json['boostExpiresAt'] == null
          ? null
          : DateTime.parse(json['boostExpiresAt'] as String),
    );

Map<String, dynamic> _$VendorModelToJson(VendorModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessName': instance.businessName,
      'displayName': instance.displayName,
      'ownerName': instance.ownerName,
      'city': instance.city,
      'phone': instance.phone,
      'email': instance.email,
      'businessType': instance.businessType,
      'yearsInOperation': instance.yearsInOperation,
      'verificationStatus': instance.verificationStatus,
      'rating': instance.rating,
      'totalTrips': instance.totalTrips,
      'logoUrl': instance.logoUrl,
      'gstNumber': instance.gstNumber,
      'panNumber': instance.panNumber,
      'bankDetails': instance.bankDetails,
      'addressLine': instance.addressLine,
      'locality': instance.locality,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'subscriptionTier': instance.subscriptionTier,
      'isSponsored': instance.isSponsored,
      'branchOfId': instance.branchOfId,
      'parentBusinessName': instance.parentBusinessName,
      'boostExpiresAt': instance.boostExpiresAt?.toIso8601String(),
    };
