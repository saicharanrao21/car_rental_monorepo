import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';
import '../providers/booking_flow_providers.dart';

class BookingTripScheduleCard extends ConsumerWidget {
  final CarModel car;
  final VendorModel vendor;

  const BookingTripScheduleCard({
    super.key,
    required this.car,
    required this.vendor,
  });

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
        return 'Professional chauffeur included • Airport pickup/drop';
      case 'Local':
      default:
        return 'Professional chauffeur included • Intra-city travel';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Vehicle Header Card ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.largeBorderRadius,
            border: const Border.fromBorderSide(
              BorderSide(color: DDSColors.borderLight),
            ),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: DDSRadius.mediumBorderRadius,
                child: car.photos.isNotEmpty
                    ? Image.network(
                        car.photos.first,
                        width: 88,
                        height: 68,
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
                    const Gap(6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _featureBadge(car.type),
                        _featureBadge(car.isAC ? 'AC' : 'Non-AC'),
                        _featureBadge(car.fuelType),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Immutable Service / Trip Type Badge ──────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
          decoration: BoxDecoration(
            color: DDSColors.infoBlueBg,
            borderRadius: DDSRadius.mediumBorderRadius,
            border: Border.all(
              color: DDSColors.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DDSSpacing.xs),
                decoration: BoxDecoration(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getServiceIcon(draft.tripType),
                  color: DDSColors.primaryBlue,
                  size: 20,
                ),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Service: ${draft.tripType}',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DDSColors.primaryBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(DDSSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DDSColors.primaryBlue,
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: Text(
                            'Selected',
                            style: DDSTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      _getServiceSubtitle(draft.tripType),
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Schedule & Locations Card ────────────────────────────────
        Container(
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
              Text(
                'Trip Schedule & Locations',
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DDSColors.textPrimary,
                ),
              ),
              const Gap(DDSSpacing.sm),
              const Divider(
                height: 1,
                color: DDSColors.borderLight,
              ),
              const Gap(DDSSpacing.sm),

              // Pickup Location
              _locationTile(
                context,
                icon: Icons.location_on_outlined,
                iconColor: DDSColors.primaryBlue,
                label: 'Pickup',
                value: draft.pickupLocation.isEmpty
                    ? 'Not specified'
                    : draft.pickupLocation,
                isPlaceholder: draft.pickupLocation.isEmpty,
                onTap: () {
                  LocationSelectionSheet.show(
                    context: context,
                    title: 'Update Pickup Location',
                    initialValue: draft.pickupLocation,
                    city: vendor.city,
                    onLocationSelected: (loc, {lat, lng}) {
                      ref.read(bookingDraftProvider.notifier).update(
                            (d) => d.copyWith(pickupLocation: loc),
                          );
                    },
                  );
                },
              ),
              const Gap(DDSSpacing.sm),

              // Drop / Destination Location (if applicable)
              if (draft.tripType != 'Local') ...[
                _locationTile(
                  context,
                  icon: Icons.flag_outlined,
                  iconColor: DDSColors.warningOrange,
                  label: draft.tripType == 'Outstation' ? 'Destination' : 'Drop',
                  value: draft.dropLocation.isEmpty
                      ? 'Not specified'
                      : draft.dropLocation,
                  isPlaceholder: draft.dropLocation.isEmpty,
                  onTap: () {
                    LocationSelectionSheet.show(
                      context: context,
                      title: draft.tripType == 'Outstation'
                          ? 'Update Destination'
                          : 'Update Drop Location',
                      initialValue: draft.dropLocation,
                      city: vendor.city,
                      isDropLocation: true,
                      onLocationSelected: (loc, {lat, lng}) {
                        ref.read(bookingDraftProvider.notifier).update(
                              (d) => d.copyWith(dropLocation: loc),
                            );
                      },
                    );
                  },
                ),
                const Gap(DDSSpacing.sm),
              ],

              // Rental Dates
              _locationTile(
                context,
                icon: Icons.calendar_today_outlined,
                iconColor: DDSColors.accentAmber,
                label: 'Dates',
                value: draft.startDate != null && draft.endDate != null
                    ? '${draft.startDate!.toDDMMYYYY()} → ${draft.endDate!.toDDMMYYYY()}'
                    : 'Select dates',
                isPlaceholder: draft.startDate == null || draft.endDate == null,
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: today.subtract(const Duration(days: 1)),
                    lastDate: today.add(const Duration(days: 90)),
                    initialDateRange: draft.startDate != null && draft.endDate != null
                        ? DateTimeRange(
                            start: draft.startDate!, end: draft.endDate!)
                        : DateTimeRange(
                            start: today,
                            end: today.add(const Duration(days: 2))),
                  );
                  if (picked != null) {
                    ref.read(bookingDraftProvider.notifier).update(
                          (d) => d.copyWith(
                            startDate: picked.start,
                            endDate: picked.end,
                          ),
                        );
                  }
                },
              ),
              const Gap(DDSSpacing.sm),

              // Duration & Chauffeur Rows
              Container(
                padding: const EdgeInsets.all(DDSSpacing.sm),
                decoration: BoxDecoration(
                  color: DDSColors.surfaceSubtle,
                  borderRadius: DDSRadius.mediumBorderRadius,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.nights_stay_outlined,
                            size: 16,
                            color: DDSColors.textSecondary,
                          ),
                          const Gap(6),
                          Text(
                            'Duration: ',
                            style: DDSTypography.bodyMedium.copyWith(
                              color: DDSColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${draft.rentalDays} day${draft.rentalDays == 1 ? '' : 's'}',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DDSColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin_outlined,
                            size: 16,
                            color: DDSColors.textSecondary,
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              draft.driverIncluded
                                  ? 'Chauffeur Included'
                                  : 'Self-Drive (No Chauffeur)',
                              style: DDSTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DDSColors.textPrimary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isPlaceholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: DDSRadius.mediumBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.sm, vertical: DDSSpacing.xs),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: const Border.fromBorderSide(
            BorderSide(color: DDSColors.borderLight),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const Gap(DDSSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: DDSColors.textMuted,
                    ),
                  ),
                  const Gap(1),
                  Text(
                    value,
                    style: DDSTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPlaceholder
                          ? DDSColors.textMuted
                          : DDSColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Gap(6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: DDSRadius.smallBorderRadius,
                border: const Border.fromBorderSide(
                  BorderSide(color: DDSColors.borderMedium),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change',
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DDSColors.primaryBlue,
                    ),
                  ),
                  const Gap(2),
                  const Icon(
                    Icons.edit_outlined,
                    size: 11,
                    color: DDSColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DDSColors.surfaceSubtle,
        borderRadius: DDSRadius.smallBorderRadius,
        border: const Border.fromBorderSide(BorderSide(color: DDSColors.borderLight)),
      ),
      child: Text(
        text,
        style: DDSTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: DDSColors.textSecondary,
        ),
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 88,
      height: 68,
      decoration: BoxDecoration(
        color: DDSColors.surfaceSubtle,
        borderRadius: DDSRadius.mediumBorderRadius,
      ),
      child: const Icon(Icons.directions_car, color: DDSColors.textMuted, size: 28),
    );
  }
}
