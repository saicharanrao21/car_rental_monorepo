import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class SelectedTripSummaryCard extends StatelessWidget {
  final DateTimeRange? dates;
  final String? tripType;
  final String? pickup;
  final String? drop;
  final String city;
  final VoidCallback? onChangeSearch;

  const SelectedTripSummaryCard({
    super.key,
    required this.dates,
    required this.tripType,
    required this.city,
    this.pickup,
    this.drop,
    this.onChangeSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (dates == null) {
      return Container(
        padding: const EdgeInsets.all(DDSSpacing.md),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(DDSRadius.medium),
          border: Border.all(color: DDSColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DDSSpacing.xs),
              decoration: const BoxDecoration(
                color: DDSColors.infoBlueBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: DDSColors.primaryBlue,
                size: 18,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select dates to check availability',
                    style: DDSTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    'Choose dates to confirm accurate pricing',
                    style: DDSTypography.labelSmall.copyWith(
                      color: DDSColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Gap(8),
            DriveGoButton(
              text: 'Search',
              isFullWidth: false,
              size: DriveGoButtonSize.compact,
              variant: DriveGoButtonVariant.primary,
              onPressed: onChangeSearch ?? () => context.push('/search'),
            ),
          ],
        ),
      );
    }

    final durationDays = dates!.duration.inDays;
    final durationText = durationDays > 0
        ? '$durationDays ${durationDays == 1 ? 'day' : 'days'}'
        : '1 day';
    final hasDrop = drop != null && drop!.isNotEmpty && tripType == 'Outstation';

    return Container(
      decoration: BoxDecoration(
        color: DDSColors.successGreenBg,
        borderRadius: BorderRadius.circular(DDSRadius.medium),
        border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(DDSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Checkmark & Title & Change Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(DDSSpacing.xxs),
                decoration: BoxDecoration(
                  color: DDSColors.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: DDSColors.successGreen,
                  size: 16,
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  'Available for your schedule',
                  style: DDSTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.successGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: onChangeSearch ?? () => context.push('/search'),
                borderRadius: BorderRadius.circular(DDSRadius.small),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSSpacing.xs + 2,
                    vertical: DDSSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DDSRadius.small),
                    border: Border.all(
                      color: DDSColors.successGreen.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Change',
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DDSColors.successGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(10),
          const Divider(height: 1, color: DDSColors.borderLight),
          const Gap(10),

          // Details Columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP & LOCATION',
                      style: DDSTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      pickup != null && pickup!.isNotEmpty
                          ? '$pickup, $city'
                          : city,
                      style: DDSTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: DDSColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasDrop) ...[
                      const Gap(2),
                      Text(
                        'Drop: $drop',
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.warningOrange,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RENTAL SCHEDULE',
                      style: DDSTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      '${dates!.start.toDDMMYYYY()} → ${dates!.end.toDDMMYYYY()}',
                      style: DDSTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: DDSColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      '$durationText • ${tripType ?? 'Self-Drive'}',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
