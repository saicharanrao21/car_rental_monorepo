import 'package:core/core.dart';
import '../domain/dispute_model.dart';
import '../domain/repositories/admin_disputes_repository.dart';

class ApiAdminDisputesRepository implements AdminDisputesRepository {
  final ApiClient apiClient;

  ApiAdminDisputesRepository({required this.apiClient});

  @override
  Future<List<DisputeModel>> getDisputes({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query['status'] = status.toUpperCase();
    }

    final res = await apiClient.dio.get('/admin/disputes', queryParameters: query);
    final List list = res.data is Map ? (res.data['data'] as List? ?? []) : (res.data as List);
    return list.map((item) => DisputeModel.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  @override
  Future<DisputeModel> getDisputeById(String id) async {
    final res = await apiClient.dio.get('/disputes/$id');
    return DisputeModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<void> updateDisputeStatus({
    required String id,
    required String status,
    String? resolutionNote,
  }) async {
    await apiClient.dio.patch('/admin/disputes/$id', data: {
      'status': status.toUpperCase(),
      if (resolutionNote != null && resolutionNote.isNotEmpty) 'resolutionNote': resolutionNote,
    });
  }
}
