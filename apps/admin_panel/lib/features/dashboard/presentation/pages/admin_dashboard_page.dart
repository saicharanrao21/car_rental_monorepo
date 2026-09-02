import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:models/models.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../providers/admin_dashboard_providers.dart';
import '../../../locations/presentation/providers/locations_providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(adminKpisProvider);
    final bookingsChartAsync = ref.watch(bookingsPerDayProvider);
    final revenueChartAsync = ref.watch(revenuePerCityProvider);
    final recentBookingsAsync = ref.watch(recentBookingsProvider);
    final pendingApprovalsAsync = ref.watch(pendingVendorApprovalsProvider);
    final topVendorsAsync = ref.watch(topVendorsProvider);
    final operationalMapOverviewAsync = ref.watch(operationalLocationsOverviewProvider);

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminKpisProvider);
          ref.invalidate(bookingsPerDayProvider);
          ref.invalidate(revenuePerCityProvider);
          ref.invalidate(recentBookingsProvider);
          ref.invalidate(pendingVendorApprovalsProvider);
          ref.invalidate(topVendorsProvider);
          ref.invalidate(operationalLocationsOverviewProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Title & Triage Status ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Command Center',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(4),
                      Text(
                        'Live operational triage, ecosystem health, and financial pulse',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF64748B)),
                        const Gap(6),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(20),

              // ─── Operational Triage Bar ───
              _buildOperationalTriageBar(
                context,
                pendingApprovalsAsync: pendingApprovalsAsync,
                operationalMapOverviewAsync: operationalMapOverviewAsync,
                kpisAsync: kpisAsync,
              ),
              const Gap(24),

              // ─── Executive KPI Cards ───
              kpisAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: AppLoader(),
                )),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading KPI statistics',
                  onRetry: () => ref.invalidate(adminKpisProvider),
                ),
                data: (kpis) => _KpisSection(kpis: kpis),
              ),
              const Gap(28),

              // ─── Visual Trend Analytics (Charts) ───
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: bookingsChartAsync.when(
                        loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
                        error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading LineChart'))),
                        data: (counts) => _LineChartWidget(counts: counts),
                      ),
                    ),
                    const Gap(24),
                    Expanded(
                      flex: 2,
                      child: revenueChartAsync.when(
                        loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
                        error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading BarChart'))),
                        data: (revMap) => _BarChartWidget(revenueMap: revMap),
                      ),
                    ),
                  ],
                )
              else ...[
                bookingsChartAsync.when(
                  loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
                  error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading LineChart'))),
                  data: (counts) => _LineChartWidget(counts: counts),
                ),
                const Gap(24),
                revenueChartAsync.when(
                  loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
                  error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading BarChart'))),
                  data: (revMap) => _BarChartWidget(revenueMap: revMap),
                ),
              ],
              const Gap(32),

              // ─── Recent Bookings & Triage Queues ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Recent Bookings Table
                  Expanded(
                    flex: isDesktop ? 3 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionHeader(title: 'Live Bookings Feed'),
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text('View All Bookings', style: TextStyle(fontSize: 12)),
                              onPressed: () => context.go('/bookings'),
                            ),
                          ],
                        ),
                        const Gap(12),
                        recentBookingsAsync.when(
                          loading: () => const Center(child: AppLoader()),
                          error: (err, _) => ErrorStateWidget(
                            message: 'Error loading recent bookings',
                            onRetry: () => ref.invalidate(recentBookingsProvider),
                          ),
                          data: (bookings) => _RecentBookingsTable(bookings: bookings),
                        ),
                      ],
                    ),
                  ),

                  // Right side: Pending Approvals & Top Partners (Desktop)
                  if (isDesktop) ...[
                    const Gap(24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Partner Verification Queue'),
                          const Gap(12),
                          pendingApprovalsAsync.when(
                            loading: () => const Center(child: AppLoader()),
                            error: (err, _) => ErrorStateWidget(
                              message: 'Error loading pending approvals',
                              onRetry: () => ref.invalidate(pendingVendorApprovalsProvider),
                            ),
                            data: (vendors) => _PendingApprovalsWidget(vendors: vendors),
                          ),
                          const Gap(28),
                          const SectionHeader(title: 'Top Performing Fleet Partners'),
                          const Gap(12),
                          topVendorsAsync.when(
                            loading: () => const Center(child: AppLoader()),
                            error: (err, _) => ErrorStateWidget(
                              message: 'Error loading top vendors',
                              onRetry: () => ref.invalidate(topVendorsProvider),
                            ),
                            data: (vendors) => _TopVendorsWidget(vendors: vendors),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Mobile/Tablet side widgets
              if (!isDesktop) ...[
                const Gap(32),
                const SectionHeader(title: 'Partner Verification Queue'),
                const Gap(12),
                pendingApprovalsAsync.when(
                  loading: () => const Center(child: AppLoader()),
                  error: (err, _) => ErrorStateWidget(
                    message: 'Error loading pending approvals',
                    onRetry: () => ref.invalidate(pendingVendorApprovalsProvider),
                  ),
                  data: (vendors) => _PendingApprovalsWidget(vendors: vendors),
                ),
                const Gap(28),
                const SectionHeader(title: 'Top Performing Fleet Partners'),
                const Gap(12),
                topVendorsAsync.when(
                  loading: () => const Center(child: AppLoader()),
                  error: (err, _) => ErrorStateWidget(
                    message: 'Error loading top vendors',
                    onRetry: () => ref.invalidate(topVendorsProvider),
                  ),
                  data: (vendors) => _TopVendorsWidget(vendors: vendors),
                ),
              ],
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationalTriageBar(
    BuildContext context, {
    required AsyncValue<List<VendorModel>> pendingApprovalsAsync,
    required AsyncValue<OperationalLocationOverviewModel> operationalMapOverviewAsync,
    required AsyncValue<AdminKpis> kpisAsync,
  }) {
    final pendingCount = pendingApprovalsAsync.asData?.value.length ?? 0;
    final activeBookingsCount = kpisAsync.asData?.value.activeBookings ?? 0;
    final sosCount = operationalMapOverviewAsync.asData?.value.totalActiveSosAlerts ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 20),
          const Gap(8),
          const Text(
            'TRIAGE RADAR:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF0F172A),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildTriageChip(
                  label: 'Pending Approvals ($pendingCount)',
                  icon: Icons.storefront_outlined,
                  color: pendingCount > 0 ? Colors.orange : Colors.grey,
                  onTap: () => context.go('/vendors'),
                ),
                _buildTriageChip(
                  label: 'Emergency SOS ($sosCount)',
                  icon: Icons.emergency_outlined,
                  color: sosCount > 0 ? Colors.red : Colors.green,
                  onTap: () => context.go('/emergency-dispatch'),
                ),
                _buildTriageChip(
                  label: 'Active On-Road ($activeBookingsCount)',
                  icon: Icons.directions_car_outlined,
                  color: Colors.blue,
                  onTap: () => context.go('/bookings'),
                ),
                _buildTriageChip(
                  label: 'Location Governance',
                  icon: Icons.share_location_outlined,
                  color: Colors.indigo,
                  onTap: () => context.go('/locations/governance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── KPI Cards Section ──────────────────────────────────────────────────────

class _KpisSection extends StatelessWidget {
  final AdminKpis kpis;
  const _KpisSection({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width < 1024 && MediaQuery.of(context).size.width >= 600;

    final cards = [
      _KpiCard(
        title: 'Platform Users',
        value: kpis.totalUsers.toString(),
        icon: Icons.people_outline,
        color: const Color(0xFF2563EB),
      ),
      _KpiCard(
        title: 'Verified Partners',
        value: kpis.totalVendors.toString(),
        icon: Icons.storefront_outlined,
        color: const Color(0xFFD97706),
      ),
      _KpiCard(
        title: 'Active Bookings',
        value: kpis.activeBookings.toString(),
        icon: Icons.book_online_outlined,
        color: const Color(0xFF16A34A),
      ),
      _KpiCard(
        title: 'Today\'s Commission',
        value: '₹${NumberFormat('#,##,###').format(kpis.todaysRevenue)}',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF9333EA),
      ),
    ];

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const Gap(16),
              Expanded(child: cards[1]),
            ],
          ),
          const Gap(16),
          Row(
            children: [
              Expanded(child: cards[2]),
              const Gap(16),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: c,
      ))).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const Gap(4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Chart Widget (Bookings) ───────────────────────────────────────────

class _LineChartWidget extends StatelessWidget {
  final List<int> counts;
  const _LineChartWidget({required this.counts});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(counts.length, (i) => FlSpot(i.toDouble(), counts[i].toDouble()));
    final double maxY = counts.isEmpty ? 10 : (counts.reduce((a, b) => a > b ? a : b).toDouble() * 1.2);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fleet Booking Volume (Last 30 Days)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const Gap(24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx % 5 != 0 || idx >= counts.length) return const SizedBox.shrink();
                        return Text(
                          'Day $idx',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF2563EB),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bar Chart Widget (Revenue Per City) ────────────────────────────────────

class _BarChartWidget extends StatelessWidget {
  final Map<String, double> revenueMap;
  const _BarChartWidget({required this.revenueMap});

  @override
  Widget build(BuildContext context) {
    final keys = revenueMap.keys.toList();
    final double maxVal = revenueMap.values.isEmpty ? 10000 : (revenueMap.values.reduce((a, b) => a > b ? a : b) * 1.2);

    final barGroups = List.generate(keys.length, (i) {
      final city = keys[i];
      final val = revenueMap[city] ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: const Color(0xFF0284C7),
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Distribution by City',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const Gap(24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (v, _) => Text(
                        '₹${(v / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= keys.length) return const SizedBox.shrink();
                        return Text(
                          keys[idx],
                          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Bookings DataTable ──────────────────────────────────────────────

class _RecentBookingsTable extends StatelessWidget {
  final List<BookingModel> bookings;
  const _RecentBookingsTable({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return AdminDataGrid<BookingModel>(
      items: bookings,
      emptyTitle: 'No recent bookings registered',
      emptyMessage: 'Live operational booking events will appear here in real time.',
      onRowTap: (b) => context.go('/bookings'),
      columns: [
        AdminDataColumn(
          title: 'BOOKING ID',
          builder: (b) => Text(
            '#${b.id.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB), fontSize: 13),
          ),
        ),
        AdminDataColumn(
          title: 'CUSTOMER',
          builder: (b) => Text(
            'Customer #${b.customerId.length > 6 ? b.customerId.substring(0, 6) : b.customerId}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AdminDataColumn(
          title: 'VENDOR PARTNER',
          builder: (b) => Text(
            'Vendor #${b.vendorId.length > 6 ? b.vendorId.substring(0, 6) : b.vendorId}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AdminDataColumn(
          title: 'PICKUP HUB',
          builder: (b) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              b.pickupLocation,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        AdminDataColumn(
          title: 'START DATE',
          builder: (b) => Text(
            DateFormat('dd MMM yyyy').format(b.startDate),
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        AdminDataColumn(
          title: 'TOTAL FARE',
          numeric: true,
          builder: (b) => PriceTag(
            amount: b.totalFare,
            amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        AdminDataColumn(
          title: 'STATUS',
          builder: (b) => AdminStatusBadge(status: b.status),
        ),
      ],
      mobileCardBuilder: (ctx, b) {
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
                'Pickup: ${b.pickupLocation}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(b.startDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  PriceTag(
                    amount: b.totalFare,
                    amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Pending Approvals Widget ───────────────────────────────────────────────

class _PendingApprovalsWidget extends ConsumerWidget {
  final List<VendorModel> vendors;
  const _PendingApprovalsWidget({required this.vendors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardControllerProvider);
    final isLoading = controller.isLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Partner Review Queue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${vendors.length} pending',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const Gap(16),
          if (vendors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'All vendor applications processed! No pending items.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vendors.length,
              separatorBuilder: (c, i) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final v = vendors[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      child: Text(
                        v.businessName.isNotEmpty ? v.businessName[0].toUpperCase() : 'V',
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('City: ${v.city} • Owner: ${v.ownerName}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                    const Gap(10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(adminDashboardControllerProvider.notifier)
                                  .setVendorApprovalStatus(v.id, 'verified'),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(adminDashboardControllerProvider.notifier)
                                  .setVendorApprovalStatus(v.id, 'rejected'),
                          tooltip: 'Reject',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Top Performing Partners Widget ──────────────────────────────────────────

class _TopVendorsWidget extends StatelessWidget {
  final List<VendorModel> vendors;
  const _TopVendorsWidget({required this.vendors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Partner Fleet Ranking',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const Gap(16),
          if (vendors.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No vendor rankings available', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vendors.length,
              separatorBuilder: (c, i) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final v = vendors[index];
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.amber
                            : (index == 1
                                ? Colors.grey[400]
                                : (index == 2 ? Colors.orange[300] : Colors.grey[200])),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index < 3 ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${v.city} • ${v.totalTrips} Trips', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                    const Gap(8),
                    StarRating(rating: v.rating, size: 14),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
