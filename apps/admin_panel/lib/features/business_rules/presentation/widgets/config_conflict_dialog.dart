import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../domain/repositories/business_rules_repository.dart';

class ConfigConflictDialog extends StatelessWidget {
  final ConcurrencyConflictException conflict;
  final VoidCallback onReload;

  const ConfigConflictDialog({
    super.key,
    required this.conflict,
    required this.onReload,
  });

  static Future<void> show({
    required BuildContext context,
    required ConcurrencyConflictException conflict,
    required VoidCallback onReload,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfigConflictDialog(
        conflict: conflict,
        onReload: onReload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          Gap(10),
          Text('Version Concurrency Conflict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Another administrator has modified and published a newer version of this rule while your editor was open. Your save was rejected to prevent silent data overwrites.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.4),
              ),
            ),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOUR EDITOR REVISION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const Gap(4),
                        Text('v${conflict.expectedVersion}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT SERVER REVISION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        const Gap(4),
                        Text(
                          conflict.currentServerVersion != null ? 'v${conflict.currentServerVersion}' : 'Newer',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            const Text(
              'Please reload the current server configuration to review the latest changes before applying modifications.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onReload();
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reload Latest Server Value'),
        ),
      ],
    );
  }
}
