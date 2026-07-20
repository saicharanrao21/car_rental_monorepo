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
                width: 500,
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
    final controllerState = ref.watch(adminVendorControllerProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Filter Top Bar ───
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: 'Search Partner',
                    controller: _searchController,
                    hint: 'Search by business or owner name...',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const Gap(16),
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
                const Gap(16),
                Expanded(
                  flex: 2,
                  child: AppDropdown<String>(
                    label: 'Status',
                    value: statusFilter ?? 'All',
                    items: const ['All', 'pending', 'verified', 'suspended']
                        .map((status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (val) {
                      ref.read(vendorStatusFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
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
            const Gap(24),

            // ─── Data List Area ───
            Expanded(
              child: vendorsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading vendors list',
                  onRetry: () => ref.invalidate(adminVendorsProvider),
                ),
                data: (vendors) {
                  if (vendors.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: 'No Partners Found',
                        subtitle: 'No vendor partners match the filters.',
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
                          DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Cars', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Bookings', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: vendors.map((v) {
                          // Check if row is selectable (only pending rows can be checkbox selected for bulk approval)
                          final isPending = v.verificationStatus == 'pending';
                          final isChecked = _selectedPendingIds.contains(v.id);

                          // Lookup stats synchronously
                          final carsCount = MockData.cars.where((c) => c.vendorId == v.id).length;
                          final bookingsCount = MockData.bookings.where((b) => b.vendorId == v.id).length;

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
                                InkWell(
                                  onTap: () => _showDetailPanel(context, v.id),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                        child: Text(
                                          v.businessName.isNotEmpty ? v.businessName[0].toUpperCase() : 'V',
                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const Gap(12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(v.businessName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(v.ownerName, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(v.city)),
                              DataCell(Text('$carsCount')),
                              DataCell(Text('$bookingsCount')),
                              DataCell(StatusBadge(status: v.verificationStatus)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (v.verificationStatus == 'pending' || v.verificationStatus == 'suspended')
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                        onPressed: () {
                                          _showConfirmDialog(
                                            context: context,
                                            title: 'Verify Vendor',
                                            content: 'Approve "${v.businessName}" as a verified platform partner?',
                                            onConfirm: () async {
                                              await ref
                                                  .read(adminVendorControllerProvider.notifier)
                                                  .setVendorStatus(v.id, 'verified');
                                              setState(() {
                                                _selectedPendingIds.remove(v.id);
                                              });
                                            },
                                          );
                                        },
                                        tooltip: 'Approve',
                                      ),
                                    if (v.verificationStatus == 'verified')
                                      IconButton(
                                        icon: const Icon(Icons.block_flipped, color: Colors.orange),
                                        onPressed: () {
                                          _showConfirmDialog(
                                            context: context,
                                            title: 'Suspend Vendor',
                                            content: 'Suspend "${v.businessName}"? Their listings will be temporarily disabled.',
                                            onConfirm: () async {
                                              await ref
                                                  .read(adminVendorControllerProvider.notifier)
                                                  .setVendorStatus(v.id, 'suspended');
                                              setState(() {
                                                _selectedPendingIds.remove(v.id);
                                              });
                                            },
                                          );
                                        },
                                        tooltip: 'Suspend',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        _showConfirmDialog(
                                          context: context,
                                          title: 'Remove Vendor',
                                          content: 'Permanently remove "${v.businessName}"? This action is irreversible.',
                                          onConfirm: () async {
                                            await ref
                                                .read(adminVendorControllerProvider.notifier)
                                                .setVendorStatus(v.id, 'removed');
                                            setState(() {
                                              _selectedPendingIds.remove(v.id);
                                            });
                                          },
                                        );
                                      },
                                      tooltip: 'Remove',
                                    ),
                                  ],
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
class _VendorDetailPanel extends ConsumerWidget {
  final String vendorId;
  final VoidCallback onStatusChanged;

  const _VendorDetailPanel({
    required this.vendorId,
    required this.onStatusChanged,
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(vendorDetailBundleProvider(vendorId));
    final controllerState = ref.watch(adminVendorControllerProvider);

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

          // Lookup car models details in mock data
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
                                StatusBadge(status: v.verificationStatus),
                              ],
                            ),
                            const Gap(8),
                            Text('Owner: ${v.ownerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            const Gap(4),
                            Text('City: ${v.city} • Phone: ${v.phone}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const Gap(8),
                            Row(
                              children: [
                                StarRating(rating: v.rating, size: 16),
                                const Gap(6),
                                Text(
                                  '(${v.rating.toStringAsFixed(1)}) • ${v.totalTrips} Trips Completed',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Gap(24),

                      // Business & Bank details
                      const SectionHeader(title: 'Legal & Bank Information'),
                      const Gap(12),
                      _DetailRow(label: 'GST Number', value: (v.gstNumber != null && v.gstNumber!.isNotEmpty) ? v.gstNumber! : 'N/A'),
                      _DetailRow(label: 'Bank Account', value: (v.bankDetails != null && v.bankDetails!.isNotEmpty) ? v.bankDetails! : 'N/A'),
                      const Gap(24),

                      // Documents checklist (Placeholders)
                      const SectionHeader(title: 'Verification Documents'),
                      const Gap(12),
                      const _DocumentItem(name: 'Certificate of Incorporation / Business License'),
                      const _DocumentItem(name: 'Owner PAN & Aadhaar Cards'),
                      const _DocumentItem(name: 'Cancelled Bank Cheque / Passbook'),
                      const Gap(24),

                      // Fleet List Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionHeader(title: 'Vehicles Fleet'),
                          Text(
                            '${bundle.carCount} Listed',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
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

                      // Booking History Table
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

              // Action Buttons Bottom Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    if (v.verificationStatus == 'pending' || v.verificationStatus == 'suspended')
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppButton(
                            text: 'Approve Partner',
                            backgroundColor: Colors.green,
                            onPressed: controllerState.isLoading
                                ? null
                                : () => _showConfirm(context, 'Approve', () async {
                                      await ref
                                          .read(adminVendorControllerProvider.notifier)
                                          .setVendorStatus(v.id, 'verified');
                                      onStatusChanged();
                                    }),
                          ),
                        ),
                      ),
                    if (v.verificationStatus == 'verified')
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppButton(
                            text: 'Suspend',
                            backgroundColor: Colors.orange,
                            onPressed: controllerState.isLoading
                                ? null
                                : () => _showConfirm(context, 'Suspend', () async {
                                      await ref
                                          .read(adminVendorControllerProvider.notifier)
                                          .setVendorStatus(v.id, 'suspended');
                                      onStatusChanged();
                                    }),
                          ),
                        ),
                      ),
                    Expanded(
                      child: AppButton(
                        text: 'Remove',
                        backgroundColor: Colors.red,
                        onPressed: controllerState.isLoading
                            ? null
                            : () => _showConfirm(context, 'Remove', () async {
                                  await ref
                                      .read(adminVendorControllerProvider.notifier)
                                      .setVendorStatus(v.id, 'removed');
                                  onStatusChanged();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                }),
                      ),
                    ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _DocumentItem extends StatelessWidget {
  final String name;
  const _DocumentItem({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: Colors.grey, size: 20),
                const Gap(10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {}, // No-op View button
            child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
