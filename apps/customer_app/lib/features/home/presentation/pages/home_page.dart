import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../../home_providers.dart';
import '../../recently_viewed_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/locality_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _localityController = TextEditingController();
  Timer? _debounceTimer;
  String _localitySearchText = '';
  bool _showLocalitySuggestions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickupController.text = ref.read(pickupLocationProvider) ?? '';
      _dropController.text = ref.read(dropLocationProvider) ?? '';
      _localityController.text = ref.read(selectedLocalityProvider) ?? '';

      // Trigger location permission rationale dialog on first load post-login
      ref.read(userLocationProvider.notifier).requestLocationPermission(
        context,
        onCityAutoSelected: (nearestCity) {
          ref.read(selectedCityProvider.notifier).state = nearestCity;
        },
      );
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _localityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onLocalityChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _localitySearchText = text;
        _showLocalitySuggestions = text.trim().isNotEmpty;
      });
    });
  }

  void _showCitySelector() {
    final selectedCity = ref.read(selectedCityProvider);
    AppBottomSheet.show(
      context,
      title: 'Select City',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppConstants.indianCities.map((city) {
          final isSelected = city == selectedCity;
          return ListTile(
            title: Text(
              city,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              ref.read(selectedCityProvider.notifier).state = city;
              ref.read(selectedLocalityProvider.notifier).state = null;
              _localityController.clear();
              setState(() {
                _localitySearchText = '';
                _showLocalitySuggestions = false;
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Hatchback':
        return Icons.directions_car_outlined;
      case 'Sedan':
        return Icons.local_taxi_outlined;
      case 'SUV':
        return Icons.departure_board_outlined;
      case 'Luxury':
        return Icons.auto_awesome_outlined;
      case 'Tempo Traveller':
        return Icons.airport_shuttle_outlined;
      case 'Mini Bus':
        return Icons.directions_bus_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  void _searchCars() {
    final city = ref.read(selectedCityProvider);
    final tripType = ref.read(selectedTripTypeProvider);
    final dateRange = ref.read(selectedDateRangeProvider);
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();

    ref.read(pickupLocationProvider.notifier).state = pickup.isEmpty ? null : pickup;
    ref.read(dropLocationProvider.notifier).state = drop.isEmpty ? null : drop;

    final startStr = dateRange?.start.toIso8601String() ?? '';
    final endStr = dateRange?.end.toIso8601String() ?? '';

    context.push(
      '/search?city=${Uri.encodeComponent(city)}'
      '&tripType=${Uri.encodeComponent(tripType)}'
      '&start=${Uri.encodeComponent(startStr)}'
      '&end=${Uri.encodeComponent(endStr)}'
      '&pickup=${Uri.encodeComponent(pickup)}'
      '&drop=${Uri.encodeComponent(drop)}'
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedCity = ref.watch(selectedCityProvider);
    final tripType = ref.watch(selectedTripTypeProvider);
    final dateRange = ref.watch(selectedDateRangeProvider);

    final bannersVal = ref.watch(bannersProvider);
    final vendorsVal = ref.watch(topVendorsProvider);
    final recentlyViewedVal = ref.watch(recentlyViewedCarsProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    final localityQuery = LocalityQuery(city: selectedCity, search: _localitySearchText);
    final localitySuggestionsVal = ref.watch(localitySuggestionsProvider(localityQuery));

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showCitySelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your City',
                    style: TextStyle(fontSize: 12, color: cs.onPrimary.withValues(alpha: 0.7)),
                  ),
                  Row(
                    children: [
                      Text(
                        selectedCity,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: cs.onPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Saved Cars',
            onPressed: () => context.push('/wishlist'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(topVendorsProvider);
          ref.invalidate(availableCarsProvider);
          ref.invalidate(recentlyViewedCarsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: AppConstants.tripTypes.map((type) {
                          final isSelected = type == tripType;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => ref.read(selectedTripTypeProvider.notifier).state = type,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? cs.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isSelected ? cs.onPrimary : cs.onSurface,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Gap(20),
                    // Locality Autocomplete Input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Locality / Area (Optional)',
                          hint: 'Search area in $selectedCity (e.g. Bandra)',
                          controller: _localityController,
                          prefixIcon: const Icon(Icons.my_location, color: AppColors.primary),
                          onChanged: _onLocalityChanged,
                        ),
                        if (_showLocalitySuggestions)
                          localitySuggestionsVal.when(
                            data: (suggestions) {
                              if (suggestions.isEmpty) return const SizedBox.shrink();
                              return ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 150),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: cs.outline),
                                    boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4)],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: suggestions.length,
                                    itemBuilder: (context, idx) {
                                      final item = suggestions[idx];
                                      return ListTile(
                                        dense: true,
                                        title: Text(item, style: const TextStyle(fontSize: 13)),
                                        onTap: () {
                                          _localityController.text = item;
                                          ref.read(selectedLocalityProvider.notifier).state = item;
                                          setState(() {
                                            _showLocalitySuggestions = false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            loading: () => const LinearProgressIndicator(minHeight: 2),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                    const Gap(16),
                    AppDateRangePicker(
                      label: 'Rental Duration',
                      hint: 'Select pick-up and drop-off dates',
                      initialDateRange: dateRange,
                      onDateRangeSelected: (range) {
                        ref.read(selectedDateRangeProvider.notifier).state = range;
                      },
                    ),
                    const Gap(16),
                    AppTextField(
                      label: 'Pickup Location',
                      hint: 'Enter pickup address or point',
                      controller: _pickupController,
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                    ),
                    if (tripType != 'Local') ...[
                      const Gap(16),
                      AppTextField(
                        label: 'Drop Location',
                        hint: 'Enter drop-off address',
                        controller: _dropController,
                        prefixIcon: const Icon(Icons.location_off_outlined, color: AppColors.primary),
                      ),
                    ],
                    const Gap(24),
                    AppButton(
                      text: 'Search Cars',
                      onPressed: _searchCars,
                    ),
                  ],
                ),
              ),

              bannersVal.when(
                data: (banners) {
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Exclusive Offers'),
                      const Gap(12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: banners.length,
                          itemBuilder: (context, index) {
                            final banner = banners[index];
                            return Container(
                              width: 280,
                              margin: const EdgeInsets.only(right: 12),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                margin: EdgeInsets.zero,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      banner.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(Icons.image, color: AppColors.primary),
                                      ),
                                    ),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Color(0x99000000), // intentional dark scrim for image overlay
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Text(
                                        '',
                                        style: TextStyle(
                                          color: Colors.white, // on dark image scrim — intentional
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Text(
                                        banner.title,
                                        style: const TextStyle(
                                          color: Colors.white, // on dark image scrim — intentional
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Gap(24),
                    ],
                  );
                },
                loading: () => const Column(
                  children: [
                    SectionHeader(title: 'Exclusive Offers'),
                    Gap(12),
                    SizedBox(height: 140, child: AppLoader()),
                    Gap(24),
                  ],
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              // Recently Viewed Section
              recentlyViewedVal.when(
                data: (recentCars) {
                  if (recentCars.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Recently Viewed'),
                      const Gap(12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentCars.length,
                          itemBuilder: (context, index) {
                            final car = recentCars[index];
                            final isWishlisted = wishlistedIds.contains(car.id);
                            return Container(
                              width: 260,
                              margin: const EdgeInsets.only(right: 12),
                              child: CarCard(
                                car: car,
                                isWishlisted: isWishlisted,
                                onWishlistToggle: () {
                                  ref.read(wishlistIdsProvider.notifier).toggle(car.id);
                                },
                                onTap: () => context.push('/car/${car.id}'),
                              ),
                            );
                          },
                        ),
                      ),
                      const Gap(24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SectionHeader(title: 'Popular Car Types'),
              const Gap(12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppConstants.carCategories.length,
                  itemBuilder: (context, index) {
                    final category = AppConstants.carCategories[index];
                    final icon = _getCategoryIcon(category);
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 100,
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        margin: EdgeInsets.zero,
                        onTap: () {
                          context.push('/search?city=${Uri.encodeComponent(selectedCity)}&category=${Uri.encodeComponent(category)}');
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: AppColors.primary, size: 28),
                            const Gap(8),
                            Text(
                              category,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Gap(24),

              vendorsVal.when(
                data: (vendors) {
                  if (vendors.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(title: 'Top Rated Vendors in $selectedCity'),
                      const Gap(12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: vendors.length,
                          itemBuilder: (context, index) {
                            return _VendorCard(vendor: vendors[index]);
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Column(
                  children: [
                    SectionHeader(title: 'Top Rated Vendors in $selectedCity'),
                    const Gap(12),
                    const SizedBox(height: 120, child: AppLoader()),
                  ],
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorModel vendor;

  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final displayName = vendor.displayName ?? vendor.businessName;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (vendor.verificationStatus == 'verified') ...[
                  const Gap(4),
                  const Icon(
                    Icons.verified,
                    color: Colors.blue,
                    size: 16,
                  ),
                ],
              ],
            ),
            const Gap(4),
            Text(
              vendor.locality != null ? '${vendor.locality}, ${vendor.city}' : vendor.city,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Row(
              children: [
                StarRating(
                  rating: vendor.rating,
                ),
                const Gap(6),
                Text(
                  vendor.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(4),
            Text(
              '${vendor.totalTrips} Trips',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
