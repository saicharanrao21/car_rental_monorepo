import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';
import '../../../fleet/presentation/providers/fleet_providers.dart';

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
                final displayBookings = bookings;

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

    final fleetCars = ref.watch(fleetCarsProvider).valueOrNull ?? [];
    final car = fleetCars.where((c) => c.id == booking.carId).firstOrNull;
    final plate = car?.registrationNumber ??
        (booking.id.length > 8 ? '#${booking.id.substring(0, 8).toUpperCase()}' : '#${booking.id.toUpperCase()}');
    final carTitle = car != null ? '${car.make} ${car.model} • ${car.year}' : '${booking.tripType} Rental';

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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      plate,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: Color(0xFF0B192C),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Text(
                carTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
              ),
              const Gap(4),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      'Booking #${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()} • ${booking.tripType}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
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
}

