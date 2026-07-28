import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../domain/audit_log_model.dart';
import '../../domain/repositories/admin_audit_log_repository.dart';
import '../../data/api_admin_audit_log_repository.dart';

final adminAuditLogRepositoryProvider = Provider<AdminAuditLogRepository>((ref) {
  return ApiAdminAuditLogRepository(apiClient: ref.watch(apiClientProvider));
});

final auditActionFilterProvider = StateProvider<String>((ref) => 'ALL');
final auditTargetTypeFilterProvider = StateProvider<String>((ref) => 'ALL');
final auditSearchQueryProvider = StateProvider<String>((ref) => '');

final adminAuditLogsProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((ref) async {
  final repo = ref.watch(adminAuditLogRepositoryProvider);
  final action = ref.watch(auditActionFilterProvider);
  final targetType = ref.watch(auditTargetTypeFilterProvider);
  final search = ref.watch(auditSearchQueryProvider).toLowerCase();

  final list = await repo.getAuditLogs(action: action, targetType: targetType);

  if (search.isEmpty) return list;

  return list.where((AuditLogEntry item) {
    return item.adminUserName.toLowerCase().contains(search) ||
        item.action.toLowerCase().contains(search) ||
        item.targetType.toLowerCase().contains(search) ||
        item.targetId.toLowerCase().contains(search);
  }).toList();
});
