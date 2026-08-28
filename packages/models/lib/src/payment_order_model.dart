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
  final bool isFullWallet;
  final double walletApplied;
  final double promoApplied;
  final double realApplied;
  final double gatewayAmount;

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
    this.isFullWallet = false,
    this.walletApplied = 0.0,
    this.promoApplied = 0.0,
    this.realApplied = 0.0,
    this.gatewayAmount = 0.0,
  });

  bool get isUsableCreatedOrder =>
      status.toUpperCase() == 'CREATED' &&
      razorpayOrderId != null &&
      razorpayOrderId!.isNotEmpty &&
      (isFullWallet ||
          (keyId != null && keyId!.isNotEmpty && amountInPaise > 0));

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

    final breakdown = json['breakdown'] is Map ? json['breakdown'] as Map : null;
    final rzOrderId =
        (json['razorpayOrderId'] ?? json['orderId']) as String?;
    final explicitFullWallet = json['isFullWallet'] == true ||
        (rzOrderId != null && rzOrderId.startsWith('order_wallet_full_'));

    return PaymentOrderModel(
      id: json['id'] as String?,
      bookingId: (json['bookingId'] as String?) ?? '',
      razorpayOrderId: rzOrderId,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      amount: parsedAmount,
      amountInPaise: parsedAmountInPaise,
      currency: (json['currency'] as String?) ?? 'INR',
      keyId: (json['keyId'] as String?) ?? 'rzp_test_TPzexZ2MVR3a1e',
      status: (json['status'] as String?) ?? 'CREATED',
      isFullWallet: explicitFullWallet,
      walletApplied: breakdown != null
          ? ((breakdown['walletApplied'] as num?)?.toDouble() ?? 0.0)
          : (json['walletApplied'] as num?)?.toDouble() ?? 0.0,
      promoApplied: breakdown != null
          ? ((breakdown['promoApplied'] as num?)?.toDouble() ?? 0.0)
          : (json['promoApplied'] as num?)?.toDouble() ?? 0.0,
      realApplied: breakdown != null
          ? ((breakdown['realApplied'] as num?)?.toDouble() ?? 0.0)
          : (json['realApplied'] as num?)?.toDouble() ?? 0.0,
      gatewayAmount: breakdown != null
          ? ((breakdown['gatewayAmount'] as num?)?.toDouble() ?? parsedAmount)
          : (json['gatewayAmount'] as num?)?.toDouble() ?? parsedAmount,
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
      'isFullWallet': isFullWallet,
      'walletApplied': walletApplied,
      'promoApplied': promoApplied,
      'realApplied': realApplied,
      'gatewayAmount': gatewayAmount,
    };
  }
}
