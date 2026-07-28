import 'package:core/core.dart';
import '../domain/audit_log_model.dart';
import '../domain/repositories/admin_audit_log_repository.dart';

class ApiAdminAuditLogRepository implements AdminAuditLogRepository {
  final ApiClient apiClient;

  ApiAdminAuditLogRepository({required this.apiClient});

  @override
  Future<List<AuditLogEntry>> getAuditLogs({
    String? adminUserId,
    String? action,
    String? targetType,
  }) async {
    final query = <String, dynamic>{};
    if (adminUserId != null && adminUserId.isNotEmpty) query['adminUserId'] = adminUserId;
    if (action != null && action.isNotEmpty && action != 'ALL') query['action'] = action;
    if (targetType != null && targetType.isNotEmpty && targetType != 'ALL') query['targetType'] = targetType;

    final res = await apiClient.dio.get('/admin/audit-log', queryParameters: query);
    final List list = res.data is Map ? (res.data['data'] as List? ?? []) : (res.data as List);
    return list.map((item) => AuditLogEntry.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
