enum WalletStatus {
  ACTIVE,
  FROZEN,
  CLOSED;

  static WalletStatus fromString(String? value) {
    if (value == null) return WalletStatus.ACTIVE;
    return WalletStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => WalletStatus.ACTIVE,
    );
  }
}

enum WalletBucketType {
  REAL_MONEY,
  PROMOTIONAL,
  REFUND_CREDIT;

  static WalletBucketType fromString(String? value) {
    if (value == null) return WalletBucketType.REAL_MONEY;
    return WalletBucketType.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => WalletBucketType.REAL_MONEY,
    );
  }
}

enum LedgerEntryType {
  CUSTOMER_DEPOSIT,
  CHECKOUT_DEBIT,
  BOOKING_REFUND,
  REFERRAL_REWARD,
  LOYALTY_CONVERSION,
  ADMIN_ADJUSTMENT,
  CANCELLATION_CREDIT,
  EXPIRATION;

  static LedgerEntryType fromString(String? value) {
    if (value == null) return LedgerEntryType.CUSTOMER_DEPOSIT;
    return LedgerEntryType.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => LedgerEntryType.CUSTOMER_DEPOSIT,
    );
  }
}

enum LedgerDirection {
  CREDIT,
  DEBIT;

  static LedgerDirection fromString(String? value) {
    if (value == null) return LedgerDirection.CREDIT;
    return LedgerDirection.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => LedgerDirection.CREDIT,
    );
  }
}

class WalletModel {
  final String id;
  final String userId;
  final String currency;
  final double availableBalance;
  final double lockedBalance;
  final double realBalance;
  final double promoBalance;
  final WalletStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    this.currency = 'INR',
    required this.availableBalance,
    this.lockedBalance = 0.0,
    this.realBalance = 0.0,
    this.promoBalance = 0.0,
    this.status = WalletStatus.ACTIVE,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      currency: json['currency'] as String? ?? 'INR',
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['lockedBalance'] as num?)?.toDouble() ?? 0.0,
      realBalance: (json['realBalance'] as num?)?.toDouble() ?? 0.0,
      promoBalance: (json['promoBalance'] as num?)?.toDouble() ?? 0.0,
      status: WalletStatus.fromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'currency': currency,
      'availableBalance': availableBalance,
      'lockedBalance': lockedBalance,
      'realBalance': realBalance,
      'promoBalance': promoBalance,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class WalletLedgerEntryModel {
  final String id;
  final String walletId;
  final LedgerEntryType type;
  final LedgerDirection direction;
  final WalletBucketType bucket;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String referenceType;
  final String? referenceId;
  final String idempotencyKey;
  final String description;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const WalletLedgerEntryModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.direction,
    required this.bucket,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.referenceType,
    this.referenceId,
    required this.idempotencyKey,
    required this.description,
    this.expiresAt,
    this.metadata,
    required this.createdAt,
  });

  factory WalletLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntryModel(
      id: json['id'] as String? ?? '',
      walletId: json['walletId'] as String? ?? '',
      type: LedgerEntryType.fromString(json['type'] as String?),
      direction: LedgerDirection.fromString(json['direction'] as String?),
      bucket: WalletBucketType.fromString(json['bucket'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['referenceType'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      description: json['description'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'type': type.name,
      'direction': direction.name,
      'bucket': bucket.name,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'idempotencyKey': idempotencyKey,
      'description': description,
      'expiresAt': expiresAt?.toIso8601String(),
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
