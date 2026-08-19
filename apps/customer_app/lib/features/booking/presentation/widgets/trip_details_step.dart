import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

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
    _distanceCtrl =
        TextEditingController(text: draft.estimatedDistanceKm.toString());
    _distanceCtrl.addListener(_syncDistance);
  }

  void _syncDistance() {
    final n = int.tryParse(_distanceCtrl.text);
    if (n != null && n > 0) {
      ref
          .read(bookingDraftProvider.notifier)
          .update((d) => d.copyWith(estimatedDistanceKm: n));
    }
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    super.dispose();
  }

  IconData _getServiceIcon(String tripType) {
    switch (tripType) {
      case 'Self-Drive':
        return Icons.key_outlined;
      case 'Outstation':
        return Icons.alt_route_outlined;
      case 'Airport':
      case 'Airport Transfer':
        return Icons.flight_takeoff_outlined;
      case 'Local':
      default:
        return Icons.directions_car_outlined;
    }
  }

  String _getServiceSubtitle(String tripType) {
    switch (tripType) {
      case 'Self-Drive':
        return 'Chauffeur not included • Drive at your own pace';
      case 'Outstation':
        return 'Professional chauffeur included • Inter-city travel';
      case 'Airport':
      case 'Airport Transfer':
        return 'Professional chauffeur included • On-time airport pickup/drop';
      case 'Local':
      default:
        return 'Professional chauffeur included • Intra-city travel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final car = widget.car;
    final vendor = widget.vendor;
    final cs = Theme.of(context).colorScheme;

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
                      ? Image.network(
                          car.photos.first,
                          width: 90,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.make} ${car.model} (${car.year})',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        vendor.businessName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Gap(6),
                      Wrap(
                        spacing: 4,
                        children: [
                          _chip(car.type),
                          _chip(car.isAC ? 'AC' : 'Non-AC'),
                          _chip(car.fuelType),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Immutable Service / Trip Type Badge ──────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getServiceIcon(draft.tripType),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Service: ${draft.tripType}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(2),
                      Text(
                        _getServiceSubtitle(draft.tripType),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Context-Aware Trip Fields ────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Schedule & Locations',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),
                _infoTile(
                  Icons.location_on_outlined,
                  'Pickup',
                  draft.pickupLocation.isEmpty
                      ? 'Not specified'
                      : draft.pickupLocation,
                ),
                if (draft.tripType != 'Local')
                  _infoTile(
                    Icons.flag_outlined,
                    draft.tripType == 'Outstation' ? 'Destination' : 'Drop',
                    draft.dropLocation.isEmpty
                        ? 'Not specified'
                        : draft.dropLocation,
                  ),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: today.subtract(const Duration(days: 1)),
                      lastDate: today.add(const Duration(days: 90)),
                      initialDateRange:
                          draft.startDate != null && draft.endDate != null
                              ? DateTimeRange(
                                  start: draft.startDate!, end: draft.endDate!)
                              : DateTimeRange(
                                  start: today,
                                  end: today.add(const Duration(days: 2))),
                    );
                    if (picked != null) {
                      ref
                          .read(bookingDraftProvider.notifier)
                          .update((d) => d.copyWith(
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
                _infoTile(
                  Icons.nights_stay_outlined,
                  'Duration',
                  '${draft.rentalDays} day${draft.rentalDays == 1 ? '' : 's'}',
                ),
                _infoTile(
                  Icons.person_pin_outlined,
                  'Chauffeur',
                  draft.driverIncluded
                      ? 'Chauffeur Included'
                      : 'Self-Drive (No Chauffeur)',
                ),
              ],
            ),
          ),
          const Gap(16),

          // ── Estimated Distance (Context-Aware) ───────────────────────
          if (draft.tripType != 'Airport' &&
              draft.tripType != 'Airport Transfer') ...[
            const Text(
              'Estimated Distance (km)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Gap(4),
            Text(
              draft.tripType == 'Self-Drive'
                  ? 'Used to compute estimated kilometer allowance and pricing.'
                  : 'Used to calculate your outstation / local fare based on distance.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Gap(8),
            AppTextField(
              label: '',
              hint: 'e.g. 50',
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              prefixIcon:
                  const Icon(Icons.route_outlined, color: AppColors.primary),
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
            onPressed: widget.onNext,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const Gap(10),
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
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
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );

  Widget _placeholder() => Container(
        width: 90,
        height: 70,
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.directions_car, color: Colors.grey),
      );
}
