import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarIdentitySection extends StatelessWidget {
  final CarModel car;
  final VendorModel vendor;
  final int reviewsCount;

  const CarIdentitySection({
    super.key,
    required this.car,
    required this.vendor,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    final rating = car.rating > 0 ? car.rating : vendor.rating;
    final isVerified = vendor.verificationStatus.toLowerCase() == 'verified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Status Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car.make} ${car.model}',
                    style: DDSTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    '${car.year} • ${car.fuelType} • ${car.seating} Seats • ${car.type}',
                    style: DDSTypography.bodyMedium.copyWith(
                      color: DDSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            DriveGoStatusBadge(
              label: car.isAvailable ? 'AVAILABLE' : 'BLOCKED',
              variant: car.isAvailable
                  ? DriveGoBadgeVariant.success
                  : DriveGoBadgeVariant.error,
            ),
          ],
        ),
        const Gap(10),

        // Partner Trust Tag & Rating Pill
        Row(
          children: [
            // Rating pill
            if (rating > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DDSSpacing.xs,
                  vertical: DDSSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DDSRadius.small),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const Gap(4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: DDSTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (reviewsCount > 0) ...[
                const Gap(6),
                Text(
                  '($reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'})',
                  style: DDSTypography.labelSmall.copyWith(
                    color: DDSColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Gap(12),
            ],

            // Partner Verified Badge
            if (isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DDSSpacing.xs,
                  vertical: DDSSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: DDSColors.infoBlueBg,
                  borderRadius: BorderRadius.circular(DDSRadius.small),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified,
                      size: 13,
                      color: DDSColors.primaryBlue,
                    ),
                    const Gap(4),
                    Text(
                      'Partner in ${vendor.city}',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
