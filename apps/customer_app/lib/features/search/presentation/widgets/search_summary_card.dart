import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class SearchSummaryCard extends StatelessWidget {
  final String city;
  final String tripType;
  final String? pickup;
  final String? drop;
  final DateTimeRange? dates;
  final VoidCallback onEditPressed;

  const SearchSummaryCard({
    super.key,
    required this.city,
    required this.tripType,
    required this.onEditPressed,
    this.pickup,
    this.drop,
    this.dates,
  });

  IconData _getTripTypeIcon(String type) {
    switch (type) {
      case 'Self-Drive':
        return Icons.directions_car_rounded;
      case 'Outstation':
        return Icons.alt_route_rounded;
      case 'Local':
        return Icons.location_city_rounded;
      case 'Airport Transfer':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutstationOrAirport = tripType == 'Outstation' || tripType == 'Airport Transfer';
    final hasDrop = isOutstationOrAirport && drop != null && drop!.isNotEmpty;

    final durationDays = dates != null ? dates!.duration.inDays : 0;
    final durationText = durationDays > 0 ? ' ($durationDays ${durationDays == 1 ? 'day' : 'days'})' : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.mediumBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.subtleShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Trip Type Icon Avatar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: DDSColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: DDSRadius.smallBorderRadius,
            ),
            child: Icon(
              _getTripTypeIcon(tripType),
              color: DDSColors.primaryBlue,
              size: 22,
            ),
          ),
          const Gap(12),

          // ── Search Context Information ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location & Trip Type Pill
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      pickup != null && pickup!.isNotEmpty ? '$pickup, $city' : city,
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: DDSColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: DDSRadius.smallBorderRadius,
                      ),
                      child: Text(
                        tripType,
                        style: DDSTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: DDSColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),

                // Optional Destination drop if Outstation
                if (hasDrop) ...[
                  const Gap(3),
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, size: 12, color: DDSColors.warningOrange),
                      const Gap(4),
                      Expanded(
                        child: Text(
                          'To $drop',
                          style: DDSTypography.bodyMedium.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: DDSColors.warningOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const Gap(3),

                // Bottom line: Dates & duration
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: DDSColors.textMuted,
                    ),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        dates != null
                            ? '${dates!.start.toDDMMYYYY()} → ${dates!.end.toDDMMYYYY()}$durationText'
                            : 'Flexible Schedule',
                        style: DDSTypography.bodyMedium.copyWith(
                          fontSize: 11,
                          color: DDSColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Gap(8),

          // ── Change Search Action ──────────────────────────────────────────
          DriveGoButton(
            text: 'Change',
            variant: DriveGoButtonVariant.secondary,
            size: DriveGoButtonSize.compact,
            isFullWidth: false,
            onPressed: onEditPressed,
          ),
        ],
      ),
    );
  }
}
