import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../home/home_providers.dart';
import '../widgets/search_car_card.dart';
import '../widgets/search_summary_card.dart';
import '../widgets/search_filter_bar_widget.dart';
import '../widgets/choose_trip_type_view.dart';
import '../widgets/search_trip_details_form.dart';

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

  @override
  Widget build(BuildContext context) {
    final tripType = ref.watch(searchTripTypeProvider);
    final city = ref.watch(searchCityProvider);
    final dates = ref.watch(searchDatesProvider);
    final pickup = ref.watch(searchPickupLocationProvider) ?? ref.watch(pickupLocationProvider);
    final drop = ref.watch(searchDropLocationProvider) ?? ref.watch(dropLocationProvider);

    // 1. If no trip type selected, show Trip Type Decision View
    if (tripType == null || tripType.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Choose Trip Type'),
        ),
        body: const ChooseTripTypeView(),
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
        body: SearchTripDetailsForm(
          tripType: tripType,
          pickupController: _pickupController,
          dropController: _dropController,
          initialDateRange: _formDateRange ?? dates,
          onDateRangeChanged: (range) {
            _formDateRange = range;
          },
          onSubmit: () => _submitTripSearchForm(tripType),
        ),
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
          // ── Search Summary Header Card ──────────────────────────────────────
          SearchSummaryCard(
            city: city,
            tripType: tripType,
            pickup: pickup,
            drop: drop,
            dates: dates,
            onEditPressed: () {
              setState(() {
                _isEditingTripDetails = true;
                _formDateRange = dates;
              });
            },
          ),

          // ── Responsive Filter Bar ──────────────────────────────────────────
          SearchFilterBarWidget(currentTripType: tripType),

          // ── Sort By Dropdown ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
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
          const Gap(4),

          // ── Available Cars List ───────────────────────────────────────────
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
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                    return SearchCarCard(
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
                padding: const EdgeInsets.all(16),
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
