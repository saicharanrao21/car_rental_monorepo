import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TaxConfigEditor extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final bool isReadOnly;
  final void Function(Map<String, dynamic> value, bool isValid) onChanged;

  const TaxConfigEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<TaxConfigEditor> createState() => _TaxConfigEditorState();
}

class _TaxConfigEditorState extends State<TaxConfigEditor> {
  late final TextEditingController _gstCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialRate = (widget.initialValue['gstRate'] as num?)?.toDouble() ?? 18.0;
    _gstCtrl = TextEditingController(text: initialRate.toStringAsFixed(initialRate.truncateToDouble() == initialRate ? 0 : 2));
    _gstCtrl.addListener(_validateAndNotify);
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    super.dispose();
  }

  void _validateAndNotify() {
    final text = _gstCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'GST rate is required');
      widget.onChanged({'gstRate': 0}, false);
      return;
    }

    final val = double.tryParse(text);
    if (val == null || val.isNaN) {
      setState(() => _errorText = 'Enter a valid numeric percentage');
      widget.onChanged({'gstRate': 0}, false);
      return;
    }

    if (val < 0 || val > 100) {
      setState(() => _errorText = 'GST rate must be between 0% and 100%');
      widget.onChanged({'gstRate': val}, false);
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged({'gstRate': val}, true);
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = double.tryParse(_gstCtrl.text.trim()) ?? 18.0;
    const exampleFee = 200.0;
    final exampleGst = (exampleFee * currentRate) / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Configuration explanation banner
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
              Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
              Gap(10),
              Expanded(
                child: Text(
                  'Goods & Services Tax (GST) rate applied directly to the platform service fee during quote generation. Legally mandated in India at 18% standard, but customizable for special tax exemptions.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const Gap(20),

        // Input Field
        TextFormField(
          controller: _gstCtrl,
          enabled: !widget.isReadOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'GST Percentage Rate (%)',
            hintText: 'e.g. 18',
            suffixText: '%',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.percent_rounded),
          ),
        ),
        const Gap(16),

        // Quick Preset Buttons
        if (!widget.isReadOnly) ...[
          const Text(
            'Quick Rate Presets:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
              final isSelected = currentRate == rate;
              return ChoiceChip(
                label: Text('${rate.toInt()}%'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _gstCtrl.text = rate.toInt().toString();
                  }
                },
              );
            }).toList(),
          ),
          const Gap(20),
        ],

        // Real-Time Calculation Simulation Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF2563EB)),
                  Gap(6),
                  Text(
                    'LIVE FARE ENGINE SIMULATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Platform Service Fee (Sample):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('₹${exampleFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GST Calculated (@ ${currentRate.toStringAsFixed(1)}%):',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('₹${exampleGst.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
