import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/admin_booking_providers.dart';
import '../../vendors/presentation/providers/admin_vendor_providers.dart';

class AdminBookingManagementPage extends ConsumerStatefulWidget {
  const AdminBookingManagementPage({super.key});

  @override
  ConsumerState<AdminBookingManagementPage> createState() => _AdminBookingManagementPageState();
}

class _AdminBookingManagementPageState extends ConsumerState<AdminBookingManagementPage> {
  void _showDetailPanel(BuildContext context, String bookingId) {
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
                width: 550,
                height: double.infinity,
                child: _BookingDetailPanel(bookingId: bookingId),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final cityFilter = ref.watch(bookingCityFilterProvider);
    final tripTypeFilter = ref.watch(bookingTripTypeFilterProvider);
    final statusFilter = ref.watch(bookingStatusFilterProvider);
    final vendorFilter = ref.watch(bookingVendorFilterProvider);
    final carTypeFilter = ref.watch(bookingCarTypeFilterProvider);
    final dateRangeFilter = ref.watch(bookingDateRangeFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Filter Top Bar ───
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 150,
                  child: AppDropdown<String>(
                    label: 'City',
                    value: cityFilter ?? 'All',
                    items: ['All', ...AppConstants.indianCities]
                        .map((city) => DropdownMenuItem<String>(
                              value: city,
                              child: SizedBox(
                                width: 80,
                                child: Text(city, overflow: TextOverflow.ellipsis),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      ref.read(bookingCityFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: AppDropdown<String>(
                    label: 'Trip Type',
                    value: tripTypeFilter ?? 'All',
                    items: ['All', ...AppConstants.tripTypes]
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: SizedBox(
                                width: 100,
                                child: Text(type, overflow: TextOverflow.ellipsis),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      ref.read(bookingTripTypeFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: AppDropdown<String>(
                    label: 'Status',
                    value: statusFilter ?? 'All',
                    items: const ['All', 'pending', 'confirmed', 'ongoing', 'completed', 'cancelled']
                        .map((status) => DropdownMenuItem<String>(
                              value: status,
                              child: SizedBox(
                                width: 90,
                                child: Text(status, overflow: TextOverflow.ellipsis),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      ref.read(bookingStatusFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: AppDropdown<String>(
                    label: 'Vendor',
                    value: vendorFilter ?? 'All',
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'All',
                        child: SizedBox(
                          width: 150,
                          child: Text('All Vendors', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      ...(ref.watch(adminVendorsProvider).value ?? []).map((v) => DropdownMenuItem<String>(
                            value: v.id,
                            child: SizedBox(
                              width: 150,
                              child: Text(v.businessName, overflow: TextOverflow.ellipsis),
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      ref.read(bookingVendorFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: AppDropdown<String>(
                    label: 'Car Type',
                    value: carTypeFilter ?? 'All',
                    items: ['All', ...AppConstants.carCategories]
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: SizedBox(
                                width: 90,
                                child: Text(type, overflow: TextOverflow.ellipsis),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      ref.read(bookingCarTypeFilterProvider.notifier).state =
                          (val == 'All' || val == null) ? null : val;
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Date Range',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Gap(8),
                      InkWell(
                        onTap: () async {
                          final pickedRange = await showDateRangePicker(
                            context: context,
                            initialDateRange: dateRangeFilter,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2027),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedRange != null) {
                            ref.read(bookingDateRangeFilterProvider.notifier).state = pickedRange;
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[350]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dateRangeFilter == null
                                      ? 'Select date range'
                                      : '${DateFormat('dd MMM').format(dateRangeFilter.start)} - ${DateFormat('dd MMM yyyy').format(dateRangeFilter.end)}',
                                  style: TextStyle(
                                    color: dateRangeFilter == null ? Colors.grey[600] : Colors.black87,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cityFilter != null ||
                    tripTypeFilter != null ||
                    statusFilter != null ||
                    vendorFilter != null ||
                    carTypeFilter != null ||
                    dateRangeFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(bookingCityFilterProvider.notifier).state = null;
                      ref.read(bookingTripTypeFilterProvider.notifier).state = null;
                      ref.read(bookingStatusFilterProvider.notifier).state = null;
                      ref.read(bookingVendorFilterProvider.notifier).state = null;
                      ref.read(bookingCarTypeFilterProvider.notifier).state = null;
                      ref.read(bookingDateRangeFilterProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
            const Gap(24),

            // ─── Bookings Data Table ───
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading bookings list',
                  onRetry: () => ref.invalidate(adminBookingsProvider),
                ),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'No Bookings Found',
                        subtitle: 'No bookings match the search criteria.',
                      ),
                    );
                  }

                  return AppCard(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Booking ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Car', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Trip Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Dates', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Fare', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Dispute', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: bookings.map((b) {
                          final custName = 'Customer #${b.customerId.length > 6 ? b.customerId.substring(0, 6) : b.customerId}';
                          final vendName = 'Vendor #${b.vendorId.length > 6 ? b.vendorId.substring(0, 6) : b.vendorId}';
                          final carTitle = 'Vehicle #${b.carId.length > 6 ? b.carId.substring(0, 6) : b.carId}';

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showDetailPanel(context, b.id),
                                  child: Text(
                                    b.id.toUpperCase(),
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              DataCell(Text(custName)),
                              DataCell(Text(vendName)),
                              DataCell(Text(carTitle)),
                              DataCell(Text(b.pickupLocation)),
                              DataCell(Text(b.tripType)),
                              DataCell(Text('${DateFormat('dd MMM').format(b.startDate)} - ${DateFormat('dd MMM yyyy').format(b.endDate)}')),
                              DataCell(Text('₹${b.totalFare.toStringAsFixed(0)}')),
                              DataCell(StatusBadge(status: b.status)),
                              DataCell(
                                b.disputeFlag
                                    ? const Icon(Icons.flag, color: Colors.red, size: 20)
                                    : const SizedBox.shrink(),
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

class _BookingDetailPanel extends ConsumerWidget {
  final String bookingId;
  const _BookingDetailPanel({required this.bookingId});

  void _showDisputeSheet(BuildContext context, WidgetRef ref) {
    final noteController = TextEditingController();
    AppBottomSheet.show(
      context,
      title: 'Flag Dispute',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Provide details explaining the reason for flagging this booking for dispute.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Gap(16),
          AppTextField(
            label: 'Dispute Reason / Notes',
            controller: noteController,
            hint: 'Enter dispute details...',
          ),
          const Gap(24),
          AppButton(
            text: 'Submit Dispute',
            onPressed: () {
              if (noteController.text.trim().isNotEmpty) {
                ref.read(adminBookingControllerProvider.notifier).flagBookingDispute(bookingId, noteController.text.trim());
                Navigator.pop(context);
              }
            },
          ),
          const Gap(16),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(bookingDetailBundleProvider(bookingId));
    final controllerState = ref.watch(adminBookingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details - ${bookingId.toUpperCase()}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bundleAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (bundle) {
          final b = bundle.booking;
          final car = bundle.car;
          final vendor = bundle.vendor;
          final customer = bundle.customer;

          final baseFare = b.totalFare - b.platformFee - b.gstAmount;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge(status: b.status),
                        if (b.disputeFlag)
                          const Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red, size: 20),
                              Gap(4),
                              Text(
                                'DISPUTED',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Customer Details
                    const SectionHeader(title: 'Customer Details'),
                    const Gap(12),
                    _DetailRow(label: 'Name', value: customer.name),
                    _DetailRow(label: 'Phone', value: customer.phone),
                    _DetailRow(label: 'Email', value: customer.email ?? 'N/A'),
                    const Divider(height: 32),

                    // Vendor Details
                    const SectionHeader(title: 'Vendor Partner'),
                    const Gap(12),
                    _DetailRow(label: 'Business Name', value: vendor.businessName),
                    _DetailRow(label: 'Owner Name', value: vendor.ownerName),
                    _DetailRow(label: 'City', value: vendor.city),
                    _DetailRow(label: 'Phone', value: vendor.phone.isEmpty ? 'N/A' : vendor.phone),
                    const Divider(height: 32),

                    // Car Details
                    const SectionHeader(title: 'Vehicle Details'),
                    const Gap(12),
                    _DetailRow(label: 'Car Model', value: '${car.make} ${car.model} (${car.year})'),
                    _DetailRow(label: 'Type / Category', value: car.type),
                    _DetailRow(label: 'AC Status', value: car.isAC ? 'Air Conditioned' : 'Non-AC'),
                    _DetailRow(label: 'Seats', value: '${car.seating} Seater'),
                    const Divider(height: 32),

                    // Trip Information
                    const SectionHeader(title: 'Trip Details'),
                    const Gap(12),
                    _DetailRow(label: 'Trip Type', value: b.tripType),
                    _DetailRow(label: 'Pickup Location', value: b.pickupLocation),
                    if (b.dropLocation != null) _DetailRow(label: 'Drop Location', value: b.dropLocation!),
                    _DetailRow(
                      label: 'Dates',
                      value: '${DateFormat('dd MMM yyyy').format(b.startDate)} to ${DateFormat('dd MMM yyyy').format(b.endDate)}',
                    ),
                    const Divider(height: 32),

                    // Dispute Information Section
                    if (b.disputeFlag) ...[
                      const SectionHeader(title: 'Dispute Information'),
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          b.disputeNote ?? 'No details provided.',
                          style: TextStyle(color: Colors.red[900], fontSize: 13),
                        ),
                      ),
                      const Divider(height: 32),
                    ],

                    // Fare Breakdown
                    const SectionHeader(title: 'Fare Breakdown'),
                    const Gap(12),
                    _DetailRow(label: 'Base Ride Fare', value: '₹${baseFare.toStringAsFixed(2)}'),
                    _DetailRow(label: 'Platform Fee (10%)', value: '₹${b.platformFee.toStringAsFixed(2)}'),
                    _DetailRow(label: 'GST (18% on platform fee)', value: '₹${b.gstAmount.toStringAsFixed(2)}'),
                    const Divider(height: 8),
                    _DetailRow(
                      label: 'Total Fare (charged to customer)',
                      value: '₹${b.totalFare.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    const Gap(4),
                    _DetailRow(
                      label: 'Net Pay to Vendor Partner',
                      value: '₹${b.netToVendor.toStringAsFixed(2)}',
                      isBold: true,
                      valueColor: Colors.green[700],
                    ),
                    const Gap(40),

                    // Admin Action Buttons
                    Row(
                      children: [
                        if (b.status != 'cancelled')
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppButton(
                                text: 'Force Cancel',
                                backgroundColor: Colors.red[600],
                                onPressed: () {
                                  _showConfirmDialog(
                                    context: context,
                                    title: 'Force Cancel Booking',
                                    content: 'Are you sure you want to FORCE CANCEL this booking? This bypasses standard vendor/customer flows.',
                                    onConfirm: () => ref.read(adminBookingControllerProvider.notifier).overrideBookingStatus(b.id, 'cancelled'),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (b.status != 'completed' && b.status != 'cancelled')
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppButton(
                                text: 'Force Complete',
                                backgroundColor: Colors.green[600],
                                onPressed: () {
                                  _showConfirmDialog(
                                    context: context,
                                    title: 'Force Complete Booking',
                                    content: 'Are you sure you want to FORCE COMPLETE this booking? This will trigger payouts.',
                                    onConfirm: () => ref.read(adminBookingControllerProvider.notifier).overrideBookingStatus(b.id, 'completed'),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Gap(12),
                    if (b.disputeFlag)
                      AppButton(
                        text: 'Resolve Dispute',
                        backgroundColor: Colors.blue[600],
                        onPressed: () {
                          _showConfirmDialog(
                            context: context,
                            title: 'Resolve Dispute',
                            content: 'Are you sure you want to resolve and clear this booking dispute?',
                            onConfirm: () => ref.read(adminBookingControllerProvider.notifier).flagBookingDispute(b.id, ''),
                          );
                        },
                      )
                    else
                      AppButton(
                        text: 'Flag Booking Dispute',
                        backgroundColor: Colors.orange[700],
                        onPressed: () => _showDisputeSheet(context, ref),
                      ),
                    const Gap(32),
                  ],
                ),
              ),
              if (controllerState.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: const Center(child: AppLoader()),
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
  final bool isBold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? Colors.black87 : Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? (isBold ? Colors.black87 : Colors.black87),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
