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

abstract class MyBookingsRepository {
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter});
  Future<CancellationPreviewModel> getCancellationPreview(String bookingId);
  Future<void> cancelBooking(String bookingId, String reason);
  Future<void> submitReview(ReviewModel review);
  Future<SecurityDepositModel?> getSecurityDeposit(String bookingId);
}
