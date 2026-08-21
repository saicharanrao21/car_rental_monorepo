import 'package:models/models.dart';

class CancellationPreviewModel {
  final String bookingId;
  final String tier;
  final String tierDescription;
  final DateTime startDate;
  final double hoursRemaining;
  final double amountPaid;
  final int cancellationFeePercent;
  final double cancellationFee;
  final int refundAmountPercent;
  final double refundAmount;
  final String currency;
  final bool isEligibleForRefund;

  const CancellationPreviewModel({
    required this.bookingId,
    required this.tier,
    required this.tierDescription,
    required this.startDate,
    required this.hoursRemaining,
    required this.amountPaid,
    required this.cancellationFeePercent,
    required this.cancellationFee,
    required this.refundAmountPercent,
    required this.refundAmount,
    required this.currency,
    required this.isEligibleForRefund,
  });

  factory CancellationPreviewModel.fromJson(Map<String, dynamic> json) {
    return CancellationPreviewModel(
      bookingId: json['bookingId']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      tierDescription: json['tierDescription']?.toString() ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      hoursRemaining: (json['hoursRemaining'] as num?)?.toDouble() ?? 0.0,
      amountPaid: double.tryParse(json['amountPaid']?.toString() ?? '') ?? 0.0,
      cancellationFeePercent: (json['cancellationFeePercent'] as num?)?.toInt() ?? 0,
      cancellationFee: double.tryParse(json['cancellationFee']?.toString() ?? '') ?? 0.0,
      refundAmountPercent: (json['refundAmountPercent'] as num?)?.toInt() ?? 0,
      refundAmount: double.tryParse(json['refundAmount']?.toString() ?? '') ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      isEligibleForRefund: json['isEligibleForRefund'] == true,
    );
  }
}

class TripExtensionQuoteModel {
  final String bookingId;
  final DateTime currentEndDate;
  final DateTime requestedEndDate;
  final int additionalHours;
  final int additionalDays;
  final double additionalBaseFare;
  final double gstAmount;
  final double totalAdditionalFare;
  final bool isAvailable;
  final String? conflictMessage;

  const TripExtensionQuoteModel({
    required this.bookingId,
    required this.currentEndDate,
    required this.requestedEndDate,
    required this.additionalHours,
    required this.additionalDays,
    required this.additionalBaseFare,
    required this.gstAmount,
    required this.totalAdditionalFare,
    required this.isAvailable,
    this.conflictMessage,
  });

  factory TripExtensionQuoteModel.fromJson(Map<String, dynamic> json) {
    return TripExtensionQuoteModel(
      bookingId: json['bookingId']?.toString() ?? '',
      currentEndDate: DateTime.tryParse(json['currentEndDate']?.toString() ?? '') ?? DateTime.now(),
      requestedEndDate: DateTime.tryParse(json['requestedEndDate']?.toString() ?? '') ?? DateTime.now(),
      additionalHours: (json['additionalHours'] as num?)?.toInt() ?? 0,
      additionalDays: (json['additionalDays'] as num?)?.toInt() ?? 1,
      additionalBaseFare: double.tryParse(json['additionalBaseFare']?.toString() ?? '') ?? 0.0,
      gstAmount: double.tryParse(json['gstAmount']?.toString() ?? '') ?? 0.0,
      totalAdditionalFare: double.tryParse(json['totalAdditionalFare']?.toString() ?? '') ?? 0.0,
      isAvailable: json['isAvailable'] == true || json['available'] == true,
      conflictMessage: json['conflictMessage']?.toString(),
    );
  }
}

class CustomerBookingItem {
  final BookingModel booking;
  final CarModel? car;
  final VendorModel? vendor;
  final String? mileagePackageName;
  final int? includedKmPerDay;
  final int? includedKmTotal;
  final double? extraKmRate;
  final String? protectionCode;
  final double? protectionFee;
  final double? protectionDeductible;
  final String? deliveryType;
  final String? deliveryAddress;
  final double? deliveryFee;
  final String? pickupAddress;
  final double? pickupFee;
  final String? cancellationReason;
  final double? cancellationFee;
  final double? refundAmount;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? paymentStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpayRefundId;

  const CustomerBookingItem({
    required this.booking,
    this.car,
    this.vendor,
    this.mileagePackageName,
    this.includedKmPerDay,
    this.includedKmTotal,
    this.extraKmRate,
    this.protectionCode,
    this.protectionFee,
    this.protectionDeductible,
    this.deliveryType,
    this.deliveryAddress,
    this.deliveryFee,
    this.pickupAddress,
    this.pickupFee,
    this.cancellationReason,
    this.cancellationFee,
    this.refundAmount,
    this.cancelledAt,
    this.cancelledBy,
    this.paymentStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpayRefundId,
  });

  CustomerBookingItem copyWith({
    BookingModel? booking,
    CarModel? car,
    VendorModel? vendor,
    String? mileagePackageName,
    int? includedKmPerDay,
    int? includedKmTotal,
    double? extraKmRate,
    String? protectionCode,
    double? protectionFee,
    double? protectionDeductible,
    String? deliveryType,
    String? deliveryAddress,
    double? deliveryFee,
    String? pickupAddress,
    double? pickupFee,
    String? cancellationReason,
    double? cancellationFee,
    double? refundAmount,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? paymentStatus,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpayRefundId,
  }) {
    return CustomerBookingItem(
      booking: booking ?? this.booking,
      car: car ?? this.car,
      vendor: vendor ?? this.vendor,
      mileagePackageName: mileagePackageName ?? this.mileagePackageName,
      includedKmPerDay: includedKmPerDay ?? this.includedKmPerDay,
      includedKmTotal: includedKmTotal ?? this.includedKmTotal,
      extraKmRate: extraKmRate ?? this.extraKmRate,
      protectionCode: protectionCode ?? this.protectionCode,
      protectionFee: protectionFee ?? this.protectionFee,
      protectionDeductible: protectionDeductible ?? this.protectionDeductible,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupFee: pickupFee ?? this.pickupFee,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      refundAmount: refundAmount ?? this.refundAmount,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpayRefundId: razorpayRefundId ?? this.razorpayRefundId,
    );
  }
}

abstract class MyBookingsRepository {
  Future<List<CustomerBookingItem>> getEnrichedBookingsForUser(String userId, {String? statusFilter});
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter});
  Future<CustomerBookingItem?> getEnrichedBookingById(String bookingId);
  Future<CancellationPreviewModel> getCancellationPreview(String bookingId);
  Future<void> cancelBooking(String bookingId, String reason);
  Future<TripExtensionQuoteModel> getTripExtensionQuote(String bookingId, String requestedEndDate);
  Future<void> requestTripExtension(String bookingId, String requestedEndDate);
  Future<void> submitReview(ReviewModel review);
  Future<SecurityDepositModel?> getSecurityDeposit(String bookingId);
  Future<PaymentOrderModel?> getPaymentForBooking(String bookingId);
  Future<List<InspectionModel>> getInspections(String bookingId);
  Future<bool> sendHandoverOtp(String bookingId, String otpType);
}
