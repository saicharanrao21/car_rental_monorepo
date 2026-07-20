import 'package:freezed_annotation/freezed_annotation.dart';

part 'vendor_model.freezed.dart';
part 'vendor_model.g.dart';

@freezed
class VendorModel with _$VendorModel {
  const factory VendorModel({
    required String id,
    required String businessName,
    required String ownerName,
    required String city,
    @Default('') String phone,
    String? email,
    String? businessType,
    String? gstNumber,
    String? panNumber,
    String? bankDetails,
    required String verificationStatus, // pending, verified, rejected, suspended
    @Default(0.0) double rating,
    @Default(0) int totalTrips,
  }) = _VendorModel;

  factory VendorModel.fromJson(Map<String, dynamic> json) => _$VendorModelFromJson(json);
}
