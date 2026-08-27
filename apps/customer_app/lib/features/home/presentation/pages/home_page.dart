import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../home_providers.dart';
import '../../../../core/providers/location_provider.dart';
import '../widgets/home_header_widget.dart';
import '../widgets/home_trip_type_selector_widget.dart';
import '../widgets/home_trip_config_card.dart';
import '../widgets/home_quick_categories_widget.dart';
import '../widgets/home_banners_carousel_widget.dart';
import '../widgets/home_recently_viewed_widget.dart';
import '../widgets/home_top_vendors_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAndPermissions();
    });
  }

  void _initLocationAndPermissions() {
    final locationState = ref.read(userLocationProvider);
    if (!locationState.isRequestedThisSession) {
      ref.read(userLocationProvider.notifier).requestLocationPermission(
        context,
        onCityAutoSelected: (nearestCity) {
          if (mounted) {
            final currentSelected = ref.read(selectedCityProvider);
            if (currentSelected != nearestCity) {
              _showCityChangePrompt(nearestCity);
            }
          }
        },
        onLocationResolved: (lat, lng) async {
          if (!mounted) return;
          try {
            final repo = ref.read(homeRepositoryProvider);
            final nearest = await repo.getNearestCity(lat, lng);
            if (mounted) {
              final currentSelected = ref.read(selectedCityProvider);
              if (currentSelected != nearest.name) {
                _showCityChangePrompt(nearest.name);
              }
            }
          } catch (e) {
            debugPrint('Failed to fetch nearest city: $e');
          }
        },
      );
    }
  }

  void _showCityChangePrompt(String detectedCity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.my_location, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Location Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('It looks like you are near $detectedCity. Would you like to switch your city to $detectedCity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Current'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(selectedCityProvider.notifier).state = detectedCity;
              Navigator.pop(ctx);
            },
            child: const Text('Switch City'),
          ),
        ],
      ),
    );
  }

  void _showCitySelector() {
    final currentCity = ref.read(selectedCityProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _SearchableCitySelector(
          selectedCity: currentCity,
          onSelectCity: (city) {
            ref.read(selectedCityProvider.notifier).state = city;
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  bool _isTripTypeEnabled(String type, List<String> enabledTypes) {
    final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
      return enabledTypes.contains('AIRPORT_TRANSFER');
    }
    return enabledTypes.contains(norm);
  }

  void _searchCars() {
    final city = ref.read(selectedCityProvider);
    final tripType = ref.read(selectedTripTypeProvider);
    var dateRange = ref.read(selectedDateRangeProvider);
    final pickup = ref.read(pickupLocationProvider) ?? '';
    final drop = ref.read(dropLocationProvider) ?? '';

    final publicSettingsVal = ref.read(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];
    if (!_isTripTypeEnabled(tripType, enabledTripTypes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected trip type is coming soon in your city.')),
      );
      return;
    }

    // If date range is not selected yet, assign a sensible default (tomorrow + 2 days)
    if (dateRange == null) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final end = start.add(const Duration(days: 2));
      dateRange = DateTimeRange(start: start, end: end);
      ref.read(selectedDateRangeProvider.notifier).state = dateRange;
    }

    final startStr = dateRange.start.toIso8601String();
    final endStr = dateRange.end.toIso8601String();

    context.push(
      '/search?city=${Uri.encodeComponent(city)}'
      '&tripType=${Uri.encodeComponent(tripType)}'
      '&start=${Uri.encodeComponent(startStr)}'
      '&end=${Uri.encodeComponent(endStr)}'
      '&pickup=${Uri.encodeComponent(pickup)}'
      '&drop=${Uri.encodeComponent(drop)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeHeaderWidget(
        onCityTap: _showCitySelector,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(topVendorsProvider);
          ref.invalidate(availableCarsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Trip Type Pill Selector
              const HomeTripTypeSelectorWidget(),
              const Gap(14),

              // 2. Main Hero Trip Configuration Card
              HomeTripConfigCard(
                onSearchPressed: _searchCars,
              ),
              const Gap(24),

              // 3. Quick Popular Categories
              const HomeQuickCategoriesWidget(),
              const Gap(24),

              // 4. Exclusive Offers & Banners Carousel
              const HomeBannersCarouselWidget(),
              const Gap(24),

              // 5. Recently Viewed Cars (if available)
              const HomeRecentlyViewedWidget(),
              const Gap(24),

              // 6. Top Rated Fleet Partners
              const HomeTopVendorsWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchableCitySelector extends ConsumerStatefulWidget {
  final String selectedCity;
  final Function(String city) onSelectCity;

  const _SearchableCitySelector({
    required this.selectedCity,
    required this.onSelectCity,
  });

  @override
  ConsumerState<_SearchableCitySelector> createState() => _SearchableCitySelectorState();
}

class _SearchableCitySelectorState extends ConsumerState<_SearchableCitySelector> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportedCitiesVal = ref.watch(supportedCitiesProvider);
    final allCityNames = supportedCitiesVal.maybeWhen(
      data: (cities) => cities.isNotEmpty
          ? cities.map((c) => c.name).toList()
          : AppConstants.indianCities,
      orElse: () => AppConstants.indianCities,
    );

    final filteredCities = allCityNames
        .where((city) => city.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search city...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: filteredCities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No matching cities found', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    final isSelected = city == widget.selectedCity;
                    return ListTile(
                      dense: true,
                      title: Text(
                        city,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 18) : null,
                      onTap: () => widget.onSelectCity(city),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
