import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/models/vendor_fleet_models.dart';
import '../providers/admin_fleet_providers.dart';
import '../../../vendors/presentation/providers/admin_vendor_providers.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';

class AdminFleetOverviewPage extends ConsumerStatefulWidget {
  const AdminFleetOverviewPage({super.key});

  @override
  ConsumerState<AdminFleetOverviewPage> createState() => _AdminFleetOverviewPageState();
}

class _AdminFleetOverviewPageState extends ConsumerState<AdminFleetOverviewPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDetailPanel(BuildContext context, String carId) {
    AdminDetailDrawer.show(
      context: context,
      title: 'Vehicle Fleet & Operations',
      subtitle: 'Vehicle ID: #${carId.toUpperCase()}',
      width: 580,
      child: _CarDetailPanel(carId: carId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpisAsync = ref.watch(fleetKpisProvider);
    final vehiclesAsync = ref.watch(adminFleetVehiclesProvider);

    final cityFilter = ref.watch(fleetCityFilterProvider);
    final vendorFilter = ref.watch(fleetVendorFilterProvider);
    final opStatusFilter = ref.watch(fleetOperationalStatusFilterProvider);
    final verStatusFilter = ref.watch(fleetVerificationStatusFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header & KPIs ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet Operations & Vehicle Readiness',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Gap(4),
                    Text(
                      'Server-authoritative vehicle lifecycle, compliance verification, and operational availability',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(fleetKpisProvider);
                    ref.invalidate(adminFleetVehiclesProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Fleet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Gap(20),

            // ─── KPI Cards Banner ───
            kpisAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => const SizedBox.shrink(),
              data: (kpis) => _buildKpiRow(kpis),
            ),
            const Gap(20),

            // ─── Filters Bar ───
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Search Input
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search plate, model...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (val) {
                        ref.read(fleetSearchQueryProvider.notifier).state = val.trim().isEmpty ? null : val.trim();
                      },
                    ),
                  ),
                  const Gap(12),

                  // City Dropdown
                  SizedBox(
                    width: 140,
                    child: AppDropdown<String>(
                      label: 'City',
                      value: cityFilter ?? 'All',
                      items: ['All', ...AppConstants.indianCities]
                          .map((city) => DropdownMenuItem<String>(
                                value: city,
                                child: Text(city, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        ref.read(fleetCityFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  const Gap(12),

                  // Operational Status Dropdown
                  SizedBox(
                    width: 180,
                    child: AppDropdown<String>(
                      label: 'Lifecycle Status',
                      value: opStatusFilter ?? 'All',
                      items: const [
                        'All',
                        'ACTIVE',
                        'DRAFT',
                        'PENDING_VERIFICATION',
                        'INACTIVE',
                        'MAINTENANCE',
                        'SUSPENDED',
                        'RETIRED',
                      ]
                          .map((st) => DropdownMenuItem<String>(
                                value: st,
                                child: Text(st, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        ref.read(fleetOperationalStatusFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  const Gap(12),

                  // Verification Status Dropdown
                  SizedBox(
                    width: 170,
                    child: AppDropdown<String>(
                      label: 'Verification',
                      value: verStatusFilter ?? 'All',
                      items: const ['All', 'VERIFIED', 'PENDING', 'REJECTED']
                          .map((st) => DropdownMenuItem<String>(
                                value: st,
                                child: Text(st, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        ref.read(fleetVerificationStatusFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  const Gap(12),

                  // Vendor Filter Dropdown
                  SizedBox(
                    width: 200,
                    child: AppDropdown<String>(
                      label: 'Vendor Partner',
                      value: vendorFilter ?? 'All',
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'All',
                          child: Text('All Vendors', overflow: TextOverflow.ellipsis),
                        ),
                        ...(ref.watch(adminVendorsProvider).value ?? []).map(
                          (v) => DropdownMenuItem<String>(
                            value: v.id,
                            child: Text(v.businessName, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        ref.read(fleetVendorFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),

                  if (cityFilter != null ||
                      vendorFilter != null ||
                      opStatusFilter != null ||
                      verStatusFilter != null ||
                      _searchController.text.isNotEmpty) ...[
                    const Gap(12),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(fleetSearchQueryProvider.notifier).state = null;
                        ref.read(fleetCityFilterProvider.notifier).state = null;
                        ref.read(fleetVendorFilterProvider.notifier).state = null;
                        ref.read(fleetOperationalStatusFilterProvider.notifier).state = null;
                        ref.read(fleetVerificationStatusFilterProvider.notifier).state = null;
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(16),

            // ─── Main Fleet Grid ───
            Expanded(
              child: vehiclesAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading vehicle fleet: $err',
                  onRetry: () => ref.invalidate(adminFleetVehiclesProvider),
                ),
                data: (vehicles) {
                  return AdminDataGrid<AdminFleetVehicleModel>(
                    items: vehicles,
                    emptyTitle: 'No Fleet Vehicles Found',
                    emptyMessage: 'No vehicles match the selected filter criteria.',
                    emptyIcon: Icons.directions_car_outlined,
                    onRowTap: (v) => _showDetailPanel(context, v.id),
                    columns: [
                      AdminDataColumn(
                        title: 'VEHICLE / PLATE',
                        builder: (v) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${v.make} ${v.model} (${v.year})',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                            ),
                            Text(
                              v.registrationNumber.isNotEmpty ? v.registrationNumber : '#${v.id.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      AdminDataColumn(
                        title: 'VENDOR / CITY',
                        builder: (v) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              v.vendorBusinessName ?? 'Vendor #${v.vendorId.substring(0, 6)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              v.vendorCity ?? '—',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      AdminDataColumn(
                        title: 'SERVICE AREA',
                        builder: (v) => Text(
                          v.serviceAreaName ?? 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: v.serviceAreaName != null ? const Color(0xFF0F172A) : Colors.orange[800],
                            fontWeight: v.serviceAreaName != null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      AdminDataColumn(
                        title: 'PRICE / DAY',
                        numeric: true,
                        builder: (v) => Text('₹${v.pricePerDay.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      AdminDataColumn(
                        title: 'VERIFICATION',
                        builder: (v) => _buildVerificationBadge(v.verificationStatus),
                      ),
                      AdminDataColumn(
                        title: 'OPERATIONAL STATUS',
                        builder: (v) => _buildOperationalBadge(v.operationalStatus),
                      ),
                      AdminDataColumn(
                        title: 'ACTIONS',
                        builder: (v) => OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showDetailPanel(context, v.id),
                          child: const Text('Inspect & Operate', style: TextStyle(fontSize: 11.5)),
                        ),
                      ),
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

  Widget _buildKpiRow(FleetKpisModel kpis) {
    return Row(
      children: [
        Expanded(child: _kpiCard('Total Fleet', '${kpis.total}', Icons.directions_car, const Color(0xFF3B82F6))),
        const Gap(12),
        Expanded(child: _kpiCard('Active & Online', '${kpis.active}', Icons.check_circle_outline, const Color(0xFF10B981))),
        const Gap(12),
        Expanded(child: _kpiCard('Pending Review', '${kpis.pendingVerification}', Icons.hourglass_top, const Color(0xFFF59E0B))),
        const Gap(12),
        Expanded(child: _kpiCard('In Maintenance', '${kpis.maintenance}', Icons.build_circle_outlined, const Color(0xFFEA580C))),
        const Gap(12),
        Expanded(child: _kpiCard('Suspended', '${kpis.suspended}', Icons.block, const Color(0xFFEF4444))),
        const Gap(12),
        Expanded(child: _kpiCard('Readiness Rate', '${kpis.operationalReadinessRate}%', Icons.speed, const Color(0xFF8B5CF6))),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'ACTIVE':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'PENDING_VERIFICATION':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'MAINTENANCE':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF9A3412);
        break;
      case 'SUSPENDED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'RETIRED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      default:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVerificationBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'VERIFIED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Detailed Vehicle Drawer Panel with Operational Readiness
// ─────────────────────────────────────────────────────────────

class _CarDetailPanel extends ConsumerStatefulWidget {
  final String carId;
  const _CarDetailPanel({required this.carId});

  @override
  ConsumerState<_CarDetailPanel> createState() => _CarDetailPanelState();
}

class _CarDetailPanelState extends ConsumerState<_CarDetailPanel> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showActionDialog({
    required String title,
    required String prompt,
    required String confirmLabel,
    required Color confirmColor,
    required bool requiresReason,
    required Future<void> Function(String reason) onConfirm,
  }) {
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const Gap(12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: requiresReason ? 'Enter mandatory reason/notes...' : 'Optional notes...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            onPressed: () async {
              final text = _reasonController.text.trim();
              if (requiresReason && text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A valid reason is required for this action.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await onConfirm(text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title completed successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readinessAsync = ref.watch(vehicleReadinessProvider(widget.carId));
    final auditLogsAsync = ref.watch(vehicleAuditLogsProvider(widget.carId));
    final vehiclesAsync = ref.watch(adminFleetVehiclesProvider);

    final vehicle = (vehiclesAsync.value ?? []).firstWhere(
      (v) => v.id == widget.carId,
      orElse: () => AdminFleetVehicleModel(
        id: widget.carId,
        vendorId: '',
        make: 'Vehicle',
        model: 'Detail',
        year: 2024,
        type: 'SEDAN',
        fuelType: 'PETROL',
        seating: 5,
        isAC: true,
        registrationNumber: '',
        photos: [],
        pricePerKm: 0,
        pricePerDay: 0,
        pricePerHour: 0,
        isAvailable: false,
        operationalStatus: 'DRAFT',
        verificationStatus: 'PENDING',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car, color: Color(0xFF2563EB), size: 32),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle.make} ${vehicle.model} (${vehicle.year})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const Gap(4),
                        Text(
                          'Plate: ${vehicle.registrationNumber} | Fuel: ${vehicle.fuelType} | Seating: ${vehicle.seating}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const Gap(4),
                        Text(
                          'Vendor: ${vehicle.vendorBusinessName ?? vehicle.vendorId} (${vehicle.vendorCity ?? "—"})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Operational Readiness Card
            readinessAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Readiness error: $e'),
              data: (readiness) => _buildReadinessCard(readiness),
            ),
            const Gap(16),

            // Maintenance Banner (if in maintenance)
            if (vehicle.operationalStatus == 'MAINTENANCE') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.build_circle, color: Color(0xFFEA580C), size: 18),
                        Gap(8),
                        Text(
                          'Vehicle In Scheduled Maintenance',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9A3412), fontSize: 13),
                        ),
                      ],
                    ),
                    const Gap(6),
                    Text(
                      'Reason: ${vehicle.maintenanceReason ?? "Routine inspection"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                    if (vehicle.expectedReturnDate != null) ...[
                      const Gap(4),
                      Text(
                        'Expected Return: ${DateFormat("MMM dd, yyyy").format(vehicle.expectedReturnDate!)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9A3412)),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(16),
            ],

            // Sensitive Administrative Action Controls
            const Text(
              'Administrative Operations & Transitions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Verify
                if (vehicle.verificationStatus != 'VERIFIED')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Approve Verification'),
                    onPressed: () => _showActionDialog(
                      title: 'Verify Vehicle',
                      prompt: 'Approve vehicle registration and documentation. Vehicle will auto-activate if readiness checks pass.',
                      confirmLabel: 'Verify & Activate',
                      confirmColor: const Color(0xFF10B981),
                      requiresReason: false,
                      onConfirm: (notes) => ref.read(adminFleetControllerProvider.notifier).verifyVehicle(
                            widget.carId,
                            notes: notes,
                            autoActivate: true,
                          ),
                    ),
                  ),

                // Reject
                if (vehicle.verificationStatus != 'REJECTED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Reject Verification'),
                    onPressed: () => _showActionDialog(
                      title: 'Reject Vehicle Verification',
                      prompt: 'Specify the compliance or documentation blocker reason for rejecting this vehicle.',
                      confirmLabel: 'Reject Vehicle',
                      confirmColor: Colors.red,
                      requiresReason: true,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).rejectVehicle(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),

                // Activate
                if (vehicle.operationalStatus != 'ACTIVE')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Activate for Booking'),
                    onPressed: () => _showActionDialog(
                      title: 'Activate Vehicle',
                      prompt: 'Server-side engine will evaluate readiness requirements before granting bookable status.',
                      confirmLabel: 'Activate',
                      confirmColor: const Color(0xFF2563EB),
                      requiresReason: false,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).activateVehicle(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),

                // Deactivate
                if (vehicle.operationalStatus == 'ACTIVE')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[800]),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Deactivate'),
                    onPressed: () => _showActionDialog(
                      title: 'Deactivate Vehicle',
                      prompt: 'Move vehicle to INACTIVE status. Vehicle will stop appearing in search results.',
                      confirmLabel: 'Deactivate',
                      confirmColor: Colors.grey[800]!,
                      requiresReason: false,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).deactivateVehicle(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),

                // Start Maintenance
                if (vehicle.operationalStatus != 'MAINTENANCE' && vehicle.operationalStatus != 'RETIRED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEA580C)),
                    icon: const Icon(Icons.build, size: 16),
                    label: const Text('Start Maintenance'),
                    onPressed: () => _showActionDialog(
                      title: 'Place in Maintenance',
                      prompt: 'Specify reason for maintenance. If conflicting active bookings exist, action will be rejected.',
                      confirmLabel: 'Initiate Maintenance',
                      confirmColor: const Color(0xFFEA580C),
                      requiresReason: true,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).startMaintenance(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),

                // Complete Maintenance
                if (vehicle.operationalStatus == 'MAINTENANCE')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Complete Maintenance'),
                    onPressed: () => _showActionDialog(
                      title: 'Complete Maintenance',
                      prompt: 'Certify maintenance completion. Vehicle will be restored to ACTIVE if eligible.',
                      confirmLabel: 'Complete & Reactivate',
                      confirmColor: const Color(0xFF10B981),
                      requiresReason: false,
                      onConfirm: (notes) => ref.read(adminFleetControllerProvider.notifier).completeMaintenance(
                            widget.carId,
                            notes: notes,
                          ),
                    ),
                  ),

                // Suspend
                if (vehicle.operationalStatus != 'SUSPENDED' && vehicle.operationalStatus != 'RETIRED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red[800]),
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('Suspend Vehicle'),
                    onPressed: () => _showActionDialog(
                      title: 'Suspend Vehicle Operations',
                      prompt: 'Administratively suspend this vehicle due to safety, fraudulent, or policy violations.',
                      confirmLabel: 'Suspend Fleet Vehicle',
                      confirmColor: Colors.red[800]!,
                      requiresReason: true,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).suspendVehicle(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),

                // Retire
                if (vehicle.operationalStatus != 'RETIRED')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Retire Decommission'),
                    onPressed: () => _showActionDialog(
                      title: 'Permanently Retire Vehicle',
                      prompt: 'Decommission vehicle from DriveGo fleet. This action is terminal.',
                      confirmLabel: 'Permanently Retire',
                      confirmColor: Colors.red,
                      requiresReason: true,
                      onConfirm: (reason) => ref.read(adminFleetControllerProvider.notifier).retireVehicle(
                            widget.carId,
                            reason: reason,
                          ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),

            // Audit Timeline
            const Text(
              'Audit & Operational History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const Gap(10),
            auditLogsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading audit: $e'),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Text('No operational audit events recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 12));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (ctx, idx) {
                    final l = logs[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.history, size: 14, color: Color(0xFF475569)),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l.action.replaceAll('_', ' '),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, HH:mm').format(l.createdAt),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              if (l.reason != null && l.reason!.isNotEmpty) ...[
                                const Gap(2),
                                Text(
                                  l.reason!,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                ),
                              ],
                              const Gap(2),
                              Text(
                                'Actor: ${l.actorRole} (${l.actorId}) | ${l.fromStatus ?? "NONE"} → ${l.toStatus}',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard(VehicleReadinessModel readiness) {
    final eligible = readiness.eligible;
    final color = eligible ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(eligible ? Icons.check_circle : Icons.warning_amber_rounded, color: color, size: 20),
              const Gap(8),
              Text(
                eligible ? 'Vehicle Operationally Eligible & Bookable' : 'Activation Blockers Detected',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
            ],
          ),
          if (!eligible && readiness.blockers.isNotEmpty) ...[
            const Gap(10),
            ...readiness.blockers.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        b.message,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!eligible && readiness.requiredActions.isNotEmpty) ...[
            const Gap(6),
            const Text(
              'Required Actions to Unlock Activation:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF991B1B)),
            ),
            const Gap(4),
            ...readiness.requiredActions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 14, color: Color(0xFF991B1B)),
                    Expanded(
                      child: Text(a, style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
