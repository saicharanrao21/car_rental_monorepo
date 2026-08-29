import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gap/gap.dart';

enum DriveGoLoadingVariant {
  fullPage,
  card,
  list,
  inline,
}

/// DriveGo Design System (DDS) — Unified Loading Component
class DriveGoLoadingState extends StatelessWidget {
  final DriveGoLoadingVariant variant;
  final String? message;
  final int itemCount;

  const DriveGoLoadingState({
    super.key,
    this.variant = DriveGoLoadingVariant.fullPage,
    this.message,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case DriveGoLoadingVariant.inline:
        return const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DDSColors.primaryBlue,
            ),
          ),
        );

      case DriveGoLoadingVariant.card:
        return const DriveGoShimmerCard();

      case DriveGoLoadingVariant.list:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (_, __) => const DriveGoShimmerCard(),
        );

      case DriveGoLoadingVariant.fullPage:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: DDSColors.primaryBlue,
                ),
              ),
              if (message != null) ...[
                const Gap(16),
                Text(
                  message!,
                  style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// Skeleton Card Placeholder with Smooth Shimmer Wave
class DriveGoShimmerCard extends StatelessWidget {
  const DriveGoShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: DDSRadius.mediumBorderRadius,
        side: const BorderSide(color: DDSColors.borderLight, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF8FAFC),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 18,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: DDSRadius.smallBorderRadius,
                    ),
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      Container(
                        height: 14,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DDSRadius.smallBorderRadius,
                        ),
                      ),
                      const Gap(12),
                      Container(
                        height: 14,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DDSRadius.smallBorderRadius,
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 20,
                        width: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DDSRadius.smallBorderRadius,
                        ),
                      ),
                      Container(
                        height: 38,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DDSRadius.mediumBorderRadius,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
