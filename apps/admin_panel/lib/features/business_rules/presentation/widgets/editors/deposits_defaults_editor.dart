import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DepositsDefaultsEditor extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final bool isReadOnly;
  final void Function(Map<String, dynamic> value, bool isValid) onChanged;

  const DepositsDefaultsEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<DepositsDefaultsEditor> createState() => _DepositsDefaultsEditorState();
}

class _DepositsDefaultsEditorState extends State<DepositsDefaultsEditor> {
  final Map<String, TextEditingController> _controllers = {};
  String? _validationError;

  static const _categories = [
    'HATCHBACK',
    'SEDAN',
    'SUV',
    'LUXURY',
    'TEMPO_TRAVELLER',
    'MINI_BUS',
  ];

  @override
  void initState() {
    super.initState();
    for (final cat in _categories) {
      final val = (widget.initialValue[cat] as num?)?.toInt() ?? _defaultFor(cat);
      final ctrl = TextEditingController(text: val.toString());
      ctrl.addListener(_validateAndNotify);
      _controllers[cat] = ctrl;
    }
  }

  int _defaultFor(String cat) {
    switch (cat) {
      case 'HATCHBACK':
        return 3000;
      case 'SEDAN':
        return 4000;
      case 'SUV':
        return 5000;
      case 'LUXURY':
        return 10000;
      case 'TEMPO_TRAVELLER':
        return 8000;
      case 'MINI_BUS':
        return 10000;
      default:
        return 5000;
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _validateAndNotify() {
    final result = <String, double>{};
    for (final cat in _categories) {
      final ctrl = _controllers[cat];
      final text = ctrl?.text.trim() ?? '';
      if (text.isEmpty) {
        setState(() => _validationError = 'Deposit amount for $cat is required.');
        widget.onChanged({}, false);
        return;
      }
      final parsed = double.tryParse(text);
      if (parsed == null || parsed < 0) {
        setState(() => _validationError = 'Deposit for $cat must be a non-negative amount.');
        widget.onChanged({}, false);
        return;
      }
      result[cat] = parsed;
    }

    setState(() => _validationError = null);
    widget.onChanged(result, true);
  }

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF475569)),
              Gap(10),
              Expanded(
                child: Text(
                  'Default security deposit amount held in escrow per vehicle category when a vehicle does not have custom deposit rules defined. Fully refunded upon verified vehicle return.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        if (_validationError != null) ...[
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
                    _validationError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
        ],

        // Grid of Category Deposit Fields
        ...List.generate(_categories.length, (i) {
          final cat = _categories[i];
          final ctrl = _controllers[cat]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    cat.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: ctrl,
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
