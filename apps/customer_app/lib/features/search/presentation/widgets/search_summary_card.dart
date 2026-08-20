import 'package:flutter/material.dart';
import 'package:core/core.dart';
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
        return Icons.directions_car_outlined;
      case 'Outstation':
        return Icons.alt_route_outlined;
      case 'Local':
        return Icons.location_city_outlined;
      case 'Airport Transfer':
        return Icons.flight_takeoff_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOutstationOrAirport = tripType == 'Outstation' || tripType == 'Airport Transfer';
    final hasDrop = isOutstationOrAirport && drop != null && drop!.isNotEmpty;

    final durationDays = dates != null ? dates!.duration.inDays : 0;
    final durationText = durationDays > 0 ? ' ($durationDays ${durationDays == 1 ? 'day' : 'days'})' : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Trip Type Icon Avatar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getTripTypeIcon(tripType),
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const Gap(10),

          // ── Search Context Information ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location & Trip Type
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      pickup != null && pickup!.isNotEmpty ? '$pickup, $city' : city,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tripType,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Optional Destination drop if Outstation
                if (hasDrop) ...[
                  const Gap(2),
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 11, color: Colors.orange[800]),
                      const Gap(4),
                      Expanded(
                        child: Text(
                          'To $drop',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const Gap(2),

                // Bottom line: Dates & duration
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: cs.onSurfaceVariant,
                    ),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        dates != null
                            ? '${dates!.start.toDDMMYYYY()} → ${dates!.end.toDDMMYYYY()}$durationText'
                            : 'Flexible Schedule',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
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
          OutlinedButton(
            onPressed: onEditPressed,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Change Search',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
