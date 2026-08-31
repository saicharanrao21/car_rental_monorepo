import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../providers/dashboard_providers.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/models/operations_models.dart';
import '../../../profile/presentation/providers/documents_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendorSessionProvider);
    final vendor = session.vendor;
    final businessName = vendor?.businessName ?? 'Partner';
    final city = vendor?.city ?? 'Hub';

    final triageAsync = ref.watch(operationsTriageProvider);
    final matrixAsync = ref.watch(bookingMatrixProvider);
    final timelineAsync = ref.watch(todayOperationsProvider);
    final fleetAsync = ref.watch(fleetSummaryProvider);
    final earningsAsync = ref.watch(earningsSnapshotProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    final nowFormatted = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        backgroundColor: DDSColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DriveGo Partner OS',
              style: DDSTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              nowFormatted,
              style: DDSTypography.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: DDSColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(vendorSessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DDSColors.primaryBlue,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(latestBookingRequestsProvider);
          ref.invalidate(operationsTriageProvider);
          ref.invalidate(todayOperationsProvider);
          ref.invalidate(bookingMatrixProvider);
          ref.invalidate(fleetSummaryProvider);
          ref.invalidate(earningsSnapshotProvider);
          ref.invalidate(vendorDocumentsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DDSSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Partner Banner & Health Status
              _buildPartnerHeroBanner(context, businessName, city, vendor?.verificationStatus),
              const Gap(DDSSpacing.md),

              // 2. ACTION REQUIRED — Operational Triage Center
              _buildActionRequiredSection(context, ref, triageAsync),
              const Gap(DDSSpacing.lg),

              // 3. Booking Operations Matrix
              _buildBookingOperationsMatrix(context, ref, matrixAsync, statsAsync),
              const Gap(DDSSpacing.lg),

              // 4. Today's Operations Timeline
              _buildTodayOperationsTimeline(context, ref, timelineAsync),
              const Gap(DDSSpacing.lg),

              // 5. Fleet Availability Snapshot
              _buildFleetSnapshot(context, ref, fleetAsync, statsAsync),
              const Gap(DDSSpacing.lg),

              // 6. Financial & Earnings Snapshot
              _buildEarningsSnapshot(context, ref, earningsAsync, statsAsync),
              const Gap(DDSSpacing.lg),

              // 7. Operational Quick Actions
              _buildOperationalQuickActions(context),
              const Gap(DDSSpacing.lg),

              // 8. 24x7 Partner Support & Emergency Assistance
              _buildSupportSection(context),
              const Gap(DDSSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Hero Banner ---
  Widget _buildPartnerHeroBanner(
    BuildContext context,
    String businessName,
    String city,
    String? status,
  ) {
    final isVerified = status == 'verified';

    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.primaryNavy,
        borderRadius: DDSRadius.largeBorderRadius,
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: DDSColors.primaryBlue.withValues(alpha: 0.3),
                child: Text(
                  businessName.isNotEmpty ? businessName[0].toUpperCase() : 'P',
                  style: DDSTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: DDSTypography.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DDSTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified
                      ? DDSColors.successGreen.withValues(alpha: 0.2)
                      : DDSColors.warningOrange.withValues(alpha: 0.2),
                  borderRadius: DDSRadius.pillBorderRadius,
                  border: Border.all(
                    color: isVerified ? DDSColors.successGreen : DDSColors.warningOrange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.pending,
                      size: 14,
                      color: isVerified ? DDSColors.successGreen : DDSColors.warningOrange,
                    ),
                    const Gap(4),
                    Text(
                      isVerified ? 'VERIFIED' : 'PENDING',
                      style: DDSTypography.labelSmall.copyWith(
                        color: isVerified ? DDSColors.successGreen : DDSColors.warningOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: DDSRadius.mediumBorderRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: DDSColors.accentAmber),
                      const Gap(4),
                      Expanded(
                        child: Text(
                          '$city Hub Operations',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DDSTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DDSColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Fleet Active',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Action Required / Triage Center ---
  Widget _buildActionRequiredSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TriageItem>> triageAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: DDSColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: DDSRadius.smallBorderRadius,
                    ),
                    child: const Icon(Icons.bolt, size: 18, color: DDSColors.errorRed),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'ACTION REQUIRED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            triageAsync.maybeWhen(
              data: (items) {
                if (items.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DDSColors.errorRed,
                    borderRadius: DDSRadius.pillBorderRadius,
                  ),
                  child: Text(
                    '${items.length} PENDING',
                    style: DDSTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const Gap(DDSSpacing.sm),
        triageAsync.when(
          loading: () => const ShimmerCard(),
          error: (err, stack) => _buildTriageError(ref),
          data: (items) {
            if (items.isEmpty) {
              return _buildZeroActionState();
            }
            return Column(
              children: items.map((item) => _buildTriageCard(context, ref, item)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildZeroActionState() {
    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3), width: 1.5),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DDSColors.successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: DDSColors.successGreen, size: 28),
          ),
          const Gap(DDSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're All Caught Up!",
                  style: DDSTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.textPrimary,
                  ),
                ),
                const Gap(2),
                Text(
                  'No urgent actions required. All operations are running smoothly.',
                  style: DDSTypography.bodyMedium.copyWith(
                    color: DDSColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageCard(BuildContext context, WidgetRef ref, TriageItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: DDSSpacing.sm),
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: item.priority.color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.priority.backgroundColor,
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Text(
                  item.badgeText,
                  style: DDSTypography.labelSmall.copyWith(
                    color: item.priority.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                item.priority.label,
                style: DDSTypography.labelSmall.copyWith(
                  color: item.priority.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.xs),
          Text(
            item.title,
            style: DDSTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: DDSColors.textPrimary,
            ),
          ),
          const Gap(2),
          Text(
            item.subtitle,
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
            ),
          ),
          const Gap(DDSSpacing.sm),

          // Action Row
          if (item.isBookingAction && item.bookingId != null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DDSColors.successGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      final success = await ref
                          .read(dashboardControllerProvider.notifier)
                          .respondToBooking(item.bookingId!, true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Booking confirmed successfully!' : 'Failed to confirm booking'),
                            backgroundColor: success ? DDSColors.successGreen : DDSColors.errorRed,
                          ),
                        );
                      }
                    },
                    child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DDSColors.errorRed,
                      side: const BorderSide(color: DDSColors.errorRed),
                      shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showRejectDialog(context, ref, item.bookingId!),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: DDSColors.primaryBlue),
                  tooltip: 'View Details',
                  onPressed: () => context.push(item.routePath),
                ),
              ],
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DDSColors.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(item.actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => context.push(item.routePath),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTriageError(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DDSColors.errorRed, size: 24),
          const Gap(DDSSpacing.sm),
          const Expanded(child: Text('Could not refresh operations triage')),
          TextButton(
            onPressed: () => ref.invalidate(operationsTriageProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // --- 3. Booking Operations Matrix ---
  Widget _buildBookingOperationsMatrix(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<BookingMatrix> matrixAsync,
    AsyncValue<DashboardStats> statsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Booking Operations Matrix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/bookings'),
              child: const Text('All Bookings →'),
            ),
          ],
        ),
        const Gap(DDSSpacing.xs),
        matrixAsync.when(
          loading: () => const ShimmerCard(),
          error: (err, stack) => statsAsync.maybeWhen(
            data: (stats) => _buildMatrixGrid(
              context,
              BookingMatrix(
                todayCount: stats.todaysBookings,
                pendingCount: stats.pendingRequests,
                upcomingCount: 0,
                completedCount: 0,
                activeCount: stats.todaysBookings,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          data: (matrix) => _buildMatrixGrid(context, matrix),
        ),
      ],
    );
  }

  Widget _buildMatrixGrid(BuildContext context, BookingMatrix matrix) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: DDSSpacing.sm,
      mainAxisSpacing: DDSSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _buildMatrixCard(
          context,
          'Today\'s Drives',
          matrix.todayCount.toString(),
          'Scheduled Today',
          Icons.today,
          DDSColors.primaryBlue,
          () => context.push('/bookings'),
        ),
        _buildMatrixCard(
          context,
          'Pending Action',
          matrix.pendingCount.toString(),
          'Requires Accept',
          Icons.pending_actions,
          DDSColors.warningOrange,
          () => context.push('/bookings'),
        ),
        _buildMatrixCard(
          context,
          'Upcoming Handovers',
          matrix.upcomingCount.toString(),
          'Confirmed Ahead',
          Icons.schedule,
          DDSColors.primaryNavy,
          () => context.push('/bookings'),
        ),
        _buildMatrixCard(
          context,
          'Completed Trips',
          matrix.completedCount.toString(),
          'Safely Returned',
          Icons.task_alt,
          DDSColors.successGreen,
          () => context.push('/bookings'),
        ),
      ],
    );
  }

  Widget _buildMatrixCard(
    BuildContext context,
    String title,
    String count,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DDSRadius.mediumBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(DDSSpacing.sm),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.mediumBorderRadius,
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(icon, size: 16, color: color),
                ],
              ),
              Text(
                count,
                style: DDSTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                  fontSize: 22,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. Today's Operations Timeline ---
  Widget _buildTodayOperationsTimeline(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TodayTimelineItem>> timelineAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Today\'s Operations Timeline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: DDSRadius.pillBorderRadius,
              ),
              child: Text(
                'LIVE SCHEDULE',
                style: DDSTypography.labelSmall.copyWith(
                  color: DDSColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const Gap(DDSSpacing.sm),
        timelineAsync.when(
          loading: () => const ShimmerCard(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (timeline) {
            if (timeline.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(DDSSpacing.md),
                decoration: BoxDecoration(
                  color: DDSColors.surfaceCard,
                  borderRadius: DDSRadius.largeBorderRadius,
                  border: Border.all(color: DDSColors.borderLight),
                  boxShadow: DDSElevation.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: DDSColors.primaryBlue, size: 24),
                    const Gap(DDSSpacing.sm),
                    Expanded(
                      child: Text(
                        'No scheduled vehicle pickups or returns for today.',
                        style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: timeline.map((event) => _buildTimelineEventCard(context, event)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimelineEventCard(BuildContext context, TodayTimelineItem event) {
    final timeStr = DateFormat('hh:mm a').format(event.time);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/bookings/${event.bookingId}'),
        borderRadius: DDSRadius.mediumBorderRadius,
        child: Container(
          margin: const EdgeInsets.only(bottom: DDSSpacing.xs),
          padding: const EdgeInsets.all(DDSSpacing.sm),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.mediumBorderRadius,
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: event.type.color.withValues(alpha: 0.12),
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Column(
                  children: [
                    Text(
                      event.type.label,
                      style: DDSTypography.labelSmall.copyWith(
                        color: event.type.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      timeStr,
                      style: DDSTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: event.type.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.vehicleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DDSTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DDSColors.bgCanvas,
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: Text(
                            event.tripType,
                            style: DDSTypography.labelSmall.copyWith(
                              color: DDSColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      'Customer: ${event.customerSafeName} • ${event.hubLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: DDSColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. Fleet Snapshot ---
  Widget _buildFleetSnapshot(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<FleetSummary> fleetAsync,
    AsyncValue<DashboardStats> statsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Fleet Status & Availability',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/fleet'),
              child: const Text('Manage Fleet →'),
            ),
          ],
        ),
        const Gap(DDSSpacing.xs),
        fleetAsync.when(
          loading: () => const ShimmerCard(),
          error: (err, stack) => statsAsync.maybeWhen(
            data: (stats) => _buildFleetCard(
              context,
              FleetSummary(
                totalCars: stats.activeCars + stats.inactiveCars,
                availableCars: stats.activeCars,
                onTripCars: 0,
                unavailableCars: stats.inactiveCars,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          data: (fleet) => _buildFleetCard(context, fleet),
        ),
      ],
    );
  }

  Widget _buildFleetCard(BuildContext context, FleetSummary fleet) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/fleet'),
        borderRadius: DDSRadius.largeBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.largeBorderRadius,
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_car, color: DDSColors.primaryBlue),
                        ),
                        const Gap(DDSSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${fleet.totalCars} Total Vehicles',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DDSTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: DDSColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${fleet.availableCars} Ready for Booking',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DDSTypography.bodyMedium.copyWith(
                                  color: DDSColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: DDSColors.textMuted),
                ],
              ),
              const Gap(DDSSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildFleetPill(
                      'Ready (${fleet.availableCars})',
                      DDSColors.successGreen,
                    ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: _buildFleetPill(
                      'On Trip (${fleet.onTripCars})',
                      DDSColors.primaryBlue,
                    ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: _buildFleetPill(
                      'Offline (${fleet.unavailableCars})',
                      DDSColors.warningOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFleetPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: DDSRadius.smallBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DDSTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // --- 6. Financial & Earnings Snapshot ---
  Widget _buildEarningsSnapshot(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<EarningsSnapshot> earningsAsync,
    AsyncValue<DashboardStats> statsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Financial Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/earnings'),
              child: const Text('View Ledger →'),
            ),
          ],
        ),
        const Gap(DDSSpacing.xs),
        earningsAsync.when(
          loading: () => const ShimmerCard(),
          error: (err, stack) => statsAsync.maybeWhen(
            data: (stats) => _buildEarningsCard(
              context,
              EarningsSnapshot(
                thisMonthEarnings: stats.thisMonthEarnings,
                availableBalance: stats.thisMonthEarnings,
                heldEarnings: 0,
                totalEarnings: stats.thisMonthEarnings,
                totalPaidOut: 0,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          data: (earnings) => _buildEarningsCard(context, earnings),
        ),
      ],
    );
  }

  Widget _buildEarningsCard(BuildContext context, EarningsSnapshot earnings) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/earnings'),
        borderRadius: DDSRadius.largeBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.largeBorderRadius,
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Month Net Earnings',
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(2),
                      PriceTag(
                        amount: earnings.thisMonthEarnings,
                        amountStyle: DDSTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DDSColors.successGreen,
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DDSColors.successGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: DDSColors.successGreen),
                  ),
                ],
              ),
              const Gap(DDSSpacing.md),
              const Divider(height: 1, color: DDSColors.borderLight),
              const Gap(DDSSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialMetric(
                      'Available Balance',
                      '₹${earnings.availableBalance.toStringAsFixed(0)}',
                      DDSColors.primaryBlue,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _buildFinancialMetric(
                      'Pending Settlement',
                      '₹${earnings.heldEarnings.toStringAsFixed(0)}',
                      DDSColors.warningOrange,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _buildFinancialMetric(
                      'Lifetime Earnings',
                      '₹${earnings.totalEarnings.toStringAsFixed(0)}',
                      DDSColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DDSTypography.labelSmall.copyWith(
            color: DDSColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const Gap(2),
        Text(
          value,
          style: DDSTypography.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- 7. Operational Quick Actions ---
  Widget _buildOperationalQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Quick Actions',
          style: DDSTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(DDSSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionBtn(
                context,
                '+ Add Vehicle',
                Icons.add_circle_outline,
                DDSColors.primaryBlue,
                () => context.push('/fleet/add'),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _buildQuickActionBtn(
                context,
                'Fleet Manager',
                Icons.garage_outlined,
                DDSColors.primaryNavy,
                () => context.push('/fleet'),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _buildQuickActionBtn(
                context,
                'Earnings',
                Icons.analytics_outlined,
                DDSColors.successGreen,
                () => context.push('/earnings'),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _buildQuickActionBtn(
                context,
                'Branch Hubs',
                Icons.store_mall_directory_outlined,
                DDSColors.accentAmber,
                () => context.push('/branches'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DDSRadius.mediumBorderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.mediumBorderRadius,
            border: Border.all(color: DDSColors.borderLight),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const Gap(6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DDSColors.textPrimary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 8. 24x7 Partner Support & Emergency Assistance ---
  Widget _buildSupportSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DDSColors.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, color: DDSColors.errorRed, size: 20),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24x7 Partner Operations Support',
                      style: DDSTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Helpline: +91 8000 374 834 (Priority Dispatch)',
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DDSColors.primaryBlue,
                    side: const BorderSide(color: DDSColors.primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Partner FAQs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support Desk: Connected with DriveGo Partner Relations')),
                    );
                  },
                ),
              ),
              const Gap(8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DDSColors.primaryNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.gavel_outlined, size: 16),
                  label: const Text('Dispute Desk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dispute Desk: Reviewing partner claim logs')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Modals and Dialogs ---
  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Operational Alerts',
                    style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const Gap(DDSSpacing.sm),
              _buildNotificationItem('New booking request received for Hyundai Creta', '2 mins ago', Icons.book_online),
              _buildNotificationItem('Payout settlement ₹12,400 processed', '2 hours ago', Icons.payments),
              _buildNotificationItem('Insurance renewal due in 5 days for TS09EA1234', '1 day ago', Icons.warning_amber),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(String message, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DDSColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: DDSColors.primaryBlue),
          ),
          const Gap(DDSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: DDSTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                Text(time, style: DDSTypography.labelSmall.copyWith(color: DDSColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String bookingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
        title: const Text('Decline Booking Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for declining this booking request:'),
            const Gap(12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Vehicle in routine service',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DDSColors.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Vehicle unavailable';
              final success = await ref
                  .read(dashboardControllerProvider.notifier)
                  .rejectBooking(bookingId, reason);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Booking request declined' : 'Failed to decline request'),
                    backgroundColor: success ? DDSColors.warningOrange : DDSColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('Confirm Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
