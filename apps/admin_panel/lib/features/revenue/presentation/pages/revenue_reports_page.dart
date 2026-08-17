import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../providers/revenue_providers.dart';

class RevenueReportsPage extends ConsumerWidget {
  const RevenueReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(revenueDateRangeProvider);
    final summaryAsync = ref.watch(revenueSummaryProvider);
    final lifecycleAsync = ref.watch(bookingLifecycleStatsProvider);
    final fleetAsync = ref.watch(fleetUtilizationProvider);
    final customerAsync = ref.watch(customerGrowthStatsProvider);
    final addonAsync = ref.watch(addonAdoptionStatsProvider);

    final formattedStart = DateFormat('dd MMM yyyy').format(range.start);
    final formattedEnd = DateFormat('dd MMM yyyy').format(range.end);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics & Financial Reports',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Authoritative metrics & reconciliation for: $formattedStart - $formattedEnd',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Export to CSV',
                  isFullWidth: false,
                  onPressed: () => _handleCsvExport(context, ref),
                ),
              ],
            ),
            const Gap(16),

            // Date Range Presets Row
            Row(
              children: [
                const Text(
                  'Filter Range:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Gap(12),
                Expanded(child: _buildPresetChips(context, ref)),
              ],
            ),
            const Gap(24),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary cards
                    summaryAsync.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: AppLoader()),
                      ),
                      error: (err, _) => const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Error loading financial summary')),
                        ),
                      ),
                      data: (summary) => _buildExecutiveSummaryGrid(context, summary),
                    ),
                    const Gap(24),

                    // Operational Analytics KPI Section
                    _buildOperationalMetricsSection(context, lifecycleAsync, fleetAsync, customerAsync, addonAsync),
                    const Gap(24),

                    // Charts Grid
                    _buildChartsGrid(context, ref),
                    const Gap(24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChips(BuildContext context, WidgetRef ref) {
    final currentRange = ref.watch(revenueDateRangeProvider);
    final now = DateTime.now();

    final today = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final thisWeek = DateTimeRange(
      start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonth = DateTimeRange(
      start: startOfMonth,
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    bool isSameDay(DateTimeRange a, DateTimeRange b) {
      return a.start.year == b.start.year &&
          a.start.month == b.start.month &&
          a.start.day == b.start.day &&
          a.end.year == b.end.year &&
          a.end.month == b.end.month &&
          a.end.day == b.end.day;
    }

    final isToday = isSameDay(currentRange, today);
    final isThisWeek = isSameDay(currentRange, thisWeek);
    final isThisMonth = isSameDay(currentRange, thisMonth);
    final isCustom = !isToday && !isThisWeek && !isThisMonth;

    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: isToday,
          onSelected: (val) {
            if (val) ref.read(revenueDateRangeProvider.notifier).state = today;
          },
        ),
        ChoiceChip(
          label: const Text('This Week'),
          selected: isThisWeek,
          onSelected: (val) {
            if (val) ref.read(revenueDateRangeProvider.notifier).state = thisWeek;
          },
        ),
        ChoiceChip(
          label: const Text('This Month'),
          selected: isThisMonth,
          onSelected: (val) {
            if (val) ref.read(revenueDateRangeProvider.notifier).state = thisMonth;
          },
        ),
        ChoiceChip(
          label: const Text('Custom Range'),
          selected: isCustom,
          onSelected: (val) async {
            if (val) {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: currentRange,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref.read(revenueDateRangeProvider.notifier).state = picked;
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildExecutiveSummaryGrid(BuildContext context, RevenueSummaryModel summary) {
    final isDesktop = Responsive.isDesktop(context);

    final cards = [
      _buildSummaryCard('Gross Booking Value (GMV)', summary.grossBookingValue, Colors.black87, Icons.currency_rupee),
      _buildSummaryCard('Platform Fee (Commission)', summary.platformRevenue, Colors.blue, Icons.account_balance),
      _buildSummaryCard('Net Platform Revenue', summary.netPlatformRevenue, Colors.indigo, Icons.trending_up),
      _buildSummaryCard('GST Collected (18%)', summary.gstCollected, Colors.amber[800]!, Icons.receipt_long),
      _buildSummaryCard('Vendor Payouts (Completed)', summary.vendorPayouts, Colors.green, Icons.payments),
      _buildSummaryCard('Protection Fee Revenue', summary.protectionRevenue, Colors.teal, Icons.shield),
      _buildSummaryCard('Delivery Fee Revenue', summary.deliveryRevenue, Colors.deepOrange, Icons.local_shipping),
      _buildSummaryCard('Discounts Absorbed', summary.discountTotal, Colors.purple, Icons.discount),
      _buildSummaryCard('Wallet Liability (All Wallets)', summary.walletLiability, Colors.blueGrey, Icons.account_balance_wallet),
      _buildSummaryCard('Loyalty Liability (Points / 2)', summary.loyaltyLiability, Colors.amber[900]!, Icons.stars),
    ];

    if (isDesktop) {
      return GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
        children: cards,
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: c)).toList(),
      );
    }
  }

  Widget _buildSummaryCard(String label, double amount, Color color, IconData icon) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Gap(6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(8),
          PriceTag(
            amount: amount,
            amountStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalMetricsSection(
    BuildContext context,
    AsyncValue<BookingLifecycleStatsModel> lifecycleAsync,
    AsyncValue<FleetUtilizationModel> fleetAsync,
    AsyncValue<CustomerGrowthModel> customerAsync,
    AsyncValue<AddonAdoptionModel> addonAsync,
  ) {
    final isDesktop = Responsive.isDesktop(context);

    final panel1 = lifecycleAsync.when(
      loading: () => const SizedBox(height: 130, child: Center(child: AppLoader())),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _buildMetricCard(
        title: 'Booking Lifecycle',
        items: [
          'Total: ${data.totalBookings} bookings',
          'Completed: ${data.completedBookings} (${data.completionRate}%)',
          'Cancelled: ${data.cancelledBookings} (${data.cancellationRate}%)',
          'Avg Value: ₹${data.averageBookingValue.toStringAsFixed(0)}',
        ],
        accentColor: Colors.blue,
      ),
    );

    final panel2 = fleetAsync.when(
      loading: () => const SizedBox(height: 130, child: Center(child: AppLoader())),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _buildMetricCard(
        title: 'Fleet Utilization',
        items: [
          'Total Fleet: ${data.totalCars} cars',
          'Available: ${data.availableCars} cars',
          'Active / On Trip: ${data.activeCars}',
          'Utilization: ${data.utilizationRate}%',
        ],
        accentColor: Colors.teal,
      ),
    );

    final panel3 = customerAsync.when(
      loading: () => const SizedBox(height: 130, child: Center(child: AppLoader())),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _buildMetricCard(
        title: 'Customer Growth',
        items: [
          'Registered: ${data.totalRegisteredCustomers}',
          'New in Range: ${data.newCustomersInRange}',
          'Repeat Rate: ${data.repeatCustomerRate}%',
          'Avg Spend: ₹${data.avgCustomerSpend.toStringAsFixed(0)}',
        ],
        accentColor: Colors.purple,
      ),
    );

    final panel4 = addonAsync.when(
      loading: () => const SizedBox(height: 130, child: Center(child: AppLoader())),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _buildMetricCard(
        title: 'Add-on Adoption',
        items: [
          'Protection: ${data.protectionAdoptionRate}%',
          'Doorstep Delivery: ${data.deliveryAdoptionRate}%',
          'Driver Addon: ${data.driverAdoptionRate}%',
          'Coupon Usage: ${data.couponUsageRate}%',
        ],
        accentColor: Colors.deepOrange,
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: panel1),
          const Gap(16),
          Expanded(child: panel2),
          const Gap(16),
          Expanded(child: panel3),
          const Gap(16),
          Expanded(child: panel4),
        ],
      );
    } else {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: panel1),
          SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: panel2),
          SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: panel3),
          SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: panel4),
        ],
      );
    }
  }

  Widget _buildMetricCard({
    required String title,
    required List<String> items,
    required Color accentColor,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accentColor),
          ),
          const Gap(10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(item, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsGrid(BuildContext context, WidgetRef ref) {
    final overTimeAsync = ref.watch(revenueOverTimeProvider);
    final cityAsync = ref.watch(bookingsByCityProvider);
    final typeAsync = ref.watch(bookingsByTripTypeProvider);
    final vendorsAsync = ref.watch(topVendorsByRevenueProvider);

    final chart1 = overTimeAsync.when(
      loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
      error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading LineChart'))),
      data: (data) => _RevenueOverTimeChart(data: data),
    );

    final chart2 = cityAsync.when(
      loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
      error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading BarChart'))),
      data: (data) => _CityBookingsChart(data: data),
    );

    final chart3 = typeAsync.when(
      loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
      error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading PieChart'))),
      data: (data) => _TripTypePieChart(data: data),
    );

    final chart4 = vendorsAsync.when(
      loading: () => const SizedBox(height: 250, child: Center(child: AppLoader())),
      error: (err, _) => const SizedBox(height: 250, child: Center(child: Text('Error loading VendorChart'))),
      data: (data) => _TopVendorsRevenueChart(vendors: data),
    );

    if (Responsive.isDesktop(context)) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: chart1),
              const Gap(24),
              Expanded(child: chart2),
            ],
          ),
          const Gap(24),
          Row(
            children: [
              Expanded(child: chart3),
              const Gap(24),
              Expanded(child: chart4),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          chart1,
          const Gap(24),
          chart2,
          const Gap(24),
          chart3,
          const Gap(24),
          chart4,
        ],
      );
    }
  }

  Future<void> _handleCsvExport(BuildContext context, WidgetRef ref) async {
    final range = ref.read(revenueDateRangeProvider);
    final repo = ref.read(revenueRepositoryProvider);

    try {
      final csv = await repo.exportRevenueCsv(range);
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                Gap(8),
                Text('CSV Export Ready'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Authoritative revenue dataset generated successfully.'),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Preview:\n${csv.split('\n').take(3).join('\n')}\n... (${csv.split('\n').length} lines total)',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _RevenueOverTimeChart extends StatelessWidget {
  final List<double> data;
  const _RevenueOverTimeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, double.infinity);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Commission Trend (Daily)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Text(
                          '₹${(v / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          if (v.toInt() % 5 == 0) {
                            return Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
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

class _CityBookingsChart extends StatelessWidget {
  final Map<String, double> data;
  const _CityBookingsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList();
    final values = data.values.toList();
    final maxVal = values.isEmpty ? 10.0 : (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(10.0, double.infinity);

    final barGroups = List.generate(keys.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i],
            color: Colors.green,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gross Revenue by City (₹)',
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
                    getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Text(
                          '₹${(v / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx >= keys.length) return const SizedBox.shrink();
                          return Text(
                            keys[idx],
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
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

class _TripTypePieChart extends StatelessWidget {
  final Map<String, int> data;
  const _TripTypePieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.blue, Colors.green, Colors.amber, Colors.purple, Colors.orange];
    final keys = data.keys.toList();
    final values = data.values.toList();
    final total = values.fold<int>(0, (s, e) => s + e);

    final sections = List.generate(keys.length, (i) {
      final val = values[i];
      final pct = total == 0 ? 0.0 : (val / total) * 100;
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: val.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Type Distribution',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: sections.isEmpty
                            ? [
                                PieChartSectionData(
                                  color: Colors.grey[300]!,
                                  value: 1,
                                  title: 'N/A',
                                  radius: 50,
                                ),
                              ]
                            : sections,
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(keys.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Gap(6),
                              Expanded(
                                child: Text(
                                  '${keys[i]} (${values[i]})',
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
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

class _TopVendorsRevenueChart extends StatelessWidget {
  final List<VendorModel> vendors;
  const _TopVendorsRevenueChart({required this.vendors});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Partners',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(16),
            if (vendors.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(child: Text('No vendor revenue data available')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vendors.length.clamp(0, 5),
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, idx) {
                  final v = vendors[idx];
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue[50],
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.businessName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('${v.ownerName} • ${v.city}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified, size: 16, color: Colors.green),
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
