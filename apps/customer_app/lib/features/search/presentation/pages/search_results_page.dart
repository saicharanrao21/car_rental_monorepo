import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../home/home_providers.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';

class SearchResultsPage extends ConsumerStatefulWidget {
  final String city;
  final String tripType;
  final String start;
  final String end;
  final String pickup;
  final String drop;
  final String category;

  const SearchResultsPage({
    super.key,
    required this.city,
    required this.tripType,
    required this.start,
    required this.end,
    required this.pickup,
    required this.drop,
    required this.category,
  });

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  final _scrollController = ScrollController();
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  bool _isEditingTripDetails = false;
  DateTimeRange? _formDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (widget.pickup.isNotEmpty) {
      _pickupController.text = widget.pickup;
    }
    if (widget.drop.isNotEmpty) {
      _dropController.text = widget.drop;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.city.isNotEmpty) {
        ref.read(searchCityProvider.notifier).state = widget.city;
      }
      if (widget.tripType.isNotEmpty) {
        ref.read(searchTripTypeProvider.notifier).state = widget.tripType;
        ref.read(selectedTripTypeProvider.notifier).state = widget.tripType;
      }
      if (widget.category.isNotEmpty) {
        ref.read(searchCarCategoryFilterProvider.notifier).state = widget.category;
      }
      if (widget.pickup.isNotEmpty) {
        ref.read(searchPickupLocationProvider.notifier).state = widget.pickup;
        ref.read(pickupLocationProvider.notifier).state = widget.pickup;
      }
      if (widget.drop.isNotEmpty) {
        ref.read(searchDropLocationProvider.notifier).state = widget.drop;
        ref.read(dropLocationProvider.notifier).state = widget.drop;
      }
      if (widget.start.isNotEmpty && widget.end.isNotEmpty) {
        try {
          final startDt = DateTime.parse(widget.start);
          final endDt = DateTime.parse(widget.end);
          final range = DateTimeRange(start: startDt, end: endDt);
          ref.read(searchDatesProvider.notifier).state = range;
          ref.read(selectedDateRangeProvider.notifier).state = range;
          setState(() {
            _formDateRange = range;
          });
        } catch (_) {}
      } else {
        final existingDates = ref.read(selectedDateRangeProvider) ?? ref.read(searchDatesProvider);
        if (existingDates != null) {
          ref.read(searchDatesProvider.notifier).state = existingDates;
          setState(() {
            _formDateRange = existingDates;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchResultsProvider.notifier).loadMore();
    }
  }

  bool _isTripTypeEnabled(String type, List<String> enabledTypes) {
    final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
      return enabledTypes.contains('AIRPORT_TRANSFER');
    }
    return enabledTypes.contains(norm);
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
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
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
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
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

  void _showTripTypeBottomSheet(BuildContext context, WidgetRef ref) {
    final currentTripType = ref.read(searchTripTypeProvider);
    final publicSettingsVal = ref.read(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    AppBottomSheet.show(
      context,
      title: 'Select Trip Type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...AppConstants.tripTypes.map((type) {
            final isEnabled = _isTripTypeEnabled(type, enabledTripTypes);
            final isSelected = type == currentTripType;
            return ListTile(
              enabled: isEnabled,
              leading: Icon(_getTripTypeIcon(type), color: isEnabled ? AppColors.primary : Colors.grey),
              title: Text(
                type,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isEnabled ? null : Colors.grey,
                ),
              ),
              subtitle: !isEnabled ? const Text('Coming soon', style: TextStyle(fontSize: 11)) : null,
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: isEnabled
                  ? () {
                      ref.read(searchTripTypeProvider.notifier).state = type;
                      ref.read(selectedTripTypeProvider.notifier).state = type;
                      ref.read(searchCarCategoryFilterProvider.notifier).state = null;
                      Navigator.pop(context);
                    }
                  : null,
            );
          }),
        ],
      ),
    );
  }

  void _showCarTypeBottomSheet(BuildContext context, WidgetRef ref) {
    final selected = ref.read(searchCarCategoryFilterProvider);
    AppBottomSheet.show(
      context,
      title: 'Select Car Type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('All Types'),
            trailing: selected == null ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              ref.read(searchCarCategoryFilterProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          ...AppConstants.carCategories.map((type) {
            final isSelected = type == selected;
            return ListTile(
              title: Text(type),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(searchCarCategoryFilterProvider.notifier).state = type;
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  void _showPriceRangeBottomSheet(BuildContext context, WidgetRef ref) {
    final range = ref.read(searchPriceRangeFilterProvider) ?? const RangeValues(0, 20000);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Price Range (per day)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(searchPriceRangeFilterProvider.notifier).state = null;
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const Gap(24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${range.start.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${range.end.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  RangeSlider(
                    values: range,
                    min: 0,
                    max: 20000,
                    divisions: 40,
                    activeColor: AppColors.primary,
                    onChanged: (values) {
                      setModalState(() {});
                      ref.read(searchPriceRangeFilterProvider.notifier).state = values;
                    },
                  ),
                  const Gap(24),
                  AppButton(
                    text: 'Apply Filter',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRatingBottomSheet(BuildContext context, WidgetRef ref) {
    final selectedRating = ref.read(searchRatingFilterProvider);
    AppBottomSheet.show(
      context,
      title: 'Filter by Minimum Rating',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Any Rating'),
            trailing: selectedRating == null ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              ref.read(searchRatingFilterProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          ...[4.5, 4.0, 3.5, 3.0].map((rating) {
            final isSelected = selectedRating == rating;
            return ListTile(
              title: Row(
                children: [
                  StarRating(rating: rating),
                  const Gap(8),
                  Text('${rating.toStringAsFixed(1)}+ Stars'),
                ],
              ),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(searchRatingFilterProvider.notifier).state = rating;
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, String currentTripType) {
    final selectedCarCategory = ref.watch(searchCarCategoryFilterProvider);
    final isAC = ref.watch(searchACFilterProvider);
    final priceRange = ref.watch(searchPriceRangeFilterProvider);
    final minRating = ref.watch(searchRatingFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            avatar: const Icon(Icons.swap_horiz, size: 16),
            label: Text(currentTripType),
            selected: true,
            onSelected: (_) => _showTripTypeBottomSheet(context, ref),
          ),
          const Gap(8),
          FilterChip(
            label: Text(selectedCarCategory ?? 'Car Type'),
            selected: selectedCarCategory != null,
            onSelected: (_) => _showCarTypeBottomSheet(context, ref),
          ),
          const Gap(8),
          FilterChip(
            label: Text(isAC == true ? 'AC only' : 'AC / Non-AC'),
            selected: isAC == true,
            onSelected: (_) {
              ref.read(searchACFilterProvider.notifier).state = isAC == true ? null : true;
            },
          ),
          const Gap(8),
          FilterChip(
            label: Text(priceRange != null
                ? '₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}'
                : 'Price Range'),
            selected: priceRange != null,
            onSelected: (_) => _showPriceRangeBottomSheet(context, ref),
          ),
          const Gap(8),
          FilterChip(
            label: Text(minRating != null ? '${minRating.toStringAsFixed(1)}+ ★' : 'Rating'),
            selected: minRating != null,
            onSelected: (_) => _showRatingBottomSheet(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTypeSelectionView(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    final tripOptions = [
      (
        type: 'Self-Drive',
        title: 'Self-Drive Cars',
        subtitle: 'Drive yourself with flexible daily & mileage packages',
        icon: Icons.directions_car_outlined,
        badge: 'Popular',
      ),
      (
        type: 'Outstation',
        title: 'Outstation Travel',
        subtitle: 'Comfortable long distance rides across cities',
        icon: Icons.alt_route_outlined,
        badge: 'Intercity',
      ),
      (
        type: 'Local',
        title: 'Local City Rentals',
        subtitle: 'Hourly and daily rentals within city limits',
        icon: Icons.location_city_outlined,
        badge: null,
      ),
      (
        type: 'Airport Transfer',
        title: 'Airport Transfer',
        subtitle: 'Reliable pickup & drop to and from airports',
        icon: Icons.flight_takeoff_outlined,
        badge: null,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select your trip type to find the best available cars',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Gap(16),
          ...tripOptions.map((opt) {
            final isEnabled = _isTripTypeEnabled(opt.type, enabledTripTypes);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isEnabled
                    ? () {
                        ref.read(searchTripTypeProvider.notifier).state = opt.type;
                        ref.read(selectedTripTypeProvider.notifier).state = opt.type;
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${opt.type} is coming soon.')),
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEnabled ? cs.outline.withValues(alpha: 0.5) : cs.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? cs.primaryContainer.withValues(alpha: 0.7)
                              : cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          opt.icon,
                          color: isEnabled ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          size: 28,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    opt.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isEnabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (opt.badge != null && isEnabled) ...[
                                  const Gap(8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      opt.badge!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (!isEnabled) ...[
                                  const Gap(8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Gap(4),
                            Text(
                              opt.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isEnabled ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _submitTripSearchForm(String tripType) {
    final now = DateTime.now();
    final defaultRange = _formDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).add(const Duration(days: 5, hours: 10)),
          end: DateTime(now.year, now.month, now.day).add(const Duration(days: 7, hours: 10)),
        );

    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();

    ref.read(searchDatesProvider.notifier).state = defaultRange;
    ref.read(selectedDateRangeProvider.notifier).state = defaultRange;

    ref.read(searchPickupLocationProvider.notifier).state = pickup.isEmpty ? null : pickup;
    ref.read(pickupLocationProvider.notifier).state = pickup.isEmpty ? null : pickup;

    ref.read(searchDropLocationProvider.notifier).state = drop.isEmpty ? null : drop;
    ref.read(dropLocationProvider.notifier).state = drop.isEmpty ? null : drop;

    setState(() {
      _isEditingTripDetails = false;
      _formDateRange = defaultRange;
    });
  }

  Widget _buildTripSearchDetailsForm(BuildContext context, WidgetRef ref, String tripType) {
    final cs = Theme.of(context).colorScheme;
    final city = ref.watch(searchCityProvider);
    final now = DateTime.now();
    final defaultStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 5, hours: 10));
    final defaultEnd = DateTime(now.year, now.month, now.day).add(const Duration(days: 7, hours: 10));
    final currentRange = _formDateRange ?? ref.watch(searchDatesProvider) ?? DateTimeRange(start: defaultStart, end: defaultEnd);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getTripTypeIcon(tripType), color: cs.primary, size: 24),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Details — $tripType',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Gap(2),
                          Text(
                            'Enter your schedule to find available cars',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showTripTypeBottomSheet(context, ref),
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // City Selector
                GestureDetector(
                  onTap: _showCitySelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
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
                      title: tripType == 'Airport Transfer'
                          ? 'Select Airport / Terminal'
                          : 'Select Pickup Location',
                      initialValue: _pickupController.text,
                      city: city,
                      onLocationSelected: (loc, {lat, lng}) {
                        setState(() {
                          _pickupController.text = loc;
                        });
                      },
                    );
                  },
                  child: AbsorbPointer(
                    child: AppTextField(
                      label: tripType == 'Airport Transfer'
                          ? 'Airport / Terminal'
                          : 'Pickup Location / Locality',
                      hint: tripType == 'Airport Transfer'
                          ? 'e.g. Terminal 2, CSIA'
                          : 'Enter pickup area in $city',
                      controller: _pickupController,
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      suffixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    ),
                  ),
                ),
                const Gap(16),

                // Drop location for Outstation / Airport
                if (tripType == 'Outstation' || tripType == 'Airport Transfer') ...[
                  GestureDetector(
                    onTap: () {
                      LocationSelectionSheet.show(
                        context: context,
                        title: tripType == 'Outstation'
                            ? 'Select Destination City / Address'
                            : 'Select Drop-off Address',
                        initialValue: _dropController.text,
                        city: city,
                        isDropLocation: true,
                        onLocationSelected: (loc, {lat, lng}) {
                          setState(() {
                            _dropController.text = loc;
                          });
                        },
                      );
                    },
                    child: AbsorbPointer(
                      child: AppTextField(
                        label: tripType == 'Outstation'
                            ? 'Destination City / Address'
                            : 'Drop-off Address',
                        hint: tripType == 'Outstation'
                            ? 'e.g. Pune / Lonavala'
                            : 'Enter drop destination',
                        controller: _dropController,
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
                  initialDateRange: currentRange,
                  onDateRangeSelected: (range) {
                    setState(() {
                      _formDateRange = range;
                    });
                  },
                ),
                const Gap(24),

                AppButton(
                  text: 'Search Available Cars',
                  onPressed: () => _submitTripSearchForm(tripType),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummaryBar(BuildContext context, WidgetRef ref, String city, String tripType, DateTimeRange? dates) {
    final cs = Theme.of(context).colorScheme;
    final pickup = ref.watch(searchPickupLocationProvider) ?? ref.watch(pickupLocationProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getTripTypeIcon(tripType), color: AppColors.primary, size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        pickup != null && pickup.isNotEmpty ? '$pickup, $city' : city,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tripType,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const Gap(2),
                Text(
                  dates != null
                      ? '${dates.start.toDDMMYYYY()} → ${dates.end.toDDMMYYYY()}'
                      : 'Flexible dates',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isEditingTripDetails = true;
                _formDateRange = dates;
              });
            },
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Change Search', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripType = ref.watch(searchTripTypeProvider);
    final city = ref.watch(searchCityProvider);
    final dates = ref.watch(searchDatesProvider);

    // 1. If no trip type selected, show Trip Type Decision View
    if (tripType == null || tripType.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Choose Trip Type'),
        ),
        body: _buildTripTypeSelectionView(context, ref),
      );
    }

    // 2. If editing trip details or dates not yet set, show Trip Search Details Form
    if (_isEditingTripDetails || dates == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trip Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (dates != null && _isEditingTripDetails) {
                setState(() {
                  _isEditingTripDetails = false;
                });
              } else {
                ref.read(searchTripTypeProvider.notifier).state = null;
              }
            },
          ),
        ),
        body: _buildTripSearchDetailsForm(context, ref, tripType),
      );
    }

    // 3. Show filtered search results
    final resultsVal = ref.watch(searchResultsProvider);
    final sortBy = ref.watch(sortByProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    final titleText = resultsVal.when(
      data: (state) => '${state.items.length} available in $city',
      loading: () => 'Finding available cars...',
      error: (_, __) => 'Error in $city',
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            Text(
              '${dates.start.toDDMMYYYY()} → ${dates.end.toDDMMYYYY()} • $tripType',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchSummaryBar(context, ref, city, tripType, dates),
          _buildFilterBar(context, ref, tripType),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: AppDropdown<String>(
              label: 'Sort By',
              value: sortBy,
              items: const [
                DropdownMenuItem(value: 'Recommended', child: Text('Recommended')),
                DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
                DropdownMenuItem(value: 'Price Low-High', child: Text('Price Low-High')),
                DropdownMenuItem(value: 'Price High-Low', child: Text('Price High-Low')),
                DropdownMenuItem(value: 'Rating', child: Text('Rating')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(sortByProvider.notifier).state = val;
                }
              },
            ),
          ),
          const Gap(8),
          Expanded(
            child: resultsVal.when(
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'No Available Cars',
                    subtitle: 'No vehicles are available for the selected dates and filters. Try adjusting your trip dates or filters.',
                    actionText: 'Change Trip Dates',
                    onActionPressed: () {
                      setState(() {
                        _isEditingTripDetails = true;
                      });
                    },
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      if (state.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: AppLoader(),
                        );
                      } else if (state.hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: AppButton(
                            text: 'Load More',
                            onPressed: () => ref.read(searchResultsProvider.notifier).loadMore(),
                          ),
                        );
                      } else {
                        return const Gap(16);
                      }
                    }

                    final car = state.items[index];
                    final isWishlisted = wishlistedIds.contains(car.id);
                    return CarCard(
                      car: car,
                      isWishlisted: isWishlisted,
                      onWishlistToggle: () {
                        ref.read(wishlistIdsProvider.notifier).toggle(car.id);
                      },
                      onTap: () {
                        context.push('/car/${car.id}');
                      },
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                itemBuilder: (context, index) => const ShimmerCard(),
              ),
              error: (err, stack) => ErrorStateWidget(
                message: 'Failed to search cars: ${err.toString()}',
                onRetry: () => ref.invalidate(searchResultsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
