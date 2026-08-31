import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';

/// DriveGo Design System (DDS) — Popular Destination Cities Discovery Widget
class HomePopularCitiesWidget extends ConsumerWidget {
  const HomePopularCitiesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final supportedCitiesVal = ref.watch(supportedCitiesProvider);

    return supportedCitiesVal.when(
      data: (cities) {
        if (cities.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DriveGoSectionHeader(title: 'Explore Popular Cities'),
            const Gap(12),
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final city = cities[index];
                  final isSelected = city.name.toLowerCase() == selectedCity.toLowerCase();

                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: isSelected ? DDSColors.primaryBlue : DDSColors.surfaceCard,
                      borderRadius: DDSRadius.mediumBorderRadius,
                      child: InkWell(
                        borderRadius: DDSRadius.mediumBorderRadius,
                        onTap: () {
                          ref.read(selectedCityProvider.notifier).state = city.name;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: DDSRadius.mediumBorderRadius,
                            border: Border.all(
                              color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
                            ),
                            boxShadow: isSelected ? DDSElevation.subtleShadow : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_city_rounded,
                                    size: 18,
                                    color: isSelected ? Colors.white : DDSColors.primaryBlue,
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                              const Gap(8),
                              Text(
                                city.name,
                                style: DDSTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : DDSColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Gap(2),
                              Text(
                                city.state,
                                style: DDSTypography.labelSmall.copyWith(
                                  fontSize: 10,
                                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : DDSColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
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
