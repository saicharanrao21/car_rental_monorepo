import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/api_providers.dart';

class AdminReconciliationPage extends ConsumerStatefulWidget {
  const AdminReconciliationPage({super.key});

  @override
  ConsumerState<AdminReconciliationPage> createState() =>
      _AdminReconciliationPageState();
}

class _AdminReconciliationPageState
    extends ConsumerState<AdminReconciliationPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _exceptions = [];
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetchExceptions();
  }

  Future<void> _fetchExceptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{};
      if (_statusFilter != null) queryParams['status'] = _statusFilter;

      final res = await apiClient.dio.get(
        '/api/v1/integrations/admin/payment-ecosystem/reconciliation/exceptions',
        queryParameters: queryParams,
      );

      if (mounted) {
        setState(() {
          _exceptions = res.data is List ? res.data as List<dynamic> : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load reconciliation exceptions: $e';
        });
      }
    }
  }

  Future<void> _runReconciliationSweep() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trigger Reconciliation Engine Sweep'),
        content: const Text(
          'This will execute a live financial sweep comparing Gateway Clearing transactions against General Ledger Journals and Booking states.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Run Sweep')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.post(
        '/api/v1/integrations/admin/payment-ecosystem/reconciliation/run',
        data: {},
      );

      if (mounted) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : {};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reconciliation complete. Matched: ${data['matchedCount'] ?? 0}, Discrepancies: ${data['discrepancyCount'] ?? 0}',
            ),
          ),
        );
        _fetchExceptions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reconciliation run failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resolveException(Map<String, dynamic> ex) async {
    final exceptionId = ex['id'].toString();
    String selectedAction = 'MANUAL_ADJUSTMENT';
    final notesCtrl = TextEditingController();

    final resolved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setStateModal) => AlertDialog(
          title: Text('Resolve Exception #${ex['id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Discrepancy: ${ex['description'] ?? ex['exceptionType'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Gap(12),
              const Text('Select Resolution Action:'),
              const Gap(8),
              DropdownButtonFormField<String>(
                value: selectedAction,
                items: const [
                  DropdownMenuItem(value: 'MANUAL_ADJUSTMENT', child: Text('Post Compensating Adjustment')),
                  DropdownMenuItem(value: 'RETRY_REFUND', child: Text('Retry Gateway Refund')),
                  DropdownMenuItem(value: 'FORCE_SETTLE', child: Text('Force Settle to Ledger')),
                  DropdownMenuItem(value: 'DISMISS', child: Text('Dismiss / Marked Validated')),
                ],
                onChanged: (val) {
                  if (val != null) setStateModal(() => selectedAction = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const Gap(12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Resolution Notes *', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (notesCtrl.text.trim().isEmpty) return;
                Navigator.pop(c, true);
              },
              child: const Text('Confirm Resolution'),
            ),
          ],
        ),
      ),
    );

    if (resolved != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/api/v1/integrations/admin/payment-ecosystem/reconciliation/exceptions/$exceptionId/resolve',
        data: {
          'action': selectedAction,
          'notes': notesCtrl.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exception resolved.')),
        );
        _fetchExceptions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve exception: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Financial Reconciliation & Exceptions'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Run Sweep'),
            onPressed: _runReconciliationSweep,
          ),
          const Gap(16),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const Gap(8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _fetchExceptions();
                  },
                ),
                const Gap(8),
                ChoiceChip(
                  label: const Text('OPEN'),
                  selected: _statusFilter == 'OPEN',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'OPEN');
                    _fetchExceptions();
                  },
                ),
                const Gap(8),
                ChoiceChip(
                  label: const Text('RESOLVED'),
                  selected: _statusFilter == 'RESOLVED',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'RESOLVED');
                    _fetchExceptions();
                  },
                ),
              ],
            ),
          ),

          // Main Exceptions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _exceptions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                                const Gap(8),
                                Text(
                                  'No reconciliation exceptions found.',
                                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Ledger and gateway transactions are fully balanced.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _exceptions.length,
                            separatorBuilder: (_, __) => const Gap(8),
                            itemBuilder: (ctx, idx) {
                              final ex = _exceptions[idx] as Map<String, dynamic>;
                              final status = ex['status']?.toString() ?? 'OPEN';
                              final isResolved = status == 'RESOLVED';

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: isResolved ? Colors.grey[200]! : Colors.red[200]!),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    isResolved ? Icons.check_circle : Icons.warning_amber_rounded,
                                    color: isResolved ? Colors.green : Colors.red,
                                  ),
                                  title: Text(
                                    ex['exceptionType']?.toString() ?? 'Discrepancy',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${ex['description'] ?? '-'}\n'
                                    'Expected: ₹${ex['expectedAmount'] ?? 0} • Actual: ₹${ex['actualAmount'] ?? 0} • Diff: ₹${ex['discrepancyAmount'] ?? 0}\n'
                                    'Ref: ${ex['referenceId'] ?? '-'} • Date: ${ex['createdAt'] != null ? DateFormat.yMMMd().format(DateTime.parse(ex['createdAt'])) : '-'}',
                                  ),
                                  trailing: isResolved
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('RESOLVED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () => _resolveException(ex),
                                          child: const Text('Resolve'),
                                        ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
