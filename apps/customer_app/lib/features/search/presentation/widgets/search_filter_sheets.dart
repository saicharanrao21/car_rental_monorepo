import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class SearchFilterSheets {
  /// Master Comprehensive Filter Bottom Sheet
  static void showMasterFilterSheet({
    required BuildContext context,
    required String currentTripType,
    required List<String> enabledTripTypes,
    required String? currentCategory,
    required bool? currentIsAC,
    required String? currentFuelType,
    required int? currentSeating,
    required RangeValues? currentPriceRange,
    required double? currentRating,
    required void Function({
      required String tripType,
      required String? category,
      required bool? isAC,
      required String? fuelType,
      required int? seating,
      required RangeValues? priceRange,
      required double? minRating,
    }) onApply,
    required VoidCallback onResetAll,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var tempTripType = currentTripType;
        var tempCategory = currentCategory;
        var tempIsAC = currentIsAC;
        var tempFuelType = currentFuelType;
        var tempSeating = currentSeating;
        var tempPriceRange = currentPriceRange ?? const RangeValues(0, 20000);
        var tempRating = currentRating;

        bool isTripTypeEnabled(String type) {
          final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
          if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
            return enabledTripTypes.contains('AIRPORT_TRANSFER');
          }
          return enabledTripTypes.contains(norm);
        }

        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            var activeCount = 0;
            if (tempCategory != null) activeCount++;
            if (tempIsAC == true) activeCount++;
            if (tempFuelType != null) activeCount++;
            if (tempSeating != null) activeCount++;
            if (currentPriceRange != null || tempPriceRange.start > 0 || tempPriceRange.end < 20000) activeCount++;
            if (tempRating != null) activeCount++;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar with Drag Handle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: DDSColors.borderMedium,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'Filters',
                                      style: DDSTypography.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: DDSColors.textPrimary,
                                      ),
                                    ),
                                    if (activeCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: DDSRadius.smallBorderRadius,
                                        ),
                                        child: Text(
                                          '$activeCount active',
                                          style: DDSTypography.labelSmall.copyWith(
                                            color: DDSColors.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    tempCategory = null;
                                    tempIsAC = null;
                                    tempFuelType = null;
                                    tempSeating = null;
                                    tempPriceRange = const RangeValues(0, 20000);
                                    tempRating = null;
                                  });
                                  onResetAll();
                                },
                                child: Text(
                                  'Reset All',
                                  style: DDSTypography.labelLarge.copyWith(
                                    color: DDSColors.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: DDSColors.borderLight),

                    // Scrollable Filter Sections
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          // 1. Trip Type Section
                          _buildSectionTitle('Trip Type'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: AppConstants.tripTypes.map<Widget>((type) {
                              final isEnabled = isTripTypeEnabled(type);
                              final isSelected = type == tempTripType;
                              return DriveGoChip(
                                label: isEnabled ? type : '$type (Soon)',
                                isSelected: isSelected,
                                onTap: isEnabled
                                    ? () => setModalState(() => tempTripType = type)
                                    : null,
                              );
                            }).toList(),
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 2. Car Category Section
                          _buildSectionTitle('Car Type'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              DriveGoChip(
                                label: 'All Types',
                                isSelected: tempCategory == null,
                                onTap: () => setModalState(() => tempCategory = null),
                              ),
                              ...AppConstants.carCategories.map<Widget>((cat) {
                                final isSelected = cat == tempCategory;
                                return DriveGoChip(
                                  label: cat,
                                  isSelected: isSelected,
                                  onTap: () => setModalState(() => tempCategory = isSelected ? null : cat),
                                );
                              }),
                            ],
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 3. Price Range Slider Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: _buildSectionTitle('Price Range (per day)')),
                              const Gap(8),
                              Flexible(
                                child: Text(
                                  '₹${tempPriceRange.start.toInt()} - ₹${tempPriceRange.end.toInt()}',
                                  style: DDSTypography.titleMedium.copyWith(
                                    color: DDSColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          RangeSlider(
                            values: tempPriceRange,
                            min: 0,
                            max: 20000,
                            divisions: 40,
                            activeColor: DDSColors.primaryBlue,
                            inactiveColor: DDSColors.primaryBlue.withValues(alpha: 0.15),
                            onChanged: (values) {
                              setModalState(() {
                                tempPriceRange = values;
                              });
                            },
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 4. Fuel Type Section
                          _buildSectionTitle('Fuel Type'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              DriveGoChip(
                                label: 'Any Fuel',
                                isSelected: tempFuelType == null,
                                onTap: () => setModalState(() => tempFuelType = null),
                              ),
                              ...['Petrol', 'Diesel', 'Electric', 'CNG', 'Hybrid'].map<Widget>((fuel) {
                                final isSelected = tempFuelType?.toLowerCase() == fuel.toLowerCase();
                                return DriveGoChip(
                                  label: fuel,
                                  isSelected: isSelected,
                                  onTap: () => setModalState(() => tempFuelType = isSelected ? null : fuel),
                                );
                              }),
                            ],
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 5. Seating Capacity Section
                          _buildSectionTitle('Seating Capacity'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              DriveGoChip(
                                label: 'Any Seats',
                                isSelected: tempSeating == null,
                                onTap: () => setModalState(() => tempSeating = null),
                              ),
                              ...[4, 5, 6, 7].map<Widget>((seats) {
                                final isSelected = tempSeating == seats;
                                return DriveGoChip(
                                  label: '$seats+ Seats',
                                  isSelected: isSelected,
                                  onTap: () => setModalState(() => tempSeating = isSelected ? null : seats),
                                );
                              }),
                            ],
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 6. Air Conditioning Section
                          _buildSectionTitle('Air Conditioning'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              DriveGoChip(
                                label: 'All (AC & Non-AC)',
                                isSelected: tempIsAC == null,
                                onTap: () => setModalState(() => tempIsAC = null),
                              ),
                              DriveGoChip(
                                label: 'AC Only',
                                isSelected: tempIsAC == true,
                                onTap: () => setModalState(() => tempIsAC = tempIsAC == true ? null : true),
                              ),
                            ],
                          ),

                          const Gap(20),
                          const Divider(height: 1, color: DDSColors.borderLight),
                          const Gap(16),

                          // 7. Host Rating Section
                          _buildSectionTitle('Minimum Rating'),
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              DriveGoChip(
                                label: 'Any Rating',
                                isSelected: tempRating == null,
                                onTap: () => setModalState(() => tempRating = null),
                              ),
                              ...[4.5, 4.0, 3.5].map<Widget>((rating) {
                                final isSelected = tempRating == rating;
                                return DriveGoChip(
                                  label: '${rating.toStringAsFixed(1)}+ ★',
                                  isSelected: isSelected,
                                  onTap: () => setModalState(() => tempRating = isSelected ? null : rating),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Sticky Bottom Apply Action
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: const BoxDecoration(
                        color: DDSColors.surfaceCard,
                        border: Border(top: BorderSide(color: DDSColors.borderLight)),
                      ),
                      child: DriveGoButton(
                        text: activeCount > 0 ? 'Apply Filters ($activeCount)' : 'Apply Filters',
                        size: DriveGoButtonSize.large,
                        isFullWidth: true,
                        onPressed: () {
                          final isPriceChanged = tempPriceRange.start > 0 || tempPriceRange.end < 20000;
                          onApply(
                            tripType: tempTripType,
                            category: tempCategory,
                            isAC: tempIsAC,
                            fuelType: tempFuelType,
                            seating: tempSeating,
                            priceRange: isPriceChanged ? tempPriceRange : null,
                            minRating: tempRating,
                          );
                          Navigator.pop(ctx);
                        },
                      ),
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

  /// Sort Options Modal Sheet
  static void showSortSheet({
    required BuildContext context,
    required String currentSort,
    required ValueChanged<String> onSortSelected,
  }) {
    final sortOptions = [
      (label: 'Recommended', description: 'Best overall match by DriveGo ranking'),
      (label: 'Nearest', description: 'Closest vehicles based on your location'),
      (label: 'Price Low-High', description: 'Lowest rental price per day first'),
      (label: 'Price High-Low', description: 'Highest rental price per day first'),
      (label: 'Rating', description: 'Top rated fleet partner vehicles first'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
      ),
      backgroundColor: DDSColors.surfaceCard,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort By',
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: DDSColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(10),
                ...sortOptions.map((opt) {
                  final isSelected = opt.label == currentSort;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: DDSRadius.smallBorderRadius,
                        side: BorderSide(
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
                        ),
                      ),
                      tileColor: isSelected ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                      title: Text(
                        opt.label,
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        opt.description,
                        style: DDSTypography.bodyMedium.copyWith(
                          color: DDSColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
                          : const Icon(Icons.radio_button_unchecked_rounded, color: DDSColors.borderMedium, size: 22),
                      onTap: () {
                        onSortSelected(opt.label);
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

  /// Single Quick Sheet for Trip Type
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
          return Icons.directions_car_rounded;
        case 'Outstation':
          return Icons.alt_route_rounded;
        case 'Local':
          return Icons.location_city_rounded;
        case 'Airport Transfer':
          return Icons.flight_takeoff_rounded;
        default:
          return Icons.directions_car_rounded;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
      ),
      backgroundColor: DDSColors.surfaceCard,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Trip Type',
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: DDSColors.textMuted),
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
                        borderRadius: DDSRadius.smallBorderRadius,
                        side: BorderSide(
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
                        ),
                      ),
                      tileColor: isSelected ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                      leading: Icon(
                        getTripTypeIcon(type),
                        color: isEnabled ? (isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary) : DDSColors.textMuted,
                      ),
                      title: Text(
                        type,
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isEnabled ? (isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary) : DDSColors.textMuted,
                        ),
                      ),
                      subtitle: !isEnabled
                          ? Text('Launching soon', style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted))
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
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

  /// Single Quick Sheet for Car Type
  static void showCarTypeSheet({
    required BuildContext context,
    required String? currentCategory,
    required ValueChanged<String?> onCategorySelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
      ),
      backgroundColor: DDSColors.surfaceCard,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Car Type',
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: DDSColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: DDSRadius.smallBorderRadius,
                    side: BorderSide(
                      color: currentCategory == null ? DDSColors.primaryBlue : DDSColors.borderLight,
                    ),
                  ),
                  tileColor: currentCategory == null ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                  title: Text(
                    'All Types',
                    style: DDSTypography.titleMedium.copyWith(
                      fontWeight: currentCategory == null ? FontWeight.bold : FontWeight.w600,
                      color: currentCategory == null ? DDSColors.primaryBlue : DDSColors.textPrimary,
                    ),
                  ),
                  trailing: currentCategory == null
                      ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
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
                        borderRadius: DDSRadius.smallBorderRadius,
                        side: BorderSide(
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
                        ),
                      ),
                      tileColor: isSelected ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                      title: Text(
                        type,
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
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

  /// Single Quick Sheet for Price Range
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
      ),
      backgroundColor: DDSColors.surfaceCard,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: DDSColors.borderMedium,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price Range (per day)',
                          style: DDSTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            onRangeApplied(null);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Reset',
                            style: DDSTypography.labelLarge.copyWith(
                              color: DDSColors.errorRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                            color: DDSColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: Text(
                            '₹${tempRange.start.toInt()}',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.primaryBlue,
                            ),
                          ),
                        ),
                        Text(
                          'to',
                          style: DDSTypography.bodyMedium.copyWith(
                            color: DDSColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: DDSColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: Text(
                            '₹${tempRange.end.toInt()}',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.primaryBlue,
                            ),
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
                      activeColor: DDSColors.primaryBlue,
                      inactiveColor: DDSColors.primaryBlue.withValues(alpha: 0.2),
                      onChanged: (values) {
                        setModalState(() {
                          tempRange = values;
                        });
                      },
                    ),
                    const Gap(20),
                    DriveGoButton(
                      text: 'Apply Price Range',
                      size: DriveGoButtonSize.large,
                      isFullWidth: true,
                      onPressed: () {
                        onRangeApplied(tempRange);
                        Navigator.pop(ctx);
                      },
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

  /// Single Quick Sheet for Rating
  static void showRatingSheet({
    required BuildContext context,
    required double? currentRating,
    required ValueChanged<double?> onRatingSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DDSRadius.large)),
      ),
      backgroundColor: DDSColors.surfaceCard,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Rating',
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: DDSColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: DDSRadius.smallBorderRadius,
                    side: BorderSide(
                      color: currentRating == null ? DDSColors.primaryBlue : DDSColors.borderLight,
                    ),
                  ),
                  tileColor: currentRating == null ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                  title: Text(
                    'Any Rating',
                    style: DDSTypography.titleMedium.copyWith(
                      fontWeight: currentRating == null ? FontWeight.bold : FontWeight.w600,
                      color: currentRating == null ? DDSColors.primaryBlue : DDSColors.textPrimary,
                    ),
                  ),
                  trailing: currentRating == null
                      ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
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
                        borderRadius: DDSRadius.smallBorderRadius,
                        side: BorderSide(
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
                        ),
                      ),
                      tileColor: isSelected ? DDSColors.primaryBlue.withValues(alpha: 0.06) : null,
                      title: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: DDSColors.accentAmber),
                          const Gap(6),
                          Text(
                            '${rating.toStringAsFixed(1)}+ Stars',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 22)
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

  static Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: DDSTypography.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: DDSColors.textPrimary,
      ),
    );
  }
}
