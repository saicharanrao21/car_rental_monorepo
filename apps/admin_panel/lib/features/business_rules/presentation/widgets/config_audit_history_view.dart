import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../providers/business_rules_providers.dart';

class ConfigAuditHistoryView extends ConsumerWidget {
  final String configKey;

  const ConfigAuditHistoryView({super.key, required this.configKey});

  String _formatJson(dynamic val) {
    if (val == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(val);
    } catch (_) {
      return val.toString();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(ruleAuditHistoryProvider(configKey));

    return auditAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.red),
              const Gap(8),
              Text('Failed to load audit history: $err', style: const TextStyle(fontSize: 13, color: Colors.red)),
              const Gap(12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(ruleAuditHistoryProvider(configKey)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[400]),
                  const Gap(12),
                  const Text(
                    'No Audit History Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                  ),
                  const Gap(4),
                  Text(
                    'This rule is currently operating on baseline default values. Changes made by administrators will appear here chronologically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final item = logs[idx];
            final dateStr = DateFormat('MMM d, yyyy • hh:mm a').format(item.timestamp);

            return ExpansionTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                child: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              title: Row(
                children: [
                  Text(
                    item.adminDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const Gap(8),
                  if (item.version != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('v${item.version}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  if (item.reason != null && item.reason!.isNotEmpty) ...[
                    const Gap(2),
                    Text(
                      'Note: "${item.reason}"',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                    ),
                  ],
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BEFORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const Gap(4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatJson(item.previousValue),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AFTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            const Gap(4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatJson(item.newValue),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
