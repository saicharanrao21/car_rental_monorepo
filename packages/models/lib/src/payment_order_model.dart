class PaymentRefundModel {
  final String? id;
  final String? paymentId;
  final String bookingId;
  final String? gatewayRefundId;
  final String idempotencyKey;
  final double requestedAmount;
  final double? processedAmount;
  final String currency;
  final String? reason;
  final String status;
  final DateTime? createdAt;

  const PaymentRefundModel({
    this.id,
    this.paymentId,
    required this.bookingId,
    this.gatewayRefundId,
    required this.idempotencyKey,
    required this.requestedAmount,
    this.processedAmount,
    this.currency = 'INR',
    this.reason,
    this.status = 'REQUESTED',
    this.createdAt,
  });

  factory PaymentRefundModel.fromJson(Map<String, dynamic> json) {
    return PaymentRefundModel(
      id: json['id'] as String?,
      paymentId: json['paymentId'] as String?,
      bookingId: (json['bookingId'] as String?) ?? '',
      gatewayRefundId: json['gatewayRefundId'] as String?,
      idempotencyKey: (json['idempotencyKey'] as String?) ?? '',
      requestedAmount: (json['requestedAmount'] as num?)?.toDouble() ?? 0.0,
      processedAmount: (json['processedAmount'] as num?)?.toDouble(),
      currency: (json['currency'] as String?) ?? 'INR',
      reason: json['reason'] as String?,
      status: (json['status'] as String?) ?? 'REQUESTED',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentId': paymentId,
      'bookingId': bookingId,
      'gatewayRefundId': gatewayRefundId,
      'idempotencyKey': idempotencyKey,
      'requestedAmount': requestedAmount,
      'processedAmount': processedAmount,
      'currency': currency,
      'reason': reason,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class PaymentOrderModel {
  final String? id;
  final String bookingId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final double amount;
  final int amountInPaise;
  final String currency;
  final String? keyId;
  final String status; // CREATED, PENDING, AUTHORIZED, CAPTURED, PAID, FAILED, CANCELLED, PARTIALLY_REFUNDED, REFUNDED
  final bool isFullWallet;
  final double walletApplied;
  final double promoApplied;
  final double realApplied;
  final double gatewayAmount;
  final String refundStatus; // NONE, REQUESTED, PENDING, PROCESSED, FAILED
  final double refundAmount;
  final String gatewayProvider;
  final DateTime? capturedAt;
  final String? failureReason;
  final List<PaymentRefundModel> refunds;

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
    this.refundStatus = 'NONE',
    this.refundAmount = 0.0,
    this.gatewayProvider = 'RAZORPAY',
    this.capturedAt,
    this.failureReason,
    this.refunds = const [],
  });

  bool get isUsableCreatedOrder =>
      status.toUpperCase() == 'CREATED' &&
      razorpayOrderId != null &&
      razorpayOrderId!.isNotEmpty &&
      (isFullWallet ||
          (keyId != null && keyId!.isNotEmpty && amountInPaise > 0));

  bool get isPaid =>
      status.toUpperCase() == 'PAID' || status.toUpperCase() == 'CAPTURED';

  bool get isFailed => status.toUpperCase() == 'FAILED';

  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  bool get isAuthorized => status.toUpperCase() == 'AUTHORIZED';

  bool get isRefunded => status.toUpperCase() == 'REFUNDED';

  bool get isPartiallyRefunded =>
      status.toUpperCase() == 'PARTIALLY_REFUNDED' ||
      (refundAmount > 0 && refundAmount < amount);

  bool get isRefundPending =>
      refundStatus.toUpperCase() == 'PENDING' ||
      refundStatus.toUpperCase() == 'REQUESTED';

  double get refundableAmount => (amount - refundAmount).clamp(0.0, double.infinity);

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

    final rawRefunds = json['refunds'];
    final parsedRefunds = rawRefunds is List
        ? rawRefunds
            .whereType<Map<String, dynamic>>()
            .map((r) => PaymentRefundModel.fromJson(r))
            .toList()
        : <PaymentRefundModel>[];

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
      refundStatus: (json['refundStatus'] as String?) ?? 'NONE',
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0.0,
      gatewayProvider: (json['gatewayProvider'] as String?) ?? 'RAZORPAY',
      capturedAt: json['capturedAt'] != null
          ? DateTime.tryParse(json['capturedAt'].toString())
          : null,
      failureReason: json['failureReason'] as String?,
      refunds: parsedRefunds,
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
      'refundStatus': refundStatus,
      'refundAmount': refundAmount,
      'gatewayProvider': gatewayProvider,
      'capturedAt': capturedAt?.toIso8601String(),
      'failureReason': failureReason,
      'refunds': refunds.map((r) => r.toJson()).toList(),
    };
  }
}

