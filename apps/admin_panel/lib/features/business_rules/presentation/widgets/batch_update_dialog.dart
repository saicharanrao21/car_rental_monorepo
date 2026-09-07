import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../domain/models/system_config_detail.dart';
import '../../domain/repositories/business_rules_repository.dart';
import '../providers/business_rules_providers.dart';

/// Modal dialog for safely batch-updating multiple related business rules
/// in an atomic all-or-nothing transaction.
class BatchUpdateDialog extends ConsumerStatefulWidget {
  final List<SystemConfigDetail> rules;

  const BatchUpdateDialog({
    super.key,
    required this.rules,
  });

  static Future<bool?> show({
    required BuildContext context,
    required List<SystemConfigDetail> rules,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchUpdateDialog(rules: rules),
    );
  }

  @override
  ConsumerState<BatchUpdateDialog> createState() => _BatchUpdateDialogState();
}

class _BatchUpdateDialogState extends ConsumerState<BatchUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _draftValues;
  late Set<String> _selectedKeys;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedKeys = widget.rules.map((r) => r.key).toSet();
    _draftValues = {};
    for (final rule in widget.rules) {
      _draftValues[rule.key] = rule.effectiveValue;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitBatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedKeys.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one configuration to update.';
      });
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Audit attribution requires an explanation note for batch updates.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final items = <BatchConfigItem>[];
      for (final rule in widget.rules) {
        if (_selectedKeys.contains(rule.key)) {
          items.add(
            BatchConfigItem(
              key: rule.key,
              value: _draftValues[rule.key],
              expectedVersion: rule.version,
            ),
          );
        }
      }

      await ref.read(ruleMutationControllerProvider.notifier).batchUpdateRules(
            items: items,
            reason: reason,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Batch update executed successfully (${items.length} rules updated atomically).',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Transaction rejected: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.layers_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Atomic Batch Configuration Update',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Gap(4),
                          Text(
                            'Apply multiple business rule changes atomically. All rules are validated together; if any fail or experience an OCC conflict, the entire batch rolls back.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Gap(20),

                // Error alert if present
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                ],

                // Config Rules List
                const Text(
                  'SELECT AND EDIT CONFIGURATION TARGETS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Gap(10),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.rules.length,
                    separatorBuilder: (_, __) => const Gap(10),
                    itemBuilder: (ctx, idx) {
                      final rule = widget.rules[idx];
                      final isSelected = _selectedKeys.contains(rule.key);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF8FAFC) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: _isSubmitting
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedKeys.add(rule.key);
                                        } else {
                                          _selectedKeys.remove(rule.key);
                                        }
                                      });
                                    },
                            ),
                            const Gap(8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        rule.humanReadableName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'v${rule.version}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    rule.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quick editor field depending on rule type
                            SizedBox(
                              width: 180,
                              child: _buildQuickField(rule, isSelected),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Gap(20),

                // Audit Reason Input
                TextFormField(
                  controller: _reasonController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Change Reason Note * (Mandatory for Audit Trail)',
                    hintText: 'e.g. Q4 2026 Fiscal Strategy: Updated GST rate and quote expiry',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a reason for the batch configuration change';
                    }
                    return null;
                  },
                ),
                const Gap(24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const Gap(12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitBatch,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(_isSubmitting
                          ? 'Executing Batch...'
                          : 'Execute Batch (${_selectedKeys.length} items)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickField(SystemConfigDetail rule, bool isEnabled) {
    if (rule.key == 'pricing.tax') {
      final currentGst = (_draftValues[rule.key] is Map)
          ? (_draftValues[rule.key]['gstPercentage'] ?? 18).toString()
          : '18';
      return TextFormField(
        enabled: isEnabled && !_isSubmitting,
        initialValue: currentGst,
        decoration: const InputDecoration(
          labelText: 'GST %',
          suffixText: '%',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (val) {
          final numVal = double.tryParse(val);
          if (numVal != null) {
            _draftValues[rule.key] = {'gstPercentage': numVal};
          }
        },
      );
    }

    if (rule.key == 'pricing.quote') {
      final currentValidity = (_draftValues[rule.key] is Map)
          ? (_draftValues[rule.key]['validityDurationMinutes'] ?? 15).toString()
          : '15';
      return TextFormField(
        enabled: isEnabled && !_isSubmitting,
        initialValue: currentValidity,
        decoration: const InputDecoration(
          labelText: 'Validity Mins',
          suffixText: 'm',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _draftValues[rule.key] = {'validityDurationMinutes': intVal};
          }
        },
      );
    }

    if (rule.key == 'pricing.commission') {
      final currentComm = (_draftValues[rule.key] is Map)
          ? (_draftValues[rule.key]['defaultCommissionPercentage'] ?? 20).toString()
          : '20';
      return TextFormField(
        enabled: isEnabled && !_isSubmitting,
        initialValue: currentComm,
        decoration: const InputDecoration(
          labelText: 'Commission %',
          suffixText: '%',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (val) {
          final numVal = double.tryParse(val);
          if (numVal != null) {
            _draftValues[rule.key] = {'defaultCommissionPercentage': numVal};
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Full editor in drawer',
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }
}
