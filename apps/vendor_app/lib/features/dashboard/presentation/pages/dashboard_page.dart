import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendorSessionProvider);
    final vendor = session.vendor;
    final businessName = vendor?.businessName ?? 'Partner';

    final statsAsync = ref.watch(dashboardStatsProvider);
    final requestsAsync = ref.watch(latestBookingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(vendorSessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load dashboard statistics',
            onRetry: () {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(latestBookingRequestsProvider);
            },
          ),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(latestBookingRequestsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            businessName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          businessName.isNotEmpty ? businessName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Quick Stats Cards (3 column-like cards)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Today\'s Bookings',
                          stats.todaysBookings.toString(),
                          Icons.today,
                          Colors.blue,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Pending Requests',
                          stats.pendingRequests.toString(),
                          Icons.pending_actions,
                          Colors.amber,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Earnings',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Gap(4),
                                    const Icon(Icons.account_balance_wallet, size: 16, color: Colors.green),
                                  ],
                                ),
                                const Gap(8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: PriceTag(
                                    amount: stats.thisMonthEarnings,
                                    amountStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700]!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Quick Actions Grid/Row
                  const SectionHeader(title: 'Quick Actions'),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionBtn(
                          context,
                          'Add Car',
                          Icons.add_road,
                          () => context.push('/fleet/add'),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: _buildActionBtn(
                          context,
                          'View Earnings',
                          Icons.bar_chart,
                          () => context.push('/earnings'),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: _buildActionBtn(
                          context,
                          'Manage Fleet',
                          Icons.directions_car,
                          () => context.push('/fleet'),
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Fleet Status Card
                  AppCard(
                    onTap: () => context.push('/fleet'),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.garage, color: AppColors.primary),
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fleet Status Summary',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const Gap(4),
                                Text(
                                  '${stats.activeCars} active, ${stats.inactiveCars} unavailable',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const Gap(24),

                  // Active Bookings Today
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Active Trips Today',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (stats.todaysBookings > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: (stats.todaysBookings > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.24), width: 1),
                                ),
                                child: Text(
                                  stats.todaysBookings > 0 ? 'ACTIVE' : 'NO TRIPS',
                                  style: TextStyle(
                                    color: stats.todaysBookings > 0 ? Colors.green : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(12),
                          Text(
                            stats.todaysBookings == 1
                                ? 'You have 1 ongoing or confirmed booking scheduled for today (July 1, 2026).'
                                : 'You have ${stats.todaysBookings} ongoing or confirmed bookings scheduled for today (July 1, 2026).',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(24),

                  // Incoming Booking Requests Card
                  const SectionHeader(title: 'Incoming Booking Requests'),
                  const Gap(12),
                  requestsAsync.when(
                    loading: () => const Center(child: AppLoader()),
                    error: (err, stack) => const Text('Error loading booking requests'),
                    data: (requests) {
                      if (requests.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.pending_actions,
                          title: 'No requests',
                          subtitle: 'No pending booking requests',
                        );
                      }
                      return Column(
                        children: requests.map((req) => _buildRequestCard(context, ref, req)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Gap(4),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const Gap(8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const Gap(8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, WidgetRef ref, BookingModel req) {
    // Synchronous user lookup
    final customer = MockData.customers.firstWhere(
      (c) => c.id == req.customerId,
      orElse: () => UserModel(id: req.customerId, name: 'Customer', phone: '', email: '', role: 'customer'),
    );

    // Synchronous car lookup
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
      margin: const EdgeInsets.only(bottom: 12),
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
                          .read(dashboardControllerProvider.notifier)
                          .respondToBooking(req.id, true);
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
                      .read(dashboardControllerProvider.notifier)
                      .rejectBooking(bookingId, selectedReason);
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
