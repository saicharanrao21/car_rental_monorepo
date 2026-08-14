enum SecurityDepositStatus {
  REQUIRED,
  HELD,
  REFUNDED,
  PARTIALLY_REFUNDED,
  FORFEITED,
  CANCELLED;

  static SecurityDepositStatus fromString(String? value) {
    if (value == null) return SecurityDepositStatus.REQUIRED;
    return SecurityDepositStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => SecurityDepositStatus.REQUIRED,
    );
  }
}

class SecurityDepositModel {
  final String id;
  final String bookingId;
  final double amount;
  final double refundedAmount;
  final double deductedAmount;
  final String? razorpayPaymentId;
  final String? razorpayRefundId;
  final SecurityDepositStatus status;
  final DateTime? heldAt;
  final DateTime? releasedAt;
  final DateTime createdAt;

  const SecurityDepositModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.refundedAmount = 0.0,
    this.deductedAmount = 0.0,
    this.razorpayPaymentId,
    this.razorpayRefundId,
    this.status = SecurityDepositStatus.REQUIRED,
    this.heldAt,
    this.releasedAt,
    required this.createdAt,
  });

  factory SecurityDepositModel.fromJson(Map<String, dynamic> json) {
    return SecurityDepositModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0.0,
      deductedAmount: (json['deductedAmount'] as num?)?.toDouble() ?? 0.0,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      razorpayRefundId: json['razorpayRefundId'] as String?,
      status: SecurityDepositStatus.fromString(json['status'] as String?),
      heldAt: json['heldAt'] != null
          ? DateTime.tryParse(json['heldAt'] as String)
          : null,
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'amount': amount,
      'refundedAmount': refundedAmount,
      'deductedAmount': deductedAmount,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayRefundId': razorpayRefundId,
      'status': status.name,
      'heldAt': heldAt?.toIso8601String(),
      'releasedAt': releasedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
