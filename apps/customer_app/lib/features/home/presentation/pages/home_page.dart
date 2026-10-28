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
import '../widgets/home_available_cars_section.dart';
import '../widgets/home_banners_carousel_widget.dart';
import '../widgets/home_popular_cities_widget.dart';
import '../widgets/home_top_vendors_widget.dart';
import '../widgets/home_recently_viewed_widget.dart';
import '../widgets/home_trust_assurance_widget.dart';

/// DriveGo Design System (DDS) — Modern Customer Home Marketplace Feed
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
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    final locationNotifier = ref.read(userLocationProvider.notifier);

    // 1. Check whether the app already has a valid, previously selected location
    final hasSaved = await locationNotifier.loadSavedLocation();
    if (hasSaved) {
      final savedCity = ref.read(userLocationProvider).resolvedCity;
      if (savedCity != null && savedCity.isNotEmpty) {
        if (mounted) {
          ref.read(selectedCityProvider.notifier).state = savedCity;
        }
        return; // Restored saved location without prompting
      }
    }

    // 2. If no location has been selected, explain why location access is useful and request location permission
    if (!mounted) return;
    final locationState = ref.read(userLocationProvider);
    if (!locationState.isRequestedThisSession) {
      await locationNotifier.requestLocationPermission(
        context,
        onCityAutoSelected: (nearestCity) {
          if (mounted) {
            ref.read(selectedCityProvider.notifier).state = nearestCity;
          }
        },
      );
    }
  }

  void _showCitySelector() {
    final currentCity = ref.read(selectedCityProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: DDSColors.surfaceCard,
          borderRadius: DDSRadius.sheetTopRadius,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _SearchableCitySelector(
          selectedCity: currentCity,
          onSelectCity: (city) {
            ref.read(userLocationProvider.notifier).setManualLocation(city: city);
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
        SnackBar(
          content: Text('$tripType is coming soon in your city.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
        ),
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

    context.go(
      '/search?city=${Uri.encodeComponent(city)}'
      '&tripType=${Uri.encodeComponent(tripType)}'
      '&start=${Uri.encodeComponent(startStr)}'
      '&end=${Uri.encodeComponent(endStr)}'
      '&pickup=${Uri.encodeComponent(pickup)}'
      '&drop=${Uri.encodeComponent(drop)}',
    );
  }

  Widget _buildLocationBanner(UserLocationState locationState) {
    if (locationState.detectionStatus == LocationDetectionStatus.serviceDisabled) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.accentAmber.withValues(alpha: 0.12),
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.accentAmber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: DDSColors.accentAmber, size: 22),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Services Disabled',
                    style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(2),
                  Text(
                    'Turn on GPS to find cars near you or select manually.',
                    style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.read(userLocationProvider.notifier).openLocationSettings(),
              child: const Text('Enable GPS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (locationState.detectionStatus == LocationDetectionStatus.permissionDenied ||
        locationState.detectionStatus == LocationDetectionStatus.permanentlyDenied) {
      final isPermanent = locationState.detectionStatus == LocationDetectionStatus.permanentlyDenied;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.primaryBlue.withValues(alpha: 0.08),
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: DDSColors.primaryBlue, size: 22),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPermanent ? 'Location Permission Blocked' : 'Location Permission Denied',
                    style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(2),
                  Text(
                    isPermanent
                        ? 'Enable in system settings to detect your city, or choose manually.'
                        : 'Select your city manually to discover available cars.',
                    style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                  ),
                ],
              ),
            ),
            if (isPermanent)
              TextButton(
                onPressed: () => ref.read(userLocationProvider.notifier).openAppSettings(),
                child: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              TextButton(
                onPressed: _showCitySelector,
                child: const Text('Select City', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
    }

    if (locationState.detectionStatus == LocationDetectionStatus.timeout) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.borderMedium),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: DDSColors.textMuted, size: 22),
            const Gap(10),
            Expanded(
              child: Text(
                'Location request timed out. You can select your city manually.',
                style: DDSTypography.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: _showCitySelector,
              child: const Text('Select City', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: HomeHeaderWidget(
        onCityTap: _showCitySelector,
      ),
      body: RefreshIndicator(
        color: DDSColors.primaryBlue,
        backgroundColor: DDSColors.surfaceCard,
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(topVendorsProvider);
          ref.invalidate(availableCarsProvider);
          ref.invalidate(supportedCitiesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Location Status / Warning Banner
              _buildLocationBanner(locationState),

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

              // 4. Available & Recommended Cars in Selected City
              HomeAvailableCarsSection(
                onSelectCityPressed: _showCitySelector,
              ),
              const Gap(24),

              // 5. Exclusive Offers & Promotional Banners Carousel
              const HomeBannersCarouselWidget(),
              const Gap(24),

              // 6. Popular Destinations / Cities Discovery
              const HomePopularCitiesWidget(),
              const Gap(24),

              // 7. Top Rated Fleet Partners
              const HomeTopVendorsWidget(),
              const Gap(24),

              // 8. Recently Viewed Cars (if available)
              const HomeRecentlyViewedWidget(),
              const Gap(24),

              // 9. The DriveGo Assurance / Trust Section
              const HomeTrustAssuranceWidget(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: DDSColors.borderMedium,
              borderRadius: DDSRadius.pillBorderRadius,
            ),
          ),
        ),
        Text(
          'Select Pickup City',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(12),

        // GPS Use Current Location Option
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DDSRadius.smallBorderRadius,
            onTap: () async {
              Navigator.pop(context);
              final res = await ref.read(userLocationProvider.notifier).detectCurrentLocation();
              if (res.status == LocationDetectionStatus.success && res.resolvedCity != null) {
                ref.read(selectedCityProvider.notifier).state = res.resolvedCity!;
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location_rounded, color: DDSColors.primaryBlue, size: 20),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use Current Location',
                          style: DDSTypography.bodyMedium.copyWith(
                            color: DDSColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Detect nearby cars using GPS',
                          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Gap(8),
        const Divider(height: 1, color: DDSColors.borderLight),
        const Gap(12),

        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search city...',
              hintStyle: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: DDSColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: DDSColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: DDSColors.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: DDSRadius.mediumBorderRadius,
                borderSide: const BorderSide(color: DDSColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DDSRadius.mediumBorderRadius,
                borderSide: const BorderSide(color: DDSColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DDSRadius.mediumBorderRadius,
                borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 1.5),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.40,
          ),
          child: filteredCities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No matching cities found',
                      style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredCities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: DDSColors.borderLight),
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    final isSelected = city.toLowerCase() == widget.selectedCity.toLowerCase();

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Icon(
                        Icons.location_city_rounded,
                        size: 20,
                        color: isSelected ? DDSColors.primaryBlue : DDSColors.textMuted,
                      ),
                      title: Text(
                        city,
                        style: DDSTypography.bodyLarge.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: DDSColors.primaryBlue, size: 20)
                          : null,
                      onTap: () => widget.onSelectCity(city),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
