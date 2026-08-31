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

    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: const Border.fromBorderSide(
          BorderSide(color: DDSColors.borderLight),
        ),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Car Header ─────────────────────────────────────────────
          Row(
            children: [
              ClipRRect(
                borderRadius: DDSRadius.mediumBorderRadius,
                child: car.photos.isNotEmpty
                    ? Image.network(
                        car.photos.first,
                        width: 72,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _carPlaceholder(),
                      )
                    : _carPlaceholder(),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.make} ${car.model} (${car.year})',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      vendor.businessName,
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const Gap(4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DDSColors.infoBlueBg,
                        borderRadius: DDSRadius.smallBorderRadius,
                      ),
                      child: Text(
                        draft.tripType,
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.sm),
          const Divider(
            height: 1,
            color: DDSColors.borderLight,
          ),
          const Gap(DDSSpacing.sm),

          // ── Trip Details ───────────────────────────────────────────
          _itemRow(
            'Pickup Location',
            draft.pickupLocation.isEmpty ? 'Not specified' : draft.pickupLocation,
            Icons.location_on_outlined,
            DDSColors.primaryBlue,
          ),
          if (draft.dropLocation.isNotEmpty) ...[
            const Gap(8),
            _itemRow(
              draft.tripType == 'Outstation' ? 'Destination' : 'Drop Location',
              draft.dropLocation,
              Icons.flag_outlined,
              DDSColors.warningOrange,
            ),
          ],
          const Gap(8),
          _itemRow(
            'Rental Schedule',
            draft.startDate != null && draft.endDate != null
                ? '${draft.startDate!.toDDMMYYYY()} → ${draft.endDate!.toDDMMYYYY()} (${draft.rentalDays}d)'
                : 'Flexible',
            Icons.calendar_today_outlined,
            DDSColors.accentAmber,
          ),
          const Gap(8),
          _itemRow(
            'Selected Plan',
            draft.selectedMileagePackage != null
                ? '${draft.selectedMileagePackage!.name} (${draft.selectedMileagePackage!.isUnlimited ? "Unlimited km" : "${draft.selectedMileagePackage!.totalIncludedKm(draft.rentalDays)} km total"})'
                : '${draft.estimatedDistanceKm} km allowance',
            Icons.speed_outlined,
            DDSColors.primaryBlue,
          ),
          if (draft.selectedProtectionPackageId != null ||
              draft.hasDoorstepDelivery ||
              draft.hasAdditionalDriver ||
              draft.childSeat ||
              draft.extraLuggage) ...[
            const Gap(DDSSpacing.sm),
            const Divider(
              height: 1,
              color: DDSColors.borderLight,
            ),
            const Gap(DDSSpacing.xs),
            Text(
              'Included Add-ons & Coverage',
              style: DDSTypography.titleMedium.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: DDSColors.textPrimary,
              ),
            ),
            const Gap(6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (draft.selectedProtectionPackageId == 'zero_dep_tier')
                  _chip('Premium Zero-Dep', DDSColors.successGreen, DDSColors.successGreenBg),
                if (draft.selectedProtectionPackageId == 'standard_tier')
                  _chip('Standard Protection', DDSColors.infoBlue, DDSColors.infoBlueBg),
                if (draft.hasDoorstepDelivery)
                  _chip('Doorstep Delivery (+₹400)', DDSColors.primaryBlue, DDSColors.infoBlueBg),
                if (draft.hasAdditionalDriver)
                  _chip('Additional Driver (+₹350)', DDSColors.successGreen, DDSColors.successGreenBg),
                if (draft.childSeat) _chip('Child Seat', DDSColors.accentAmber, DDSColors.surfaceSubtle),
                if (draft.extraLuggage)
                  _chip('Extra Luggage', DDSColors.textSecondary, DDSColors.surfaceSubtle),
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
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: DDSTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: DDSColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color fgColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: DDSRadius.smallBorderRadius,
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: DDSTypography.labelSmall.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 72,
      height: 54,
      decoration: BoxDecoration(
        color: DDSColors.surfaceSubtle,
        borderRadius: DDSRadius.mediumBorderRadius,
      ),
      child: const Icon(Icons.directions_car, color: DDSColors.textMuted, size: 24),
    );
  }
}
