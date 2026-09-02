import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/locations_providers.dart';
import '../widgets/location_detail_drawer.dart';

class LocationGovernancePage extends ConsumerStatefulWidget {
  const LocationGovernancePage({super.key});

  @override
  ConsumerState<LocationGovernancePage> createState() => _LocationGovernancePageState();
}

class _LocationGovernancePageState extends ConsumerState<LocationGovernancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _inspectLocation(VendorLocationModel location) {
    AdminDetailDrawer.show(
      context: context,
      title: location.name,
      subtitle: '${location.city}, ${location.state ?? ""} • ${location.type.displayName}',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _getStatusColor(location.status).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          location.status.toApiString(),
          style: TextStyle(
            color: _getStatusColor(location.status),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
      child: LocationDetailDrawerContent(location: location),
    );
  }

  Color _getStatusColor(VendorLocationStatus status) {
    switch (status) {
      case VendorLocationStatus.active:
        return Colors.green;
      case VendorLocationStatus.pendingApproval:
        return Colors.orange;
      case VendorLocationStatus.temporarilyClosed:
        return Colors.amber;
      case VendorLocationStatus.suspended:
        return Colors.red;
      case VendorLocationStatus.inactive:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(locationCatalogProvider);
    final citiesAsync = ref.watch(supportedCitiesListProvider);
    final selectedCity = ref.watch(locationCityFilterProvider);
    final selectedStatus = ref.watch(locationStatusFilterProvider);
    final searchQuery = ref.watch(locationSearchQueryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(locationCatalogProvider);
          ref.invalidate(operationalLocationsOverviewProvider);
          ref.invalidate(supportedCitiesListProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header & Top Actions ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location Governance & Hub Review',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'Control vendor yards, airport hubs, pickup points, operating hours, and delivery policies',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Live Operational Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.go('/locations'),
                  ),
                ],
              ),
              const Gap(24),

              // ─── KPI Summary Cards Row ───
              catalogAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: AppLoader(),
                )),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading location catalog',
                  onRetry: () => ref.invalidate(locationCatalogProvider),
                ),
                data: (locations) {
                  final total = locations.length;
                  final activeYards = locations
                      .where((l) =>
                          l.type == VendorLocationType.vendorYard ||
                          l.type == VendorLocationType.branch)
                      .length;
                  final transitPoints = locations
                      .where((l) =>
                          l.type == VendorLocationType.airport ||
                          l.type == VendorLocationType.railwayStation ||
                          l.type == VendorLocationType.publicPoint)
                      .length;
                  final pendingReview = locations
                      .where((l) => l.status == VendorLocationStatus.pendingApproval)
                      .length;

                  return _buildKpiRow(
                    total: total,
                    activeYards: activeYards,
                    transitPoints: transitPoints,
                    pendingReview: pendingReview,
                    isDesktop: isDesktop,
                  );
                },
              ),
              const Gap(24),

              // ─── Filter & Search Bar ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by hub name, vendor ID, address...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(locationSearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        onChanged: (val) {
                          ref.read(locationSearchQueryProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const Gap(16),

                    // City Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: citiesAsync.when(
                        loading: () => const SizedBox(height: 40, child: Center(child: AppLoader())),
                        error: (_, __) => DropdownButtonFormField<String>(
                          initialValue: selectedCity,
                          decoration: InputDecoration(
                            labelText: 'City',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Cities')),
                            DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
                            DropdownMenuItem(value: 'Bengaluru', child: Text('Bengaluru')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(locationCityFilterProvider.notifier).state = val;
                            }
                          },
                        ),
                        data: (cities) {
                          final items = [
                            const DropdownMenuItem(value: 'All', child: Text('All Cities')),
                            ...cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                          ];

                          return DropdownButtonFormField<String>(
                            initialValue: items.any((i) => i.value == selectedCity) ? selectedCity : 'All',
                            decoration: InputDecoration(
                              labelText: 'City Filter',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: items,
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(locationCityFilterProvider.notifier).state = val;
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const Gap(16),

                    // Status Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Review Status',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('Active Hubs')),
                          DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Review')),
                          DropdownMenuItem(value: 'TEMPORARILY_CLOSED', child: Text('Paused / Closed')),
                          DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(locationStatusFilterProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // ─── Tabs & Data Grid ───
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF2563EB),
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: const Color(0xFF2563EB),
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'All Locations & Governance'),
                        Tab(text: 'Vendor Yards & Garages'),
                        Tab(text: 'Transit Hubs & Airports'),
                        Tab(text: 'Delivery Policies & Matrix'),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    catalogAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: AppLoader()),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Error loading locations: $err')),
                      ),
                      data: (locations) {
                        return SizedBox(
                          height: 520,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 1: All Locations
                              _buildLocationTable(
                                _filterLocations(locations, null, selectedCity, selectedStatus, searchQuery),
                              ),
                              // Tab 2: Vendor Yards
                              _buildLocationTable(
                                _filterLocations(
                                  locations,
                                  [VendorLocationType.vendorYard, VendorLocationType.branch, VendorLocationType.office],
                                  selectedCity,
                                  selectedStatus,
                                  searchQuery,
                                ),
                              ),
                              // Tab 3: Transit Hubs
                              _buildLocationTable(
                                _filterLocations(
                                  locations,
                                  [VendorLocationType.airport, VendorLocationType.railwayStation, VendorLocationType.publicPoint, VendorLocationType.busTerminal],
                                  selectedCity,
                                  selectedStatus,
                                  searchQuery,
                                ),
                              ),
                              // Tab 4: Delivery Policy Summary
                              _buildDeliveryPolicyView(locations),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VendorLocationModel> _filterLocations(
    List<VendorLocationModel> locations,
    List<VendorLocationType>? allowedTypes,
    String cityFilter,
    String statusFilter,
    String query,
  ) {
    return locations.where((loc) {
      if (allowedTypes != null && !allowedTypes.contains(loc.type)) {
        return false;
      }
      if (cityFilter != 'All' && loc.city.toLowerCase() != cityFilter.toLowerCase()) {
        return false;
      }
      if (statusFilter != 'ALL' && loc.status.toApiString() != statusFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchName = loc.name.toLowerCase().contains(q);
        final matchCity = loc.city.toLowerCase().contains(q);
        final matchAddress = loc.address.toLowerCase().contains(q);
        final matchVendor = loc.vendorId.toLowerCase().contains(q);
        if (!matchName && !matchCity && !matchAddress && !matchVendor) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildKpiRow({
    required int total,
    required int activeYards,
    required int transitPoints,
    required int pendingReview,
    required bool isDesktop,
  }) {
    final cards = [
      _buildKpiCard('Total Managed Hubs', total.toString(), Icons.domain_outlined, Colors.blue),
      _buildKpiCard('Active Yards & Garages', activeYards.toString(), Icons.garage_outlined, Colors.indigo),
      _buildKpiCard('Airport & Transit Points', transitPoints.toString(), Icons.flight_takeoff_outlined, Colors.teal),
      _buildKpiCard(
        'Pending Governance Review',
        pendingReview.toString(),
        Icons.pending_actions_outlined,
        pendingReview > 0 ? Colors.orange : Colors.green,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: 170, child: c)).toList(),
      );
    }
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const Gap(4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTable(List<VendorLocationModel> locations) {
    return AdminDataGrid<VendorLocationModel>(
      items: locations,
      emptyTitle: 'No locations found',
      emptyMessage: 'No locations match your filter or search criteria.',
      emptyIcon: Icons.location_off_outlined,
      onRowTap: (loc) => _inspectLocation(loc),
      columns: [
        AdminDataColumn(
          title: 'HUB NAME & TYPE',
          builder: (loc) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                loc.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              Text(
                loc.type.displayName,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        AdminDataColumn(
          title: 'CITY / STATE',
          builder: (loc) => Text('${loc.city}, ${loc.state ?? ""}', style: const TextStyle(fontSize: 13)),
        ),
        AdminDataColumn(
          title: 'STREET ADDRESS',
          builder: (loc) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              loc.address,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        AdminDataColumn(
          title: 'FLEET CAPACITY',
          builder: (loc) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_outlined, size: 16, color: Colors.blue),
              const Gap(6),
              Text('${loc.assignedCarCount} cars', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        ),
        AdminDataColumn(
          title: 'STATUS',
          builder: (loc) => AdminStatusBadge(status: loc.status.toApiString()),
        ),
        AdminDataColumn(
          title: 'ACTIONS',
          builder: (loc) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _inspectLocation(loc),
                child: const Text('Inspect', style: TextStyle(fontSize: 12)),
              ),
              if (loc.status == VendorLocationStatus.pendingApproval) ...[
                const Gap(6),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  tooltip: 'Approve Hub',
                  onPressed: () {
                    ref.read(locationGovernanceControllerProvider.notifier).updateStatus(loc.id, 'ACTIVE');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
      mobileCardBuilder: (ctx, loc) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      loc.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AdminStatusBadge(status: loc.status.toApiString(), compact: true),
                ],
              ),
              const Gap(4),
              Text(
                '${loc.type.displayName} • ${loc.city}, ${loc.state ?? ""}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Gap(6),
              Text(
                loc.address,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 16, color: Colors.blue),
                      const Gap(6),
                      Text('${loc.assignedCarCount} vehicles', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _inspectLocation(loc),
                    child: const Text('Inspect Hub', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryPolicyView(List<VendorLocationModel> locations) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 22),
              const Gap(10),
              const Text(
                'Platform Doorstep Delivery & Fulfillment Governance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Canonical Matrix Source: PostgreSQL', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Gap(16),
          Text(
            'Doorstep delivery policies define base operating radiuses (km), per-km charges, and inter-city one-way fulfillment rates calculated dynamically via /locations/quote.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const Gap(24),
          Expanded(
            child: ListView(
              children: [
                _buildPolicyFeatureCard(
                  'Standard Doorstep Delivery',
                  'Base Distance: Up to 15.0 km • Base Fee: ₹250 • Rate Per Km: ₹25/km above base radius',
                  Icons.home_outlined,
                  Colors.blue,
                ),
                const Gap(12),
                _buildPolicyFeatureCard(
                  'Airport & Express Transit Delivery',
                  'Designated Express Hubs (RGIA, Kempegowda, IGI) with flat terminal transfer rates.',
                  Icons.flight_outlined,
                  Colors.teal,
                ),
                const Gap(12),
                _buildPolicyFeatureCard(
                  'Inter-City One-Way Return Matrix',
                  'Inter-hub relocations supported across verified paired corridors (e.g. Hyderabad -> Bengaluru). Transit fees dynamically calculated based on deadhead distance.',
                  Icons.alt_route_outlined,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyFeatureCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                const Gap(4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
