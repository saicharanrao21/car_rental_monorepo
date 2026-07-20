import 'package:models/models.dart';

/// Summary totals for the earnings screen
class EarningsSummary {
  final double thisMonth;
  final double lastMonth;
  final double totalLifetime;

  const EarningsSummary({
    required this.thisMonth,
    required this.lastMonth,
    required this.totalLifetime,
  });
}

/// A synthesised payout record (weekly disbursement)
class PayoutRecord {
  final DateTime date;
  final double amount;

  const PayoutRecord({required this.date, required this.amount});
}

abstract interface class EarningsRepository {
  Future<EarningsSummary> getSummary(String vendorId);
  Future<List<EarningsModel>> getDailyEarnings(String vendorId, {int days = 30});
  Future<List<PayoutRecord>> getPayoutHistory(String vendorId);
  Future<List<BookingModel>> getCompletedBookings(String vendorId);
}
