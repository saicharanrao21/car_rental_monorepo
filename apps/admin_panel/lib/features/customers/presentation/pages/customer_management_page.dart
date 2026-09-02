import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/admin_customer_providers.dart';

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  ConsumerState<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends ConsumerState<CustomerManagementPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(customerSearchQueryProvider.notifier).state = _searchController.text;
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
            child: Text(title, style: TextStyle(color: title.startsWith('Ban') ? Colors.red : Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showDetailPanel(BuildContext context, String customerId) {
    AdminDetailDrawer.show(
      context: context,
      title: 'Customer Profile',
      subtitle: 'Customer ID: #${customerId.toUpperCase()}',
      width: 500,
      child: _CustomerDetailPanel(customerId: customerId),
    );
  }

  String _deriveCustomerCity(String customerId) {
    return 'Mumbai';
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(adminCustomersProvider);
    final controllerState = ref.watch(adminCustomerControllerProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Search Bar ───
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Search Customers',
                    controller: _searchController,
                    hint: 'Search by customer name or phone...',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            const Gap(24),
            // ─── Customer Data Table Area ───
            Expanded(
              child: customersAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading customer records: $err',
                  onRetry: () => ref.invalidate(adminCustomersProvider),
                ),
                data: (customers) {
                  return AdminDataGrid<UserModel>(
                    items: customers,
                    emptyTitle: 'No Customers Found',
                    emptyMessage: 'No registered customers match the filter or search query.',
                    emptyIcon: Icons.people_outline,
                    onRowTap: (c) => _showDetailPanel(context, c.id),
                    columns: [
                      AdminDataColumn(
                        title: 'CUSTOMER PROFILE',
                        builder: (c) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const Gap(10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                Text(c.email ?? 'No email on record', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AdminDataColumn(
                        title: 'PHONE NUMBER',
                        builder: (c) => Text(c.phone, style: const TextStyle(fontSize: 12.5)),
                      ),
                      AdminDataColumn(
                        title: 'PRIMARY CITY',
                        builder: (c) => Text(_deriveCustomerCity(c.id), style: const TextStyle(fontSize: 12.5)),
                      ),
                      AdminDataColumn(
                        title: 'STATUS',
                        builder: (c) => AdminStatusBadge(status: c.banned ? 'BANNED' : 'ACTIVE'),
                      ),
                      AdminDataColumn(
                        title: 'ACTIONS',
                        builder: (c) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showDetailPanel(context, c.id),
                              child: const Text('View Profile', style: TextStyle(fontSize: 11.5)),
                            ),
                            const Gap(6),
                            IconButton(
                              icon: Icon(
                                c.banned ? Icons.check_circle_outline : Icons.block_flipped,
                                color: c.banned ? Colors.green : Colors.red,
                                size: 18,
                              ),
                              onPressed: controllerState.isLoading
                                  ? null
                                  : () {
                                      final actionTitle = c.banned ? 'Unban Customer' : 'Ban Customer';
                                      final actionContent = c.banned
                                          ? 'Unban "${c.name}"? They will regain access to rent cars.'
                                          : 'Ban "${c.name}"? They will be locked out of the mobile app.';
                                      _showConfirmDialog(
                                        context: context,
                                        title: actionTitle,
                                        content: actionContent,
                                        onConfirm: () {
                                          ref
                                              .read(adminCustomerControllerProvider.notifier)
                                              .toggleCustomerBanned(c.id, !c.banned);
                                        },
                                      );
                                    },
                              tooltip: c.banned ? 'Unban Customer' : 'Ban Customer',
                            ),
                          ],
                        ),
                      ),
                    ],
                    mobileCardBuilder: (ctx, c) {
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
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        child: Text(
                                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                          style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                      const Gap(8),
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AdminStatusBadge(status: c.banned ? 'BANNED' : 'ACTIVE', compact: true),
                              ],
                            ),
                            const Gap(6),
                            Text(
                              'Phone: ${c.phone} • ${c.email ?? "No email"}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const Gap(10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _showDetailPanel(context, c.id),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('View Profile', style: TextStyle(fontSize: 11.5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

// ─── Customer Details Slide-in Panel ───
class _CustomerDetailPanel extends ConsumerWidget {
  final String customerId;

  const _CustomerDetailPanel({required this.customerId});

  void _showConfirm(BuildContext context, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Customer'),
        content: Text('Are you sure you want to $action this customer account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(action, style: TextStyle(color: action == 'Ban' ? Colors.red : Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(customerDetailBundleProvider(customerId));
    final controllerState = ref.watch(adminCustomerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Error loading customer details: $err')),
        data: (bundle) {
          final c = bundle.profile;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Profile info
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
                                    c.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (c.banned ? Colors.red : Colors.green).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: (c.banned ? Colors.red : Colors.green).withValues(alpha: 0.24)),
                                  ),
                                  child: Text(
                                    c.banned ? 'BANNED' : 'ACTIVE',
                                    style: TextStyle(
                                      color: c.banned ? Colors.red : Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(8),
                            Text('Phone: ${c.phone}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            const Gap(4),
                            Text('Email: ${c.email ?? "N/A"}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const Gap(4),
                            Text('Joined: 15 Jan 2026', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      const Gap(24),

                      // Bookings history
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionHeader(title: 'Rental Booking Logs'),
                          Text(
                            '${bundle.bookingHistory.length} Bookings',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const Gap(12),
                      if (bundle.bookingHistory.isEmpty)
                        const Text(
                          'No rentals recorded for this customer.',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bundle.bookingHistory.length,
                          itemBuilder: (context, index) {
                            final b = bundle.bookingHistory[index];
                            final carTitle = 'Vehicle #${b.carId.length > 6 ? b.carId.substring(0, 6) : b.carId}';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long_outlined, color: Colors.blue),
                                title: Text(carTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'Dates: ${DateFormat('dd MMM').format(b.startDate)} - ${DateFormat('dd MMM').format(b.endDate)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${b.totalFare.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                    const Gap(2),
                                    StatusBadge(status: b.status),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const Gap(40),
                    ],
                  ),
                ),
              ),

              // Action Ban/Unban bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: AppButton(
                  text: c.banned ? 'Unban Customer' : 'Ban Customer Account',
                  backgroundColor: c.banned ? Colors.green : Colors.red,
                  onPressed: controllerState.isLoading
                      ? null
                      : () => _showConfirm(context, c.banned ? 'Unban' : 'Ban', () {
                            ref
                                .read(adminCustomerControllerProvider.notifier)
                                .toggleCustomerBanned(c.id, !c.banned);
                          }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
