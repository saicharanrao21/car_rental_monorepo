import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../data/models/marketplace_provider_model.dart';
import '../providers/integration_marketplace_provider.dart';

class TestConnectionDialog extends ConsumerStatefulWidget {
  final MarketplaceProviderModel provider;

  const TestConnectionDialog({super.key, required this.provider});

  @override
  ConsumerState<TestConnectionDialog> createState() => _TestConnectionDialogState();
}

class _TestConnectionDialogState extends ConsumerState<TestConnectionDialog> {
  bool _isRunning = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _executeTest();
  }

  Future<void> _executeTest() async {
    setState(() {
      _isRunning = true;
      _result = null;
    });

    final res = await ref.read(marketplaceNotifierProvider.notifier).testConnection(
          widget.provider.category,
          widget.provider.providerId,
        );

    if (mounted) {
      setState(() {
        _isRunning = false;
        _result = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHealthy = _result?['isHealthy'] == true;
    final status = _result?['status']?.toString() ?? (isHealthy ? 'HEALTHY' : 'FAILED');
    final latency = _result?['latencyMs'] ?? 0;
    final errorMsg = _result?['errorMessage']?.toString();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test Connection: ${widget.provider.name}'),
                Text(
                  'Environment: ${widget.provider.activeEnvironment} • ${widget.provider.category}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRunning) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      Gap(16),
                      Text('Executing live handshake & ping...'),
                    ],
                  ),
                ),
              ),
            ] else if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHealthy
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHealthy
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFEF4444).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 24,
                        ),
                        const Gap(10),
                        Text(
                          isHealthy ? 'Connection Successful' : 'Connection Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${latency}ms',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Text(
                      isHealthy
                          ? 'Handshake completed with valid response from remote gateway.'
                          : (errorMsg ?? 'Failed to reach or authenticate with remote API endpoint.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Gap(16),
              // Diagnostic details
              Text('Connection Parameters', style: theme.textTheme.labelMedium),
              const Gap(8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _diagRow('Provider ID', widget.provider.providerId),
                    _diagRow('Category', widget.provider.category),
                    _diagRow('Environment', widget.provider.activeEnvironment),
                    _diagRow('Health Status', status),
                    _diagRow('Latency', '${latency}ms'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _isRunning ? null : _executeTest,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retest'),
        ),
      ],
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
