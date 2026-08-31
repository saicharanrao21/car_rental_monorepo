import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../recently_viewed_providers.dart';
import '../../../wishlist/wishlist_providers.dart';

/// DriveGo Design System (DDS) — Recently Viewed Cars Widget
class HomeRecentlyViewedWidget extends ConsumerWidget {
  const HomeRecentlyViewedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyViewedVal = ref.watch(recentlyViewedCarsProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    return recentlyViewedVal.when(
      data: (recentCars) {
        if (recentCars.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DriveGoSectionHeader(title: 'Recently Viewed'),
            const Gap(12),
            SizedBox(
              height: 310,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: recentCars.length,
                itemBuilder: (context, index) {
                  final car = recentCars[index];
                  final isWishlisted = wishlistedIds.contains(car.id);

                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 14),
                    child: CarCard(
                      car: car,
                      imageHeight: 120,
                      isWishlisted: isWishlisted,
                      onWishlistToggle: () {
                        ref.read(wishlistIdsProvider.notifier).toggle(car.id);
                      },
                      onTap: () => context.push('/car/${car.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
