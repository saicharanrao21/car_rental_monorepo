import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/fleet_providers.dart';

class FleetListPage extends ConsumerStatefulWidget {
  const FleetListPage({super.key});

  @override
  ConsumerState<FleetListPage> createState() => _FleetListPageState();
}

class _FleetListPageState extends ConsumerState<FleetListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(fleetSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _FleetFilterModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fleetControllerProvider);
    final isGrid = ref.watch(fleetViewGridModeProvider);
    final filteredCarsAsync = ref.watch(filteredFleetCarsProvider);
    final healthStats = ref.watch(fleetHealthSummaryProvider);
    final statusFilter = ref.watch(fleetFilterStatusProvider);
    final fuelFilter = ref.watch(fleetFilterFuelProvider);
    final categoryFilter = ref.watch(fleetFilterCategoryProvider);

    final activeFilterCount = (statusFilter != 'ALL' ? 1 : 0) +
        (fuelFilter != 'ALL' ? 1 : 0) +
        (categoryFilter != 'ALL' ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Fleet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.search_off : Icons.search),
            tooltip: 'Search Vehicles',
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchCtrl.clear();
                  ref.read(fleetSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter Fleet',
                onPressed: () => _showFilterBottomSheet(context),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Bulk CSV Import',
            onPressed: () => context.push('/fleet/bulk-upload'),
          ),
          IconButton(
            icon: Icon(isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: isGrid ? 'Switch to List' : 'Switch to Grid',
            onPressed: () {
              ref.read(fleetViewGridModeProvider.notifier).state = !isGrid;
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Search Bar (if expanded)
          if (_isSearchExpanded)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by make, model, or plate (e.g. Swift, MH 12)',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(fleetSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(fleetSearchQueryProvider.notifier).state = val;
                  },
                ),
              ),
            ),

          // 2. Fleet Health Metrics Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Total Fleet',
                      count: healthStats.total,
                      color: const Color(0xFF0F172A),
                      icon: Icons.directions_car_rounded,
                    ),
                  ),
                  _buildMetricDivider(),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Available',
                      count: healthStats.available,
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  _buildMetricDivider(),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'On Trip',
                      count: healthStats.onTrip,
                      color: const Color(0xFF3B82F6),
                      icon: Icons.near_me_rounded,
                    ),
                  ),
                  _buildMetricDivider(),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Offline/Block',
                      count: healthStats.maintenance,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.build_circle_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Active filter chips (if any)
          if (activeFilterCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Filters:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    if (statusFilter != 'ALL')
                      _buildActiveFilterChip(
                        'Status: $statusFilter',
                        () => ref.read(fleetFilterStatusProvider.notifier).state = 'ALL',
                      ),
                    if (fuelFilter != 'ALL')
                      _buildActiveFilterChip(
                        'Fuel: $fuelFilter',
                        () => ref.read(fleetFilterFuelProvider.notifier).state = 'ALL',
                      ),
                    if (categoryFilter != 'ALL')
                      _buildActiveFilterChip(
                        'Type: $categoryFilter',
                        () => ref.read(fleetFilterCategoryProvider.notifier).state = 'ALL',
                      ),
                    GestureDetector(
                      onTap: () {
                        ref.read(fleetFilterStatusProvider.notifier).state = 'ALL';
                        ref.read(fleetFilterFuelProvider.notifier).state = 'ALL';
                        ref.read(fleetFilterCategoryProvider.notifier).state = 'ALL';
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Vehicle Content
          filteredCarsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: AppLoader()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(
                child: ErrorStateWidget(
                  message: 'Failed to load fleet vehicles',
                  onRetry: () => ref.invalidate(fleetCarsProvider),
                ),
              ),
            ),
            data: (cars) {
              if (cars.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: EmptyStateWidget(
                        icon: Icons.directions_car_filled_rounded,
                        title: activeFilterCount > 0 || _searchCtrl.text.isNotEmpty
                            ? 'No matching vehicles'
                            : 'No vehicles in fleet yet',
                        subtitle: activeFilterCount > 0 || _searchCtrl.text.isNotEmpty
                            ? 'Try adjusting your search criteria or clear active filters.'
                            : 'Add your first vehicle to start accepting bookings and earning revenue!',
                        actionText: activeFilterCount > 0 || _searchCtrl.text.isNotEmpty
                            ? 'Reset Filters'
                            : 'Add Vehicle',
                        onActionPressed: () {
                          if (activeFilterCount > 0 || _searchCtrl.text.isNotEmpty) {
                            _searchCtrl.clear();
                            ref.read(fleetSearchQueryProvider.notifier).state = '';
                            ref.read(fleetFilterStatusProvider.notifier).state = 'ALL';
                            ref.read(fleetFilterFuelProvider.notifier).state = 'ALL';
                            ref.read(fleetFilterCategoryProvider.notifier).state = 'ALL';
                          } else {
                            context.push('/fleet/add');
                          }
                        },
                      ),
                    ),
                  ),
                );
              }

              if (isGrid) {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.64,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildGridCarCard(context, ref, cars[index]),
                      childCount: cars.length,
                    ),
                  ),
                );
              } else {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildListCarCard(context, ref, cars[index]),
                      childCount: cars.length,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fleet/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Vehicle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const Gap(4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const Gap(2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      backgroundColor: const Color(0xFFEEF2FF),
      labelStyle: const TextStyle(color: AppColors.primary),
      deleteIconColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStatusBadge(CarModel car) {
    final isBlocked = car.blockedDates.isNotEmpty;
    String text = car.isAvailable ? 'AVAILABLE' : 'OFFLINE';
    Color bg = car.isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    Color fg = car.isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    if (isBlocked && car.isAvailable) {
      text = 'BLOCKED DATES';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }

  // Grid layout card
  Widget _buildGridCarCard(BuildContext context, WidgetRef ref, CarModel car) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/fleet/${car.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Thumbnail
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: car.photos.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: Image.network(
                            car.photos.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.directions_car_rounded, size: 40, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.directions_car_rounded, size: 40, color: Color(0xFF94A3B8)),
                        ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _buildStatusBadge(car),
                ),
              ],
            ),
            // Info details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car.make} ${car.model}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const Gap(2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                          ),
                          child: Text(
                            car.registrationNumber.isNotEmpty
                                ? car.registrationNumber
                                : 'REG PENDING',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          '${car.year} • ${car.fuelType} • ${car.type}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${car.pricePerDay.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                '/day',
                                style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        // Quick switch
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: car.isAvailable,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              ref.read(fleetControllerProvider.notifier).toggleAvailability(car.id, val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List layout card
  Widget _buildListCarCard(BuildContext context, WidgetRef ref, CarModel car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/fleet/${car.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              Stack(
                children: [
                  Container(
                    height: 80,
                    width: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: car.photos.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              car.photos.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.directions_car_rounded, size: 32, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.directions_car_rounded, size: 32, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _buildStatusBadge(car),
                  ),
                ],
              ),
              const Gap(12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.make} ${car.model}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                          ),
                          child: Text(
                            car.registrationNumber.isNotEmpty
                                ? car.registrationNumber
                                : 'REG PENDING',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Gap(8),
                        Text(
                          '${car.year} • ${car.fuelType}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                    const Gap(6),
                    Row(
                      children: [
                        const Icon(Icons.event_seat_rounded, size: 14, color: Color(0xFF64748B)),
                        const Gap(3),
                        Text('${car.seating} seats', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const Gap(10),
                        const Icon(Icons.ac_unit_rounded, size: 14, color: Color(0xFF64748B)),
                        const Gap(3),
                        Text(car.isAC ? 'AC' : 'Non-AC', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              // Price & Toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${car.pricePerDay.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    '/day',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  const Gap(4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: car.isAvailable,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        ref.read(fleetControllerProvider.notifier).toggleAvailability(car.id, val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetFilterModal extends ConsumerWidget {
  const _FleetFilterModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(fleetFilterStatusProvider);
    final fuelFilter = ref.watch(fleetFilterFuelProvider);
    final categoryFilter = ref.watch(fleetFilterCategoryProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Fleet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const Gap(10),

          // Operational Status
          const Text('Operational Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterOption('All Statuses', 'ALL', statusFilter, (val) {
                ref.read(fleetFilterStatusProvider.notifier).state = val;
              }),
              _buildFilterOption('Available', 'AVAILABLE', statusFilter, (val) {
                ref.read(fleetFilterStatusProvider.notifier).state = val;
              }),
              _buildFilterOption('Unavailable/Offline', 'UNAVAILABLE', statusFilter, (val) {
                ref.read(fleetFilterStatusProvider.notifier).state = val;
              }),
              _buildFilterOption('Blocked Dates', 'BLOCKED', statusFilter, (val) {
                ref.read(fleetFilterStatusProvider.notifier).state = val;
              }),
            ],
          ),
          const Gap(16),

          // Fuel Type
          const Text('Fuel Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterOption('All Fuels', 'ALL', fuelFilter, (val) {
                ref.read(fleetFilterFuelProvider.notifier).state = val;
              }),
              _buildFilterOption('Petrol', 'PETROL', fuelFilter, (val) {
                ref.read(fleetFilterFuelProvider.notifier).state = val;
              }),
              _buildFilterOption('Diesel', 'DIESEL', fuelFilter, (val) {
                ref.read(fleetFilterFuelProvider.notifier).state = val;
              }),
              _buildFilterOption('Electric', 'ELECTRIC', fuelFilter, (val) {
                ref.read(fleetFilterFuelProvider.notifier).state = val;
              }),
              _buildFilterOption('CNG', 'CNG', fuelFilter, (val) {
                ref.read(fleetFilterFuelProvider.notifier).state = val;
              }),
            ],
          ),
          const Gap(16),

          // Body / Category Type
          const Text('Body Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterOption('All Categories', 'ALL', categoryFilter, (val) {
                ref.read(fleetFilterCategoryProvider.notifier).state = val;
              }),
              _buildFilterOption('Hatchback', 'HATCHBACK', categoryFilter, (val) {
                ref.read(fleetFilterCategoryProvider.notifier).state = val;
              }),
              _buildFilterOption('Sedan', 'SEDAN', categoryFilter, (val) {
                ref.read(fleetFilterCategoryProvider.notifier).state = val;
              }),
              _buildFilterOption('SUV', 'SUV', categoryFilter, (val) {
                ref.read(fleetFilterCategoryProvider.notifier).state = val;
              }),
              _buildFilterOption('Luxury', 'LUXURY', categoryFilter, (val) {
                ref.read(fleetFilterCategoryProvider.notifier).state = val;
              }),
            ],
          ),
          const Gap(24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(fleetFilterStatusProvider.notifier).state = 'ALL';
                    ref.read(fleetFilterFuelProvider.notifier).state = 'ALL';
                    ref.read(fleetFilterCategoryProvider.notifier).state = 'ALL';
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset Filters'),
                ),
              ),
              const Gap(12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(
    String label,
    String value,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedValue == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onSelected(value),
    );
  }
}
