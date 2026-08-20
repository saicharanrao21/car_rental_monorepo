import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';

class HomeQuickCategoriesWidget extends ConsumerWidget {
  const HomeQuickCategoriesWidget({super.key});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Hatchback':
        return Icons.directions_car_outlined;
      case 'Sedan':
        return Icons.local_taxi_outlined;
      case 'SUV':
        return Icons.departure_board_outlined;
      case 'Luxury':
        return Icons.auto_awesome_outlined;
      case 'Tempo Traveller':
        return Icons.airport_shuttle_outlined;
      case 'Mini Bus':
        return Icons.directions_bus_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Popular Car Types'),
        const Gap(12),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: AppConstants.carCategories.length,
            itemBuilder: (context, index) {
              final category = AppConstants.carCategories[index];
              final icon = _getCategoryIcon(category);

              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 95,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    context.push(
                      '/search?city=${Uri.encodeComponent(selectedCity)}&category=${Uri.encodeComponent(category)}',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: AppColors.primary, size: 26),
                        const Gap(6),
                        Text(
                          category,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
