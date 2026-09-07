import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DurationTierModel {
  int minDays;
  double discountPercent;

  DurationTierModel({required this.minDays, required this.discountPercent});

  Map<String, dynamic> toJson() => {
        'minDays': minDays,
        'discountPercent': discountPercent,
      };
}

class DurationDiscountsEditor extends StatefulWidget {
  final dynamic initialValue;
  final bool isReadOnly;
  final void Function(dynamic value, bool isValid) onChanged;

  const DurationDiscountsEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<DurationDiscountsEditor> createState() => _DurationDiscountsEditorState();
}

class _DurationDiscountsEditorState extends State<DurationDiscountsEditor> {
  late List<DurationTierModel> _tiers;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _initTiers();
  }

  void _initTiers() {
    _tiers = [];
    final raw = widget.initialValue;
    List<dynamic> list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw['tiers'] is List) {
      list = raw['tiers'] as List;
    }

    for (final item in list) {
      if (item is Map) {
        final days = (item['minDays'] as num?)?.toInt() ?? 1;
        final disc = (item['discountPercent'] as num?)?.toDouble() ?? 0.0;
        _tiers.add(DurationTierModel(minDays: days, discountPercent: disc));
      }
    }

    if (_tiers.isEmpty) {
      _tiers = [
        DurationTierModel(minDays: 7, discountPercent: 10),
        DurationTierModel(minDays: 30, discountPercent: 20),
      ];
    }

    _tiers.sort((a, b) => a.minDays.compareTo(b.minDays));
  }

  void _validateAndNotify() {
    if (_tiers.isEmpty) {
      setState(() => _validationError = 'At least one discount tier is required.');
      widget.onChanged([], false);
      return;
    }

    // Check unique days
    final seenDays = <int>{};
    for (final t in _tiers) {
      if (t.minDays < 1) {
        setState(() => _validationError = 'Duration must be at least 1 day.');
        widget.onChanged(_serialize(), false);
        return;
      }
      if (seenDays.contains(t.minDays)) {
        setState(() => _validationError = 'Duplicate duration threshold: ${t.minDays} days.');
        widget.onChanged(_serialize(), false);
        return;
      }
      seenDays.add(t.minDays);

      if (t.discountPercent < 0 || t.discountPercent > 100) {
        setState(() => _validationError = 'Discount must be between 0% and 100%.');
        widget.onChanged(_serialize(), false);
        return;
      }
    }

    // Check monotonicity
    final sorted = [..._tiers]..sort((a, b) => a.minDays.compareTo(b.minDays));
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].discountPercent < sorted[i - 1].discountPercent) {
        setState(() => _validationError =
            'Monotonicity violation: ${sorted[i].minDays} days has lower discount (${sorted[i].discountPercent}%) than ${sorted[i - 1].minDays} days (${sorted[i - 1].discountPercent}%). Higher duration must have greater or equal discount.');
        widget.onChanged(_serialize(), false);
        return;
      }
    }

    setState(() => _validationError = null);
    widget.onChanged(_serialize(), true);
  }

  List<Map<String, dynamic>> _serialize() {
    return _tiers.map((t) => t.toJson()).toList();
  }

  void _addTier() {
    final highestDays = _tiers.isEmpty ? 0 : _tiers.map((t) => t.minDays).reduce((a, b) => a > b ? a : b);
    final highestDisc = _tiers.isEmpty ? 0.0 : _tiers.map((t) => t.discountPercent).reduce((a, b) => a > b ? a : b);

    setState(() {
      _tiers.add(
        DurationTierModel(
          minDays: highestDays + 7,
          discountPercent: (highestDisc + 5.0).clamp(0.0, 100.0),
        ),
      );
      _tiers.sort((a, b) => a.minDays.compareTo(b.minDays));
    });
    _validateAndNotify();
  }

  void _removeTier(int index) {
    if (_tiers.length <= 1) return;
    setState(() {
      _tiers.removeAt(index);
    });
    _validateAndNotify();
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
              Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF475569)),
              Gap(10),
              Expanded(
                child: Text(
                  'Duration discount tiers reward multi-day rentals. Tiers are automatically matched based on booking duration in days. Discounts must be strictly non-decreasing with rental duration.',
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

        // Tiers Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('MINIMUM RENTAL DAYS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 3, child: Text('DISCOUNT PERCENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              SizedBox(width: 48),
            ],
          ),
        ),

        // Tiers List
        ...List.generate(_tiers.length, (idx) {
          final tier = _tiers[idx];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: tier.minDays.toString(),
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'days',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null) {
                        tier.minDays = parsed;
                        _validateAndNotify();
                      }
                    },
                  ),
                ),
                const Gap(12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: tier.discountPercent.toStringAsFixed(tier.discountPercent.truncateToDouble() == tier.discountPercent ? 0 : 1),
                    enabled: !widget.isReadOnly,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      suffixText: '%',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null) {
                        tier.discountPercent = parsed;
                        _validateAndNotify();
                      }
                    },
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 40,
                  child: (!widget.isReadOnly && _tiers.length > 1)
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _removeTier(idx),
                          tooltip: 'Remove Tier',
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }),

        const Gap(12),
        if (!widget.isReadOnly)
          OutlinedButton.icon(
            onPressed: _addTier,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Duration Tier', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
