import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/models/operations_models.dart';

class MockDashboardRepository with LatencySimulator implements DashboardRepository {
  final referenceToday = DateTime(2026, 7, 1);

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    await simulateLatency();

    final vendorBookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    final vendorCars = MockData.cars.where((c) => c.vendorId == vendorId).toList();

    final todaysBookingsCount = vendorBookings.where((b) {
      final isSameDay = b.startDate.year == referenceToday.year &&
          b.startDate.month == referenceToday.month &&
          b.startDate.day == referenceToday.day;
      final isOngoingOrConfirmed = b.status == 'ongoing' || b.status == 'confirmed';
      return isSameDay && isOngoingOrConfirmed;
    }).length;

    final pendingRequestsCount = vendorBookings.where((b) => b.status == 'pending').length;

    double earnings = 0.0;
    final julyCompletedBookings = vendorBookings.where((b) {
      return b.status == 'completed' &&
          b.startDate.year == referenceToday.year &&
          b.startDate.month == referenceToday.month;
    });

    if (julyCompletedBookings.isNotEmpty) {
      earnings = julyCompletedBookings.fold(0.0, (sum, b) => sum + b.netToVendor);
    } else {
      final allCompleted = vendorBookings.where((b) => b.status == 'completed');
      earnings = allCompleted.fold(0.0, (sum, b) => sum + b.netToVendor);
    }

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

  @override
  Future<List<TriageItem>> getOperationsTriage(String vendorId) async {
    await simulateLatency();
    final vendorBookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    final items = <TriageItem>[];

    for (final b in vendorBookings) {
      final car = MockData.cars.where((c) => c.id == b.carId).firstOrNull;
      final carName = car != null ? '${car.make} ${car.model}' : 'Vehicle';

      if (b.status == 'pending') {
        items.add(TriageItem(
          id: 'pending_${b.id}',
          title: 'Booking confirmation required',
          subtitle: '₹${b.totalFare.toStringAsFixed(0)} • $carName',
          priority: TriagePriority.urgent,
          badgeText: 'PENDING ACTION',
          actionLabel: 'Review Request',
          routePath: '/bookings/${b.id}',
          vehicleName: carName,
          bookingId: b.id,
          isBookingAction: true,
        ));
      } else if (b.status == 'confirmed') {
        items.add(TriageItem(
          id: 'pickup_${b.id}',
          title: 'Pickup scheduled at 10:00 AM',
          subtitle: '$carName • ${b.pickupLocation}',
          priority: TriagePriority.high,
          badgeText: 'TODAY PICKUP',
          actionLabel: 'Prepare Handover',
          routePath: '/bookings/${b.id}',
          vehicleName: carName,
          bookingId: b.id,
        ));
      }
    }

    items.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return items;
  }

  @override
  Future<List<TodayTimelineItem>> getTodayOperations(String vendorId) async {
    await simulateLatency();
    final vendorBookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    final timeline = <TodayTimelineItem>[];

    for (final b in vendorBookings) {
      final car = MockData.cars.where((c) => c.id == b.carId).firstOrNull;
      final carName = car != null ? '${car.make} ${car.model}' : 'Vehicle';

      timeline.add(TodayTimelineItem(
        id: 'pickup_${b.id}',
        bookingId: b.id,
        type: TimelineEventType.pickup,
        time: b.startDate,
        vehicleName: carName,
        registrationNumber: car?.registrationNumber,
        customerSafeName: 'Amit S.',
        hubLocation: b.pickupLocation,
        status: b.status.toUpperCase(),
        tripType: b.tripType,
      ));
    }
    return timeline;
  }

  @override
  Future<BookingMatrix> getBookingMatrix(String vendorId) async {
    await simulateLatency();
    final vendorBookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    return BookingMatrix(
      todayCount: vendorBookings.where((b) => b.status == 'confirmed' || b.status == 'ongoing').length,
      pendingCount: vendorBookings.where((b) => b.status == 'pending').length,
      upcomingCount: vendorBookings.where((b) => b.status == 'confirmed').length,
      completedCount: vendorBookings.where((b) => b.status == 'completed').length,
      activeCount: vendorBookings.where((b) => b.status == 'ongoing').length,
    );
  }

  @override
  Future<FleetSummary> getFleetSummary(String vendorId) async {
    await simulateLatency();
    final vendorCars = MockData.cars.where((c) => c.vendorId == vendorId).toList();
    return FleetSummary(
      totalCars: vendorCars.length,
      availableCars: vendorCars.where((c) => c.isAvailable).length,
      onTripCars: 1,
      unavailableCars: vendorCars.where((c) => !c.isAvailable).length,
    );
  }

  @override
  Future<EarningsSnapshot> getEarningsSnapshot(String vendorId) async {
    await simulateLatency();
    return const EarningsSnapshot(
      thisMonthEarnings: 34500.0,
      availableBalance: 28400.0,
      heldEarnings: 6100.0,
      totalEarnings: 142000.0,
      totalPaidOut: 107500.0,
    );
  }
}

