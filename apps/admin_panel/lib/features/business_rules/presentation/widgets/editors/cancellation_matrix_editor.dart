import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CancellationTierItem {
  double minHoursBeforePickup;
  double feePercent;
  String tier;
  String description;

  CancellationTierItem({
    required this.minHoursBeforePickup,
    required this.feePercent,
    required this.tier,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'minHoursBeforePickup': minHoursBeforePickup,
        'feePercent': feePercent,
        'tier': tier,
        'description': description,
      };
}

class CancellationMatrixEditor extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final bool isReadOnly;
  final void Function(Map<String, dynamic> value, bool isValid) onChanged;

  const CancellationMatrixEditor({
    super.key,
    required this.initialValue,
    required this.isReadOnly,
    required this.onChanged,
  });

  @override
  State<CancellationMatrixEditor> createState() => _CancellationMatrixEditorState();
}

class _CancellationMatrixEditorState extends State<CancellationMatrixEditor> {
  late List<CancellationTierItem> _tiers;
  late final TextEditingController _afterStartCtrl;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _initTiers();
    final afterStart = (widget.initialValue['afterStartFeePercent'] as num?)?.toDouble() ?? 100.0;
    _afterStartCtrl = TextEditingController(text: afterStart.toInt().toString());
    _afterStartCtrl.addListener(_validateAndNotify);
  }

  @override
  void dispose() {
    _afterStartCtrl.dispose();
    super.dispose();
  }

  void _initTiers() {
    _tiers = [];
    final rawTiers = widget.initialValue['tiers'];
    if (rawTiers is List) {
      for (final item in rawTiers) {
        if (item is Map) {
          _tiers.add(
            CancellationTierItem(
              minHoursBeforePickup: (item['minHoursBeforePickup'] as num?)?.toDouble() ?? 0.0,
              feePercent: (item['feePercent'] as num?)?.toDouble() ?? 0.0,
              tier: item['tier']?.toString() ?? 'TIER',
              description: item['description']?.toString() ?? '',
            ),
          );
        }
      }
    }

    if (_tiers.isEmpty) {
      _tiers = [
        CancellationTierItem(minHoursBeforePickup: 24, feePercent: 0, tier: 'FREE_CANCELLATION', description: 'Free (>24h)'),
        CancellationTierItem(minHoursBeforePickup: 6, feePercent: 25, tier: 'MODERATE_FEE', description: 'Moderate (6-24h)'),
        CancellationTierItem(minHoursBeforePickup: 0, feePercent: 50, tier: 'LATE_FEE', description: 'Late (<6h)'),
      ];
    }

    _tiers.sort((a, b) => b.minHoursBeforePickup.compareTo(a.minHoursBeforePickup));
  }

  void _validateAndNotify() {
    if (_tiers.isEmpty) {
      setState(() => _validationError = 'At least one cancellation tier is required.');
      widget.onChanged({}, false);
      return;
    }

    final afterStart = double.tryParse(_afterStartCtrl.text.trim());
    if (afterStart == null || afterStart < 0 || afterStart > 100) {
      setState(() => _validationError = 'After-start fee must be a number between 0% and 100%.');
      widget.onChanged({}, false);
      return;
    }

    final seenHours = <double>{};
    for (final t in _tiers) {
      if (t.minHoursBeforePickup < 0) {
        setState(() => _validationError = 'Hours before pickup must be >= 0.');
        widget.onChanged({}, false);
        return;
      }
      if (seenHours.contains(t.minHoursBeforePickup)) {
        setState(() => _validationError = 'Duplicate hours threshold: ${t.minHoursBeforePickup}h.');
        widget.onChanged({}, false);
        return;
      }
      seenHours.add(t.minHoursBeforePickup);

      if (t.feePercent < 0 || t.feePercent > 100) {
        setState(() => _validationError = 'Fee percent must be between 0% and 100%.');
        widget.onChanged({}, false);
        return;
      }
    }

    // Sort descending by minHoursBeforePickup (e.g. 48h, 24h, 6h, 0h)
    final sortedDesc = [..._tiers]..sort((a, b) => b.minHoursBeforePickup.compareTo(a.minHoursBeforePickup));
    for (int i = 1; i < sortedDesc.length; i++) {
      final earlier = sortedDesc[i - 1]; // e.g. 24h
      final later = sortedDesc[i];       // e.g. 6h (closer to pickup)
      if (later.feePercent < earlier.feePercent) {
        setState(() => _validationError =
            'Fee progression violation: Fee at ${later.minHoursBeforePickup}h (${later.feePercent}%) cannot be lower than at ${earlier.minHoursBeforePickup}h (${earlier.feePercent}%). Fees must increase as trip start approaches.');
        widget.onChanged({}, false);
        return;
      }
    }

    final maxTierFee = _tiers.map((t) => t.feePercent).reduce((a, b) => a > b ? a : b);
    if (afterStart < maxTierFee) {
      setState(() => _validationError =
          'After-start fee ($afterStart%) cannot be lower than the pre-trip cancellation fee ($maxTierFee%).');
      widget.onChanged({}, false);
      return;
    }

    setState(() => _validationError = null);
    widget.onChanged({
      'tiers': sortedDesc.map((t) => t.toJson()).toList(),
      'afterStartFeePercent': afterStart,
      'afterStartTier': widget.initialValue['afterStartTier'] ?? 'NO_REFUND_AFTER_START',
      'afterStartDescription': widget.initialValue['afterStartDescription'] ?? 'Trip started (Non-refundable)',
    }, true);
  }

  void _addTier() {
    final highestHours = _tiers.isEmpty ? 0.0 : _tiers.map((t) => t.minHoursBeforePickup).reduce((a, b) => a > b ? a : b);

    setState(() {
      _tiers.add(
        CancellationTierItem(
          minHoursBeforePickup: highestHours + 24.0,
          feePercent: 0.0,
          tier: 'NEW_TIER_${_tiers.length + 1}',
          description: 'Cancellation > ${highestHours + 24} hours',
        ),
      );
      _tiers.sort((a, b) => b.minHoursBeforePickup.compareTo(a.minHoursBeforePickup));
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
              Icon(Icons.policy_outlined, size: 18, color: Color(0xFF475569)),
              Gap(10),
              Expanded(
                child: Text(
                  'Cancellation matrix dictates the customer refund percentage vs cancellation fee penalty based on hours remaining before scheduled trip start. Historical bookings preserve their signed snapshot.',
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

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('MIN HOURS BEFORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 2, child: Text('FEE %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 3, child: Text('TIER IDENTIFIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              SizedBox(width: 40),
            ],
          ),
        ),

        // Tiers
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
                    initialValue: tier.minHoursBeforePickup.toInt().toString(),
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(suffixText: 'hrs', isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null) {
                        tier.minHoursBeforePickup = parsed;
                        _validateAndNotify();
                      }
                    },
                  ),
                ),
                const Gap(8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: tier.feePercent.toInt().toString(),
                    enabled: !widget.isReadOnly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(suffixText: '%', isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed != null) {
                        tier.feePercent = parsed;
                        _validateAndNotify();
                      }
                    },
                  ),
                ),
                const Gap(8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: tier.tier,
                    enabled: !widget.isReadOnly,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (val) {
                      tier.tier = val.trim();
                      _validateAndNotify();
                    },
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 32,
                  child: (!widget.isReadOnly && _tiers.length > 1)
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _removeTier(idx),
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
            label: const Text('Add Cancellation Tier', style: TextStyle(fontSize: 12)),
          ),

        const Gap(24),
        const Divider(),
        const Gap(12),

        // After Start Fee
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('After-Start Cancellation Fee (%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Gap(2),
                  Text('Penalty applied when cancellation occurs after trip pickup time has elapsed.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Gap(16),
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _afterStartCtrl,
                enabled: !widget.isReadOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: '%', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
