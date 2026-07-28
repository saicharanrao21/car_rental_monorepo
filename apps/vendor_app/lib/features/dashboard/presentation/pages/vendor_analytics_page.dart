import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_providers.dart';
import '../../domain/repositories/analytics_repository.dart';

class VendorAnalyticsPage extends ConsumerWidget {
  const VendorAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(vendorAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(vendorAnalyticsProvider),
          ),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load analytics: $err',
            onRetry: () => ref.invalidate(vendorAnalyticsProvider),
          ),
        ),
        data: (analytics) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vendorAnalyticsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Performance & Customer Interest',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Gap(4),
                  Text(
                    'Overview of customer views, wishlist adds, and booking conversions.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Gap(20),

                  // Summary Card Row (3 Metrics)
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Total Views',
                          value: '${analytics.totalViews}',
                          icon: Icons.visibility_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Wishlisted',
                          value: '${analytics.wishlistCount}',
                          icon: Icons.favorite_border,
                          color: Colors.pink,
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Conversion Rate',
                          value: '${analytics.conversionRate.toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Views Bar Chart (Top 5 Cars)
                  const SectionHeader(title: 'Top 5 Most Viewed Cars (Last 30 Days)'),
                  const Gap(12),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (analytics.viewsByCarLast30Days.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text('No car views recorded in the last 30 days.', style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 220,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _calculateMaxY(analytics.viewsByCarLast30Days),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        final car = analytics.viewsByCarLast30Days[groupIndex];
                                        return BarTooltipItem(
                                          '${car.carName}\n${car.views} views',
                                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (double value, TitleMeta meta) {
                                          final idx = value.toInt();
                                          if (idx >= 0 && idx < analytics.viewsByCarLast30Days.length) {
                                            final name = analytics.viewsByCarLast30Days[idx].carName;
                                            final shortName = name.length > 8 ? name.substring(0, 8) : name;
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 6.0),
                                              child: Text(shortName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        getTitlesWidget: (double value, TitleMeta meta) {
                                          if (value % 1 == 0) {
                                            return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: analytics.viewsByCarLast30Days.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return BarChartGroupData(
                                      x: idx,
                                      barRods: [
                                        BarChartRodData(
                                          toY: item.views.toDouble(),
                                          color: AppColors.primary,
                                          width: 22,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Gap(24),

                  // Breakdown list of views per car
                  const SectionHeader(title: 'Car Interest Breakdown'),
                  const Gap(12),
                  if (analytics.viewsByCarLast30Days.isEmpty)
                    const AppCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No car details available yet.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: analytics.viewsByCarLast30Days.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                if (idx > 0) const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '#${idx + 1}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                          ),
                                        ),
                                        const Gap(12),
                                        Text(
                                          item.carName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.visibility_outlined, size: 16, color: Colors.grey),
                                        const Gap(4),
                                        Text(
                                          '${item.views} views',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const Gap(30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _calculateMaxY(List<CarViewsItem> items) {
    if (items.isEmpty) return 10;
    double maxViews = 0;
    for (final item in items) {
      if (item.views > maxViews) maxViews = item.views.toDouble();
    }
    return (maxViews * 1.3).ceilToDouble();
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const Gap(8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
