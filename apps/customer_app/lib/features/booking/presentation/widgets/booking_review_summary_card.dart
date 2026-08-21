import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class BookingReviewSummaryCard extends ConsumerWidget {
  final CarModel car;
  final VendorModel vendor;

  const BookingReviewSummaryCard({
    super.key,
    required this.car,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Car Header ─────────────────────────────────────────────
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: car.photos.isNotEmpty
                    ? Image.network(
                        car.photos.first,
                        width: 72,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _carPlaceholder(cs),
                      )
                    : _carPlaceholder(cs),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.make} ${car.model} (${car.year})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      vendor.businessName,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Gap(4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        draft.tripType,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
          const Gap(12),

          // ── Trip Details ───────────────────────────────────────────
          _itemRow(
            'Pickup Location',
            draft.pickupLocation.isEmpty ? 'Not specified' : draft.pickupLocation,
            Icons.location_on_outlined,
            AppColors.primary,
            cs,
          ),
          if (draft.dropLocation.isNotEmpty) ...[
            const Gap(8),
            _itemRow(
              draft.tripType == 'Outstation' ? 'Destination' : 'Drop Location',
              draft.dropLocation,
              Icons.flag_outlined,
              Colors.deepOrange,
              cs,
            ),
          ],
          const Gap(8),
          _itemRow(
            'Rental Schedule',
            draft.startDate != null && draft.endDate != null
                ? '${draft.startDate!.toDDMMYYYY()} → ${draft.endDate!.toDDMMYYYY()} (${draft.rentalDays}d)'
                : 'Flexible',
            Icons.calendar_today_outlined,
            AppColors.accent,
            cs,
          ),
          const Gap(8),
          _itemRow(
            'Selected Plan',
            draft.selectedMileagePackage != null
                ? '${draft.selectedMileagePackage!.name} (${draft.selectedMileagePackage!.isUnlimited ? "Unlimited km" : "${draft.selectedMileagePackage!.totalIncludedKm(draft.rentalDays)} km total"})'
                : '${draft.estimatedDistanceKm} km allowance',
            Icons.speed_outlined,
            Colors.indigo,
            cs,
          ),
          if (draft.selectedProtectionPackageId != null ||
              draft.hasDoorstepDelivery ||
              draft.hasAdditionalDriver ||
              draft.childSeat ||
              draft.extraLuggage) ...[
            const Gap(12),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
            const Gap(10),
            Text(
              'Included Add-ons & Coverage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Gap(6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (draft.selectedProtectionPackageId == 'zero_dep_tier')
                  _chip('Premium Zero-Dep', Colors.green, cs),
                if (draft.selectedProtectionPackageId == 'standard_tier')
                  _chip('Standard Protection', Colors.teal, cs),
                if (draft.hasDoorstepDelivery)
                  _chip('Doorstep Delivery (+₹400)', AppColors.primary, cs),
                if (draft.hasAdditionalDriver)
                  _chip('Additional Driver (+₹350)', Colors.teal, cs),
                if (draft.childSeat) _chip('Child Seat', AppColors.accent, cs),
                if (draft.extraLuggage)
                  _chip('Extra Luggage', Colors.blueGrey, cs),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ColorScheme cs,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const Gap(8),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _carPlaceholder(ColorScheme cs) {
    return Container(
      width: 72,
      height: 54,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.directions_car, color: cs.outline, size: 24),
    );
  }
}
