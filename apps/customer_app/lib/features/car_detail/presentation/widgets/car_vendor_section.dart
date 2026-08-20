import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
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
    final cs = Theme.of(context).colorScheme;
    final vendorDisplayName = vendor.displayName ?? vendor.businessName;

    // Compute review metrics
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
    final averageRating = totalReviewsCount > 0 ? totalRatingSum / totalReviewsCount : vendor.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Vendor / Host Card ───────────────────────────────────────────
        const Text(
          'Hosted by',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: AppColors.primary,
                      size: 22,
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (vendor.verificationStatus == 'verified') ...[
                              const Gap(6),
                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                            ],
                          ],
                        ),
                        const Gap(2),
                        Text(
                          vendor.locality != null ? '${vendor.locality}, ${vendor.city}' : vendor.city,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
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
              const Divider(height: 1),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 15),
                            const Gap(4),
                            Text(
                              vendor.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Gap(2),
                        Text(
                          'Host Rating',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 24, width: 1, color: cs.outline.withValues(alpha: 0.2)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${vendor.totalTrips}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Trips Completed',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 24, width: 1, color: cs.outline.withValues(alpha: 0.2)),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          '100%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Response',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(24),

        // ── 2. Reviews & Star Breakdown ─────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ratings & Reviews',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (totalReviewsCount > 0)
              Text(
                '$totalReviewsCount verified',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const Gap(4),
                        StarRating(rating: averageRating, size: 15),
                        const Gap(6),
                        Text(
                          '$totalReviewsCount reviews',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 70, width: 1, color: cs.outline.withValues(alpha: 0.15), margin: const EdgeInsets.symmetric(horizontal: 12)),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((level) {
                        final count = starCounts[level] ?? 0;
                        final pct = totalReviewsCount > 0 ? count / totalReviewsCount : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Text('$level ★', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              const Gap(6),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: pct,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(6),
                              SizedBox(
                                width: 18,
                                child: Text(
                                  '$count',
                                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              if (reviews.isNotEmpty) ...[
                const Gap(16),
                const Divider(height: 1),
                const Gap(12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.take(4).length,
                  separatorBuilder: (context, index) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final r = reviews[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Verified Customer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              r.createdAt.toDDMMYYYY(),
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const Gap(4),
                        StarRating(rating: r.rating, size: 13),
                        const Gap(6),
                        Text(
                          r.comment,
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
