enum ReferralStatus {
  INVITED,
  REGISTERED,
  QUALIFIED,
  REWARDED,
  CANCELLED,
  EXPIRED,
  FRAUD_BLOCKED;

  static ReferralStatus fromString(String? value) {
    if (value == null) return ReferralStatus.REGISTERED;
    return ReferralStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => ReferralStatus.REGISTERED,
    );
  }
}

class ReferralCampaignModel {
  final String id;
  final String name;
  final String code;
  final double referrerRewardAmount;
  final double refereeRewardAmount;
  final double minBookingAmount;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int maxReferralsPerUser;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? stats;

  const ReferralCampaignModel({
    required this.id,
    required this.name,
    required this.code,
    required this.referrerRewardAmount,
    required this.refereeRewardAmount,
    required this.minBookingAmount,
    this.city,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.maxReferralsPerUser = 20,
    required this.createdAt,
    required this.updatedAt,
    this.stats,
  });

  factory ReferralCampaignModel.fromJson(Map<String, dynamic> json) {
    return ReferralCampaignModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      referrerRewardAmount: (json['referrerRewardAmount'] as num?)?.toDouble() ?? 250.0,
      refereeRewardAmount: (json['refereeRewardAmount'] as num?)?.toDouble() ?? 250.0,
      minBookingAmount: (json['minBookingAmount'] as num?)?.toDouble() ?? 1000.0,
      city: json['city'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      isActive: json['isActive'] as bool? ?? true,
      maxReferralsPerUser: (json['maxReferralsPerUser'] as num?)?.toInt() ?? 20,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      stats: json['stats'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'referrerRewardAmount': referrerRewardAmount,
      'refereeRewardAmount': refereeRewardAmount,
      'minBookingAmount': minBookingAmount,
      'city': city,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'maxReferralsPerUser': maxReferralsPerUser,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'stats': stats,
    };
  }
}

class ReferralAttributionModel {
  final String id;
  final String refereeName;
  final String refereePhone;
  final ReferralStatus status;
  final double rewardAmount;
  final DateTime createdAt;
  final DateTime? qualifiedAt;
  final DateTime? rewardedAt;

  const ReferralAttributionModel({
    required this.id,
    required this.refereeName,
    required this.refereePhone,
    required this.status,
    required this.rewardAmount,
    required this.createdAt,
    this.qualifiedAt,
    this.rewardedAt,
  });

  factory ReferralAttributionModel.fromJson(Map<String, dynamic> json) {
    return ReferralAttributionModel(
      id: json['id'] as String? ?? '',
      refereeName: json['refereeName'] as String? ?? 'DriveGo User',
      refereePhone: json['refereePhone'] as String? ?? '',
      status: ReferralStatus.fromString(json['status'] as String?),
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 250.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      qualifiedAt: json['qualifiedAt'] != null
          ? DateTime.tryParse(json['qualifiedAt'].toString())
          : null,
      rewardedAt: json['rewardedAt'] != null
          ? DateTime.tryParse(json['rewardedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'refereeName': refereeName,
      'refereePhone': refereePhone,
      'status': status.name,
      'rewardAmount': rewardAmount,
      'createdAt': createdAt.toIso8601String(),
      'qualifiedAt': qualifiedAt?.toIso8601String(),
      'rewardedAt': rewardedAt?.toIso8601String(),
    };
  }
}

class ReferralSummaryModel {
  final int totalInvited;
  final int totalRegistered;
  final int totalCompleted;
  final int totalRewardedCount;
  final double totalEarnings;

  const ReferralSummaryModel({
    required this.totalInvited,
    required this.totalRegistered,
    required this.totalCompleted,
    required this.totalRewardedCount,
    required this.totalEarnings,
  });

  factory ReferralSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReferralSummaryModel(
      totalInvited: (json['totalInvited'] as num?)?.toInt() ?? 0,
      totalRegistered: (json['totalRegistered'] as num?)?.toInt() ?? 0,
      totalCompleted: (json['totalCompleted'] as num?)?.toInt() ?? 0,
      totalRewardedCount: (json['totalRewardedCount'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
