import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_bookings_repository.dart';

class MockVendorBookingsRepository with LatencySimulator implements VendorBookingsRepository {
  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    await simulateLatency();
    final bookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    if (statusFilter != null) {
      final filterLower = statusFilter.toLowerCase().trim();
      return bookings.where((b) => b.status.toLowerCase().trim() == filterLower).toList();
    }
    return bookings;
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    await simulateLatency();
    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = MockData.bookings[index];
      MockData.bookings[index] = old.copyWith(status: newStatus);
    }
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    await simulateLatency();
    // Simulate updating database. Rejection cancels the booking.
    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = MockData.bookings[index];
      MockData.bookings[index] = old.copyWith(status: 'cancelled');
    }
  }
}
