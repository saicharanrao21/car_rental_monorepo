import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';

/// DriveGo Design System (DDS) — Quick Categories Carousel for Customer Home
class HomeQuickCategoriesWidget extends ConsumerWidget {
  const HomeQuickCategoriesWidget({super.key});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Hatchback':
        return Icons.directions_car_rounded;
      case 'Sedan':
        return Icons.local_taxi_rounded;
      case 'SUV':
        return Icons.departure_board_rounded;
      case 'Luxury':
        return Icons.auto_awesome_rounded;
      case 'Tempo Traveller':
        return Icons.airport_shuttle_rounded;
      case 'Mini Bus':
        return Icons.directions_bus_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DriveGoSectionHeader(
          title: 'Popular Car Types',
          actionText: 'View All',
          onActionPressed: () {
            context.push('/search?city=${Uri.encodeComponent(selectedCity)}');
          },
        ),
        const Gap(12),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: AppConstants.carCategories.length,
            itemBuilder: (context, index) {
              final category = AppConstants.carCategories[index];
              final icon = _getCategoryIcon(category);

              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 100,
                child: Material(
                  color: DDSColors.surfaceCard,
                  borderRadius: DDSRadius.mediumBorderRadius,
                  child: InkWell(
                    borderRadius: DDSRadius.mediumBorderRadius,
                    onTap: () {
                      context.push(
                        '/search?city=${Uri.encodeComponent(selectedCity)}&category=${Uri.encodeComponent(category)}',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: DDSRadius.mediumBorderRadius,
                        border: Border.all(color: DDSColors.borderLight),
                        boxShadow: DDSElevation.subtleShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: DDSColors.primaryBlue.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: DDSColors.primaryBlue, size: 22),
                          ),
                          const Gap(6),
                          Text(
                            category,
                            style: DDSTypography.labelSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
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
  }
}
