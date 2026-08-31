import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../home/home_providers.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';
import 'search_filter_sheets.dart';

class SearchTripDetailsForm extends ConsumerStatefulWidget {
  final String tripType;
  final TextEditingController pickupController;
  final TextEditingController dropController;
  final DateTimeRange? initialDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onSubmit;

  const SearchTripDetailsForm({
    super.key,
    required this.tripType,
    required this.pickupController,
    required this.dropController,
    required this.initialDateRange,
    required this.onDateRangeChanged,
    required this.onSubmit,
  });

  @override
  ConsumerState<SearchTripDetailsForm> createState() => _SearchTripDetailsFormState();
}

class _SearchTripDetailsFormState extends ConsumerState<SearchTripDetailsForm> {
  DateTimeRange? _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialDateRange;
  }

  IconData _getTripTypeIcon(String type) {
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

  void _showCitySelector() {
    final selectedCity = ref.read(searchCityProvider);
    final supportedCitiesVal = ref.read(supportedCitiesProvider);

    DriveGoBottomSheet.show(
      context,
      title: 'Select City',
      child: supportedCitiesVal.when(
        data: (cities) {
          final cityList = cities.isNotEmpty
              ? cities.map((c) => c.name).toList()
              : AppConstants.indianCities;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: cityList.map((cityName) {
              final isSelected = cityName.toLowerCase() == selectedCity.toLowerCase();
              return ListTile(
                title: Text(
                  cityName,
                  style: DDSTypography.titleMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue) : null,
                onTap: () {
                  ref.read(searchCityProvider.notifier).state = cityName;
                  ref.read(selectedCityProvider.notifier).state = cityName;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConstants.indianCities.map((cityName) {
            final isSelected = cityName.toLowerCase() == selectedCity.toLowerCase();
            return ListTile(
              title: Text(
                cityName,
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue) : null,
              onTap: () {
                ref.read(searchCityProvider.notifier).state = cityName;
                ref.read(selectedCityProvider.notifier).state = cityName;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(searchCityProvider);
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    final isOutstationOrAirport = widget.tripType == 'Outstation' || widget.tripType == 'Airport Transfer';

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: DDSColors.surfaceCard,
              borderRadius: DDSRadius.mediumBorderRadius,
              border: Border.all(color: DDSColors.borderLight),
              boxShadow: DDSElevation.subtleShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: DDSRadius.smallBorderRadius,
                      ),
                      child: Icon(_getTripTypeIcon(widget.tripType), color: DDSColors.primaryBlue, size: 24),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Details — ${widget.tripType}',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Configure your schedule & locations',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: DDSColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        SearchFilterSheets.showTripTypeSheet(
                          context: context,
                          currentTripType: widget.tripType,
                          enabledTripTypes: enabledTripTypes,
                          onTripTypeSelected: (newType) {
                            ref.read(searchTripTypeProvider.notifier).state = newType;
                            ref.read(selectedTripTypeProvider.notifier).state = newType;
                          },
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: DDSColors.primaryBlue),
                      label: Text(
                        'Change',
                        style: DDSTypography.labelLarge.copyWith(
                          color: DDSColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                const Divider(height: 1, color: DDSColors.borderLight),
                const Gap(16),

                // City Selector Tile
                GestureDetector(
                  onTap: _showCitySelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: DDSColors.surfaceSubtle,
                      borderRadius: DDSRadius.smallBorderRadius,
                      border: Border.all(color: DDSColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_city_rounded, color: DDSColors.primaryBlue, size: 20),
                            const Gap(12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Service City', style: DDSTypography.labelSmall.copyWith(color: DDSColors.textMuted)),
                                Text(
                                  city,
                                  style: DDSTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: DDSColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: DDSColors.primaryBlue),
                      ],
                    ),
                  ),
                ),
                const Gap(16),

                // Pickup location
                GestureDetector(
                  onTap: () {
                    LocationSelectionSheet.show(
                      context: context,
                      title: widget.tripType == 'Airport Transfer'
                          ? 'Select Airport / Terminal'
                          : 'Select Pickup Location',
                      initialValue: widget.pickupController.text,
                      city: city,
                      onLocationSelected: (loc, {lat, lng}) {
                        setState(() {
                          widget.pickupController.text = loc;
                        });
                      },
                    );
                  },
                  child: AbsorbPointer(
                    child: AppTextField(
                      label: widget.tripType == 'Airport Transfer'
                          ? 'Airport / Terminal'
                          : 'Pickup Location / Locality',
                      hint: widget.tripType == 'Airport Transfer'
                          ? 'e.g. Terminal 2, CSIA'
                          : 'Enter pickup area in $city',
                      controller: widget.pickupController,
                      prefixIcon: const Icon(Icons.location_on_outlined, color: DDSColors.primaryBlue),
                      suffixIcon: const Icon(Icons.search_rounded, size: 18, color: DDSColors.textMuted),
                    ),
                  ),
                ),
                const Gap(16),

                // Drop location for Outstation / Airport
                if (isOutstationOrAirport) ...[
                  GestureDetector(
                    onTap: () {
                      LocationSelectionSheet.show(
                        context: context,
                        title: widget.tripType == 'Outstation'
                            ? 'Select Destination City / Address'
                            : 'Select Drop-off Address',
                        initialValue: widget.dropController.text,
                        city: city,
                        isDropLocation: true,
                        onLocationSelected: (loc, {lat, lng}) {
                          setState(() {
                            widget.dropController.text = loc;
                          });
                        },
                      );
                    },
                    child: AbsorbPointer(
                      child: AppTextField(
                        label: widget.tripType == 'Outstation'
                            ? 'Destination City / Address'
                            : 'Drop-off Address',
                        hint: widget.tripType == 'Outstation'
                            ? 'e.g. Pune / Lonavala'
                            : 'Enter drop destination',
                        controller: widget.dropController,
                        prefixIcon: const Icon(Icons.flag_outlined, color: DDSColors.primaryBlue),
                        suffixIcon: const Icon(Icons.search_rounded, size: 18, color: DDSColors.textMuted),
                      ),
                    ),
                  ),
                  const Gap(16),
                ],

                // Dates & Schedule
                AppDateRangePicker(
                  label: 'Rental Schedule',
                  hint: 'Select pickup and return dates',
                  initialDateRange: _currentRange,
                  onDateRangeSelected: (range) {
                    setState(() {
                      _currentRange = range;
                    });
                    widget.onDateRangeChanged(range);
                  },
                ),
                const Gap(24),

                DriveGoButton(
                  text: 'Search Available Cars',
                  size: DriveGoButtonSize.large,
                  isFullWidth: true,
                  onPressed: widget.onSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
