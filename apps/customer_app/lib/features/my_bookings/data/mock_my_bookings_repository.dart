import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../../booking/domain/repositories/booking_repository.dart';
import '../domain/repositories/my_bookings_repository.dart';

class MockMyBookingsRepositoryImpl with LatencySimulator implements MyBookingsRepository {
  final BookingRepository _bookingRepo;
  final List<ReviewModel> _reviews = [];

  MockMyBookingsRepositoryImpl(this._bookingRepo);

  @override
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter}) async {
    final bookings = await _bookingRepo.getBookingsForCustomer(userId);
    if (statusFilter != null) {
      return bookings.where((b) => b.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }
    return bookings;
  }

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _bookingRepo.cancelBooking(bookingId);
  }

  @override
  Future<void> submitReview(ReviewModel review) async {
    await simulateLatency();
    _reviews.add(review);
  }
}
