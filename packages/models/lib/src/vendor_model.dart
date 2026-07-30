import 'package:freezed_annotation/freezed_annotation.dart';

part 'vendor_model.freezed.dart';
part 'vendor_model.g.dart';

@freezed
@JsonSerializable()
class VendorModel with _$VendorModel {
  const factory VendorModel({
    required String id,
    required String businessName,
    String? displayName,
    required String ownerName,
    required String city,
    @Default('') String phone,
    String? email,
    String? businessType,
    int? yearsInOperation,
    @Default('pending') String verificationStatus,
    @Default(0.0) double rating,
    @Default(0) int totalTrips,
    String? logoUrl,
    String? gstNumber,
    String? panNumber,
    String? bankDetails,
    String? addressLine,
    String? locality,
    double? latitude,
    double? longitude,
    @Default('BASIC') String? subscriptionTier,
    @Default(false) bool isSponsored,
    String? branchOfId,
    String? parentBusinessName,
    DateTime? boostExpiresAt,
  }) = _VendorModel;

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    json['businessName'] ??= json['displayName'] ?? 'Partner';
    json['ownerName'] ??= json['displayName'] ?? 'Partner';
    json['city'] ??= '';
    json['verificationStatus'] ??= 'verified';
    return _$VendorModelFromJson(json);
  }
}
