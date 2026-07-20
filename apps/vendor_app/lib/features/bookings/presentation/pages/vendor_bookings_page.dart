import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';

class VendorBookingsPage extends ConsumerWidget {
  const VendorBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(vendorBookingsTabProvider);
    final bookingsAsync = ref.watch(vendorBookingsProvider);

    return DefaultTabController(
      length: 5,
      initialIndex: activeTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Bookings'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) {
              ref.read(vendorBookingsTabProvider.notifier).state = index;
            },
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Confirmed'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const Center(child: AppLoader()),
          error: (err, stack) => Center(
            child: ErrorStateWidget(
              message: 'Failed to load bookings',
              onRetry: () => ref.invalidate(vendorBookingsProvider),
            ),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return _buildEmptyState(activeTab);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                if (activeTab == 0) {
                  return _buildPendingRequestCard(context, ref, booking);
                } else {
                  return _buildStandardBookingCard(context, booking);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(int activeTab) {
    final Map<int, (IconData, String, String)> tabConfigs = {
      0: (Icons.pending_actions, 'No Pending Requests', 'No pending booking requests right now.'),
      1: (Icons.thumb_up_alt_outlined, 'No Confirmed Trips', 'You do not have any confirmed trips.'),
      2: (Icons.directions_car_outlined, 'No Ongoing Trips', 'No trips currently ongoing.'),
      3: (Icons.check_circle_outline, 'No Completed Trips', 'You haven\'t completed any trips yet.'),
      4: (Icons.cancel_outlined, 'No Cancelled Trips', 'Great! No trips have been cancelled.'),
    };

    final config = tabConfigs[activeTab] ?? (Icons.event_note, 'No Bookings', 'No bookings found.');

    return EmptyStateWidget(
      icon: config.$1,
      title: config.$2,
      subtitle: config.$3,
    );
  }

  Widget _buildPendingRequestCard(BuildContext context, WidgetRef ref, BookingModel req) {
    // Lookup customer name
    final customer = MockData.customers.firstWhere(
      (c) => c.id == req.customerId,
      orElse: () => UserModel(id: req.customerId, name: 'Customer', phone: '', email: '', role: 'customer'),
    );

    // Lookup car details
    final car = MockData.cars.firstWhere(
      (c) => c.id == req.carId,
      orElse: () => const CarModel(
        id: '',
        vendorId: '',
        make: 'Unknown',
        model: 'Car',
        year: 2022,
        type: '',
        fuelType: '',
        seating: 5,
        isAC: true,
        photos: [],
        pricePerKm: 0,
        pricePerDay: 0,
        pricePerHour: 0,
      ),
    );

    final formatter = DateFormat('dd MMM, hh:mm a');
    final dateStr = '${formatter.format(req.startDate)} - ${formatter.format(req.endDate)}';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                StatusBadge(
                  status: req.tripType,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 16, color: Colors.grey),
                const Gap(8),
                Text(
                  '${car.make} ${car.model}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey),
                const Gap(8),
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: Colors.grey),
                    const Gap(8),
                    Text(
                      'Trip Fare:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                PriceTag(
                  amount: req.totalFare,
                  amountStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectBottomSheet(context, ref, req.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: AppButton(
                    text: 'Accept',
                    onPressed: () async {
                      final success = await ref
                          .read(vendorBookingsProvider.notifier)
                          .updateStatus(req.id, 'confirmed');
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking request accepted')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardBookingCard(BuildContext context, BookingModel booking) {
    // Lookup customer name
    final customer = MockData.customers.firstWhere(
      (c) => c.id == booking.customerId,
      orElse: () => UserModel(id: booking.customerId, name: 'Customer', phone: '', email: '', role: 'customer'),
    );

    // Lookup car details
    final car = MockData.cars.firstWhere(
      (c) => c.id == booking.carId,
      orElse: () => const CarModel(
        id: '',
        vendorId: '',
        make: 'Unknown',
        model: 'Car',
        year: 2022,
        type: '',
        fuelType: '',
        seating: 5,
        isAC: true,
        photos: [],
        pricePerKm: 0,
        pricePerDay: 0,
        pricePerHour: 0,
      ),
    );

    return BookingCard(
      booking: booking,
      carMake: car.make,
      carModel: car.model,
      carPhoto: car.photos.isNotEmpty ? car.photos.first : null,
      partnerName: customer.name,
      onTap: () => context.push('/bookings/${booking.id}'),
    );
  }

  void _showRejectBottomSheet(BuildContext context, WidgetRef ref, String bookingId) {
    String selectedReason = 'Vehicle undergoing maintenance';
    final reasons = [
      'Vehicle undergoing maintenance',
      'Vehicle not returned on time by previous renter',
      'Pricing error or incorrect rates',
      'Driver unavailable',
      'Other',
    ];

    AppBottomSheet.show(
      context,
      title: 'Reject Booking Request',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please select a reason for rejecting this booking request.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Gap(16),
              AppDropdown<String>(
                label: 'Reason',
                value: selectedReason,
                items: reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(r),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() {
                      selectedReason = val;
                    });
                  }
                },
              ),
              const Gap(24),
              AppButton(
                text: 'Reject Booking',
                backgroundColor: Colors.red[700],
                onPressed: () async {
                  Navigator.pop(context); // Close bottom sheet
                  final success = await ref
                      .read(vendorBookingsProvider.notifier)
                      .reject(bookingId, selectedReason);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking request rejected')),
                    );
                  }
                },
              ),
              const Gap(16),
            ],
          );
        },
      ),
    );
  }
}
