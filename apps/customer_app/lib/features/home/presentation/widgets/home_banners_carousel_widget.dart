import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';

/// DriveGo Design System (DDS) — Promotional Banners Carousel for Customer Home
class HomeBannersCarouselWidget extends ConsumerWidget {
  const HomeBannersCarouselWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersVal = ref.watch(bannersProvider);

    return bannersVal.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DriveGoSectionHeader(title: 'Exclusive Offers'),
            const Gap(12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return Container(
                    width: 290,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      borderRadius: DDSRadius.largeBorderRadius,
                      boxShadow: DDSElevation.subtleShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: DDSRadius.largeBorderRadius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            banner.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: DDSColors.surfaceSubtle,
                              child: const Icon(Icons.image_outlined, color: DDSColors.textMuted, size: 40),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Color(0xCC0F172A), // Slate 900 gradient overlay
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DDSColors.accentAmber,
                                    borderRadius: DDSRadius.smallBorderRadius,
                                  ),
                                  child: const Text(
                                    'PROMO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  banner.title,
                                  style: DDSTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriveGoSectionHeader(title: 'Exclusive Offers'),
          Gap(12),
          DriveGoLoadingState(variant: DriveGoLoadingVariant.card, itemCount: 1),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
