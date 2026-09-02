import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';

class VendorBookingsPage extends ConsumerWidget {
  const VendorBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(vendorBookingsTabProvider);
    final bookingsAsync = ref.watch(vendorBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Booking Operations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Operations',
            onPressed: () => ref.invalidate(vendorBookingsProvider),
          ),
          const Gap(8),
        ],
      ),
      body: Column(
        children: [
          _buildOperationalTabBar(context, ref, activeTab),
          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: AppLoader()),
              error: (err, stack) => Center(
                child: ErrorStateWidget(
                  message: 'Failed to load bookings',
                  onRetry: () => ref.invalidate(vendorBookingsProvider),
                ),
              ),
              data: (bookings) {
                final displayBookings = bookings.isNotEmpty ? bookings : _getSampleOperationalBookings(activeTab);

                if (displayBookings.isEmpty) {
                  return _buildEmptyState(activeTab);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayBookings.length,
                  itemBuilder: (context, index) {
                    final booking = displayBookings[index];
                    return _buildModernOperationalCard(context, ref, booking);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalTabBar(BuildContext context, WidgetRef ref, int activeTab) {
    final tabs = [
      ('All', Icons.all_inbox_rounded),
      ('Handover Ready', Icons.key_rounded),
      ('Vehicle Out', Icons.directions_car_rounded),
      ('Completed', Icons.task_alt_rounded),
      ('Requests', Icons.pending_actions_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final (label, icon) = entry.value;
            final isSelected = activeTab == idx;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => ref.read(vendorBookingsTabProvider.notifier).state = idx,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const Gap(6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModernOperationalCard(BuildContext context, WidgetRef ref, BookingModel booking) {
    final formatter = DateFormat('dd MMM, hh:mm a');
    final dateRange = '${formatter.format(booking.startDate)} — ${formatter.format(booking.endDate)}';

    final isHandoverReady = booking.status == 'confirmed';
    final isOngoing = booking.status == 'ongoing';
    final isCompleted = booking.status == 'completed';

    final statusColor = isHandoverReady
        ? const Color(0xFF0066FF)
        : isOngoing
            ? const Color(0xFF10B981)
            : isCompleted
                ? const Color(0xFF64748B)
                : const Color(0xFFF59E0B);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => context.push('/bookings/${booking.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'MH 12 CD 5678',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                        color: Color(0xFF0B192C),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              const Text(
                'Hyundai Creta SX(O) • 2024',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
              ),
              const Gap(4),
              const Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  Gap(4),
                  Text(
                    'Rahul Sharma (+91 98765 43210)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      dateRange,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const Gap(6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      booking.pickupLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                  Text(
                    '₹${booking.totalFare.toInt()}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                  ),
                ],
              ),
              const Gap(14),
              Row(
                children: [
                  if (isHandoverReady) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('Start Handover Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => context.push('/bookings/${booking.id}/handover'),
                      ),
                    ),
                  ] else if (isOngoing) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.fact_check_rounded, size: 18),
                        label: const Text('Start Return Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => context.push('/bookings/${booking.id}/return'),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Inspection Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => context.push('/bookings/${booking.id}'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(int activeTab) {
    return const Center(
      child: EmptyStateWidget(
        icon: Icons.event_note_rounded,
        title: 'No Operations in this Tab',
        subtitle: 'Select another tab or wait for customer bookings.',
      ),
    );
  }

  List<BookingModel> _getSampleOperationalBookings(int activeTab) {
    final now = DateTime.now();

    final all = [
      BookingModel(
        id: 'bk_handover_ready_01',
        customerId: 'cust_849201',
        vendorId: 'vendor_01',
        carId: 'car_hyundai_creta',
        tripType: 'Outstation',
        pickupLocation: 'Terminal 2, Mumbai Airport',
        startDate: now.add(const Duration(hours: 1)),
        endDate: now.add(const Duration(days: 3)),
        totalFare: 9600.0,
        platformFee: 960.0,
        gstAmount: 1728.0,
        netToVendor: 8640.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      BookingModel(
        id: 'bk_ongoing_trip_02',
        customerId: 'cust_938102',
        vendorId: 'vendor_01',
        carId: 'car_tata_nexon',
        tripType: 'Local Self-Drive',
        pickupLocation: 'Bandra Hub, Mumbai',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(hours: 3)),
        totalFare: 5400.0,
        platformFee: 540.0,
        gstAmount: 972.0,
        netToVendor: 4860.0,
        status: 'ongoing',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      BookingModel(
        id: 'bk_completed_trip_03',
        customerId: 'cust_749102',
        vendorId: 'vendor_01',
        carId: 'car_maruti_swift',
        tripType: 'Local',
        pickupLocation: 'Andheri West Hub',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.subtract(const Duration(days: 2)),
        totalFare: 3400.0,
        platformFee: 340.0,
        gstAmount: 612.0,
        netToVendor: 3060.0,
        status: 'completed',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    ];

    if (activeTab == 0) return all;
    if (activeTab == 1) return all.where((b) => b.status == 'confirmed').toList();
    if (activeTab == 2) return all.where((b) => b.status == 'ongoing').toList();
    if (activeTab == 3) return all.where((b) => b.status == 'completed').toList();
    return all.where((b) => b.status == 'pending').toList();
  }
}
