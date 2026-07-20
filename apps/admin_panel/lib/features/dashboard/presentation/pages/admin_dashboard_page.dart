import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../providers/admin_dashboard_providers.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';

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

    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminKpisProvider);
          ref.invalidate(bookingsPerDayProvider);
          ref.invalidate(revenuePerCityProvider);
          ref.invalidate(recentBookingsProvider);
          ref.invalidate(pendingVendorApprovalsProvider);
          ref.invalidate(topVendorsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── KPI Cards Row ───
              kpisAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading KPI statistics',
                  onRetry: () => ref.invalidate(adminKpisProvider),
                ),
                data: (kpis) => _KpisSection(kpis: kpis),
              ),
              const Gap(32),

              // ─── Charts Row ───
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

              // ─── Bottom Layout: Recent Bookings & Side Widgets ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Recent Bookings Table
                  Expanded(
                    flex: isDesktop ? 3 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Recent Bookings'),
                        const Gap(16),
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

                  // Right side: Pending Approvals & Top Performing Vendors (only on Desktop/Tablet side-by-side or below)
                  if (isDesktop) ...[
                    const Gap(24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Pending Approvals'),
                          const Gap(16),
                          pendingApprovalsAsync.when(
                            loading: () => const Center(child: AppLoader()),
                            error: (err, _) => ErrorStateWidget(
                              message: 'Error loading pending approvals',
                              onRetry: () => ref.invalidate(pendingVendorApprovalsProvider),
                            ),
                            data: (vendors) => _PendingApprovalsWidget(vendors: vendors),
                          ),
                          const Gap(32),
                          const SectionHeader(title: 'Top Performing Partners'),
                          const Gap(16),
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

              // Stacking side widgets below if not desktop
              if (!isDesktop) ...[
                const Gap(32),
                const SectionHeader(title: 'Pending Approvals'),
                const Gap(16),
                pendingApprovalsAsync.when(
                  loading: () => const Center(child: AppLoader()),
                  error: (err, _) => ErrorStateWidget(
                    message: 'Error loading pending approvals',
                    onRetry: () => ref.invalidate(pendingVendorApprovalsProvider),
                  ),
                  data: (vendors) => _PendingApprovalsWidget(vendors: vendors),
                ),
                const Gap(32),
                const SectionHeader(title: 'Top Performing Partners'),
                const Gap(16),
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
}

// ─── KPI Cards Section ──────────────────────────────────────────────────────

class _KpisSection extends StatelessWidget {
  final AdminKpis kpis;
  const _KpisSection({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    final cards = [
      _KpiCard(
        title: 'Total Platform Users',
        value: kpis.totalUsers.toString(),
        icon: Icons.people_outline,
        color: Colors.blue,
      ),
      _KpiCard(
        title: 'Verified Partners',
        value: kpis.totalVendors.toString(),
        icon: Icons.storefront_outlined,
        color: Colors.orange,
      ),
      _KpiCard(
        title: 'Active Bookings',
        value: kpis.activeBookings.toString(),
        icon: Icons.book_online_outlined,
        color: Colors.green,
      ),
      _KpiCard(
        title: 'Today\'s Revenue (Commissions)',
        value: '₹${NumberFormat('#,##,###').format(kpis.todaysRevenue)}',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.purple,
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
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
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

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bookings Trend (Last 30 Days)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
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
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
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
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            color: Colors.blueAccent,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commission Revenue by City',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
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
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
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
    return AppCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Vendor Partner', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Car Model', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Fare', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: bookings.map((b) {
            // Synchronously look up mock relations
            final customerName = MockData.customers.firstWhere(
              (c) => c.id == b.customerId,
              orElse: () => UserModel(id: b.customerId, name: 'Unknown User', phone: '', role: 'customer'),
            ).name;

            final vendor = MockData.vendors.firstWhere(
              (v) => v.id == b.vendorId,
              orElse: () => VendorModel(id: b.vendorId, businessName: 'Unknown Vendor', ownerName: '', city: 'Unknown', verificationStatus: ''),
            );

            final carModel = MockData.cars.firstWhere(
              (c) => c.id == b.carId,
              orElse: () => const CarModel(id: '', vendorId: '', make: '', model: 'Unknown Car', year: 2022, type: '', fuelType: '', seating: 5, isAC: true, photos: [], pricePerKm: 0, pricePerDay: 0, pricePerHour: 0),
            );

            return DataRow(
              cells: [
                DataCell(Text('#${b.id.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue))),
                DataCell(Text(customerName)),
                DataCell(Text(vendor.businessName)),
                DataCell(Text('${carModel.make} ${carModel.model}')),
                DataCell(Text(vendor.city)),
                DataCell(Text(DateFormat('dd MMM yyyy').format(b.startDate))),
                DataCell(PriceTag(
                  amount: b.totalFare,
                  amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                )),
                DataCell(StatusBadge(status: b.status)),
              ],
            );
          }).toList(),
        ),
      ),
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

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Vendor Approvals',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
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
                    'All vendors processed! No pending approvals.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vendors.length,
                separatorBuilder: (c, i) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final v = vendors[index];
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: Text(
                          v.businessName.isNotEmpty ? v.businessName[0].toUpperCase() : 'V',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Top Performing Partners',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
            const Gap(16),
            if (vendors.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No vendor statistics available', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vendors.length,
                separatorBuilder: (c, i) => const Divider(height: 16),
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
      ),
    );
  }
}
