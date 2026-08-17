enum LoyaltyTierCode {
  bronze,
  silver,
  gold,
  platinum;

  static LoyaltyTierCode fromString(String? val) {
    if (val == null) return LoyaltyTierCode.bronze;
    switch (val.toUpperCase()) {
      case 'SILVER':
        return LoyaltyTierCode.silver;
      case 'GOLD':
        return LoyaltyTierCode.gold;
      case 'PLATINUM':
        return LoyaltyTierCode.platinum;
      case 'BRONZE':
      default:
        return LoyaltyTierCode.bronze;
    }
  }

  String toDbString() {
    return name.toUpperCase();
  }

  String get displayName {
    switch (this) {
      case LoyaltyTierCode.bronze:
        return 'Bronze';
      case LoyaltyTierCode.silver:
        return 'Silver';
      case LoyaltyTierCode.gold:
        return 'Gold';
      case LoyaltyTierCode.platinum:
        return 'Platinum';
    }
  }
}

enum LoyaltyTransactionType {
  tripCompletionEarned,
  promotionBonus,
  redemptionToWallet,
  tierUpgradeBonus,
  adminAdjustment,
  cancellationReversal,
  pointsExpiry;

  static LoyaltyTransactionType fromString(String? val) {
    if (val == null) return LoyaltyTransactionType.tripCompletionEarned;
    switch (val.toUpperCase()) {
      case 'PROMOTION_BONUS':
        return LoyaltyTransactionType.promotionBonus;
      case 'REDEMPTION_TO_WALLET':
        return LoyaltyTransactionType.redemptionToWallet;
      case 'TIER_UPGRADE_BONUS':
        return LoyaltyTransactionType.tierUpgradeBonus;
      case 'ADMIN_ADJUSTMENT':
        return LoyaltyTransactionType.adminAdjustment;
      case 'CANCELLATION_REVERSAL':
        return LoyaltyTransactionType.cancellationReversal;
      case 'POINTS_EXPIRY':
        return LoyaltyTransactionType.pointsExpiry;
      case 'TRIP_COMPLETION_EARNED':
      default:
        return LoyaltyTransactionType.tripCompletionEarned;
    }
  }

  String get displayName {
    switch (this) {
      case LoyaltyTransactionType.tripCompletionEarned:
        return 'Trip Completed';
      case LoyaltyTransactionType.promotionBonus:
        return 'Promotion Bonus';
      case LoyaltyTransactionType.redemptionToWallet:
        return 'Wallet Redemption';
      case LoyaltyTransactionType.tierUpgradeBonus:
        return 'Tier Upgrade';
      case LoyaltyTransactionType.adminAdjustment:
        return 'Support Adjustment';
      case LoyaltyTransactionType.cancellationReversal:
        return 'Cancellation Reversal';
      case LoyaltyTransactionType.pointsExpiry:
        return 'Points Expired';
    }
  }

  bool get isCredit {
    switch (this) {
      case LoyaltyTransactionType.tripCompletionEarned:
      case LoyaltyTransactionType.promotionBonus:
      case LoyaltyTransactionType.tierUpgradeBonus:
        return true;
      case LoyaltyTransactionType.redemptionToWallet:
      case LoyaltyTransactionType.cancellationReversal:
      case LoyaltyTransactionType.pointsExpiry:
        return false;
      case LoyaltyTransactionType.adminAdjustment:
        return true; // Dynamic based on points sign
    }
  }
}

class LoyaltyTierModel {
  final String id;
  final LoyaltyTierCode code;
  final String name;
  final int minPointsRequired;
  final double pointsMultiplier;
  final double cashbackPercent;
  final bool prioritySupport;
  final int freeCancellationCount;

  const LoyaltyTierModel({
    required this.id,
    required this.code,
    required this.name,
    required this.minPointsRequired,
    required this.pointsMultiplier,
    this.cashbackPercent = 1.0,
    this.prioritySupport = false,
    this.freeCancellationCount = 0,
  });

