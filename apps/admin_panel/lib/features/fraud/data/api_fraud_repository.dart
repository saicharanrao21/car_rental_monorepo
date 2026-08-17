import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/fraud_repository.dart';

class ApiFraudRepository implements FraudRepository {
  final ApiClient _apiClient;

  ApiFraudRepository(this._apiClient);

  @override
  Future<FraudSummaryModel> getSummary() async {
    final response = await _apiClient.dio.get('/admin/fraud/summary');
    return FraudSummaryModel.fromJson(response.data);
  }

  @override
  Future<List<RiskAssessmentModel>> getAssessments({
    String? riskLevel,
    String? status,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (riskLevel != null && riskLevel.isNotEmpty) {
      queryParams['riskLevel'] = riskLevel;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['userId'] = userId;
    }

    final response = await _apiClient.dio.get(
      '/admin/fraud/assessments',
      queryParameters: queryParams,
    );

    final rawList = response.data['data'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => RiskAssessmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RiskAssessmentModel> getUserRiskProfile(String userId) async {
    final response = await _apiClient.dio.get('/admin/fraud/users/$userId/risk-profile');
    return RiskAssessmentModel.fromJson(response.data);
  }

  @override
  Future<bool> resolveAssessment(
    String assessmentId, {
    required String status,
    required String adminNotes,
  }) async {
    final response = await _apiClient.dio.post(
      '/admin/fraud/assessments/$assessmentId/resolve',
      data: {
        'status': status,
        'adminNotes': adminNotes,
      },
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
}
