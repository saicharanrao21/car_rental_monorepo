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

  void _showCitySelector() {
    final selectedCity = ref.read(searchCityProvider);
    final supportedCitiesVal = ref.read(supportedCitiesProvider);

    AppBottomSheet.show(
      context,
      title: 'Select City',
      child: supportedCitiesVal.when(
        data: (cities) => Column(
          mainAxisSize: MainAxisSize.min,
          children: cities.map((city) {
            final isSelected = city.name.toLowerCase() == selectedCity.toLowerCase();
            return ListTile(
              title: Text(city.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () {
                ref.read(searchCityProvider.notifier).state = city.name;
                ref.read(selectedCityProvider.notifier).state = city.name;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Mumbai', 'Delhi NCR', 'Bengaluru', 'Hyderabad', 'Pune'].map((cityName) {
            final isSelected = cityName.toLowerCase() == selectedCity.toLowerCase();
            return ListTile(
              title: Text(cityName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
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
    final cs = Theme.of(context).colorScheme;
    final city = ref.watch(searchCityProvider);
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    final isOutstationOrAirport = widget.tripType == 'Outstation' || widget.tripType == 'Airport Transfer';

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getTripTypeIcon(widget.tripType), color: AppColors.primary, size: 24),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Details — ${widget.tripType}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const Gap(2),
                          Text(
                            'Configure your schedule & locations',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                ),
                const Gap(16),
                const Divider(height: 1),
                const Gap(16),

                // City Selector Tile
                GestureDetector(
                  onTap: _showCitySelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_city, color: AppColors.primary, size: 20),
                            const Gap(12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Service City', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                Text(city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
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
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      suffixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
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
                        prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.primary),
                        suffixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
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

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: widget.onSubmit,
                  child: const Text(
                    'Search Available Cars',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