  factory LoyaltyTierModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTierModel(
      id: json['id'] as String? ?? '',
      code: LoyaltyTierCode.fromString(json['code'] as String?),
      name: json['name'] as String? ?? 'Bronze',
      minPointsRequired: (json['minPointsRequired'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      cashbackPercent: (json['cashbackPercent'] as num?)?.toDouble() ?? 1.0,
      prioritySupport: json['prioritySupport'] as bool? ?? false,
      freeCancellationCount: (json['freeCancellationCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code.toDbString(),
      'name': name,
      'minPointsRequired': minPointsRequired,
      'pointsMultiplier': pointsMultiplier,
      'cashbackPercent': cashbackPercent,
      'prioritySupport': prioritySupport,
      'freeCancellationCount': freeCancellationCount,
    };
  }
}

class LoyaltyNextTierModel {
  final LoyaltyTierCode code;
  final String name;
  final int minPointsRequired;
  final double pointsMultiplier;
  final int pointsToNextTier;
  final double progressPercent;

  const LoyaltyNextTierModel({
    required this.code,
    required this.name,
    required this.minPointsRequired,
    required this.pointsMultiplier,
    required this.pointsToNextTier,
    required this.progressPercent,
  });

  factory LoyaltyNextTierModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyNextTierModel(
      code: LoyaltyTierCode.fromString(json['code'] as String?),
      name: json['name'] as String? ?? '',
      minPointsRequired: (json['minPointsRequired'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      pointsToNextTier: (json['pointsToNextTier'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code.toDbString(),
      'name': name,
      'minPointsRequired': minPointsRequired,
      'pointsMultiplier': pointsMultiplier,
      'pointsToNextTier': pointsToNextTier,
      'progressPercent': progressPercent,
    };
  }
}

class LoyaltyAccountModel {
  final String id;
  final String userId;
  final LoyaltyTierCode tierCode;
  final String tierName;
  final double pointsMultiplier;
  final int pointsBalance;
  final int lifetimePoints;
  final int walletEquivalent;
  final LoyaltyTierModel currentTier;
  final LoyaltyNextTierModel? nextTier;
  final DateTime updatedAt;

  const LoyaltyAccountModel({
    required this.id,
    required this.userId,
    required this.tierCode,
    required this.tierName,
    required this.pointsMultiplier,
    required this.pointsBalance,
    required this.lifetimePoints,
    required this.walletEquivalent,
    required this.currentTier,
    this.nextTier,
    required this.updatedAt,
  });

  factory LoyaltyAccountModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyAccountModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tierCode: LoyaltyTierCode.fromString(json['tierCode'] as String?),
      tierName: json['tierName'] as String? ?? 'Bronze',
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      pointsBalance: (json['pointsBalance'] as num?)?.toInt() ?? 0,
      lifetimePoints: (json['lifetimePoints'] as num?)?.toInt() ?? 0,
      walletEquivalent: (json['walletEquivalent'] as num?)?.toInt() ?? 0,
      currentTier: json['currentTier'] != null
          ? LoyaltyTierModel.fromJson(json['currentTier'] as Map<String, dynamic>)
          : LoyaltyTierModel(
              id: '',
              code: LoyaltyTierCode.fromString(json['tierCode'] as String?),
              name: json['tierName'] as String? ?? 'Bronze',
              minPointsRequired: 0,
              pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
            ),
      nextTier: json['nextTier'] != null
          ? LoyaltyNextTierModel.fromJson(json['nextTier'] as Map<String, dynamic>)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tierCode': tierCode.toDbString(),
      'tierName': tierName,
      'pointsMultiplier': pointsMultiplier,
      'pointsBalance': pointsBalance,
      'lifetimePoints': lifetimePoints,
      'walletEquivalent': walletEquivalent,
      'currentTier': currentTier.toJson(),
      'nextTier': nextTier?.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class LoyaltyTransactionModel {
  final String id;
  final LoyaltyTransactionType type;
  final int points;
  final int balanceBefore;
  final int balanceAfter;
  final String referenceType;
  final String? referenceId;
  final String idempotencyKey;
  final String description;
  final DateTime createdAt;

  const LoyaltyTransactionModel({
    required this.id,
    required this.type,
    required this.points,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.referenceType,
    this.referenceId,
    required this.idempotencyKey,
    required this.description,
    required this.createdAt,
  });

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      id: json['id'] as String? ?? '',
      type: LoyaltyTransactionType.fromString(json['type'] as String?),
      points: (json['points'] as num?)?.toInt() ?? 0,
      balanceBefore: (json['balanceBefore'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      referenceType: json['referenceType'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'points': points,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'idempotencyKey': idempotencyKey,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class LoyaltyTierBreakdownItem {
  final LoyaltyTierCode code;
  final String name;
  final int minPoints;
  final double multiplier;
  final int accountCount;

  const LoyaltyTierBreakdownItem({
    required this.code,
    required this.name,
    required this.minPoints,
    required this.multiplier,
    required this.accountCount,
  });

  factory LoyaltyTierBreakdownItem.fromJson(Map<String, dynamic> json) {
    return LoyaltyTierBreakdownItem(
      code: LoyaltyTierCode.fromString(json['code'] as String?),
      name: json['name'] as String? ?? '',
      minPoints: (json['minPoints'] as num?)?.toInt() ?? 0,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      accountCount: (json['accountCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltySummaryModel {
  final int totalAccounts;
  final int totalLifetimePoints;
  final int totalAvailablePoints;
  final int totalPointsRedeemed;
  final int outstandingLiabilityInr;
  final List<LoyaltyTierBreakdownItem> tierBreakdown;

  const LoyaltySummaryModel({
    required this.totalAccounts,
    required this.totalLifetimePoints,
    required this.totalAvailablePoints,
    required this.totalPointsRedeemed,
    required this.outstandingLiabilityInr,
    required this.tierBreakdown,
  });

  factory LoyaltySummaryModel.fromJson(Map<String, dynamic> json) {
    final breakdownList = json['tierBreakdown'] as List<dynamic>? ?? [];
    return LoyaltySummaryModel(
      totalAccounts: (json['totalAccounts'] as num?)?.toInt() ?? 0,
      totalLifetimePoints: (json['totalLifetimePoints'] as num?)?.toInt() ?? 0,
      totalAvailablePoints: (json['totalAvailablePoints'] as num?)?.toInt() ?? 0,
      totalPointsRedeemed: (json['totalPointsRedeemed'] as num?)?.toInt() ?? 0,
      outstandingLiabilityInr: (json['outstandingLiabilityInr'] as num?)?.toInt() ?? 0,
      tierBreakdown: breakdownList
          .map((e) => LoyaltyTierBreakdownItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
