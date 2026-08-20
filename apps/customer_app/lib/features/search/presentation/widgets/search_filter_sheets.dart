import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class SearchFilterSheets {
  static void showTripTypeSheet({
    required BuildContext context,
    required String currentTripType,
    required List<String> enabledTripTypes,
    required ValueChanged<String> onTripTypeSelected,
  }) {
    bool isTripTypeEnabled(String type) {
      final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
      if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
        return enabledTripTypes.contains('AIRPORT_TRANSFER');
      }
      return enabledTripTypes.contains(norm);
    }

    IconData getTripTypeIcon(String type) {
      switch (type) {
        case 'Self-Drive':
          return Icons.directions_car_outlined;
        case 'Outstation':
          return Icons.alt_route_outlined;
        case 'Local':
          return Icons.location_city_outlined;
        case 'Airport Transfer':
          return Icons.flight_takeoff_outlined;
        default:
          return Icons.directions_car_outlined;
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Trip Type',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                ...AppConstants.tripTypes.map((type) {
                  final isEnabled = isTripTypeEnabled(type);
                  final isSelected = type == currentTripType;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      enabled: isEnabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : cs.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
                      leading: Icon(
                        getTripTypeIcon(type),
                        color: isEnabled ? (isSelected ? AppColors.primary : cs.onSurface) : Colors.grey,
                      ),
                      title: Text(
                        type,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isEnabled ? null : Colors.grey,
                        ),
                      ),
                      subtitle: !isEnabled
                          ? const Text('Launching soon', style: TextStyle(fontSize: 11, color: Colors.grey))
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: isEnabled
                          ? () {
                              onTripTypeSelected(type);
                              Navigator.pop(ctx);
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showCarTypeSheet({
    required BuildContext context,
    required String? currentCategory,
    required ValueChanged<String?> onCategorySelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Car Category',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: currentCategory == null ? AppColors.primary : cs.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  tileColor: currentCategory == null ? AppColors.primary.withValues(alpha: 0.06) : null,
                  title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: currentCategory == null
                      ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    onCategorySelected(null);
                    Navigator.pop(ctx);
                  },
                ),
                const Gap(8),
                ...AppConstants.carCategories.map((type) {
                  final isSelected = type == currentCategory;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : cs.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
                      title: Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        onCategorySelected(type);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showPriceRangeSheet({
    required BuildContext context,
    required RangeValues? currentRange,
    required ValueChanged<RangeValues?> onRangeApplied,
  }) {
    var tempRange = currentRange ?? const RangeValues(0, 20000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price Range (per day)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            onRangeApplied(null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${tempRange.start.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                        ),
                        const Text('to', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${tempRange.end.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    RangeSlider(
                      values: tempRange,
                      min: 0,
                      max: 20000,
                      divisions: 40,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                      onChanged: (values) {
                        setModalState(() {
                          tempRange = values;
                        });
                      },
                    ),
                    const Gap(20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        onRangeApplied(tempRange);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply Filter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showRatingSheet({
    required BuildContext context,
    required double? currentRating,
    required ValueChanged<double?> onRatingSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Rating',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: currentRating == null ? AppColors.primary : cs.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  tileColor: currentRating == null ? AppColors.primary.withValues(alpha: 0.06) : null,
                  title: const Text('Any Rating', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: currentRating == null
                      ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    onRatingSelected(null);
                    Navigator.pop(ctx);
                  },
                ),
                const Gap(8),
                ...[4.5, 4.0, 3.5, 3.0].map((rating) {
                  final isSelected = currentRating == rating;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : cs.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
                      title: Row(
                        children: [
                          StarRating(rating: rating),
                          const Gap(8),
                          Text('${rating.toStringAsFixed(1)}+ Stars', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        onRatingSelected(rating);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
