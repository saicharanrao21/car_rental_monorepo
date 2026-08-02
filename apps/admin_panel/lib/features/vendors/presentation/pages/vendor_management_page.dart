import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../providers/admin_vendor_providers.dart';

class VendorManagementPage extends ConsumerStatefulWidget {
  const VendorManagementPage({super.key});

  @override
  ConsumerState<VendorManagementPage> createState() => _VendorManagementPageState();
}

class _VendorManagementPageState extends ConsumerState<VendorManagementPage> {
  final _searchController = TextEditingController();
  final Set<String> _selectedPendingIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(vendorSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(title, style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showDetailPanel(BuildContext context, String vendorId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(anim1),
            child: Material(
              color: Colors.white,
              elevation: 16,
              child: SizedBox(
                width: 540,
                height: double.infinity,
                child: _VendorDetailPanel(
                  vendorId: vendorId,
                  onStatusChanged: () {
                    setState(() {
                      _selectedPendingIds.remove(vendorId);
                    });
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(adminVendorsProvider);
    final cityFilter = ref.watch(vendorCityFilterProvider);
    final statusFilter = ref.watch(vendorStatusFilterProvider);
    final typeFilter = ref.watch(vendorTypeFilterProvider);
    final sponsoredFilter = ref.watch(vendorSponsoredFilterProvider);
    final controllerState = ref.watch(adminVendorControllerProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vendor Partner Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Approve accounts, manage location branches, and configure sponsored listing boosts.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(adminVendorsProvider),
                  tooltip: 'Refresh Vendors List',
                ),
              ],
            ),
            const Gap(20),

            // Filter Bar
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Search Partners',
                        hint: 'Search by vendor name, owner, phone...',
                        controller: _searchController,
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'City',
                        value: cityFilter ?? 'All',
                        items: ['All', ...AppConstants.indianCities]
                            .map((city) => DropdownMenuItem<String>(
                                  value: city,
                                  child: Text(city),
                                ))
                            .toList(),
                        onChanged: (val) {
                          ref.read(vendorCityFilterProvider.notifier).state =
                              (val == 'All' || val == null) ? null : val;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'Status',
                        value: statusFilter ?? 'All',
                        items: const ['All', 'PENDING', 'VERIFIED', 'SUSPENDED']
                            .map((st) => DropdownMenuItem<String>(
                                  value: st,
                                  child: Text(st),
                                ))
                            .toList(),
                        onChanged: (val) {
                          ref.read(vendorStatusFilterProvider.notifier).state =
                              (val == 'All' || val == null) ? null : val;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'Type',
                        value: typeFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                          DropdownMenuItem(value: 'HQ', child: Text('Headquarters')),
                          DropdownMenuItem(value: 'BRANCH', child: Text('Branches')),
                        ],
                        onChanged: (val) {
                          if (val != null) ref.read(vendorTypeFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: AppDropdown<String>(
                        label: 'Sponsorship',
                        value: sponsoredFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Listings')),
                          DropdownMenuItem(value: 'SPONSORED', child: Text('Sponsored Only')),
                          DropdownMenuItem(value: 'ORGANIC', child: Text('Organic Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) ref.read(vendorSponsoredFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                    const Gap(16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('', style: TextStyle(fontSize: 12)),
                        const Gap(6),
                        AppButton(
                          isFullWidth: false,
                          text: _selectedPendingIds.isEmpty
                              ? 'Bulk Approve'
                              : 'Approve Selected (${_selectedPendingIds.length})',
                          onPressed: _selectedPendingIds.isEmpty || controllerState.isLoading
                              ? null
                              : () {
                                  _showConfirmDialog(
                                    context: context,
                                    title: 'Bulk Approve',
                                    content: 'Are you sure you want to approve ${_selectedPendingIds.length} partners?',
                                    onConfirm: () async {
                                      await ref
                                          .read(adminVendorControllerProvider.notifier)
                                          .bulkApprove(_selectedPendingIds.toList());
                                      setState(() {
                                        _selectedPendingIds.clear();
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Selected partners verified successfully')),
                                        );
                                      }
                                    },
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // Data Table List Area
            Expanded(
              child: vendorsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading vendors list: $err',
                  onRetry: () => ref.invalidate(adminVendorsProvider),
                ),
                data: (vendors) {
                  if (vendors.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: 'No Partners Found',
                        subtitle: 'No vendor partners match the selected filters.',
                      ),
                    );
                  }

                  return AppCard(
                    child: SingleChildScrollView(
                      child: DataTable(
                        showCheckboxColumn: true,
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Business Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('City / Locality', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Sponsored Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Trips', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: vendors.map((v) {
                          final isPending = v.verificationStatus.toUpperCase() == 'PENDING';
                          final isChecked = _selectedPendingIds.contains(v.id);
                          final isBranch = v.branchOfId != null && v.branchOfId!.isNotEmpty;

                          int? daysUntilBoostExpires;
                          if (v.isSponsored && v.boostExpiresAt != null) {
                            daysUntilBoostExpires = v.boostExpiresAt!.difference(DateTime.now()).inDays;
                          }

                          return DataRow(
                            selected: isChecked,
                            onSelectChanged: isPending
                                ? (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedPendingIds.add(v.id);
                                      } else {
                                        _selectedPendingIds.remove(v.id);
                                      }
                                    });
                                  }
                                : null,
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(v.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Owner: ${v.ownerName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  v.locality != null && v.locality!.isNotEmpty ? '${v.locality}, ${v.city}' : v.city,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              DataCell(
                                isBranch
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange[300]!),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'BRANCH',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                            ),
                                            if (v.parentBusinessName != null)
                                              Text(
                                                'of ${v.parentBusinessName}',
                                                style: TextStyle(fontSize: 9, color: Colors.orange[800]),
                                              ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue[200]!),
                                        ),
                                        child: Text(
                                          'HQ',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                        ),
                                      ),
                              ),
                              DataCell(
                                v.isSponsored
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[50],
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.purple[300]!),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star, size: 12, color: Colors.purple[700]),
                                                const Gap(4),
                                                Text(
                                                  'BOOSTED',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple[900]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (daysUntilBoostExpires != null) ...[
                                            const Gap(2),
                                            if (daysUntilBoostExpires < 0)
                                              Text('Boost Expired', style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold))
                                            else if (daysUntilBoostExpires <= 7)
                                              Text('Expires in ${daysUntilBoostExpires}d', style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold))
                                            else
                                              Text('Expires ${DateFormat('dd MMM').format(v.boostExpiresAt!)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ],
                                      )
                                    : const Text('Organic', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                              DataCell(Text('${v.totalTrips}')),
                              DataCell(StatusBadge(status: v.verificationStatus.toLowerCase())),
                              DataCell(
                                OutlinedButton.icon(
                                  onPressed: () => _showDetailPanel(context, v.id),
                                  icon: const Icon(Icons.visibility_outlined, size: 14),
                                  label: const Text('View / Manage', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
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
}

// ─── Right Side Detail Panel Widget ───
class _VendorDetailPanel extends ConsumerStatefulWidget {
  final String vendorId;
  final VoidCallback onStatusChanged;

  const _VendorDetailPanel({
    required this.vendorId,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_VendorDetailPanel> createState() => _VendorDetailPanelState();
}

class _VendorDetailPanelState extends ConsumerState<_VendorDetailPanel> {
  bool _isSponsoredLocal = false;
  DateTime? _boostExpiresAtLocal;
  bool _initialized = false;
  bool _isUpdatingSponsorship = false;

  void _showConfirm(BuildContext context, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Partner'),
        content: Text('Are you sure you want to $action this partner?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBoostDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _boostExpiresAtLocal ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _boostExpiresAtLocal = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _saveSponsorship() async {
    setState(() => _isUpdatingSponsorship = true);
    try {
      await ref
          .read(adminVendorControllerProvider.notifier)
          .updateSponsorship(widget.vendorId, _isSponsoredLocal, _boostExpiresAtLocal);

      if (mounted) {
        setState(() => _isUpdatingSponsorship = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsorship boost updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingSponsorship = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update sponsorship: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(vendorDetailBundleProvider(widget.vendorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Partner Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Error loading vendor details: $err')),
        data: (bundle) {
          final v = bundle.vendor;

          if (!_initialized) {
            _isSponsoredLocal = v.isSponsored;
            _boostExpiresAtLocal = v.boostExpiresAt ?? DateTime.now().add(const Duration(days: 30));
            _initialized = true;
          }

          final isBranch = v.branchOfId != null && v.branchOfId!.isNotEmpty;
          final carsList = MockData.cars.where((c) => c.vendorId == v.id).toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    v.businessName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                StatusBadge(status: v.verificationStatus.toLowerCase()),
                              ],
                            ),
                            const Gap(8),
                            if (isBranch) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.store_mall_directory_outlined, size: 14, color: Colors.orange[800]),
                                    const Gap(6),
                                    Flexible(
                                      child: Text(
                                        'Location Branch of ${v.parentBusinessName ?? 'Parent HQ'}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                            ],
                            Text('Owner: ${v.ownerName} • Phone: ${v.phone}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            if (v.email != null) Text('Email: ${v.email}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ],
                        ),
                      ),
                      const Gap(20),

                      // Sponsorship Controls Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple[50]!.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.purple[700], size: 20),
                                    const Gap(8),
                                    const Text(
                                      'Sponsored Listing Controls',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _isSponsoredLocal,
                                  activeThumbColor: Colors.purple[700],
                                  onChanged: (val) {
                                    setState(() {
                                      _isSponsoredLocal = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Gap(6),
                            Text(
                              'Sponsored partners receive priority ranking boost in customer search results.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            if (_isSponsoredLocal) ...[
                              const Gap(14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Boost Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const Gap(2),
                                      Text(
                                        _boostExpiresAtLocal != null
                                            ? DateFormat('dd MMM yyyy, hh:mm a').format(_boostExpiresAtLocal!)
                                            : 'No expiration date',
                                        style: TextStyle(fontSize: 13, color: Colors.purple[900], fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickBoostDate(context),
                                    icon: const Icon(Icons.calendar_today, size: 14),
                                    label: const Text('Pick Expiry Date', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                            const Gap(16),
                            ElevatedButton.icon(
                              onPressed: _isUpdatingSponsorship ? null : _saveSponsorship,
                              icon: const Icon(Icons.save, size: 16),
                              label: Text(_isUpdatingSponsorship ? 'Saving...' : 'Update Sponsorship Boost'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[700],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(20),

                      // Business & Location Info
                      const SectionHeader(title: 'Business & Location Profile'),
                      const Gap(12),
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: 'City', value: v.city),
                              const Divider(height: 20),
                              _InfoRow(label: 'Locality', value: v.locality ?? 'Main Locality'),
                              const Divider(height: 20),
                              _InfoRow(
                                label: 'GPS Coordinates',
                                value: (v.latitude != null && v.longitude != null)
                                    ? '${v.latitude!.toStringAsFixed(4)}, ${v.longitude!.toStringAsFixed(4)}'
                                    : 'Not provided',
                              ),
                              const Divider(height: 20),
                              _InfoRow(label: 'GST Number', value: v.gstNumber ?? 'Not provided'),
                              const Divider(height: 20),
                              _InfoRow(label: 'PAN Number', value: v.panNumber ?? 'Not provided'),
                            ],
                          ),
                        ),
                      ),
                      const Gap(20),

                      // Vehicles in Fleet
                      SectionHeader(title: 'Fleet Vehicles (${bundle.carCount})'),
                      const Gap(12),
                      if (carsList.isEmpty)
                        const Text('No cars added to this fleet yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: carsList.length,
                          itemBuilder: (context, index) {
                            final car = carsList[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.directions_car_outlined, color: Colors.blue),
                                title: Text('${car.make} ${car.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${car.type} • ${car.fuelType} • ${car.seating} Seater', style: const TextStyle(fontSize: 11)),
                                trailing: Text('₹${car.pricePerDay.toInt()}/day', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ),
                            );
                          },
                        ),
                      const Gap(24),

                      // Booking History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionHeader(title: 'Trips & Bookings History'),
                          Text(
                            '${bundle.bookingCount} Total',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const Gap(12),
                      if (bundle.bookingHistory.isEmpty)
                        const Text('No bookings found for this partner.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 32,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 44,
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: bundle.bookingHistory.take(5).map((b) {
                              final cust = MockData.customers.firstWhere(
                                (c) => c.id == b.customerId,
                                orElse: () => UserModel(id: b.customerId, name: 'Unknown', phone: '', role: 'customer'),
                              );
                              return DataRow(cells: [
                                DataCell(Text('#${b.id.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                                DataCell(Text(cust.name)),
                                DataCell(Text(DateFormat('dd MMM').format(b.startDate))),
                                DataCell(Text('₹${b.totalFare.toInt()}')),
                                DataCell(StatusBadge(status: b.status)),
                              ]);
                            }).toList(),
                          ),
                        ),
                      const Gap(40),
                    ],
                  ),
                ),
              ),

              // Status Action Bottom Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    if (v.verificationStatus.toUpperCase() == 'PENDING') ...[
                      Expanded(
                        child: AppButton(
                          text: isBranch ? 'Approve Branch' : 'Approve Partner',
                          onPressed: () {
                            _showConfirm(context, 'VERIFIED', () async {
                              await ref.read(adminVendorControllerProvider.notifier).setVendorStatus(v.id, 'VERIFIED');
                              widget.onStatusChanged();
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showConfirm(context, 'REJECTED', () async {
                              await ref.read(adminVendorControllerProvider.notifier).setVendorStatus(v.id, 'REJECTED');
                              widget.onStatusChanged();
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 48),
                          ),
                          child: Text(isBranch ? 'Reject Branch' : 'Reject Partner'),
                        ),
                      ),
                    ] else if (v.verificationStatus.toUpperCase() == 'VERIFIED') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showConfirm(context, 'SUSPENDED', () async {
                              await ref.read(adminVendorControllerProvider.notifier).setVendorStatus(v.id, 'SUSPENDED');
                              widget.onStatusChanged();
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                          icon: const Icon(Icons.block, size: 16),
                          label: const Text('Suspend Account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: AppButton(
                          text: 'Re-Verify Account',
                          onPressed: () {
                            _showConfirm(context, 'VERIFIED', () async {
                              await ref.read(adminVendorControllerProvider.notifier).setVendorStatus(v.id, 'VERIFIED');
                              widget.onStatusChanged();
                              if (context.mounted) Navigator.pop(context);
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}
