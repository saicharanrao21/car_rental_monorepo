import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/earnings_repository.dart';

class MockEarningsRepository with LatencySimulator implements EarningsRepository {
  @override
  Future<EarningsSummary> getSummary(String vendorId) async {
    await simulateLatency();
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(seconds: 1));

    final vendorBookings = MockData.bookings
        .where((b) => b.vendorId == vendorId && b.status == 'completed')
        .toList();

    double thisMonth = 0;
    double lastMonth = 0;
    double totalLifetime = 0;

    for (final b in vendorBookings) {
      totalLifetime += b.netToVendor;
      if (!b.startDate.isBefore(thisMonthStart)) {
        thisMonth += b.netToVendor;
      } else if (!b.startDate.isBefore(lastMonthStart) && !b.startDate.isAfter(lastMonthEnd)) {
        lastMonth += b.netToVendor;
      }
    }

    return EarningsSummary(
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      totalLifetime: totalLifetime,
    );
  }

  @override
  Future<List<EarningsModel>> getDailyEarnings(String vendorId, {int days = 30}) async {
    await simulateLatency();
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));

    // Build EarningsModel per day from completed bookings
    final vendorBookings = MockData.bookings
        .where((b) => b.vendorId == vendorId && b.status == 'completed')
        .where((b) => b.startDate.isAfter(cutoff))
        .toList();

    // Group by day
    final Map<DateTime, _DayAgg> agg = {};
    for (final b in vendorBookings) {
      final day = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      agg[day] ??= _DayAgg();
      agg[day]!.gross += b.totalFare;
      agg[day]!.fee += b.platformFee;
      agg[day]!.gst += b.gstAmount;
      agg[day]!.net += b.netToVendor;
    }

    return agg.entries
        .map((e) => EarningsModel(
              vendorId: vendorId,
              date: e.key,
              grossAmount: e.value.gross,
              platformFee: e.value.fee,
              gstAmount: e.value.gst,
              netAmount: e.value.net,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<PayoutRecord>> getPayoutHistory(String vendorId) async {
    await simulateLatency();
    final vendorBookings = MockData.bookings
        .where((b) => b.vendorId == vendorId && b.status == 'completed')
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (vendorBookings.isEmpty) return [];

    // Group into weekly payouts
    final List<PayoutRecord> payouts = [];
    final Map<int, double> weeklyAmounts = {};

    for (final b in vendorBookings) {
      // ISO week key: year * 100 + weekNumber
      final weekKey = b.startDate.year * 100 +
          ((b.startDate.difference(DateTime(b.startDate.year, 1, 1)).inDays) ~/ 7);
      weeklyAmounts[weekKey] = (weeklyAmounts[weekKey] ?? 0) + b.netToVendor;
    }

    for (final entry in weeklyAmounts.entries) {
      final year = entry.key ~/ 100;
      final weekNum = entry.key % 100;
      // Approximate payout date: Monday of that week + 2 days (Wed = payout day)
      final jan1 = DateTime(year, 1, 1);
      final payoutDate = jan1
          .add(Duration(days: weekNum * 7))
          .add(const Duration(days: 2)); // Wed
      payouts.add(PayoutRecord(date: payoutDate, amount: entry.value));
    }

    payouts.sort((a, b) => b.date.compareTo(a.date));
    return payouts.take(10).toList(); // last 10 payouts
  }

  @override
  Future<List<BookingModel>> getCompletedBookings(String vendorId) async {
    await simulateLatency();
    return MockData.bookings
        .where((b) => b.vendorId == vendorId && b.status == 'completed')
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }
}

class _DayAgg {
  double gross = 0;
  double fee = 0;
  double gst = 0;
  double net = 0;
}
