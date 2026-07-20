import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../data/api_booking_repository.dart';
import '../../../car_detail/presentation/providers/car_detail_providers.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiBookingRepository(apiClient: apiClient, ref: ref);
});

// ── My Bookings list ─────────────────────────────────────────────────────────

class MyBookingsNotifier extends AutoDisposeAsyncNotifier<List<BookingModel>> {
  @override
  Future<List<BookingModel>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated || session.user == null) return [];
    final repo = ref.watch(bookingRepositoryProvider);
    return repo.getBookingsForCustomer(session.user!.id);
  }

  Future<void> refresh() async { ref.invalidateSelf(); await future; }

  Future<void> cancel(String bookingId) async {
    await ref.read(bookingRepositoryProvider).cancelBooking(bookingId);
    ref.invalidateSelf();
  }
}

final myBookingsProvider =
    AutoDisposeAsyncNotifierProvider<MyBookingsNotifier, List<BookingModel>>(
        MyBookingsNotifier.new);

// ── Single booking detail ────────────────────────────────────────────────────

final bookingDetailProvider =
    FutureProvider.family.autoDispose<BookingModel?, String>((ref, id) {
  return ref.watch(bookingRepositoryProvider).getBookingById(id);
});

// ── Booking + car/vendor enrichment ──────────────────────────────────────────

class BookingWithDetails {
  final BookingModel booking;
  final CarModel car;
  final VendorModel vendor;
  const BookingWithDetails({required this.booking, required this.car, required this.vendor});
}

final bookingWithDetailsProvider =
    FutureProvider.family.autoDispose<BookingWithDetails?, String>((ref, bookingId) async {
  final booking = await ref.watch(bookingRepositoryProvider).getBookingById(bookingId);
  if (booking == null) return null;
  final detail = await ref.watch(carDetailDataProvider(booking.carId).future);
  return BookingWithDetails(booking: booking, car: detail.car, vendor: detail.vendor);
});
