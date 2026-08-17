enum RiskLevel {
  low,
  medium,
  high,
  critical;

  static RiskLevel fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CRITICAL':
        return RiskLevel.critical;
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }

  String get displayName {
    switch (this) {
      case RiskLevel.critical:
        return 'CRITICAL';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.medium:
        return 'MEDIUM';
      case RiskLevel.low:
        return 'LOW';
    }
  }
}

enum RiskAction {
  allow,
  monitor,
  reviewRequired,
  block;

  static RiskAction fromString(String value) {
    switch (value.toUpperCase()) {
      case 'BLOCK':
        return RiskAction.block;
      case 'REVIEW_REQUIRED':
        return RiskAction.reviewRequired;
      case 'MONITOR':
        return RiskAction.monitor;
      case 'ALLOW':
      default:
        return RiskAction.allow;
    }
  }

  String get displayName {
    switch (this) {
      case RiskAction.block:
        return 'BLOCK';
      case RiskAction.reviewRequired:
        return 'REVIEW_REQUIRED';
      case RiskAction.monitor:
        return 'MONITOR';
      case RiskAction.allow:
        return 'ALLOW';
    }
  }
}

class RiskSignalModel {
  final String code;
  final String description;
  final int scoreDelta;

  const RiskSignalModel({
    required this.code,
    required this.description,
    required this.scoreDelta,
  });

  factory RiskSignalModel.fromJson(Map<String, dynamic> json) {
    return RiskSignalModel(
      code: json['code'] as String? ?? 'UNKNOWN_SIGNAL',
      description: json['description'] as String? ?? '',
      scoreDelta: (json['scoreDelta'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      'scoreDelta': scoreDelta,
    };
  }
}

class RiskAssessmentModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final int score;
  final RiskLevel riskLevel;
  final RiskAction action;
  final List<RiskSignalModel> signals;
  final String status; // PENDING_REVIEW, RESOLVED, DISMISSED, ESCALATED
  final String? adminNotes;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const RiskAssessmentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.score,
    required this.riskLevel,
    required this.action,
    required this.signals,
    required this.status,
    this.adminNotes,
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  factory RiskAssessmentModel.fromJson(Map<String, dynamic> json) {
    final rawSignals = json['signals'] as List<dynamic>? ?? [];
    return RiskAssessmentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown User',
      userPhone: json['userPhone'] as String? ?? 'N/A',
      score: (json['score'] as num?)?.toInt() ?? 0,
      riskLevel: RiskLevel.fromString(json['riskLevel'] as String? ?? 'LOW'),
      action: RiskAction.fromString(json['action'] as String? ?? 'ALLOW'),
      signals: rawSignals
          .map((s) => RiskSignalModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'PENDING_REVIEW',
      adminNotes: json['adminNotes'] as String?,
      resolvedBy: json['resolvedBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'score': score,
      'riskLevel': riskLevel.displayName,
      'action': action.displayName,
      'signals': signals.map((s) => s.toJson()).toList(),
      'status': status,
      'adminNotes': adminNotes,
      'resolvedBy': resolvedBy,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}

class FraudSummaryModel {
  final int totalEvents;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int pendingReviewCount;

  const FraudSummaryModel({
    required this.totalEvents,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.pendingReviewCount,
  });

  factory FraudSummaryModel.fromJson(Map<String, dynamic> json) {
    return FraudSummaryModel(
      totalEvents: (json['totalEvents'] as num?)?.toInt() ?? 0,
      criticalCount: (json['criticalCount'] as num?)?.toInt() ?? 0,
      highCount: (json['highCount'] as num?)?.toInt() ?? 0,
      mediumCount: (json['mediumCount'] as num?)?.toInt() ?? 0,
      lowCount: (json['lowCount'] as num?)?.toInt() ?? 0,
      pendingReviewCount: (json['pendingReviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEvents': totalEvents,
      'criticalCount': criticalCount,
      'highCount': highCount,
      'mediumCount': mediumCount,
      'lowCount': lowCount,
      'pendingReviewCount': pendingReviewCount,
    };
  }
}
