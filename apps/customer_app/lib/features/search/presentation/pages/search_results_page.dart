import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../home/home_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

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
      if (widget.start.isNotEmpty && widget.end.isNotEmpty) {
        try {
          final startDt = DateTime.parse(widget.start);
          final endDt = DateTime.parse(widget.end);
          ref.read(searchDatesProvider.notifier).state = DateTimeRange(start: startDt, end: endDt);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final tripType = ref.watch(searchTripTypeProvider);
    final city = ref.watch(searchCityProvider);

    if (tripType == null || tripType.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Choose Trip Type'),
        ),
        body: _buildTripTypeSelectionView(context, ref),
      );
    }

    final resultsVal = ref.watch(searchResultsProvider);
    final dates = ref.watch(searchDatesProvider);
    final sortBy = ref.watch(sortByProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    final titleText = resultsVal.when(
      data: (state) => '${state.items.length} cars in $city',
      loading: () => 'Searching in $city',
      error: (_, __) => 'Error in $city',
    );

    final subtitleText = dates != null
        ? '${dates.start.toDDMMYYYY()} - ${dates.end.toDDMMYYYY()} • $tripType'
        : 'Flexible dates • $tripType';

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
              subtitleText,
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
                    title: 'No Cars Found',
                    subtitle: 'Try adjusting your filters or location search.',
                    actionText: 'Reset Filters',
                    onActionPressed: () {
                      ref.read(searchCarCategoryFilterProvider.notifier).state = null;
                      ref.read(searchACFilterProvider.notifier).state = null;
                      ref.read(searchPriceRangeFilterProvider.notifier).state = null;
                      ref.read(searchRatingFilterProvider.notifier).state = null;
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
