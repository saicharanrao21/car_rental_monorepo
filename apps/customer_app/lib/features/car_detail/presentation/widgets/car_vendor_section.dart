import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarVendorSection extends StatelessWidget {
  final VendorModel vendor;
  final List<ReviewModel> reviews;

  const CarVendorSection({
    super.key,
    required this.vendor,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final vendorDisplayName = vendor.displayName ?? vendor.businessName;
    final isVerified = vendor.verificationStatus.toLowerCase() == 'verified';

    // Compute review metrics if real reviews exist
    final totalReviewsCount = reviews.length;
    final starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    double totalRatingSum = 0;
    for (var review in reviews) {
      totalRatingSum += review.rating;
      final rounded = review.rating.round();
      if (starCounts.containsKey(rounded)) {
        starCounts[rounded] = starCounts[rounded]! + 1;
      }
    }
    final averageRating =
        totalReviewsCount > 0 ? totalRatingSum / totalReviewsCount : vendor.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Vendor / Host Card ───────────────────────────────────────────
        Text(
          'Hosted by',
          style: DDSTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: BorderRadius.circular(DDSRadius.medium),
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: DDSColors.infoBlueBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: DDSColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                vendorDisplayName,
                                style: DDSTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: DDSColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const Gap(6),
                              const Icon(
                                Icons.verified,
                                color: DDSColors.primaryBlue,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const Gap(2),
                        Text(
                          vendor.locality != null
                              ? '${vendor.locality}, ${vendor.city}'
                              : vendor.city,
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(14),
              const Divider(height: 1, color: DDSColors.borderLight),
              const Gap(14),
              Row(
                children: [
                  // Host Rating
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const Gap(4),
                            Text(
                              vendor.rating.toStringAsFixed(1),
                              style: DDSTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: DDSColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(2),
                        Text(
                          'Host Rating',
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    color: DDSColors.borderLight,
                  ),
                  // Completed Trips
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${vendor.totalTrips}+',
                          style: DDSTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Trips Hosted',
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    color: DDSColors.borderLight,
                  ),
                  // Verification
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          isVerified ? 'Verified' : 'Pending',
                          style: DDSTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isVerified
                                ? DDSColors.successGreen
                                : DDSColors.warningOrange,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Partner Status',
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 2. Real Customer Reviews Section ─────────────────────────────────
        if (reviews.isNotEmpty) ...[
          const Gap(24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Reviews ($totalReviewsCount)',
                style: DDSTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const Gap(4),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: DDSTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.take(3).length,
            separatorBuilder: (_, __) => const Gap(10),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Container(
                padding: const EdgeInsets.all(DDSSpacing.md),
                decoration: BoxDecoration(
                  color: DDSColors.surfaceCard,
                  borderRadius: BorderRadius.circular(DDSRadius.medium),
                  border: Border.all(color: DDSColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verified Customer',
                          style: DDSTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (starIndex) => Icon(
                              starIndex < review.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (review.comment.isNotEmpty) ...[
                      const Gap(6),
                      Text(
                        review.comment,
                        style: DDSTypography.bodyMedium.copyWith(
                          color: DDSColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
