import 'package:models/models.dart';

abstract class FraudRepository {
  Future<FraudSummaryModel> getSummary();
  Future<List<RiskAssessmentModel>> getAssessments({
    String? riskLevel,
    String? status,
    String? userId,
    int page = 1,
    int limit = 20,
  });
  Future<RiskAssessmentModel> getUserRiskProfile(String userId);
  Future<bool> resolveAssessment(
    String assessmentId, {
    required String status,
    required String adminNotes,
  });
}
