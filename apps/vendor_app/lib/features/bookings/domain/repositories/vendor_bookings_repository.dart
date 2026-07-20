import 'package:models/models.dart';

abstract class VendorBookingsRepository {
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter});
  Future<void> updateBookingStatus(String bookingId, String newStatus);
  Future<void> rejectBooking(String bookingId, String reason);
}
