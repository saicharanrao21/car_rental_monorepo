import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';

class VendorBookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const VendorBookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<VendorBookingDetailPage> createState() => _VendorBookingDetailPageState();
}

class _VendorBookingDetailPageState extends ConsumerState<VendorBookingDetailPage> {
  bool _isLoadingAction = false;

  @override
  Widget build(BuildContext context) {
    final bookingsVal = ref.watch(vendorBookingsProvider);
    final booking = bookingsVal.maybeWhen(
          data: (list) {
            final idx = list.indexWhere((b) => b.id == widget.bookingId);
            return idx != -1 ? list[idx] : null;
          },
          orElse: () => null,
        ) ??
        MockData.bookings.firstWhere(
          (b) => b.id == widget.bookingId,
        );

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

    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final startStr = formatter.format(booking.startDate);
    final endStr = formatter.format(booking.endDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking ${booking.id}'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    StatusBadge(status: booking.status),
                  ],
                ),
                const Divider(height: 32),

                // Vehicle Details Card
                const Text('Vehicle Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${car.make} ${car.model}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Gap(4),
                              Text(
                                'Year ${car.year} | ${car.fuelType} | ${car.type}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Trip Duration & Route Card
                const Text('Trip Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.calendar_month, 'Pickup Date', startStr),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.calendar_month, 'Return Date', endStr),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.location_on_outlined, 'Pickup Location', booking.pickupLocation),
                        if (booking.dropLocation != null) ...[
                          const Divider(height: 24),
                          _buildInfoRow(Icons.location_on, 'Drop Location', booking.dropLocation!),
                        ],
                        const Divider(height: 24),
                        _buildInfoRow(Icons.work_outline, 'Trip Type', booking.tripType),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Customer Details Card
                const Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppColors.primary),
                            ),
                            const Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const Gap(4),
                                  Text(
                                    '+91 XXXXX XXXXX',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[800], size: 16),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  'Contact via platform only. Real contact numbers are hidden for privacy.',
                                  style: TextStyle(color: Colors.amber[900], fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Payout Transparency Breakdown
                const Text('Earnings Transparency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFareRow('Total Customer Fare', booking.totalFare, isBold: true),
                        const Gap(10),
                        _buildFareRow('Platform Fee (Subtracted)', -booking.platformFee, color: Colors.red[700]),
                        const Gap(6),
                        _buildFareRow('GST/Taxes (Subtracted)', -booking.gstAmount, color: Colors.red[700]),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Payout (Net)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            PriceTag(
                              amount: booking.netToVendor,
                              amountStyle: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(40),

                // Action Buttons
                _buildActionButtons(context, booking),
                const Gap(40),
              ],
            ),
          ),
          if (_isLoadingAction)
            Container(
              color: Colors.black12,
              child: const Center(
                child: AppLoader(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const Gap(2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey[800],
          ),
        ),
        PriceTag(
          amount: amount.abs(),
          amountStyle: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (amount < 0 ? Colors.red[700] : Colors.black87),
          ),
          suffix: amount < 0 ? ' -' : null, // Display negative sign appropriately
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, BookingModel booking) {
    if (booking.status == 'confirmed') {
      return AppButton(
        text: 'Mark as Started',
        onPressed: () => _updateStatus(booking.id, 'ongoing', 'Trip started successfully'),
      );
    } else if (booking.status == 'ongoing') {
      return AppButton(
        text: 'Mark as Completed',
        onPressed: () => _updateStatus(booking.id, 'completed', 'Trip completed successfully'),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(String id, String status, String successMessage) async {
    setState(() {
      _isLoadingAction = true;
    });

    final success = await ref.read(vendorBookingsProvider.notifier).updateStatus(id, status);

    if (mounted) {
      setState(() {
        _isLoadingAction = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update booking status')),
        );
      }
    }
  }
}
