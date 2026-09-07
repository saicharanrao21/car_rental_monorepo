import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../domain/models/system_config_detail.dart';

class ConfigSaveConfirmationDialog extends StatefulWidget {
  final SystemConfigDetail config;
  final dynamic newValue;

  const ConfigSaveConfirmationDialog({
    super.key,
    required this.config,
    required this.newValue,
  });

  static Future<String?> show({
    required BuildContext context,
    required SystemConfigDetail config,
    required dynamic newValue,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfigSaveConfirmationDialog(
        config: config,
        newValue: newValue,
      ),
    );
  }

  @override
  State<ConfigSaveConfirmationDialog> createState() => _ConfigSaveConfirmationDialogState();
}

class _ConfigSaveConfirmationDialogState extends State<ConfigSaveConfirmationDialog> {
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _formatValue(dynamic val) {
    if (val == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(val);
    } catch (_) {
      return val.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prevStr = _formatValue(widget.config.effectiveValue);
    final newStr = _formatValue(widget.newValue);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.published_with_changes_rounded, color: Color(0xFF2563EB)),
          Gap(10),
          Expanded(
            child: Text(
              'Confirm Rule Modification',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.config.humanReadableName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                      ),
                      const Gap(2),
                      Text(
                        'Key: ${widget.config.key}  •  Current Revision: v${widget.config.version}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const Gap(16),

                // Comparison Columns
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PREVIOUS VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const Gap(6),
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                prevStr,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PROPOSED NEW VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          const Gap(6),
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                newStr,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(16),

                // Change Reason Input
                const Text(
                  'Change Reason / Operational Note:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Gap(6),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Approved tax exemption update, Q4 pricing policy tuning',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a brief reason for audit logging';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonCtrl.text.trim());
            }
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Confirm & Apply Change'),
        ),
      ],
    );
  }
}
