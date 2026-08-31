import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../home/home_providers.dart';
import 'search_filter_sheets.dart';

class SearchFilterBarWidget extends ConsumerWidget {
  final String currentTripType;

  const SearchFilterBarWidget({
    super.key,
    required this.currentTripType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCarCategory = ref.watch(searchCarCategoryFilterProvider);
    final isAC = ref.watch(searchACFilterProvider);
    final fuelType = ref.watch(searchFuelTypeFilterProvider);
    final seating = ref.watch(searchSeatingFilterProvider);
    final priceRange = ref.watch(searchPriceRangeFilterProvider);
    final minRating = ref.watch(searchRatingFilterProvider);
    final sortBy = ref.watch(sortByProvider);
    final activeFilterCount = ref.watch(activeFilterCountProvider);

    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    void openMasterFilters() {
      SearchFilterSheets.showMasterFilterSheet(
        context: context,
        currentTripType: currentTripType,
        enabledTripTypes: enabledTripTypes,
        currentCategory: selectedCarCategory,
        currentIsAC: isAC,
        currentFuelType: fuelType,
        currentSeating: seating,
        currentPriceRange: priceRange,
        currentRating: minRating,
        onApply: ({
          required String tripType,
          required String? category,
          required bool? isAC,
          required String? fuelType,
          required int? seating,
          required RangeValues? priceRange,
          required double? minRating,
        }) {
          ref.read(searchTripTypeProvider.notifier).state = tripType;
          ref.read(selectedTripTypeProvider.notifier).state = tripType;
          ref.read(searchCarCategoryFilterProvider.notifier).state = category;
          ref.read(searchACFilterProvider.notifier).state = isAC;
          ref.read(searchFuelTypeFilterProvider.notifier).state = fuelType;
          ref.read(searchSeatingFilterProvider.notifier).state = seating;
          ref.read(searchPriceRangeFilterProvider.notifier).state = priceRange;
          ref.read(searchRatingFilterProvider.notifier).state = minRating;
        },
        onResetAll: () {
          ref.read(searchCarCategoryFilterProvider.notifier).state = null;
          ref.read(searchACFilterProvider.notifier).state = null;
          ref.read(searchFuelTypeFilterProvider.notifier).state = null;
          ref.read(searchSeatingFilterProvider.notifier).state = null;
          ref.read(searchPriceRangeFilterProvider.notifier).state = null;
          ref.read(searchRatingFilterProvider.notifier).state = null;
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ── 1. Master "Filters" Button with Count ──────────────────────────
          InkWell(
            borderRadius: DDSRadius.pillBorderRadius,
            onTap: openMasterFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: activeFilterCount > 0
                    ? DDSColors.primaryBlue.withValues(alpha: 0.12)
                    : DDSColors.surfaceCard,
                borderRadius: DDSRadius.pillBorderRadius,
                border: Border.all(
                  color: activeFilterCount > 0
                      ? DDSColors.primaryBlue
                      : DDSColors.borderMedium,
                  width: activeFilterCount > 0 ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: activeFilterCount > 0
                        ? DDSColors.primaryBlue
                        : DDSColors.textPrimary,
                  ),
                  const Gap(6),
                  Text(
                    activeFilterCount > 0 ? 'Filters ($activeFilterCount)' : 'Filters',
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activeFilterCount > 0
                          ? DDSColors.primaryBlue
                          : DDSColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),

          // ── 2. Clear All Filters (if active) ──────────────────────────────
          if (activeFilterCount > 0) ...[
            InkWell(
              borderRadius: DDSRadius.pillBorderRadius,
              onTap: () {
                ref.read(searchCarCategoryFilterProvider.notifier).state = null;
                ref.read(searchACFilterProvider.notifier).state = null;
                ref.read(searchFuelTypeFilterProvider.notifier).state = null;
                ref.read(searchSeatingFilterProvider.notifier).state = null;
                ref.read(searchPriceRangeFilterProvider.notifier).state = null;
                ref.read(searchRatingFilterProvider.notifier).state = null;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: DDSColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: DDSRadius.pillBorderRadius,
                  border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close_rounded, size: 14, color: DDSColors.errorRed),
                    const Gap(4),
                    Text(
                      'Clear ($activeFilterCount)',
                      style: DDSTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(8),
          ],

          // ── 3. Sort By Pill ───────────────────────────────────────────────
          _buildPill(
            icon: Icons.sort_rounded,
            label: 'Sort: $sortBy',
            isActive: sortBy != 'Recommended',
            onTap: () {
              SearchFilterSheets.showSortSheet(
                context: context,
                currentSort: sortBy,
                onSortSelected: (val) {
                  ref.read(sortByProvider.notifier).state = val;
                },
              );
            },
          ),
          const Gap(8),

          // ── 4. Car Type Pill ──────────────────────────────────────────────
          _buildPill(
            icon: Icons.directions_car_rounded,
            label: selectedCarCategory ?? 'Car Type',
            isActive: selectedCarCategory != null,
            onTap: () {
              SearchFilterSheets.showCarTypeSheet(
                context: context,
                currentCategory: selectedCarCategory,
                onCategorySelected: (cat) {
                  ref.read(searchCarCategoryFilterProvider.notifier).state = cat;
                },
              );
            },
          ),
          const Gap(8),

          // ── 5. Price Range Pill ───────────────────────────────────────────
          _buildPill(
            icon: Icons.currency_rupee_rounded,
            label: priceRange != null
                ? '₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}'
                : 'Price',
            isActive: priceRange != null,
            onTap: () {
              SearchFilterSheets.showPriceRangeSheet(
                context: context,
                currentRange: priceRange,
                onRangeApplied: (range) {
                  ref.read(searchPriceRangeFilterProvider.notifier).state = range;
                },
              );
            },
          ),
          const Gap(8),

          // ── 6. AC Only Toggle Pill ────────────────────────────────────────
          _buildPill(
            icon: Icons.ac_unit_rounded,
            label: isAC == true ? 'AC Only' : 'AC',
            isActive: isAC == true,
            onTap: () {
              ref.read(searchACFilterProvider.notifier).state = isAC == true ? null : true;
            },
          ),
          const Gap(8),

          // ── 7. Rating Filter Pill ─────────────────────────────────────────
          _buildPill(
            icon: Icons.star_rounded,
            label: minRating != null ? '${minRating.toStringAsFixed(1)}+ ★' : 'Rating',
            isActive: minRating != null,
            onTap: () {
              SearchFilterSheets.showRatingSheet(
                context: context,
                currentRating: minRating,
                onRatingSelected: (r) {
                  ref.read(searchRatingFilterProvider.notifier).state = r;
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: DDSRadius.pillBorderRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? DDSColors.primaryBlue : DDSColors.surfaceCard,
          borderRadius: DDSRadius.pillBorderRadius,
          border: Border.all(
            color: isActive ? DDSColors.primaryBlue : DDSColors.borderMedium,
          ),
          boxShadow: isActive ? DDSElevation.subtleShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : DDSColors.textSecondary,
            ),
            const Gap(5),
            Text(
              label,
              style: DDSTypography.labelSmall.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.white : DDSColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
