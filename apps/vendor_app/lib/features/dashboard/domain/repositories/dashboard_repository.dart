import 'package:models/models.dart';

class DashboardStats {
  final int todaysBookings;
  final int pendingRequests;
  final double thisMonthEarnings;
  final int activeCars;
  final int inactiveCars;

  const DashboardStats({
    required this.todaysBookings,
    required this.pendingRequests,
    required this.thisMonthEarnings,
    required this.activeCars,
    required this.inactiveCars,
  });
}

abstract class DashboardRepository {
  Future<DashboardStats> getStats(String vendorId);
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3});
  Future<void> respondToBooking(String bookingId, bool accept);
}
