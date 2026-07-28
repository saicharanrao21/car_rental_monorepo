import '../audit_log_model.dart';

abstract interface class AdminAuditLogRepository {
  Future<List<AuditLogEntry>> getAuditLogs({
    String? adminUserId,
    String? action,
    String? targetType,
  });
}
