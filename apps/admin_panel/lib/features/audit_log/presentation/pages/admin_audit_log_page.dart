import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
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
    final targetTypeFilter = ref.watch(auditTargetTypeFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Audit Log',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Read-only transparency & security trail recording all administrative actions and system updates.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(adminAuditLogsProvider),
                  tooltip: 'Refresh Audit Trail',
                ),
              ],
            ),
            const Gap(20),

            // Filter Bar
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Search Audit Trail',
                        hint: 'Search by admin name, action, target ID...',
                        controller: _searchCtrl,
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'Action Filter',
                        value: actionFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Actions')),
                          DropdownMenuItem(value: 'VENDOR_STATUS_CHANGE', child: Text('Vendor Status')),
                          DropdownMenuItem(value: 'SPONSORSHIP_UPDATE', child: Text('Sponsorship Update')),
                          DropdownMenuItem(value: 'DISPUTE_UPDATE', child: Text('Dispute Resolution')),
                          DropdownMenuItem(value: 'BOOKING_OVERRIDE', child: Text('Booking Status')),
                        ],
                        onChanged: (val) {
                          if (val != null) ref.read(auditActionFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'Target Type',
                        value: targetTypeFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Targets')),
                          DropdownMenuItem(value: 'VENDOR', child: Text('Vendor')),
                          DropdownMenuItem(value: 'BOOKING', child: Text('Booking')),
                          DropdownMenuItem(value: 'DISPUTE', child: Text('Dispute')),
                          DropdownMenuItem(value: 'CAR', child: Text('Car')),
                        ],
                        onChanged: (val) {
                          if (val != null) ref.read(auditTargetTypeFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // Data Table List Area
            Expanded(
              child: auditLogsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Failed to load audit trail: $err',
                  onRetry: () => ref.invalidate(adminAuditLogsProvider),
                ),
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.history_outlined,
                        title: 'No Audit Log Entries',
                        subtitle: 'No administrative actions recorded matching current filters.',
                      ),
                    );
                  }

                  return AppCard(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Admin User', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action Performed', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Target Reference', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Metadata & Changes', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: logs.map((log) {
                          final isVendorTarget = log.targetType.toUpperCase() == 'VENDOR';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm:ss').format(log.createdAt),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              DataCell(
                                Row(
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
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Text(
                                    log.action,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                  ),
                                ),
                              ),
                              DataCell(
                                isVendorTarget
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
                                      ),
                              ),
                              DataCell(
                                _buildFormattedMetadata(log.metadata),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
