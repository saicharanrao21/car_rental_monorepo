import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/dashboard_repository.dart';

class MockDashboardRepository with LatencySimulator implements DashboardRepository {
  final referenceToday = DateTime(2026, 7, 1);

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    await simulateLatency();

    final vendorBookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    final vendorCars = MockData.cars.where((c) => c.vendorId == vendorId).toList();

    // Today's Bookings: ongoing/confirmed and starts on referenceToday
    final todaysBookingsCount = vendorBookings.where((b) {
      final isSameDay = b.startDate.year == referenceToday.year &&
          b.startDate.month == referenceToday.month &&
          b.startDate.day == referenceToday.day;
      final isOngoingOrConfirmed = b.status == 'ongoing' || b.status == 'confirmed';
      return isSameDay && isOngoingOrConfirmed;
    }).length;

    // Pending requests
    final pendingRequestsCount = vendorBookings.where((b) => b.status == 'pending').length;

    // Earnings this month (July 2026)
    double earnings = 0.0;
    final julyCompletedBookings = vendorBookings.where((b) {
      return b.status == 'completed' &&
          b.startDate.year == referenceToday.year &&
          b.startDate.month == referenceToday.month;
    });

    if (julyCompletedBookings.isNotEmpty) {
      earnings = julyCompletedBookings.fold(0.0, (sum, b) => sum + b.netToVendor);
    } else {
      // Fallback: sum all completed bookings to show realistic numbers for demo
      final allCompleted = vendorBookings.where((b) => b.status == 'completed');
      earnings = allCompleted.fold(0.0, (sum, b) => sum + b.netToVendor);
    }

    // Fleet status
    final activeCarsCount = vendorCars.where((c) => c.isAvailable).length;
    final inactiveCarsCount = vendorCars.where((c) => !c.isAvailable).length;

    return DashboardStats(
      todaysBookings: todaysBookingsCount,
      pendingRequests: pendingRequestsCount,
      thisMonthEarnings: earnings,
      activeCars: activeCarsCount,
      inactiveCars: inactiveCarsCount,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async {
    await simulateLatency();

    final pending = MockData.bookings
        .where((b) => b.vendorId == vendorId && b.status == 'pending')
        .toList();

    // Sort by createdAt descending (most recent first)
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return pending.take(limit).toList();
  }

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {
    await simulateLatency();

    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final oldBooking = MockData.bookings[index];
      MockData.bookings[index] = oldBooking.copyWith(
        status: accept ? 'confirmed' : 'cancelled',
      );
    }
  }
}
