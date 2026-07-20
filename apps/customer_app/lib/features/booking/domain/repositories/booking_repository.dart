import 'package:models/models.dart';

abstract class BookingRepository {
  /// Creates a booking, assigning a generated id and createdAt timestamp.
  Future<BookingModel> createBooking(BookingModel draft);

  Future<List<BookingModel>> getBookingsForCustomer(String customerId);

  Future<BookingModel?> getBookingById(String bookingId);

  Future<BookingModel> cancelBooking(String bookingId);

  /// Returns best matching commission config for the given params (defaults to 10%).
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  });
}
