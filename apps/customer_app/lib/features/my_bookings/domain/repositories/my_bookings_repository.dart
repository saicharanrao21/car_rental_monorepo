import 'package:models/models.dart';

abstract class MyBookingsRepository {
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter});
  Future<void> cancelBooking(String bookingId, String reason);
  Future<void> submitReview(ReviewModel review);
}
