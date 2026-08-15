class PaymentOrderModel {
  final String? id;
  final String bookingId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final double amount;
  final int amountInPaise;
  final String currency;
  final String? keyId;
  final String status; // CREATED, PAID, FAILED, REFUNDED

  const PaymentOrderModel({
    this.id,
    required this.bookingId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    required this.amount,
    required this.amountInPaise,
    required this.currency,
    this.keyId,
    required this.status,
  });

  bool get isUsableCreatedOrder =>
      status.toUpperCase() == 'CREATED' &&
      razorpayOrderId != null &&
      razorpayOrderId!.isNotEmpty &&
      keyId != null &&
      keyId!.isNotEmpty &&
      amountInPaise > 0;

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final rawAmountInPaise = json['amountInPaise'];

    final double parsedAmount;
    final int parsedAmountInPaise;

    if (rawAmountInPaise != null) {
      parsedAmountInPaise = rawAmountInPaise is int
          ? rawAmountInPaise
          : (rawAmountInPaise is num
              ? rawAmountInPaise.round()
              : int.tryParse(rawAmountInPaise.toString()) ?? 0);
      parsedAmount = rawAmount != null
          ? (rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount.toString()) ??
                  (parsedAmountInPaise / 100.0))
          : (parsedAmountInPaise / 100.0);
    } else {
      // In create-order response, 'amount' is in paise integer (e.g. 536640)
      if (rawAmount is int ||
          (rawAmount is num && rawAmount == rawAmount.round())) {
        parsedAmountInPaise = (rawAmount as num).toInt();
        parsedAmount = parsedAmountInPaise / 100.0;
      } else {
        parsedAmount = rawAmount != null
            ? (rawAmount is num
                ? rawAmount.toDouble()
                : double.tryParse(rawAmount.toString()) ?? 0.0)
            : 0.0;
        parsedAmountInPaise = (parsedAmount * 100).round();
      }
    }

    return PaymentOrderModel(
      id: json['id'] as String?,
      bookingId: (json['bookingId'] as String?) ?? '',
      razorpayOrderId:
          (json['razorpayOrderId'] ?? json['orderId']) as String?,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      amount: parsedAmount,
      amountInPaise: parsedAmountInPaise,
      currency: (json['currency'] as String?) ?? 'INR',
      keyId: (json['keyId'] as String?) ?? 'rzp_test_TPzexZ2MVR3a1e',
      status: (json['status'] as String?) ?? 'CREATED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'amount': amount,
      'amountInPaise': amountInPaise,
      'currency': currency,
      'keyId': keyId,
      'status': status,
    };
  }
}
