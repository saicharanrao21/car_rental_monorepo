import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/admin_booking_providers.dart';
import '../../../vendors/presentation/providers/admin_vendor_providers.dart';

import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';

class AdminBookingManagementPage extends ConsumerStatefulWidget {
  const AdminBookingManagementPage({super.key});

  @override
  ConsumerState<AdminBookingManagementPage> createState() => _AdminBookingManagementPageState();
}

class _AdminBookingManagementPageState extends ConsumerState<AdminBookingManagementPage> {
  void _showDetailPanel(BuildContext context, String bookingId) {
    AdminDetailDrawer.show(
      context: context,
      title: 'Booking Details',
      subtitle: '#${bookingId.toUpperCase()}',
      width: 550,
      child: _BookingDetailPanel(bookingId: bookingId),
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
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading bookings list: $err',
                  onRetry: () => ref.invalidate(adminBookingsProvider),
                ),
                data: (bookings) {
                  return AdminDataGrid<BookingModel>(
                    items: bookings,
                    emptyTitle: 'No Bookings Found',
                    emptyMessage: 'No bookings match the selected filters or search criteria.',
                    emptyIcon: Icons.receipt_long_outlined,
                    onRowTap: (b) => _showDetailPanel(context, b.id),
                    columns: [
                      AdminDataColumn<BookingModel>(
                        title: 'BOOKING ID',
                        builder: (BookingModel b) => Text(
                          '#${b.id.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                        ),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'CUSTOMER',
                        builder: (BookingModel b) => Text('Customer #${b.customerId.length > 6 ? b.customerId.substring(0, 6) : b.customerId}'),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'VENDOR',
                        builder: (BookingModel b) => Text('Vendor #${b.vendorId.length > 6 ? b.vendorId.substring(0, 6) : b.vendorId}'),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'VEHICLE',
                        builder: (BookingModel b) => Text('Vehicle #${b.carId.length > 6 ? b.carId.substring(0, 6) : b.carId}'),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'PICKUP LOCATION',
                        builder: (BookingModel b) => ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(b.pickupLocation, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'TRIP TYPE',
                        builder: (BookingModel b) => Text(b.tripType),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'DATES',
                        builder: (BookingModel b) => Text(
                          '${DateFormat('dd MMM').format(b.startDate)} - ${DateFormat('dd MMM yyyy').format(b.endDate)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'TOTAL FARE',
                        numeric: true,
                        builder: (BookingModel b) => Text(
                          '₹${b.totalFare.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'STATUS',
                        builder: (BookingModel b) => AdminStatusBadge(status: b.status),
                      ),
                      AdminDataColumn<BookingModel>(
                        title: 'DISPUTE',
                        builder: (BookingModel b) => b.disputeFlag
                            ? const Icon(Icons.flag, color: Colors.red, size: 18)
                            : const SizedBox.shrink(),
                      ),
                    ],
                    mobileCardBuilder: (ctx, BookingModel b) {
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
                                Text(
                                  '#${b.id.toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                                ),
                                AdminStatusBadge(status: b.status, compact: true),
                              ],
                            ),
                            const Gap(8),
                            Text(
                              '${b.tripType} • ${b.pickupLocation}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                            const Gap(4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${DateFormat('dd MMM').format(b.startDate)} - ${DateFormat('dd MMM yyyy').format(b.endDate)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text(
                                  '₹${b.totalFare.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildFulfillmentBadge(BookingModel b) {
    final isDoorstep = b.deliveryType == 'DOORSTEP_DELIVERY' || b.deliveryAddress != null;
    final isTransit = b.deliveryType == 'PUBLIC_LOCATION' ||
        (b.pickupHubId != null && b.pickupHubId!.startsWith('pub_'));
    final isDiffReturn = (b.oneWayFee ?? 0) > 0 || (b.dropName != null && b.dropName != b.pickupName);

    String label = 'HOST YARD';
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF166534);
    IconData icon = Icons.garage_outlined;

    if (isDoorstep) {
      label = 'DOORSTEP DELIVERY';
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
      icon = Icons.local_shipping_outlined;
    } else if (isTransit) {
      label = 'TRANSIT HUB';
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF6B21A8);
      icon = Icons.connecting_airports_outlined;
    } else if (isDiffReturn) {
      label = 'BRANCH RELOCATION';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      icon = Icons.alt_route_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const Gap(4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(bookingDetailBundleProvider(bookingId));
    final controllerState = ref.watch(adminBookingControllerProvider);

    return bundleAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: AppLoader(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $err'),
        ),
      ),
      data: (bundle) {
        final b = bundle.booking;
        final car = bundle.car;
        final vendor = bundle.vendor;
        final customer = bundle.customer;

        final fulfillmentTotal = (b.deliveryFee ?? 0) + (b.oneWayFee ?? 0) + (b.pickupFee ?? 0) + (b.returnFee ?? 0);
        final baseFare = (b.totalFare - b.platformFee - b.gstAmount - fulfillmentTotal).clamp(0.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controllerState.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
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

                    // Fulfillment & Trip Snapshot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: SectionHeader(title: 'Fulfillment & Trip Snapshot')),
                        _buildFulfillmentBadge(b),
                      ],
                    ),
                    const Gap(12),
                    _DetailRow(label: 'Trip Type', value: b.tripType),
                    _DetailRow(
                      label: 'Handover Location',
                      value: b.pickupName ?? (b.deliveryAddress != null ? 'Customer Doorstep' : b.pickupLocation),
                    ),
                    if (b.deliveryAddress != null)
                      _DetailRow(label: 'Delivery Address', value: b.deliveryAddress!),
                    if (b.pickupAddress != null && b.pickupAddress != b.deliveryAddress && b.pickupAddress != b.pickupLocation)
                      _DetailRow(label: 'Pickup Address', value: b.pickupAddress!),
                    if (b.deliveryLatitude != null && b.deliveryLongitude != null)
                      _DetailRow(
                        label: 'GPS Coordinates',
                        value: '${b.deliveryLatitude!.toStringAsFixed(4)}, ${b.deliveryLongitude!.toStringAsFixed(4)}',
                      ),
                    _DetailRow(
                      label: 'Return Destination',
                      value: b.dropName ?? b.dropLocation ?? 'Same Location',
                    ),
                    if ((b.oneWayFee ?? 0) > 0)
                      _DetailRow(
                        label: 'Relocation Surcharge',
                        value: '₹${b.oneWayFee!.toInt()}',
                        valueColor: const Color(0xFF92400E),
                      ),
                    _DetailRow(
                      label: 'Trip Schedule',
                      value: '${DateFormat('dd MMM yyyy, hh:mm a').format(b.startDate)} to ${DateFormat('dd MMM yyyy, hh:mm a').format(b.endDate)}',
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
                    const SectionHeader(title: 'Fare Breakdown & Fulfillment'),
                    const Gap(12),
                    _DetailRow(label: 'Base Ride Fare', value: '₹${baseFare.toStringAsFixed(2)}'),
                    if ((b.deliveryFee ?? 0) > 0)
                      _DetailRow(
                        label: 'Doorstep Delivery Fee',
                        value: '₹${b.deliveryFee!.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF3730A3),
                      ),
                    if ((b.oneWayFee ?? 0) > 0)
                      _DetailRow(
                        label: 'One-Way Relocation Fee',
                        value: '₹${b.oneWayFee!.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF92400E),
                      ),
                    if ((b.pickupFee ?? 0) > 0)
                      _DetailRow(
                        label: 'Pickup Hub Fee',
                        value: '₹${b.pickupFee!.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF0066FF),
                      ),
                    if ((b.returnFee ?? 0) > 0)
                      _DetailRow(
                        label: 'Return Hub Fee',
                        value: '₹${b.returnFee!.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF059669),
                      ),
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
                );
        },
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? Colors.black87 : Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Gap(12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? (isBold ? Colors.black87 : Colors.black87),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
