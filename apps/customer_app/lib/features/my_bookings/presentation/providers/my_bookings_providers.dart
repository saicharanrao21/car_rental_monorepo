import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../../data/api_my_bookings_repository.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';

final myBookingsRepositoryProvider = Provider<MyBookingsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiMyBookingsRepository(apiClient: apiClient);
});

final myBookingsTabProvider = StateProvider.autoDispose<int>((ref) => 0);

final myBookingsListProvider = AutoDisposeAsyncNotifierProvider<MyBookingsListNotifier, List<BookingModel>>(() {
  return MyBookingsListNotifier();
});

class MyBookingsListNotifier extends AutoDisposeAsyncNotifier<List<BookingModel>> {
  @override
  Future<List<BookingModel>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated || session.user == null) {
      return [];
    }

    final repo = ref.watch(myBookingsRepositoryProvider);
    final allBookings = await repo.getBookingsForUser(session.user!.id);
    final tabIndex = ref.watch(myBookingsTabProvider);
    final now = DateTime.now();

    switch (tabIndex) {
      case 0: // Upcoming: pending or confirmed with startDate in future/present
        return bookingsSorted(allBookings.where((b) {
          final isUpcomingStatus = b.status == 'confirmed' || b.status == 'pending';
          return isUpcomingStatus && b.endDate.isAfter(now);
        }).toList());
      case 1: // Ongoing: ongoing status, or currently active dates
        return bookingsSorted(allBookings.where((b) {
          return b.status == 'ongoing' || 
              (b.status == 'confirmed' && b.startDate.isBefore(now) && b.endDate.isAfter(now));
        }).toList());
      case 2: // Completed: completed status, or end date in past
        return bookingsSorted(allBookings.where((b) {
          return b.status == 'completed' || 
              (b.status == 'confirmed' && b.endDate.isBefore(now));
        }).toList());
      case 3: // Cancelled: cancelled status
        return bookingsSorted(allBookings.where((b) => b.status == 'cancelled').toList());
      default:
        return [];
    }
  }

  List<BookingModel> bookingsSorted(List<BookingModel> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> cancel(String bookingId, String reason) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      await repo.cancelBooking(bookingId, reason);
      // Invalidate the My Bookings list provider
      ref.invalidateSelf();
      // Also invalidate the enriched detail provider so it updates
      ref.invalidate(bookingWithDetailsProvider(bookingId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitBookingReview({
    required String bookingId,
    required String customerId,
    required String vendorId,
    required double rating,
    required String comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      final review = ReviewModel(
        id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
        bookingId: bookingId,
        customerId: customerId,
        vendorId: vendorId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );
      await repo.submitReview(review);
      ref.invalidateSelf();
      ref.invalidate(bookingWithDetailsProvider(bookingId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
