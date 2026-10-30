import 'package:core/core.dart';
import '../domain/models/operations_models.dart';

class ApiAdminOperationsRepository {
  final ApiClient _apiClient;

  ApiAdminOperationsRepository(this._apiClient);

  Future<List<WorkflowDefinitionModel>> getWorkflows() async {
    final response = await _apiClient.dio.get('/api/v1/operations/workflows');
    final data = response.data;
    if (data is List) {
      return data.map((json) => WorkflowDefinitionModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }
    return [];
  }

  Future<List<WorkflowExecutionModel>> getExecutions() async {
    final response = await _apiClient.dio.get('/api/v1/operations/executions');
    final data = response.data;
    if (data is List) {
      return data.map((json) => WorkflowExecutionModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }
    return [];
  }

  Future<void> retryExecution(String id) async {
    await _apiClient.dio.post('/api/v1/operations/executions/$id/retry', data: {});
  }

  Future<List<AutomationRuleModel>> getRules() async {
    final response = await _apiClient.dio.get('/api/v1/operations/rules');
    final data = response.data;
    if (data is List) {
      return data.map((json) => AutomationRuleModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }
    return [];
  }

  Future<void> updateRule(String id, Map<String, dynamic> data) async {
    await _apiClient.dio.put('/api/v1/operations/rules/$id', data: data);
  }

  Future<List<ApprovalRequestModel>> getApprovals() async {
    final response = await _apiClient.dio.get('/api/v1/operations/approvals');
    final data = response.data;
    if (data is List) {
      return data.map((json) => ApprovalRequestModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }
    return [];
  }

  Future<void> recordDecision(String id, {required String decision, int stepIndex = 0, String? note}) async {
    await _apiClient.dio.post(
      '/api/v1/operations/approvals/$id/decide',
      data: {
        'decision': decision,
        'stepIndex': stepIndex,
        'note': note ?? 'Decision recorded via Control Tower',
      },
    );
  }

  Future<List<ScheduledJobModel>> getSchedules() async {
    final response = await _apiClient.dio.get('/api/v1/operations/schedules');
    final data = response.data;
    if (data is List) {
      return data.map((json) => ScheduledJobModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    }
    return [];
  }

  Future<void> runSchedule(String id) async {
    await _apiClient.dio.post('/api/v1/operations/schedules/$id/run', data: {});
  }
}

