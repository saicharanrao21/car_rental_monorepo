import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:models/models.dart';
import '../providers/earnings_providers.dart';
import '../../domain/repositories/earnings_repository.dart';

class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(earningsSummaryProvider);
    final dailyAsync = ref.watch(dailyEarningsProvider);
    final payoutsAsync = ref.watch(payoutHistoryProvider);
    final completedAsync = ref.watch(completedBookingsEarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(earningsSummaryProvider);
              ref.invalidate(dailyEarningsProvider);
              ref.invalidate(payoutHistoryProvider);
              ref.invalidate(completedBookingsEarningsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningsSummaryProvider);
          ref.invalidate(dailyEarningsProvider);
          ref.invalidate(payoutHistoryProvider);
          ref.invalidate(completedBookingsEarningsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Summary Cards ───
              const SectionHeader(title: 'Earnings Overview'),
              const Gap(12),
              summaryAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => ErrorStateWidget(
                  message: 'Could not load summary',
                  onRetry: () => ref.invalidate(earningsSummaryProvider),
                ),
                data: (summary) => _SummaryCards(summary: summary),
              ),
              const Gap(28),

              // ─── Daily Bar Chart ───
              const SectionHeader(title: 'Daily Earnings – Last 30 Days'),
              const Gap(12),
              dailyAsync.when(
                loading: () => const SizedBox(height: 200, child: Center(child: AppLoader())),
                error: (e, _) => ErrorStateWidget(
                  message: 'Could not load chart data',
                  onRetry: () => ref.invalidate(dailyEarningsProvider),
                ),
                data: (days) => days.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.bar_chart,
                        title: 'No data yet',
                        subtitle: 'Complete trips to see your daily earnings chart.',
                      )
                    : _DailyBarChart(dailyEarnings: days),
              ),
              const Gap(28),

              // ─── Per-Booking Breakdown ───
              const SectionHeader(title: 'Completed Booking Breakdown'),
              const Gap(12),
              completedAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => ErrorStateWidget(
                  message: 'Could not load booking breakdown',
                  onRetry: () => ref.invalidate(completedBookingsEarningsProvider),
                ),
                data: (bookings) => bookings.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'No completed bookings',
                        subtitle: 'Completed trips will appear here.',
                      )
                    : _BookingEarningsList(bookings: bookings),
              ),
              const Gap(28),

              // ─── Payout History ───
              const SectionHeader(title: 'Payout History'),
              const Gap(12),
              payoutsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => ErrorStateWidget(
                  message: 'Could not load payout history',
                  onRetry: () => ref.invalidate(payoutHistoryProvider),
                ),
                data: (payouts) => payouts.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No payouts yet',
                        subtitle: 'Your payouts will appear here weekly.',
                      )
                    : _PayoutHistoryList(payouts: payouts),
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Cards ─────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final EarningsSummary summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'This Month', amount: summary.thisMonth, color: AppColors.primary)),
        const Gap(12),
        Expanded(child: _SummaryCard(label: 'Last Month', amount: summary.lastMonth, color: Colors.deepOrange)),
        const Gap(12),
        Expanded(child: _SummaryCard(label: 'Total Lifetime', amount: summary.totalLifetime, color: Colors.green)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const Gap(8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PriceTag(
                amount: amount,
                amountStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bar Chart ─────────────────────────────────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  final List<EarningsModel> dailyEarnings;
  const _DailyBarChart({required this.dailyEarnings});

  @override
  Widget build(BuildContext context) {
    final maxY = dailyEarnings.map((e) => e.netAmount).fold(0.0, (a, b) => a > b ? a : b);
    final groups = List.generate(dailyEarnings.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: dailyEarnings[i].netAmount,
            color: AppColors.primary,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final dateFormatter = DateFormat('d/M');

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
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
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      // Show label every 5th day only
                      if (idx % 5 != 0 || idx >= dailyEarnings.length) return const SizedBox.shrink();
                      return Text(
                        dateFormatter.format(dailyEarnings[idx].date),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = dailyEarnings[group.x];
                    return BarTooltipItem(
                      '${dateFormatter.format(day.date)}\n₹${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Booking Breakdown List ─────────────────────────────────────────────────

class _BookingEarningsList extends StatelessWidget {
  final List<BookingModel> bookings;
  const _BookingEarningsList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: bookings.map((b) => _BookingEarningsRow(booking: b)).toList(),
    );
  }
}

class _BookingEarningsRow extends StatelessWidget {
  final BookingModel booking;
  const _BookingEarningsRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');
    final commissionPct = booking.totalFare > 0
        ? ((booking.platformFee / booking.totalFare) * 100).toStringAsFixed(0)
        : '0';
    final isDisputed = booking.disputeFlag;
    final isCompleted = booking.status.toLowerCase() == 'completed';
    final isCancelled = booking.status.toLowerCase() == 'cancelled' ||
        booking.status.toLowerCase() == 'refunded';

    String escrowLabel = 'IN PLATFORM ESCROW';
    Color escrowBg = const Color(0xFFEFF6FF);
    Color escrowFg = const Color(0xFF1D4ED8);

    if (isDisputed) {
      escrowLabel = 'ESCROW HOLD (DISPUTED)';
      escrowBg = const Color(0xFFFEF2F2);
      escrowFg = const Color(0xFFB91C1C);
    } else if (isCancelled) {
      escrowLabel = 'REFUNDED TO CUSTOMER';
      escrowBg = const Color(0xFFF3F4F6);
      escrowFg = const Color(0xFF4B5563);
    } else if (isCompleted) {
      escrowLabel = 'SETTLEMENT ELIGIBLE';
      escrowBg = const Color(0xFFF0FDF4);
      escrowFg = const Color(0xFF15803D);
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Booking #${booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id} • ${booking.tripType}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: escrowBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    escrowLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: escrowFg,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip Date: ${formatter.format(booking.startDate)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                Text(
                  'Status: ${booking.status.toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Customer Paid (Escrow):', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                PriceTag(
                  amount: booking.totalFare,
                  amountStyle: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Gap(4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Platform Fee ($commissionPct% deducted):',
                    style: TextStyle(color: Colors.orange[700], fontSize: 11),
                  ),
                ),
                Text(
                  '-₹${booking.platformFee.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.orange[700], fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Gap(6),
            const Divider(height: 1),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Vendor Settlement:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                PriceTag(
                  amount: isCancelled ? 0.0 : booking.netToVendor,
                  amountStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? Colors.grey : (isDisputed ? Colors.deepOrange : Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Payout History List ────────────────────────────────────────────────────

class _PayoutHistoryList extends StatelessWidget {
  final List<PayoutRecord> payouts;
  const _PayoutHistoryList({required this.payouts});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');
    return Column(
      children: payouts.map((p) {
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                ),
                const Gap(14),
                Expanded(
                  child: Text(
                    'Payout on ${formatter.format(p.date)}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
                PriceTag(
                  amount: p.amount,
                  amountStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
