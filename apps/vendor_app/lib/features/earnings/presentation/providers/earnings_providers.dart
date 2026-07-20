import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../domain/repositories/earnings_repository.dart';
import '../../data/mock_earnings_repository.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return MockEarningsRepository();
});

final earningsSummaryProvider = FutureProvider.autoDispose<EarningsSummary>((ref) async {
  final vendorId = ref.watch(vendorSessionProvider).vendor?.id;
  if (vendorId == null) throw Exception('Not logged in');
  return ref.read(earningsRepositoryProvider).getSummary(vendorId);
});

final dailyEarningsProvider = FutureProvider.autoDispose<List<EarningsModel>>((ref) async {
  final vendorId = ref.watch(vendorSessionProvider).vendor?.id;
  if (vendorId == null) throw Exception('Not logged in');
  return ref.read(earningsRepositoryProvider).getDailyEarnings(vendorId, days: 30);
});

final payoutHistoryProvider = FutureProvider.autoDispose<List<PayoutRecord>>((ref) async {
  final vendorId = ref.watch(vendorSessionProvider).vendor?.id;
  if (vendorId == null) throw Exception('Not logged in');
  return ref.read(earningsRepositoryProvider).getPayoutHistory(vendorId);
});

final completedBookingsEarningsProvider =
    FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  final vendorId = ref.watch(vendorSessionProvider).vendor?.id;
  if (vendorId == null) throw Exception('Not logged in');
  return ref.read(earningsRepositoryProvider).getCompletedBookings(vendorId);
});
