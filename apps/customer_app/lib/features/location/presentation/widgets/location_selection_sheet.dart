import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/locality_provider.dart';
import '../../../../core/providers/recent_locations_provider.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../features/home/home_providers.dart';

final publicTransportCatalogProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, city) async {
  try {
    final client = ref.read(apiClientProvider).dio;
    final response = await client.get('/locations/public/catalog', queryParameters: {'city': city});
    if (response.statusCode == 200) {
      return (response.data as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
  } catch (_) {}
  return [];
});

class LocationSelectionSheet extends ConsumerStatefulWidget {
  final String title;
  final String? initialValue;
  final String city;
  final bool isDropLocation;
  final void Function(String location, {double? lat, double? lng}) onLocationSelected;

  const LocationSelectionSheet({
    super.key,
    required this.title,
    this.initialValue,
    required this.city,
    this.isDropLocation = false,
    required this.onLocationSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? initialValue,
    required String city,
    bool isDropLocation = false,
    required void Function(String location, {double? lat, double? lng}) onLocationSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSelectionSheet(
        title: title,
        initialValue: initialValue,
        city: city,
        isDropLocation: isDropLocation,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  ConsumerState<LocationSelectionSheet> createState() => _LocationSelectionSheetState();
}

class _LocationSelectionSheetState extends ConsumerState<LocationSelectionSheet> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  String _searchQuery = '';
  bool _isDetecting = false;
  String? _statusError;
  LocationDetectionStatus? _lastStatus;

  // Curated fallback popular hubs for major cities
  static const Map<String, List<String>> _cityPopularHubs = {
    'Mumbai': [
      'Chhatrapati Shivaji Maharaj Airport (T2)',
      'Domestic Airport (T1), Vile Parle',
      'Bandra Kurla Complex (BKC)',
      'Andheri West Metro Hub',
      'Dadar Western Railway Station',
      'Hiranandani Gardens, Powai',
      'Lower Parel Business District',
      'Vashi Sector 17, Navi Mumbai',
    ],
    'Delhi': [
      'Indira Gandhi International Airport (T3)',
      'Connaught Place Inner Circle',
      'Cyber City, Gurugram',
      'Noida Sector 18 Commercial Hub',
      'New Delhi Railway Station (NDLS)',
      'Aerocity Hospitality District',
    ],
    'Bangalore': [
      'Kempegowda International Airport',
      'Indiranagar 100ft Road',
      'Koramangala 5th Block',
      'Whitefield ITPL Main Road',
      'Electronic City Phase 1',
      'MG Road Metro Station',
    ],
    'Pune': [
      'Pune International Airport, Lohegaon',
      'Koregaon Park North Main Road',
      'Hinjawadi IT Park Phase 1',
      'Viman Nagar Phoenix Mall',
      'Pune Junction Railway Station',
      'Baner High Street',
    ],
    'Hyderabad': [
      'Rajiv Gandhi International Airport, Shamshabad',
      'Hitec City Cyber Towers',
      'Gachibowli Financial District',
      'Jubilee Hills Check Post',
      'Secunderabad Railway Station',
    ],
    'Goa': [
      'Dabolim International Airport (GOI)',
      'Manohar International Airport (MOPA)',
      'Panjim City Centre',
      'Candolim Beach Road',
      'Madgaon Railway Station',
    ],
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchQuery = '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
      }
    });
  }

  void _selectLocation(String location, {double? lat, double? lng}) {
    ref.read(recentLocationsProvider.notifier).addLocation(location);
    widget.onLocationSelected(location, lat: lat, lng: lng);
    Navigator.of(context).pop();
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() {
      _isDetecting = true;
      _statusError = null;
      _lastStatus = null;
    });

    final result = await ref.read(userLocationProvider.notifier).detectCurrentLocation();

    if (!mounted) return;

    setState(() {
      _isDetecting = false;
      _lastStatus = result.status;
    });

    if (result.status == LocationDetectionStatus.success) {
      final locality = result.resolvedLocality ?? '${result.resolvedCity ?? widget.city} Area';
      final formatted = '$locality, ${result.resolvedCity ?? widget.city}';

      if (result.resolvedCity != null && result.resolvedCity != widget.city) {
        ref.read(selectedCityProvider.notifier).state = result.resolvedCity!;
      }

      _selectLocation(formatted, lat: result.latitude, lng: result.longitude);
    } else {
      setState(() {
        _statusError = result.message ?? 'Unable to detect location. Please enter manually.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recentLocations = ref.watch(recentLocationsProvider);
    final catalogAsync = ref.watch(publicTransportCatalogProvider(widget.city));

    final localityQuery = LocalityQuery(city: widget.city, search: _searchQuery);
    final localitiesAsync = _searchQuery.isNotEmpty
        ? ref.watch(localitySuggestionsProvider(localityQuery))
        : null;

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search area, airport, landmark, or address...',
                  hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),

            const Gap(8),

            // Scrollable Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shrinkWrap: true,
                children: [
                  // Option A: Use Current Location Card
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isDetecting ? null : _handleUseCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: _isDetecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDetecting ? 'Detecting current location...' : 'Use current location',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  'Detect your current location automatically via GPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),

                  // Error / Recovery banner
                  if (_statusError != null) ...[
                    const Gap(12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  _statusError!,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const Gap(10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_lastStatus == LocationDetectionStatus.permanentlyDenied)
                                TextButton.icon(
                                  icon: const Icon(Icons.settings, size: 16),
                                  label: const Text('Open App Settings'),
                                  onPressed: () {
                                    ref.read(userLocationProvider.notifier).openAppSettings();
                                  },
                                )
                              else if (_lastStatus == LocationDetectionStatus.serviceDisabled)
                                TextButton.icon(
                                  icon: const Icon(Icons.location_on, size: 16),
                                  label: const Text('Enable GPS'),
                                  onPressed: () {
                                    ref.read(userLocationProvider.notifier).openLocationSettings();
                                  },
                                )
                              else
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Try Again'),
                                  onPressed: _handleUseCurrentLocation,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Gap(16),

                  // Live search suggestions if user typed
                  if (_searchQuery.isNotEmpty) ...[
                    const Text(
                      'Search Results',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const Gap(8),

                    // Option to use the exact custom typed text
                    ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                      title: Text(
                        'Use "$_searchQuery"',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text('Custom address in ${widget.city}', style: const TextStyle(fontSize: 12)),
                      onTap: () => _selectLocation('$_searchQuery, ${widget.city}'),
                    ),

                    if (localitiesAsync != null)
                      localitiesAsync.when(
                        data: (suggestions) {
                          if (suggestions.isEmpty) return const SizedBox.shrink();
                          return Column(
                            children: suggestions.map((loc) {
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                                title: Text(loc, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(widget.city, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                onTap: () => _selectLocation('$loc, ${widget.city}'),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                  ] else ...[
                    // Recent Locations Section
                    if (recentLocations.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Locations',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () => ref.read(recentLocationsProvider.notifier).clearRecents(),
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      ...recentLocations.map((loc) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, color: Colors.grey, size: 20),
                          title: Text(loc, style: const TextStyle(fontSize: 14)),
                          onTap: () => _selectLocation(loc),
                        );
                      }),
                      const Gap(12),
                    ],

                    // Popular Hubs in City Section (Live Catalog from Backend + Fallback)
                    Text(
                      'Popular Hubs in ${widget.city}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const Gap(6),
                    Builder(
                      builder: (context) {
                        final items = catalogAsync.valueOrNull;
                        if (items != null && items.isNotEmpty) {
                          return Column(
                            children: items.map((point) {
                              final name = point['name'] as String? ?? 'Hub';
                              final category = point['category'] as String? ?? widget.city;
                              final type = point['type'] as String? ?? '';
                              final lat = (point['latitude'] as num?)?.toDouble();
                              final lng = (point['longitude'] as num?)?.toDouble();

                              final isAirport = type == 'AIRPORT' || name.toLowerCase().contains('airport');
                              final isRailway = type == 'RAILWAY_STATION' || name.toLowerCase().contains('station');
                              final icon = isAirport
                                  ? Icons.flight_takeoff_outlined
                                  : isRailway
                                      ? Icons.train_outlined
                                      : Icons.business_outlined;

                              return ListTile(
                                dense: true,
                                leading: Icon(icon, color: AppColors.primary, size: 20),
                                title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: Text('$category • ${widget.city}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                onTap: () => _selectLocation('$name, ${widget.city}', lat: lat, lng: lng),
                              );
                            }).toList(),
                          );
                        }

                        // Fallback to static list if database has not returned or during load
                        final popularHubs = _cityPopularHubs[widget.city] ??
                            [
                              '${widget.city} Central Airport',
                              '${widget.city} Central Railway Station',
                              '${widget.city} Downtown Hub',
                            ];

                        return Column(
                          children: popularHubs.map((hub) {
                            final isAirport = hub.toLowerCase().contains('airport');
                            final isRailway = hub.toLowerCase().contains('railway') || hub.toLowerCase().contains('station');
                            final icon = isAirport
                                ? Icons.flight_takeoff_outlined
                                : isRailway
                                    ? Icons.train_outlined
                                    : Icons.business_outlined;

                            return ListTile(
                              dense: true,
                              leading: Icon(icon, color: AppColors.primary, size: 20),
                              title: Text(hub, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: Text(widget.city, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              onTap: () => _selectLocation('$hub, ${widget.city}'),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

