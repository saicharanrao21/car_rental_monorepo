import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';

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
                      setModalState(() {
                        // updates internal state range variable
                      });
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

  Widget _buildFilterBar(BuildContext context, WidgetRef ref) {
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

  @override
  Widget build(BuildContext context) {
    final resultsVal = ref.watch(searchResultsProvider);
    final city = ref.watch(searchCityProvider);
    final tripType = ref.watch(searchTripTypeProvider);
    final dates = ref.watch(searchDatesProvider);
    final sortBy = ref.watch(sortByProvider);

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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              subtitleText,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(context, ref),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: AppDropdown<String>(
              label: 'Sort By',
              value: sortBy,
              items: const [
                DropdownMenuItem(value: 'Relevance', child: Text('Relevance')),
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
                    return CarCard(
                      car: car,
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
