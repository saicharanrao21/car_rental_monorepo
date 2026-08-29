import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../providers/dashboard_providers.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../../profile/presentation/providers/documents_provider.dart';

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
      body: RefreshIndicator(
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
              // 1. Greeting Header (Always Visible)
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
              const Gap(16),

              // 2. Document Expiry Alert Banner (Independent)
              const _ExpiringDocsBanner(),
              const Gap(8),

              // 3. Quick Stats Row (Resilient Loading/Error)
              statsAsync.when(
                data: (stats) => _buildStatsRow(context, stats),
                loading: () => _buildStatsRowLoading(context),
                error: (err, stack) => _buildStatsRowError(context, ref, err),
              ),
              const Gap(24),

              // 4. Quick Actions (Always Visible)
              const SectionHeader(title: 'Quick Actions'),
              const Gap(8),
              _buildQuickActions(context),
              const Gap(24),

              // 5. Fleet Status Summary (Resilient)
              statsAsync.when(
                data: (stats) => _buildFleetStatusCard(context, stats),
                loading: () => const ShimmerCard(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              const Gap(24),

              // 6. Active Bookings Snapshot (Resilient)
              statsAsync.when(
                data: (stats) => _buildActiveTripsCard(context, stats),
                loading: () => const ShimmerCard(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              const Gap(24),

              // 7. Incoming Booking Requests (Independent Provider)
              const SectionHeader(title: 'Incoming Booking Requests'),
              const Gap(12),
              requestsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppLoader(),
                  ),
                ),
                error: (err, stack) => ErrorStateWidget(
                  message: 'Could not load requests',
                  onRetry: () => ref.invalidate(latestBookingRequestsProvider),
                ),
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
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, DashboardStats stats) {
    return Row(
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
    );
  }

  Widget _buildStatsRowLoading(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ShimmerCard()),
        Gap(12),
        Expanded(child: ShimmerCard()),
        Gap(12),
        Expanded(child: ShimmerCard()),
      ],
    );
  }

  Widget _buildStatsRowError(BuildContext context, WidgetRef ref, Object err) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const Gap(8),
            const Text('Could not load summary stats'),
            TextButton(
              onPressed: () => ref.invalidate(dashboardStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            context,
            'Add Car',
            Icons.add_road,
            () => context.push('/fleet/add'),
          ),
        ),
        const Gap(8),
        Expanded(
          child: _buildActionBtn(
            context,
            'Analytics',
            Icons.analytics_outlined,
            () => context.push('/analytics'),
          ),
        ),
        const Gap(8),
        Expanded(
          child: _buildActionBtn(
            context,
            'Branches',
            Icons.store_mall_directory_outlined,
            () => context.push('/branches'),
          ),
        ),
        const Gap(8),
        Expanded(
          child: _buildActionBtn(
            context,
            'Earnings',
            Icons.bar_chart,
            () => context.push('/earnings'),
          ),
        ),
      ],
    );
  }

  Widget _buildFleetStatusCard(BuildContext context, DashboardStats stats) {
    return AppCard(
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
    );
  }

  Widget _buildActiveTripsCard(BuildContext context, DashboardStats stats) {
    return AppCard(
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
                    border: Border.all(
                        color: (stats.todaysBookings > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.24), width: 1),
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
                  ? 'You have 1 ongoing or confirmed booking scheduled for today.'
                  : 'You have ${stats.todaysBookings} ongoing or confirmed bookings scheduled for today.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
          ],
        ),
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
    final customerName = 'Customer #${req.customerId.length > 6 ? req.customerId.substring(0, 6) : req.customerId}';
    final carTitle = 'Vehicle #${req.carId.length > 6 ? req.carId.substring(0, 6) : req.carId}';

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
                  customerName,
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
                  carTitle,
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

class _ExpiringDocsBanner extends ConsumerWidget {
  const _ExpiringDocsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringCount = ref.watch(expiringDocumentsCountProvider);
    if (expiringCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber[400]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[900], size: 24),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$expiringCount ${expiringCount == 1 ? "document needs" : "documents need"} renewal attention',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF795548),
                  ),
                ),
                const Gap(2),
                const Text(
                  'Documents are expiring within 30 days or expired. Please upload renewed documents.',
                  style: TextStyle(fontSize: 12, color: Colors.brown),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/profile'),
            child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
