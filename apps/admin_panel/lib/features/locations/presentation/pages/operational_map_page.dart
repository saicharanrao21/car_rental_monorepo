import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../providers/locations_providers.dart';

class OperationalMapPage extends ConsumerStatefulWidget {
  const OperationalMapPage({super.key});

  @override
  ConsumerState<OperationalMapPage> createState() => _OperationalMapPageState();
}

class _OperationalMapPageState extends ConsumerState<OperationalMapPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(operationalLocationsOverviewProvider);
    final selectedCity = ref.watch(locationCityFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operational Map & Fleet Locations',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        'Real-time geographic distribution of hubs, vendor garages, active rentals, and SOS alerts',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                AppButton(
                  text: 'Refresh Map Data',
                  isFullWidth: false,
                  onPressed: () {
                    ref.invalidate(operationalLocationsOverviewProvider);
                  },
                ),
              ],
            ),
            const Gap(20),

            // Summary Metrics Row
            overviewAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: AppLoader()),
              ),
              error: (err, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('Error loading operational overview: $err')),
                ),
              ),
              data: (overview) => _buildSummaryCards(context, overview),
            ),
            const Gap(20),

            // City Filter Row
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Filter by City:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Gap(12),
                    _buildCityFilterChips(ref, selectedCity),
                  ],
                ),
              ),
            ),
            const Gap(20),

            // Navigation Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(icon: Icon(Icons.directions_car), text: 'Active On-Trip Vehicles'),
                Tab(icon: Icon(Icons.storefront), text: 'Vendor Garages & Hubs'),
                Tab(icon: Icon(Icons.emergency), text: 'Emergency SOS Incidents'),
              ],
            ),
            const Gap(16),

            // Tab Views Content
            Expanded(
              child: overviewAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => Center(child: Text('Error loading location data: $err')),
                data: (overview) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveBookingsTab(context, overview.activeBookings),
                      _buildVendorsTab(context, overview.vendors),
                      _buildEmergenciesTab(context, overview.activeEmergencies),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, OperationalLocationOverviewModel overview) {
    final cards = [
      _buildKpiCard('Total Active Hubs', '${overview.totalHubs}', Colors.blue, Icons.location_city),
      _buildKpiCard('Vendor Garages', '${overview.totalActiveGarages}', Colors.green, Icons.storefront),
      _buildKpiCard('On-Trip Vehicles', '${overview.totalOnTripVehicles}', Colors.teal, Icons.directions_car),
      _buildKpiCard('Active SOS Alerts', '${overview.totalActiveSosAlerts}', Colors.red, Icons.emergency),
    ];

    if (Responsive.isDesktop(context)) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((c) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 64) / 2,
                  child: c,
                ))
            .toList(),
      );
    }
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Gap(6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCityFilterChips(WidgetRef ref, String selectedCity) {
    final cities = ['All', 'Hyderabad', 'Mumbai', 'Bangalore', 'Delhi', 'Pune', 'Chennai'];
    return Wrap(
      spacing: 6,
      children: cities.map((city) {
        final isSelected = selectedCity == city;
        return ChoiceChip(
          label: Text(city),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              ref.read(locationCityFilterProvider.notifier).state = city;
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildActiveBookingsTab(
    BuildContext context,
    List<ActiveTripLocationItemModel> bookings,
  ) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No active rentals on the road matching filter.'));
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isDesktop(context) ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        final lat = b.pickupLatitude ?? 17.385;
        final lng = b.pickupLongitude ?? 78.4867;

        return LocationPreviewCard(
          title: '${b.carName} (${b.registrationNumber})',
          address: 'Pickup: ${b.pickupLocation} • Customer: ${b.customerName}',
          latitude: lat,
          longitude: lng,
          distanceText: '${b.tripType} TRIP',
          etaText: b.status,
          onNavigate: () {},
        );
      },
    );
  }

  Widget _buildVendorsTab(
    BuildContext context,
    List<VendorLocationItemModel> vendors,
  ) {
    if (vendors.isEmpty) {
      return const Center(child: Text('No vendor hubs matching filter.'));
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isDesktop(context) ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final v = vendors[index];
        return LocationPreviewCard(
          title: v.businessName,
          address: '${v.ownerName} • Hub Location: ${v.city}',
          latitude: v.latitude,
          longitude: v.longitude,
          distanceText: 'GARAGE HUB',
          etaText: v.city,
          onNavigate: () {},
        );
      },
    );
  }

  Widget _buildEmergenciesTab(
    BuildContext context,
    List<EmergencyLocationItemModel> emergencies,
  ) {
    if (emergencies.isEmpty) {
      return const Center(child: Text('No active SOS emergency incidents. Platform is clear.'));
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isDesktop(context) ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: emergencies.length,
      itemBuilder: (context, index) {
        final e = emergencies[index];
        return LocationPreviewCard(
          title: 'SOS Alert: ${e.incidentType}',
          address: '${e.locationAddress} • Customer: ${e.customerName}',
          latitude: e.latitude,
          longitude: e.longitude,
          distanceText: 'URGENT DISPATCH',
          etaText: e.status,
          onNavigate: () {},
        );
      },
    );
  }
}
