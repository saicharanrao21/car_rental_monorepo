import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class GenericConfigEditor extends StatefulWidget {
  final dynamic initialValue;
  final bool isReadOnly;
  final void Function(dynamic value, bool isValid) onChanged;

  const GenericConfigEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<GenericConfigEditor> createState() => _GenericConfigEditorState();
}

class _GenericConfigEditorState extends State<GenericConfigEditor> {
  late final TextEditingController _jsonCtrl;
  String? _jsonError;

  @override
  void initState() {
    super.initState();
    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(widget.initialValue);
    _jsonCtrl = TextEditingController(text: formatted);
    _jsonCtrl.addListener(_validateAndNotify);
  }

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  void _validateAndNotify() {
    final text = _jsonCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _jsonError = 'JSON configuration cannot be empty.');
      widget.onChanged(null, false);
      return;
    }

    try {
      final decoded = jsonDecode(text);
      setState(() => _jsonError = null);
      widget.onChanged(decoded, true);
    } catch (e) {
      setState(() => _jsonError = 'Malformed JSON syntax: ${e.toString()}');
      widget.onChanged(null, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_jsonError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const Gap(8),
                Expanded(
                  child: Text(
                    _jsonError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
        ],

        TextFormField(
          controller: _jsonCtrl,
          enabled: !widget.isReadOnly,
          maxLines: 14,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
          decoration: const InputDecoration(
            labelText: 'Configuration JSON Schema',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