class PaymentAuditLogModel {
  final String? id;
  final String paymentId;
  final String bookingId;
  final String tenantId;
  final String eventType;
  final String? fromStatus;
  final String toStatus;
  final double? amount;
  final String? gatewayReference;
  final String? actorId;
  final String? actorRole;
  final String source;
  final String? payloadHash;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  const PaymentAuditLogModel({
    this.id,
    required this.paymentId,
    required this.bookingId,
    this.tenantId = 'default',
    required this.eventType,
    this.fromStatus,
    required this.toStatus,
    this.amount,
    this.gatewayReference,
    this.actorId,
    this.actorRole,
    required this.source,
    this.payloadHash,
    this.metadata,
    this.createdAt,
  });

  factory PaymentAuditLogModel.fromJson(Map<String, dynamic> json) {
    return PaymentAuditLogModel(
      id: json['id'] as String?,
      paymentId: (json['paymentId'] as String?) ?? '',
      bookingId: (json['bookingId'] as String?) ?? '',
      tenantId: (json['tenantId'] as String?) ?? 'default',
      eventType: (json['eventType'] as String?) ?? '',
      fromStatus: json['fromStatus'] as String?,
      toStatus: (json['toStatus'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      gatewayReference: json['gatewayReference'] as String?,
      actorId: json['actorId'] as String?,
      actorRole: json['actorRole'] as String?,
      source: (json['source'] as String?) ?? 'SYSTEM',
      payloadHash: json['payloadHash'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentId': paymentId,
      'bookingId': bookingId,
      'tenantId': tenantId,
      'eventType': eventType,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
      'amount': amount,
      'gatewayReference': gatewayReference,
      'actorId': actorId,
      'actorRole': actorRole,
      'source': source,
      'payloadHash': payloadHash,
      'metadata': metadata,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class VendorPaymentSummaryModel {
  final String bookingId;
  final String paymentStatus;
  final bool isPaid;
  final String currency;
  final double tripFare;
  final double netVendorEarnings;
  final double platformCommission;
  final double securityDepositHeld;
  final String refundStatus;
  final double refundAmount;
  final String settlementStatus;
  final DateTime? updatedAt;

  const VendorPaymentSummaryModel({
    required this.bookingId,
    required this.paymentStatus,
    required this.isPaid,
    this.currency = 'INR',
    required this.tripFare,
    required this.netVendorEarnings,
    required this.platformCommission,
    required this.securityDepositHeld,
    this.refundStatus = 'NONE',
    this.refundAmount = 0.0,
    required this.settlementStatus,
    this.updatedAt,
  });

  factory VendorPaymentSummaryModel.fromJson(Map<String, dynamic> json) {
    return VendorPaymentSummaryModel(
      bookingId: (json['bookingId'] as String?) ?? '',
      paymentStatus: (json['paymentStatus'] as String?) ?? 'UNPAID',
      isPaid: json['isPaid'] == true,
      currency: (json['currency'] as String?) ?? 'INR',
      tripFare: (json['tripFare'] as num?)?.toDouble() ?? 0.0,
      netVendorEarnings: (json['netVendorEarnings'] as num?)?.toDouble() ?? 0.0,
      platformCommission: (json['platformCommission'] as num?)?.toDouble() ?? 0.0,
      securityDepositHeld: (json['securityDepositHeld'] as num?)?.toDouble() ?? 0.0,
      refundStatus: (json['refundStatus'] as String?) ?? 'NONE',
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0.0,
      settlementStatus: (json['settlementStatus'] as String?) ?? 'PENDING_PAYMENT',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'paymentStatus': paymentStatus,
      'isPaid': isPaid,
      'currency': currency,
      'tripFare': tripFare,
      'netVendorEarnings': netVendorEarnings,
      'platformCommission': platformCommission,
      'securityDepositHeld': securityDepositHeld,
      'refundStatus': refundStatus,
      'refundAmount': refundAmount,
      'settlementStatus': settlementStatus,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
