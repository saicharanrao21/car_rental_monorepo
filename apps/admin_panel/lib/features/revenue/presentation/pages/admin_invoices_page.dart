import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';

final adminInvoicesSearchQueryProvider = StateProvider<String>((ref) => '');

final adminInvoicesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final search = ref.watch(adminInvoicesSearchQueryProvider);

  final queryParams = <String, dynamic>{
    if (search.isNotEmpty) 'search': search,
    'limit': 50,
  };

  final response = await client.dio.get(
    '/admin/invoices',
    queryParameters: queryParams,
  );

  final data = response.data;
  if (data is Map<String, dynamic> && data['invoices'] is List) {
    return data['invoices'] as List<dynamic>;
  }
  return [];
});

class AdminInvoicesPage extends ConsumerStatefulWidget {
  const AdminInvoicesPage({super.key});

  @override
  ConsumerState<AdminInvoicesPage> createState() => _AdminInvoicesPageState();
}

class _AdminInvoicesPageState extends ConsumerState<AdminInvoicesPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(adminInvoicesSearchQueryProvider.notifier).state =
          _searchController.text.trim();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> invoice) {
    final invoiceNum = invoice['invoiceNumber'] ?? 'N/A';
    final customer = invoice['customer']?['name'] ?? 'N/A';
    final vendor = invoice['vendor']?['businessName'] ?? 'N/A';
    final baseFare = (invoice['baseFare'] as num?)?.toDouble() ?? 0;
    final platformFee = (invoice['platformFee'] as num?)?.toDouble() ?? 0;
    final gst = (invoice['gstAmount'] as num?)?.toDouble() ?? 0;
    final discount = (invoice['discountAmount'] as num?)?.toDouble() ?? 0;
    final total = (invoice['totalFare'] as num?)?.toDouble() ?? 0;
    final deposit = (invoice['depositAmount'] as num?)?.toDouble() ?? 0;
    final issuedAt = invoice['issuedAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(invoice['issuedAt']))
        : 'N/A';

    AdminDetailDrawer.show(
      context: context,
      title: 'Tax Invoice & Receipt',
      subtitle: 'Invoice #: $invoiceNum',
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Customer:', customer),
                _detailRow('Vendor Fleet:', vendor),
                _detailRow('Booking ID:', invoice['bookingId'] ?? 'N/A'),
                _detailRow('Payment ID:', invoice['paymentId'] ?? 'N/A'),
                _detailRow('Issued Date:', issuedAt),
              ],
            ),
          ),
          const Gap(16),
          const Text('Fare & Tax Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Gap(8),
          _fareRow('Vehicle Rental Base Fare', baseFare),
          _fareRow('Platform Service Fee', platformFee),
          if (discount > 0)
            _fareRow('Promotional Coupon Discount', -discount,
                isDiscount: true),
          _fareRow('GST (18% on Platform Fee)', gst),
          const Divider(height: 16),
          _fareRow('Trip Rental Total', total, isBold: true),
          _fareRow('Refundable Security Deposit', deposit,
              isBold: true, color: Colors.blue[800]),
          const Divider(height: 16),
          _fareRow('Grand Total Received', total + deposit,
              isBold: true, color: Colors.black87),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Company GSTIN: 27AAAAA1111A1Z1 • Escrow Deposit Segregated • Immutable Tax Record',
              style: TextStyle(fontSize: 11, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _fareRow(String label, double amount,
      {bool isBold = false, bool isDiscount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isDiscount
                ? '- ₹${amount.abs().toInt()}'
                : '₹${amount.toInt()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green[700] : (color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(adminInvoicesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GST Invoices & Receipts Audit',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Authoritative, immutable tax invoices generated for confirmed bookings',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const Gap(20),

            // Search Bar
            AppTextField(
              label: 'Search Invoices',
              controller: _searchController,
              hint: 'Search by Invoice #, Booking ID, Customer, or Vendor...',
              prefixIcon: const Icon(Icons.search),
            ),
            const Gap(20),

            // Invoices Data Table
            Expanded(
              child: invoicesAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading invoices: $err',
                  onRetry: () => ref.invalidate(adminInvoicesProvider),
                ),
                data: (invoices) {
                  return AdminDataGrid<dynamic>(
                    items: invoices,
                    emptyTitle: 'No Invoices Found',
                    emptyMessage: 'No tax invoices match the search criteria.',
                    emptyIcon: Icons.receipt_long_outlined,
                    onRowTap: (inv) => _showInvoiceDetails(context, inv as Map<String, dynamic>),
                    columns: [
                      AdminDataColumn(
                        title: 'INVOICE #',
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          return Text(
                            invMap['invoiceNumber'] ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                          );
                        },
                      ),
                      AdminDataColumn(
                        title: 'DATE',
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          return Text(
                            invMap['issuedAt'] != null
                                ? DateFormat('dd MMM yyyy').format(DateTime.parse(invMap['issuedAt']))
                                : 'N/A',
                            style: const TextStyle(fontSize: 12.5),
                          );
                        },
                      ),
                      AdminDataColumn(
                        title: 'CUSTOMER',
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          return Text(invMap['customer']?['name'] ?? 'N/A');
                        },
                      ),
                      AdminDataColumn(
                        title: 'VENDOR FLEET',
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          return Text(invMap['vendor']?['businessName'] ?? 'N/A');
                        },
                      ),
                      AdminDataColumn(
                        title: 'TRIP FARE',
                        numeric: true,
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          final totalFare = (invMap['totalFare'] as num?)?.toDouble() ?? 0;
                          return Text('₹${totalFare.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold));
                        },
                      ),
                      AdminDataColumn(
                        title: 'DEPOSIT',
                        numeric: true,
                        builder: (inv) {
                          final invMap = inv as Map<String, dynamic>;
                          final deposit = (invMap['depositAmount'] as num?)?.toDouble() ?? 0;
                          return Text('₹${deposit.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue));
                        },
                      ),
                      AdminDataColumn(
                        title: 'ACTIONS',
                        builder: (inv) => OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('View', style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showInvoiceDetails(context, inv as Map<String, dynamic>),
                        ),
                      ),
                    ],
                    mobileCardBuilder: (ctx, inv) {
                      final invMap = inv as Map<String, dynamic>;
                      final invNum = invMap['invoiceNumber'] ?? 'N/A';
                      final totalFare = (invMap['totalFare'] as num?)?.toDouble() ?? 0;
                      final dateStr = invMap['issuedAt'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(invMap['issuedAt']))
                          : 'N/A';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(invNum, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                Text('₹${totalFare.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Gap(4),
                            Text('${invMap["customer"]?["name"] ?? "Customer"} • $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
