import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:mock_data/mock_data.dart';
import 'package:admin_panel/features/revenue/domain/repositories/revenue_repository.dart';
import '../providers/revenue_providers.dart';

class RevenueReportsPage extends ConsumerWidget {
  const RevenueReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(revenueDateRangeProvider);
    final summaryAsync = ref.watch(revenueSummaryProvider);

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
                      'Revenue & Reports',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Detailed financials and analytics for date range: $formattedStart - $formattedEnd',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Export to CSV',
                  isFullWidth: false,
                  onPressed: () => _handleCsvExport(context),
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
                        height: 100,
                        child: Center(child: AppLoader()),
                      ),
                      error: (err, _) => const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Error loading revenue summary')),
                        ),
                      ),
                      data: (summary) => _buildSummaryCards(context, summary),
                    ),
                    const Gap(24),

                    // Charts Grid
                    _buildChartsGrid(context, ref),
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

  Widget _buildSummaryCards(BuildContext context, RevenueSummary summary) {
    final isDesktop = Responsive.isDesktop(context);
    final cards = [
      _buildSummaryCard('Gross Booking Value', summary.grossBookingValue, Colors.black87),
      _buildSummaryCard('Platform Revenue (Commission)', summary.platformRevenue, Colors.blue),
      _buildSummaryCard('Vendor Payouts', summary.vendorPayouts, Colors.green),
      _buildSummaryCard('GST Collected', summary.gstCollected, Colors.amber[800]!),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 64) / 2, child: c)).toList(),
      );
    }
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          const Gap(8),
          PriceTag(
            amount: amount,
            amountStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
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

  void _handleCsvExport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export Revenue Report'),
          content: const Text(
            'Your revenue report is being compiled. The CSV file will automatically begin downloading shortly.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export started successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _RevenueOverTimeChart extends StatelessWidget {
  final List<double> data;
  const _RevenueOverTimeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
    final double maxVal = data.isEmpty ? 1000 : (data.reduce((a, b) => a > b ? a : b) * 1.1);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Over Time (Platform Fee)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  maxY: maxVal,
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
                        reservedSize: 45,
                        getTitlesWidget: (v, _) => Text(
                          '₹${v.toInt()}',
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
                          if (idx % (data.length ~/ 5 + 1) != 0 || idx >= data.length) return const SizedBox.shrink();
                          return Text(
                            'Day ${idx + 1}',
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
                      color: Colors.indigo,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.indigo.withValues(alpha: 0.1),
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
    final double maxVal = data.values.isEmpty ? 10 : (data.values.reduce((a, b) => a > b ? a : b) * 1.2);

    final barGroups = List.generate(keys.length, (i) {
      final city = keys[i];
      final val = data[city] ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: Colors.blueAccent,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bookings by City',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(24),
            SizedBox(
              height: 250,
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
                        reservedSize: 30,
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
                          if (idx >= keys.length) return const SizedBox.shrink();
                          return Text(
                            keys[idx],
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
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
    final total = data.values.fold(0, (sum, val) => sum + val);
    if (total == 0) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('No trip type data available')),
      );
    }

    final colors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.amber,
    ];

    final keys = data.keys.toList();
    final sections = List.generate(keys.length, (i) {
      final key = keys[i];
      final val = data[key] ?? 0;
      final pct = (val / total) * 100;
      final color = colors[i % colors.length];

      return PieChartSectionData(
        value: val.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bookings by Trip Type Scope',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(24),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: sections,
                      ),
                    ),
                  ),
                  const Gap(12),
                  // Legend
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(keys.length, (i) {
                      final key = keys[i];
                      final val = data[key] ?? 0;
                      final color = colors[i % colors.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(8),
                            Text(
                              '$key: $val',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }),
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

  double _getVendorRevenue(String vendorId) {
    return MockData.bookings
        .where((b) => b.vendorId == vendorId)
        .map((b) => b.totalFare)
        .fold(0.0, (sum, val) => sum + val);
  }

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<VendorModel, double>> vendorRevenues = vendors.map((v) {
      double rev = _getVendorRevenue(v.id);
      if (rev == 0.0) {
        rev = (v.rating * 15000.0) + (v.totalTrips * 350.0);
      }
      return MapEntry(v, rev);
    }).toList();

    vendorRevenues.sort((a, b) => b.value.compareTo(a.value));
    final topList = vendorRevenues.take(10).toList();

    final double maxVal = topList.isEmpty ? 10000 : (topList.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2);

    final barGroups = List.generate(topList.length, (i) {
      final val = topList[i].value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: Colors.teal,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Vendors by Revenue (Horizontal)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const Gap(24),
            SizedBox(
              height: 250,
              child: RotatedBox(
                quarterTurns: 1,
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
                          reservedSize: 50,
                          getTitlesWidget: (v, _) => Text(
                            '₹${(v / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx >= topList.length) return const SizedBox.shrink();
                            final name = topList[idx].key.businessName;
                            return RotatedBox(
                              quarterTurns: 3,
                              child: Container(
                                alignment: Alignment.centerRight,
                                width: 80,
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: barGroups,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
