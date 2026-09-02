import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../../domain/audit_log_model.dart';
import '../providers/admin_audit_log_providers.dart';

class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(auditSearchQueryProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(adminAuditLogsProvider);
    final actionFilter = ref.watch(auditActionFilterProvider);
    final targetFilter = ref.watch(auditTargetTypeFilterProvider);
    final searchQuery = ref.watch(auditSearchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Audit Trail & System Logs',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const Gap(4),
                    const Text(
                      'Immutable record of all administrative overrides, security events, and platform state changes.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
                IconButton.outlined(
                  onPressed: () => ref.invalidate(adminAuditLogsProvider),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Logs',
                ),
              ],
            ),
            const Gap(20),
            AdminTableToolbar(
              searchValue: searchQuery,
              onSearchChanged: (val) {
                ref.read(auditSearchQueryProvider.notifier).state = val;
              },
              searchHint: 'Search by admin name, action, or target ID...',
              filters: [
                DropdownButton<String>(
                  value: actionFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Actions', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'MANUAL_PAYOUT_RELEASE', child: Text('Payout Releases', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'VENDOR_SUSPENSION', child: Text('Vendor Suspensions', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'COMMISSION_UPDATE', child: Text('Commission Updates', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'DISPUTE_RESOLUTION', child: Text('Dispute Resolutions', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(auditActionFilterProvider.notifier).state = val;
                    }
                  },
                ),
                const Gap(8),
                DropdownButton<String>(
                  value: targetFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Targets', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'VENDOR', child: Text('Vendor', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'BOOKING', child: Text('Booking', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'COMMISSION', child: Text('Commission', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'DISPUTE', child: Text('Dispute', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(auditTargetTypeFilterProvider.notifier).state = val;
                    }
                  },
                ),
              ],
            ),
            const Gap(16),
            Expanded(
              child: auditLogsAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (e, st) => AdminErrorState(
                  message: 'Failed to load audit trail: $e',
                  onRetry: () => ref.invalidate(adminAuditLogsProvider),
                ),
                data: (logs) {
                  return AdminDataGrid<AuditLogEntry>(
                    items: logs,
                    emptyTitle: 'No Audit Log Entries',
                    emptyMessage: 'No administrative actions recorded matching current filters.',
                    emptyIcon: Icons.history_outlined,
                    columns: [
                      AdminDataColumn<AuditLogEntry>(
                        title: 'TIMESTAMP',
                        builder: (AuditLogEntry log) => Text(
                          DateFormat('dd MMM yyyy, HH:mm:ss').format(log.createdAt),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      AdminDataColumn<AuditLogEntry>(
                        title: 'ADMIN USER',
                        builder: (AuditLogEntry log) => Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                log.adminUserName.isNotEmpty ? log.adminUserName[0].toUpperCase() : 'A',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            const Gap(8),
                            Text(log.adminUserName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      AdminDataColumn<AuditLogEntry>(
                        title: 'ACTION PERFORMED',
                        builder: (AuditLogEntry log) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            log.action,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                        ),
                      ),
                      AdminDataColumn<AuditLogEntry>(
                        title: 'TARGET REFERENCE',
                        builder: (AuditLogEntry log) {
                          final isVendorTarget = log.targetType.toUpperCase() == 'VENDOR';
                          return isVendorTarget
                              ? InkWell(
                                  onTap: () => context.go('/vendors'),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${log.targetType}:${log.targetId.length > 8 ? log.targetId.substring(0, 8) : log.targetId}',
                                        style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                      ),
                                      const Gap(4),
                                      const Icon(Icons.arrow_outward, size: 12, color: Colors.blue),
                                    ],
                                  ),
                                )
                              : Text(
                                  '${log.targetType}:${log.targetId.length > 8 ? log.targetId.substring(0, 8) : log.targetId}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                );
                        },
                      ),
                      AdminDataColumn<AuditLogEntry>(
                        title: 'METADATA & CHANGES',
                        builder: (AuditLogEntry log) => _buildFormattedMetadata(log.metadata),
                      ),
                    ],
                    mobileCardBuilder: (ctx, AuditLogEntry log) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(log.adminUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(DateFormat('dd MMM, HH:mm').format(log.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const Gap(4),
                            Text(log.action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final entries = metadata.entries.take(3).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            '${e.key}: ${e.value}',
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        );
      }).toList(),
    );
  }
}
