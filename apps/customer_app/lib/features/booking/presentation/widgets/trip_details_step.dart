import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../../../home/home_providers.dart';

class TripDetailsStep extends ConsumerStatefulWidget {
  final CarModel car;
  final VendorModel vendor;
  final VoidCallback onNext;

  const TripDetailsStep({
    super.key,
    required this.car,
    required this.vendor,
    required this.onNext,
  });

  @override
  ConsumerState<TripDetailsStep> createState() => _TripDetailsStepState();
}

class _TripDetailsStepState extends ConsumerState<TripDetailsStep> {
  late final TextEditingController _distanceCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _distanceCtrl = TextEditingController(text: draft.estimatedDistanceKm.toString());
    _distanceCtrl.addListener(_syncDistance);

    // Correct the draft's tripType if the car doesn't support it.
    // This handles the case where the user selected a trip type on the home
    // screen that this particular car's availableTripTypes list doesn't include.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final car = widget.car;
      final currentDraft = ref.read(bookingDraftProvider);
      final publicSettingsVal = ref.read(publicSettingsProvider);
      final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];
      final bookableTypes = car.availableTripTypes.where((t) => _isTripTypeEnabled(t, enabledTripTypes)).toList();
      if (!bookableTypes.contains(currentDraft.tripType) && bookableTypes.isNotEmpty) {
        final correctedType = bookableTypes.first;
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          tripType: correctedType,
          driverIncluded: correctedType != 'Self-Drive',
        ));
      }
    });
  }

  void _syncDistance() {
    final n = int.tryParse(_distanceCtrl.text);
    if (n != null && n > 0) {
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(estimatedDistanceKm: n));
    }
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    super.dispose();
  }

  bool _isTripTypeEnabled(String type, List<String> enabledTypes) {
    final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
      return enabledTypes.contains('AIRPORT_TRANSFER');
    }
    return enabledTypes.contains(norm);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final car = widget.car;
    final vendor = widget.vendor;
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Car photo + name ─────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: car.photos.isNotEmpty
                      ? Image.network(car.photos.first,
                          width: 90, height: 70, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${car.make} ${car.model} (${car.year})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Gap(4),
                      Text(vendor.businessName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const Gap(6),
                      Wrap(spacing: 4, children: [
                        _chip(car.type), _chip(car.isAC ? 'AC' : 'Non-AC'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Trip Type Selector ───────────────────────────────────────
          // Only shows trip types this specific car supports.
          // The draft.tripType is guaranteed to be in availableTripTypes
          // after the initState correction above.
          if (car.availableTripTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppDropdown<String>(
                label: 'Trip Type',
                value: car.availableTripTypes.contains(draft.tripType)
                    ? draft.tripType
                    : car.availableTripTypes.first,
                items: car.availableTripTypes.map((type) {
                  final enabled = _isTripTypeEnabled(type, enabledTripTypes);
                  return DropdownMenuItem(
                    value: type,
                    enabled: enabled,
                    child: Text(
                      enabled ? type : '$type (Coming Soon)',
                      style: TextStyle(color: enabled ? null : Colors.grey),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final enabled = _isTripTypeEnabled(val, enabledTripTypes);
                    if (!enabled) return;
                    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                      tripType: val,
                      driverIncluded: val != 'Self-Drive',
                    ));
                  }
                },
              ),
            ),
          _infoTile(Icons.location_on_outlined, 'Pickup',
              draft.pickupLocation.isEmpty ? 'Not specified' : draft.pickupLocation),
          if (draft.tripType != 'Local')
            _infoTile(Icons.flag_outlined, 'Drop',
                draft.dropLocation.isEmpty ? 'Not specified' : draft.dropLocation),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
                initialDateRange: draft.startDate != null && draft.endDate != null
                    ? DateTimeRange(start: draft.startDate!, end: draft.endDate!)
                    : DateTimeRange(start: now, end: now.add(const Duration(days: 12))),
              );
              if (picked != null) {
                ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  startDate: picked.start,
                  endDate: picked.end,
                ));
              }
            },
            child: _infoTile(
              Icons.calendar_today_outlined,
              'Dates',
              draft.startDate != null && draft.endDate != null
                  ? '${draft.startDate!.toDDMMYYYY()} → ${draft.endDate!.toDDMMYYYY()} (Tap to change)'
                  : 'Flexible (Tap to select)',
            ),
          ),
          _infoTile(Icons.nights_stay_outlined, 'Duration',
              '${draft.rentalDays} day${draft.rentalDays == 1 ? '' : 's'}'),
          const Gap(16),

          // ── Editable distance ────────────────────────────────────────
          if (draft.tripType != 'Airport' && draft.tripType != 'Airport Transfer') ...[
            const Text('Estimated Distance (km)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Gap(4),
            const Text(
              'Used to calculate your fare — adjust if you know the approximate route distance.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Gap(8),
            AppTextField(
              label: '',
              hint: 'e.g. 50',
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.route_outlined, color: AppColors.primary),
            ),
            const Gap(4),
            Text(
              'Current: ${draft.estimatedDistanceKm} km',
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
            const Gap(16),
          ],

          AppButton(
            text: 'Next: Add-ons',
            onPressed: () {
              onNext();
            },
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const Gap(10),
            SizedBox(
              width: 76,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _placeholder() => Container(
        width: 90, height: 70,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.directions_car, color: Colors.grey),
      );

  VoidCallback get onNext => widget.onNext;
}
