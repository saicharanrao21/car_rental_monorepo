import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class QuoteConfigEditor extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final bool isReadOnly;
  final void Function(Map<String, dynamic> value, bool isValid) onChanged;

  const QuoteConfigEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<QuoteConfigEditor> createState() => _QuoteConfigEditorState();
}

class _QuoteConfigEditorState extends State<QuoteConfigEditor> {
  late final TextEditingController _minutesCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialMinutes = (widget.initialValue['validityMinutes'] as num?)?.toInt() ?? 15;
    _minutesCtrl = TextEditingController(text: initialMinutes.toString());
    _minutesCtrl.addListener(_validateAndNotify);
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _validateAndNotify() {
    final text = _minutesCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Validity duration is required');
      widget.onChanged({'validityMinutes': 0}, false);
      return;
    }

    final val = int.tryParse(text);
    if (val == null) {
      setState(() => _errorText = 'Enter a valid whole integer number of minutes');
      widget.onChanged({'validityMinutes': 0}, false);
      return;
    }

    if (val < 1 || val > 1440) {
      setState(() => _errorText = 'Duration must be between 1 and 1440 minutes (24 hours)');
      widget.onChanged({'validityMinutes': val}, false);
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged({'validityMinutes': val}, true);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minute${minutes == 1 ? '' : 's'}';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hour${hours == 1 ? '' : 's'}';
    }
    return '$hours hr $remainingMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: Color(0xFF475569)),
              Gap(10),
              Expanded(
                child: Text(
                  'Determines the exact lifespan of generated customer booking quotes. Once this window elapses, the quote transitions to EXPIRED and the customer must regenerate with updated vehicle availability and pricing.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const Gap(20),

        TextFormField(
          controller: _minutesCtrl,
          enabled: !widget.isReadOnly,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quote Validity Duration (Minutes)',
            hintText: 'e.g. 15',
            suffixText: 'minutes',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.hourglass_empty_rounded),
          ),
        ),
        const Gap(16),

        if (!widget.isReadOnly) ...[
          const Text(
            'Quick Duration Presets:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            children: [10, 15, 30, 60, 120].map((preset) {
              final isSelected = minutes == preset;
              return ChoiceChip(
                label: Text('$preset mins'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _minutesCtrl.text = preset.toString();
                  }
                },
              );
            }).toList(),
          ),
          const Gap(20),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_filled, size: 20, color: Color(0xFF0284C7)),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EFFECTIVE TTL WINDOW',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const Gap(2),
                  Text(
                    _formatDuration(minutes),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
