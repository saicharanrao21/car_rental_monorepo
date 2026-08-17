import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/fraud_repository.dart';

class MockFraudRepository with LatencySimulator implements FraudRepository {
  final List<RiskAssessmentModel> _assessments = [
    RiskAssessmentModel(
      id: 'risk_001',
      userId: 'usr_001',
      userName: 'Vikram Mehta',
      userPhone: '+919876543210',
      score: 85,
      riskLevel: RiskLevel.critical,
      action: RiskAction.block,
      signals: const [
        RiskSignalModel(
          code: 'BANNED_USER',
          description: 'User account flagged administratively',
          scoreDelta: 100,
        ),
      ],
      status: 'PENDING_REVIEW',
      adminNotes: null,
      resolvedBy: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    RiskAssessmentModel(
      id: 'risk_002',
      userId: 'usr_002',
      userName: 'Rahul Sharma',
      userPhone: '+919876543211',
      score: 65,
      riskLevel: RiskLevel.high,
      action: RiskAction.reviewRequired,
      signals: const [
        RiskSignalModel(
          code: 'DUPLICATE_DRIVING_LICENCE',
          description: 'Driving Licence registered on 2 other accounts',
          scoreDelta: 40,
        ),
        RiskSignalModel(
          code: 'HIGH_BOOKING_VELOCITY',
          description: '3 booking attempts in 2 hours',
          scoreDelta: 25,
        ),
      ],
      status: 'PENDING_REVIEW',
      adminNotes: null,
      resolvedBy: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    RiskAssessmentModel(
      id: 'risk_003',
      userId: 'usr_003',
      userName: 'Ananya Verma',
      userPhone: '+919876543212',
      score: 30,
      riskLevel: RiskLevel.medium,
      action: RiskAction.monitor,
      signals: const [
        RiskSignalModel(
          code: 'HIGH_CANCELLATION_VELOCITY',
          description: '3 cancellations in 24 hours',
          scoreDelta: 30,
        ),
      ],
      status: 'RESOLVED',
      adminNotes: 'Customer verified travel plans changed due to weather.',
      resolvedBy: 'admin_master',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      resolvedAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  @override
  Future<FraudSummaryModel> getSummary() async {
    await simulateLatency();
    return const FraudSummaryModel(
      totalEvents: 3,
      criticalCount: 1,
      highCount: 1,
      mediumCount: 1,
      lowCount: 0,
      pendingReviewCount: 2,
    );
  }

  @override
  Future<List<RiskAssessmentModel>> getAssessments({
    String? riskLevel,
    String? status,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    await simulateLatency();
    var filtered = _assessments;
    if (riskLevel != null && riskLevel.isNotEmpty) {
      filtered = filtered
          .where((a) => a.riskLevel.displayName == riskLevel.toUpperCase())
          .toList();
    }
    if (status != null && status.isNotEmpty) {
      filtered = filtered
          .where((a) => a.status.toUpperCase() == status.toUpperCase())
          .toList();
    }
    if (userId != null && userId.isNotEmpty) {
      filtered = filtered.where((a) => a.userId == userId).toList();
    }
    return filtered;
  }

  @override
  Future<RiskAssessmentModel> getUserRiskProfile(String userId) async {
    await simulateLatency();
    return _assessments.firstWhere(
      (a) => a.userId == userId,
      orElse: () => RiskAssessmentModel(
        id: 'risk_default',
        userId: userId,
        userName: 'Generic Customer',
        userPhone: '+919999999999',
        score: 0,
        riskLevel: RiskLevel.low,
        action: RiskAction.allow,
        signals: const [],
        status: 'RESOLVED',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<bool> resolveAssessment(
    String assessmentId, {
    required String status,
    required String adminNotes,
  }) async {
    await simulateLatency();
    final idx = _assessments.indexWhere((a) => a.id == assessmentId);
    if (idx != -1) {
      final old = _assessments[idx];
      _assessments[idx] = RiskAssessmentModel(
        id: old.id,
        userId: old.userId,
        userName: old.userName,
        userPhone: old.userPhone,
        score: old.score,
        riskLevel: old.riskLevel,
        action: old.action,
        signals: old.signals,
        status: status,
        adminNotes: adminNotes,
        resolvedBy: 'admin_current',
        createdAt: old.createdAt,
        resolvedAt: DateTime.now(),
      );
    }
    return true;
  }
}
