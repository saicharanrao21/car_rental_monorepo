import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CommissionConfigEditor extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final bool isReadOnly;
  final void Function(Map<String, dynamic> value, bool isValid) onChanged;

  const CommissionConfigEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<CommissionConfigEditor> createState() => _CommissionConfigEditorState();
}

class _CommissionConfigEditorState extends State<CommissionConfigEditor> {
  late final TextEditingController _commissionCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final rate = (widget.initialValue['defaultPercent'] ??
            widget.initialValue['defaultRate'] ??
            widget.initialValue['defaultCommissionPercent'] as num?)
        ?.toDouble() ??
        10.0;
    _commissionCtrl = TextEditingController(text: rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1));
    _commissionCtrl.addListener(_validateAndNotify);
  }

  @override
  void dispose() {
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _validateAndNotify() {
    final text = _commissionCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Commission rate is required');
      widget.onChanged({'defaultPercent': 0}, false);
      return;
    }

    final val = double.tryParse(text);
    if (val == null || val.isNaN) {
      setState(() => _errorText = 'Enter a valid numeric percentage');
      widget.onChanged({'defaultPercent': 0}, false);
      return;
    }

    if (val < 0 || val > 100) {
      setState(() => _errorText = 'Commission rate must be between 0% and 100%');
      widget.onChanged({'defaultPercent': val}, false);
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged({'defaultPercent': val}, true);
  }

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(_commissionCtrl.text.trim()) ?? 10.0;
    const exampleBooking = 5000.0;
    final platformCommission = (exampleBooking * rate) / 100.0;
    final vendorPayout = exampleBooking - platformCommission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security Confidentiality Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 18, color: Color(0xFFD97706)),
              Gap(10),
              Expanded(
                child: Text(
                  'CONFIDENTIAL PLATFORM GOVERNANCE: This is an internal configuration parameter. It is never exposed over public or customer/vendor-facing APIs.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Text(
            'Default fallback platform commission rate applied when no granular city-, category-, or vendor-specific tier matches.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
          ),
        ),
        const Gap(20),

        TextFormField(
          controller: _commissionCtrl,
          enabled: !widget.isReadOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Default Platform Commission (%)',
            hintText: 'e.g. 10',
            suffixText: '%',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
          ),
        ),
        const Gap(16),

        if (!widget.isReadOnly) ...[
          const Text(
            'Common Rates:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            children: [5.0, 8.0, 10.0, 12.5, 15.0, 20.0].map((preset) {
              final isSelected = rate == preset;
              return ChoiceChip(
                label: Text('${preset.toStringAsFixed(preset.truncateToDouble() == preset ? 0 : 1)}%'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _commissionCtrl.text = preset.toStringAsFixed(preset.truncateToDouble() == preset ? 0 : 1);
                  }
                },
              );
            }).toList(),
          ),
          const Gap(20),
        ],

        // Split simulation card
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
                  Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFF059669)),
                  Gap(6),
                  Text(
                    'MARKETPLACE SETTLEMENT PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Base Booking Value:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('₹${exampleBooking.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Platform Commission (@ ${rate.toStringAsFixed(1)}%):',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('₹${platformCommission.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Vendor Payout:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('₹${vendorPayout.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
