import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';
import '../../../wishlist/wishlist_providers.dart';

/// DriveGo Design System (DDS) — Available Cars Discovery Section
class HomeAvailableCarsSection extends ConsumerWidget {
  final VoidCallback onSelectCityPressed;

  const HomeAvailableCarsSection({
    super.key,
    required this.onSelectCityPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final availableCarsVal = ref.watch(availableCarsProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    return availableCarsVal.when(
      data: (cars) {
        if (cars.isEmpty) {
          final emptyTitle = selectedCity.isNotEmpty
              ? 'No Cars Available in $selectedCity'
              : 'No Cars Available Nearby';
          final actionText = selectedCity.isNotEmpty
              ? 'Choose Another City'
              : 'Select Your City';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DriveGoEmptyState(
              title: emptyTitle,
              subtitle: 'We are expanding rapidly! Try choosing a different pickup city or check back soon.',
              icon: Icons.directions_car_outlined,
              actionText: actionText,
              onActionPressed: onSelectCityPressed,
            ),
          );
        }

        final sectionTitle = selectedCity.isNotEmpty
            ? 'Available in $selectedCity'
            : 'Available Nearby';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DriveGoSectionHeader(
              title: sectionTitle,
              actionText: 'See all (${cars.length})',
              onActionPressed: () {
                context.go('/search?city=${Uri.encodeComponent(selectedCity)}');
              },
            ),
            const Gap(12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cars.length > 5 ? 5 : cars.length,
              itemBuilder: (context, index) {
                final car = cars[index];
                final isWishlisted = wishlistedIds.contains(car.id);

                return CarCard(
                  car: car,
                  isWishlisted: isWishlisted,
                  onWishlistToggle: () {
                    ref.read(wishlistIdsProvider.notifier).toggle(car.id);
                  },
                  onTap: () => context.push('/car/${car.id}'),
                );
              },
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriveGoSectionHeader(
            title: 'Available in $selectedCity',
          ),
          const Gap(12),
          const DriveGoLoadingState(
            variant: DriveGoLoadingVariant.list,
            itemCount: 2,
          ),
        ],
      ),
      error: (err, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriveGoSectionHeader(
            title: 'Available in $selectedCity',
          ),
          const Gap(12),
          DriveGoErrorState(
            title: 'Could not load vehicles',
            message: 'Unable to fetch cars for $selectedCity. Please check your connection.',
            onRetry: () => ref.invalidate(availableCarsProvider),
          ),
        ],
      ),
    );
  }
}
