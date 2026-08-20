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
    final priceRange = ref.watch(searchPriceRangeFilterProvider);
    final minRating = ref.watch(searchRatingFilterProvider);
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    // Count active custom filters (excluding trip type which is primary)
    var activeFilterCount = 0;
    if (selectedCarCategory != null) activeFilterCount++;
    if (isAC == true) activeFilterCount++;
    if (priceRange != null) activeFilterCount++;
    if (minRating != null) activeFilterCount++;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ── 1. Clear All Filters (if any filter active) ────────────────────
          if (activeFilterCount > 0) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ref.read(searchCarCategoryFilterProvider.notifier).state = null;
                ref.read(searchACFilterProvider.notifier).state = null;
                ref.read(searchPriceRangeFilterProvider.notifier).state = null;
                ref.read(searchRatingFilterProvider.notifier).state = null;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.clear, size: 14, color: Colors.red),
                    const Gap(4),
                    Text(
                      'Clear ($activeFilterCount)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(8),
          ],

          // ── 2. Trip Type Pill ──────────────────────────────────────────────
          _buildPill(
            icon: Icons.swap_horiz,
            label: currentTripType,
            isActive: true,
            onTap: () {
              SearchFilterSheets.showTripTypeSheet(
                context: context,
                currentTripType: currentTripType,
                enabledTripTypes: enabledTripTypes,
                onTripTypeSelected: (newType) {
                  ref.read(searchTripTypeProvider.notifier).state = newType;
                  ref.read(selectedTripTypeProvider.notifier).state = newType;
                  ref.read(searchCarCategoryFilterProvider.notifier).state = null;
                },
              );
            },
          ),
          const Gap(8),

          // ── 3. Category / Car Type Pill ───────────────────────────────────
          _buildPill(
            icon: Icons.directions_car_outlined,
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

          // ── 4. AC Only Toggle Pill ────────────────────────────────────────
          _buildPill(
            icon: Icons.ac_unit,
            label: isAC == true ? 'AC Only' : 'AC / Non-AC',
            isActive: isAC == true,
            onTap: () {
              ref.read(searchACFilterProvider.notifier).state = isAC == true ? null : true;
            },
          ),
          const Gap(8),

          // ── 5. Price Range Pill ───────────────────────────────────────────
          _buildPill(
            icon: Icons.currency_rupee,
            label: priceRange != null
                ? '₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}'
                : 'Price Range',
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

          // ── 6. Rating Filter Pill ─────────────────────────────────────────
          _buildPill(
            icon: Icons.star_border,
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey[800],
            ),
            const Gap(5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
