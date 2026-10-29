import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../domain/models/city_control_tower_models.dart';
import '../providers/supported_cities_providers.dart';

class SupportedCitiesPage extends ConsumerStatefulWidget {
  const SupportedCitiesPage({super.key});

  @override
  ConsumerState<SupportedCitiesPage> createState() => _SupportedCitiesPageState();
}

class _SupportedCitiesPageState extends ConsumerState<SupportedCitiesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL | ACTIVE | INACTIVE

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCityForm(BuildContext context, [SupportedCityModel? city]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CityFormDialog(
        cityToEdit: city,
        onSave: ({
          required String name,
          required String stateName,
          required double latitude,
          required double longitude,
          required bool isActive,
          List<String>? enabledTripTypes,
        }) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            if (city == null) {
              await ref.read(enrichedSupportedCitiesProvider.notifier).addCity(
                    name: name,
                    stateName: stateName,
                    latitude: latitude,
                    longitude: longitude,
                    isActive: isActive,
                    enabledTripTypes: enabledTripTypes,
                  );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Operational city created successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            } else {
              await ref.read(enrichedSupportedCitiesProvider.notifier).updateCity(
                    city.id,
                    name: name,
                    stateName: stateName,
                    latitude: latitude,
                    longitude: longitude,
                    isActive: isActive,
                    enabledTripTypes: enabledTripTypes,
                  );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Operational city updated successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Failed to save city: $e'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteCity(BuildContext context, SupportedCityModel city) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Supported City'),
          content: Text(
            'Are you sure you want to delete "${city.name}"? This action removes city service definitions permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(enrichedSupportedCitiesProvider.notifier).deleteCity(city.id);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('City deleted successfully!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete city: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCityReadinessDialog(BuildContext context, EnrichedSupportedCity cityItem) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return FutureBuilder<ReadinessReport>(
          future: ref.read(enrichedSupportedCitiesProvider.notifier).getCityReadiness(cityItem.city.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 140,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoader(),
                        Gap(16),
                        Text('Auditing city launch readiness...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('${cityItem.city.name} Readiness Audit'),
                content: Text('Failed to evaluate readiness: ${snapshot.error}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              );
            }

            final report = snapshot.data!;
            return _ReadinessReportDialog(report: report, title: '${cityItem.city.name} Launch Readiness');
          },
        );
      },
    );
  }

  void _showCityImpactDialog(BuildContext context, EnrichedSupportedCity cityItem) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return FutureBuilder<ImpactReport>(
          future: ref.read(enrichedSupportedCitiesProvider.notifier).getCityImpact(cityItem.city.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 140,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoader(),
                        Gap(16),
                        Text('Evaluating city deactivation impact...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('${cityItem.city.name} Impact Preview'),
                content: Text('Failed to evaluate impact: ${snapshot.error}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              );
            }

            final report = snapshot.data!;
            return _ImpactReportDialog(
              report: report,
              title: '${cityItem.city.name} Deactivation Impact Preview',
              onConfirmDeactivate: cityItem.city.isActive
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(enrichedSupportedCitiesProvider.notifier).updateCity(
                              cityItem.city.id,
                              isActive: false,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Paused operations for ${cityItem.city.name}.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  void _openServiceAreasWorkspace(BuildContext context, EnrichedSupportedCity cityItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServiceAreasWorkspaceSheet(cityItem: cityItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final citiesAsync = ref.watch(enrichedSupportedCitiesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Icon(Icons.location_city_rounded, color: theme.colorScheme.primary, size: 28),
                          const Text(
                            'City & Serviceability Control Tower',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                            ),
                            child: const Text(
                              'GOVERNANCE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        'Authoritative multi-tier location management (Supported City → Service Areas → Pickup Hubs → Fleet). Control service readiness, operational zones, and blast radius before deactivation.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                      onPressed: () => ref.read(enrichedSupportedCitiesProvider.notifier).loadCities(),
                    ),
                    const Gap(12),
                    AppButton(
                      text: 'Add Operational City',
                      isFullWidth: false,
                      onPressed: () => _showCityForm(context),
                    ),
                  ],
                ),
              ],
            ),
            const Gap(20),

            // Operational KPI Summary Cards
            citiesAsync.maybeWhen(
              data: (cities) => _buildKpiRow(theme, cities),
              orElse: () => const SizedBox.shrink(),
            ),
            const Gap(20),

            // Search & Filter Toolbar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search operational cities by name or state (e.g. Pune, Maharashtra)...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Gap(16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ALL', label: Text('All Cities')),
                    ButtonSegment(value: 'ACTIVE', label: Text('Active Only')),
                    ButtonSegment(value: 'INACTIVE', label: Text('Paused / Inactive')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                ),
              ],
            ),
            const Gap(16),

            // Master Cities List Table
            Expanded(
              child: citiesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading operational cities: $err',
                  onRetry: () => ref.read(enrichedSupportedCitiesProvider.notifier).loadCities(),
                ),
                data: (cities) {
                  final filtered = cities.where((item) {
                    if (_statusFilter == 'ACTIVE' && !item.city.isActive) return false;
                    if (_statusFilter == 'INACTIVE' && item.city.isActive) return false;
                    final q = _searchController.text.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      final matchName = item.city.name.toLowerCase().contains(q);
                      final matchState = item.city.state.toLowerCase().contains(q);
                      if (!matchName && !matchState) return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const AppCard(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_outlined, size: 48, color: Colors.grey),
                            Gap(12),
                            Text(
                              'No matching operational cities found',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Gap(6),
                            Text(
                              'Adjust search filters or click "Add Operational City" above to expand coverage.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AppCard(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                        headingRowHeight: 48,
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 64,
                        columns: const [
                          DataColumn(label: Text('City / State', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Coordinates', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Service Areas (Localities)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Partner Coverage', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Fleet Count', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Operating Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions & Governance', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((item) {
                          final city = item.city;
                          final activeAreasCount = item.serviceAreas.where((a) => a.status == 'ACTIVE').length;

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                                      child: Icon(Icons.location_city_rounded, color: theme.colorScheme.primary, size: 18),
                                    ),
                                    const Gap(12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          city.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          city.state,
                                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${city.latitude.toStringAsFixed(4)}, ${city.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              DataCell(
                                InkWell(
                                  onTap: () => _openServiceAreasWorkspace(context, item),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF6366F1)),
                                        const Gap(6),
                                        Text(
                                          '${item.serviceAreas.length} Areas ($activeAreasCount Active)',
                                          style: const TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Gap(4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF6366F1)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_outlined, size: 16, color: Colors.blueGrey),
                                    const Gap(6),
                                    Text(
                                      '${item.totalVendors} Assigned',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.directions_car_outlined, size: 16, color: Colors.blueGrey),
                                    const Gap(6),
                                    Text(
                                      '${item.totalCars} Vehicles',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                StatusBadge(
                                  status: city.isActive ? 'Active' : 'Inactive',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF10B981)),
                                      tooltip: 'Launch Readiness Checklist',
                                      onPressed: () => _showCityReadinessDialog(context, item),
                                    ),
                                    const Gap(6),
                                    IconButton(
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFF59E0B)),
                                      tooltip: 'Deactivation Blast Radius & Impact Preview',
                                      onPressed: () => _showCityImpactDialog(context, item),
                                    ),
                                    const Gap(6),
                                    IconButton(
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit City',
                                      onPressed: () => _showCityForm(context, city),
                                    ),
                                    const Gap(6),
                                    IconButton(
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                      tooltip: 'Delete City',
                                      onPressed: () => _confirmDeleteCity(context, city),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(ThemeData theme, List<EnrichedSupportedCity> cities) {
    final totalCities = cities.length;
    final activeCities = cities.where((c) => c.city.isActive).length;
    final totalAreas = cities.fold(0, (acc, c) => acc + c.serviceAreas.length);
    final activeAreas = cities.fold(
      0,
      (acc, c) => acc + c.serviceAreas.where((a) => a.status == 'ACTIVE').length,
    );
    final totalFleet = cities.fold(0, (acc, c) => acc + c.totalCars);
    final totalVendors = cities.fold(0, (acc, c) => acc + c.totalVendors);

    return Row(
      children: [
        _buildKpiCard(
          theme,
          label: 'Operational Cities',
          value: '$activeCities / $totalCities',
          icon: Icons.location_city_rounded,
          color: const Color(0xFF3B82F6),
        ),
        const Gap(16),
        _buildKpiCard(
          theme,
          label: 'Service Areas (Localities)',
          value: '$activeAreas Active / $totalAreas',
          icon: Icons.map_rounded,
          color: const Color(0xFF10B981),
        ),
        const Gap(16),
        _buildKpiCard(
          theme,
          label: 'Vendor Partner Presence',
          value: '$totalVendors Assigned',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        const Gap(16),
        _buildKpiCard(
          theme,
          label: 'Stationed Fleet Inventory',
          value: '$totalFleet Vehicles',
          icon: Icons.directions_car_filled_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CITY SERVICE AREAS WORKSPACE DRAWER / MODAL
// ============================================================================

class _ServiceAreasWorkspaceSheet extends ConsumerStatefulWidget {
  final EnrichedSupportedCity cityItem;

  const _ServiceAreasWorkspaceSheet({required this.cityItem});

  @override
  ConsumerState<_ServiceAreasWorkspaceSheet> createState() => _ServiceAreasWorkspaceSheetState();
}

class _ServiceAreasWorkspaceSheetState extends ConsumerState<_ServiceAreasWorkspaceSheet> {
  void _openAddAreaModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ServiceAreaFormDialog(
        cityId: widget.cityItem.city.id,
        cityName: widget.cityItem.city.name,
        defaultLat: widget.cityItem.city.latitude,
        defaultLng: widget.cityItem.city.longitude,
        onSave: (dto) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(enrichedSupportedCitiesProvider.notifier).createServiceArea(
                  cityId: dto['cityId'] as String,
                  name: dto['name'] as String,
                  latitude: dto['latitude'] as double,
                  longitude: dto['longitude'] as double,
                  radiusMeters: dto['radiusMeters'] as double,
                  status: dto['status'] as String,
                );
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Service locality created successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            if (mounted) setState(() {});
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to add area: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _openEditAreaModal(BuildContext context, CityServiceAreaModel area) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ServiceAreaFormDialog(
        cityId: widget.cityItem.city.id,
        cityName: widget.cityItem.city.name,
        areaToEdit: area,
        defaultLat: area.latitude,
        defaultLng: area.longitude,
        onSave: (dto) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(enrichedSupportedCitiesProvider.notifier).updateServiceArea(
                  area.id,
                  name: dto['name'] as String,
                  latitude: dto['latitude'] as double,
                  longitude: dto['longitude'] as double,
                  radiusMeters: dto['radiusMeters'] as double,
                  status: dto['status'] as String,
                );
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Service locality updated successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            if (mounted) setState(() {});
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to update area: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _showAreaReadinessCheck(BuildContext context, CityServiceAreaModel area) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<ReadinessReport>(
          future: ref.read(enrichedSupportedCitiesProvider.notifier).getServiceAreaReadiness(area.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoader(),
                        Gap(16),
                        Text('Checking locality service readiness...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('${area.name} Readiness Check'),
                content: Text('Failed: ${snapshot.error}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              );
            }

            final report = snapshot.data!;
            return _ReadinessReportDialog(report: report, title: '${area.name} Readiness Audit');
          },
        );
      },
    );
  }

  void _showAreaImpactCheck(BuildContext context, CityServiceAreaModel area) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<ImpactReport>(
          future: ref.read(enrichedSupportedCitiesProvider.notifier).getServiceAreaImpact(area.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoader(),
                        Gap(16),
                        Text('Auditing locality blast radius...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('${area.name} Impact Preview'),
                content: Text('Failed: ${snapshot.error}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              );
            }

            final report = snapshot.data!;
            return _ImpactReportDialog(
              report: report,
              title: '${area.name} Blast Radius Preview',
              onConfirmDeactivate: area.status == 'ACTIVE'
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(enrichedSupportedCitiesProvider.notifier).setServiceAreaStatus(
                              area.id,
                              'INACTIVE',
                              reason: 'Deactivated via Blast Radius Control',
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deactivated locality ${area.name}.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentCities = ref.watch(enrichedSupportedCitiesProvider).value ?? [];
    final currentCity = currentCities.firstWhere(
      (c) => c.city.id == widget.cityItem.city.id,
      orElse: () => widget.cityItem,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: Column(
        children: [
          // Sheet Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.hub_rounded, color: theme.colorScheme.primary),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentCity.city.name} — Service Areas & Localities',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Gap(2),
                      Text(
                        'Configured operational zones, pickup hubs, vendor radius, and bookable fleet units.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Service Area'),
                  onPressed: () => _openAddAreaModal(context),
                ),
                const Gap(12),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Localities List Table
          Expanded(
            child: currentCity.serviceAreas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                        const Gap(12),
                        Text(
                          'No Service Areas in ${currentCity.city.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Gap(6),
                        const Text(
                          'Add at least 1 locality to allow customers to search and book cars in this city.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const Gap(16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add First Service Area'),
                          onPressed: () => _openAddAreaModal(context),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: currentCity.serviceAreas.length,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, idx) {
                      final area = currentCity.serviceAreas[idx];
                      final radiusKm = (area.radiusMeters / 1000).toStringAsFixed(1);

                      Color statusColor;
                      switch (area.status) {
                        case 'ACTIVE':
                          statusColor = const Color(0xFF10B981);
                          break;
                        case 'COMING_SOON':
                          statusColor = const Color(0xFF3B82F6);
                          break;
                        default:
                          statusColor = const Color(0xFFEF4444);
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.pin_drop_rounded, color: statusColor, size: 22),
                                ),
                                const Gap(14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            area.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const Gap(8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              area.status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Gap(4),
                                      Text(
                                        '${area.latitude.toStringAsFixed(4)}, ${area.longitude.toStringAsFixed(4)} • Geofence Radius: ${radiusKm}km (${area.radiusMeters.toInt()}m)',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                            const Divider(height: 1),
                            const Gap(10),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatBadge(
                                      theme,
                                      icon: Icons.storefront_rounded,
                                      count: area.vendorCount,
                                      label: 'Vendors',
                                    ),
                                    const Gap(16),
                                    _buildStatBadge(
                                      theme,
                                      icon: Icons.directions_car_rounded,
                                      count: area.carCount,
                                      label: 'Fleet',
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF10B981)),
                                      label: const Text('Readiness'),
                                      onPressed: () => _showAreaReadinessCheck(context, area),
                                    ),
                                    const Gap(8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
                                      label: const Text('Impact'),
                                      onPressed: () => _showAreaImpactCheck(context, area),
                                    ),
                                    const Gap(8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit Locality Parameters',
                                      onPressed: () => _openEditAreaModal(context, area),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(ThemeData theme, {required IconData icon, required int count, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: count > 0 ? const Color(0xFF10B981) : Colors.grey),
        const Gap(6),
        Text(
          '$count $label',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: count > 0 ? theme.colorScheme.onSurface : Colors.grey,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// READINESS REPORT DIALOG
// ============================================================================

class _ReadinessReportDialog extends StatelessWidget {
  final ReadinessReport report;
  final String title;

  const _ReadinessReportDialog({required this.report, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady = report.isReadyToLaunch;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 24,
          ),
          const Gap(10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReady
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isReady ? Icons.verified_rounded : Icons.info_outline_rounded,
                    color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      isReady
                          ? 'All service criteria met. Ready to serve customer bookings.'
                          : 'Action required before public customer bookings can be enabled.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            const Text('Operational Criteria Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Gap(8),
            ...report.checklist.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      c.passed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                      size: 18,
                      color: c.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            c.description,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ============================================================================
// IMPACT PREVIEW REPORT DIALOG
// ============================================================================

class _ImpactReportDialog extends StatelessWidget {
  final ImpactReport report;
  final String title;
  final VoidCallback? onConfirmDeactivate;

  const _ImpactReportDialog({
    required this.report,
    required this.title,
    this.onConfirmDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveRentals = report.activeRentalsCount > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasActiveRentals ? Icons.error_rounded : Icons.shield_rounded,
            color: hasActiveRentals ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            size: 24,
          ),
          const Gap(10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasActiveRentals
                    ? const Color(0xFFEF4444).withOpacity(0.12)
                    : const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasActiveRentals ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasActiveRentals ? Icons.warning_rounded : Icons.info_rounded,
                    color: hasActiveRentals ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      hasActiveRentals
                          ? 'HIGH OPERATIONAL RISK: Ongoing customer trips detected! Pausing will disrupt live rentals.'
                          : 'Deactivation Blast Radius calculated. Review affected operations below.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasActiveRentals ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            Row(
              children: [
                _buildMetricBox(theme, 'Vendors Affected', '${report.affectedVendorsCount}', Colors.indigo),
                const Gap(10),
                _buildMetricBox(theme, 'Vehicles Offline', '${report.affectedVehiclesCount}', Colors.blueGrey),
                const Gap(10),
                _buildMetricBox(theme, 'Upcoming Trips', '${report.upcomingBookingsCount}', Colors.orange),
                const Gap(10),
                _buildMetricBox(theme, 'Active Rentals', '${report.activeRentalsCount}', Colors.red),
              ],
            ),
            const Gap(16),
            const Text('Operational Safeguard Recommendations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(6),
            ...report.recommendations.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right_rounded, size: 18, color: Colors.grey),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (onConfirmDeactivate != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasActiveRentals ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
            ),
            onPressed: onConfirmDeactivate,
            child: Text(hasActiveRentals ? 'Force Deactivate (Unsafe)' : 'Confirm Deactivation'),
          ),
      ],
    );
  }

  Widget _buildMetricBox(ThemeData theme, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const Gap(2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CITY FORM MODAL
// ============================================================================

class _CityFormDialog extends StatefulWidget {
  final SupportedCityModel? cityToEdit;
  final Function({
    required String name,
    required String stateName,
    required double latitude,
    required double longitude,
    required bool isActive,
    List<String>? enabledTripTypes,
  }) onSave;

  const _CityFormDialog({this.cityToEdit, required this.onSave});

  @override
  State<_CityFormDialog> createState() => _CityFormDialogState();
}

class _CityFormDialogState extends State<_CityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _stateController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cityToEdit?.name ?? '');
    _stateController = TextEditingController(text: widget.cityToEdit?.state ?? '');
    _latController = TextEditingController(
      text: widget.cityToEdit != null ? widget.cityToEdit!.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: widget.cityToEdit != null ? widget.cityToEdit!.longitude.toString() : '',
    );
    _isActive = widget.cityToEdit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stateController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        stateName: _stateController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        isActive: _isActive,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cityToEdit == null ? 'Add Operational City' : 'Edit Operational City'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'City Name',
                controller: _nameController,
                hint: 'e.g. Hyderabad',
                validator: (v) => v == null || v.trim().isEmpty ? 'City name required' : null,
              ),
              const Gap(14),
              AppTextField(
                label: 'State',
                controller: _stateController,
                hint: 'e.g. Telangana',
                validator: (v) => v == null || v.trim().isEmpty ? 'State name required' : null,
              ),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Latitude',
                      controller: _latController,
                      hint: '17.3850',
                      validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid latitude required' : null,
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: AppTextField(
                      label: 'Longitude',
                      controller: _lngController,
                      hint: '78.4867',
                      validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid longitude required' : null,
                    ),
                  ),
                ],
              ),
              const Gap(14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Operational Status', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Active cities accept customer search queries and bookings.', style: TextStyle(fontSize: 12)),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        _isSaving
            ? const Center(child: AppLoader())
            : ElevatedButton(
                onPressed: _submit,
                child: Text(widget.cityToEdit == null ? 'Add City' : 'Save Changes'),
              ),
      ],
    );
  }
}

// ============================================================================
// SERVICE AREA FORM MODAL
// ============================================================================

class _ServiceAreaFormDialog extends StatefulWidget {
  final String cityId;
  final String cityName;
  final CityServiceAreaModel? areaToEdit;
  final double defaultLat;
  final double defaultLng;
  final Function(Map<String, dynamic> dto) onSave;

  const _ServiceAreaFormDialog({
    required this.cityId,
    required this.cityName,
    this.areaToEdit,
    required this.defaultLat,
    required this.defaultLng,
    required this.onSave,
  });

  @override
  State<_ServiceAreaFormDialog> createState() => _ServiceAreaFormDialogState();
}

class _ServiceAreaFormDialogState extends State<_ServiceAreaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  String _status = 'ACTIVE';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.areaToEdit?.name ?? '');
    _latController = TextEditingController(
      text: widget.areaToEdit != null ? widget.areaToEdit!.latitude.toString() : widget.defaultLat.toString(),
    );
    _lngController = TextEditingController(
      text: widget.areaToEdit != null ? widget.areaToEdit!.longitude.toString() : widget.defaultLng.toString(),
    );
    _radiusController = TextEditingController(
      text: widget.areaToEdit != null ? widget.areaToEdit!.radiusMeters.toInt().toString() : '5000',
    );
    _status = widget.areaToEdit?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await widget.onSave({
        'cityId': widget.cityId,
        'name': _nameController.text.trim(),
        'latitude': double.parse(_latController.text.trim()),
        'longitude': double.parse(_lngController.text.trim()),
        'radiusMeters': double.parse(_radiusController.text.trim()),
        'status': _status,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.areaToEdit == null ? 'Add Service Area in ${widget.cityName}' : 'Edit Locality Parameters'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Locality / Area Name',
                controller: _nameController,
                hint: 'e.g. Hitec City, Gachibowli, Banjara Hills',
                validator: (v) => v == null || v.trim().isEmpty ? 'Area name required' : null,
              ),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Latitude',
                      controller: _latController,
                      validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Latitude required' : null,
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: AppTextField(
                      label: 'Longitude',
                      controller: _lngController,
                      validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Longitude required' : null,
                    ),
                  ),
                ],
              ),
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Geofence Radius (meters)',
                      controller: _radiusController,
                      hint: '5000',
                      validator: (v) {
                        final parsed = v != null ? double.tryParse(v.trim()) : null;
                        if (parsed == null || parsed < 500) return 'Min 500m';
                        return null;
                      },
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Operational Status'),
                      items: const [
                        DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                        DropdownMenuItem(value: 'COMING_SOON', child: Text('COMING_SOON')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        _isSaving
            ? const Center(child: AppLoader())
            : ElevatedButton(
                onPressed: _submit,
                child: Text(widget.areaToEdit == null ? 'Create Locality' : 'Save Changes'),
              ),
      ],
    );
  }
}
