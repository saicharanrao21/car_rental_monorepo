class CouponModel {
  final String id;
  final String code;
  final String? description;
  final String discountType; // PERCENTAGE or FIXED
  final double discountValue;
  final double? maxDiscountAmount;
  final double? minBookingAmount;
  final String? expiresAt;
  final String? city;
  final String? tripType;
  final String? carCategory;
  final bool firstBookingOnly;
  final bool isActive;
  final int usageCount;

  const CouponModel({
    required this.id,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minBookingAmount,
    this.expiresAt,
    this.city,
    this.tripType,
    this.carCategory,
    this.firstBookingOnly = false,
    this.isActive = true,
    this.usageCount = 0,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      discountType: json['discountType'] as String? ?? 'PERCENTAGE',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
      minBookingAmount: (json['minBookingAmount'] as num?)?.toDouble(),
      expiresAt: json['expiresAt'] as String?,
      city: json['city'] as String?,
      tripType: json['tripType'] as String?,
      carCategory: json['carCategory'] as String?,
      firstBookingOnly: json['firstBookingOnly'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minBookingAmount': minBookingAmount,
      'expiresAt': expiresAt,
      'city': city,
      'tripType': tripType,
      'carCategory': carCategory,
      'firstBookingOnly': firstBookingOnly,
      'isActive': isActive,
      'usageCount': usageCount,
    };
  }
}

class CouponValidationResultModel {
  final bool valid;
  final String couponId;
  final String code;
  final String? description;
  final String discountType;
  final double discountValue;
  final double? maxDiscountAmount;
  final double? minBookingAmount;
  final double discountAmount;
  final double finalPayableAmount;

  const CouponValidationResultModel({
    required this.valid,
    required this.couponId,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minBookingAmount,
    required this.discountAmount,
    required this.finalPayableAmount,
  });

  factory CouponValidationResultModel.fromJson(Map<String, dynamic> json) {
    return CouponValidationResultModel(
      valid: json['valid'] as bool? ?? false,
      couponId: json['couponId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      discountType: json['discountType'] as String? ?? 'PERCENTAGE',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
      minBookingAmount: (json['minBookingAmount'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      finalPayableAmount: (json['finalPayableAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'valid': valid,
      'couponId': couponId,
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minBookingAmount': minBookingAmount,
      'discountAmount': discountAmount,
      'finalPayableAmount': finalPayableAmount,
    };
  }
}
