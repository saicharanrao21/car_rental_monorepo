import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../../data/api_my_bookings_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../booking/presentation/providers/booking_providers.dart';

final myBookingsRepositoryProvider = Provider<MyBookingsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiMyBookingsRepository(apiClient: apiClient);
});

final myBookingsTabProvider = StateProvider.autoDispose<int>((ref) => 0);

final enrichedBookingDetailProvider =
    FutureProvider.autoDispose.family<CustomerBookingItem?, String>((ref, bookingId) async {
  final repo = ref.watch(myBookingsRepositoryProvider);
  final item = await repo.getEnrichedBookingById(bookingId);
  if (item != null) return item;

  // Fallback to bookingWithDetailsProvider if needed
  final fallbackBooking = await ref.watch(bookingWithDetailsProvider(bookingId).future);
  if (fallbackBooking != null) {
    return CustomerBookingItem(
      booking: fallbackBooking.booking,
      car: fallbackBooking.car,
      vendor: fallbackBooking.vendor,
      paymentStatus: fallbackBooking.booking.status == 'pending' ? 'PENDING' : 'PAID',
    );
  }
  return null;
});

final bookingSecurityDepositProvider =
    FutureProvider.autoDispose.family<SecurityDepositModel?, String>((ref, bookingId) async {
  try {
    final client = ref.watch(apiClientProvider);
    final response = await client.dio.get('/bookings/$bookingId/deposit');
    if (response.data != null && response.data is Map<String, dynamic>) {
      return SecurityDepositModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return null;
  }
});

final bookingInspectionsProvider =
    FutureProvider.autoDispose.family<List<InspectionModel>, String>((ref, bookingId) async {
  final repo = ref.watch(myBookingsRepositoryProvider);
  return repo.getInspections(bookingId);
});

final activeOngoingTripProvider = Provider.autoDispose<CustomerBookingItem?>((ref) {
  final listAsync = ref.watch(myBookingsListProvider);
  return listAsync.maybeWhen(
    data: (items) {
      final now = DateTime.now();
      try {
        return items.firstWhere((item) {
          final b = item.booking;
          final status = b.status.toLowerCase();
          return status == 'ongoing' ||
              status == 'return_pending' ||
              (status == 'handover_ready' && b.startDate.isBefore(now)) ||
              (status == 'confirmed' && b.startDate.isBefore(now) && b.endDate.isAfter(now));
        });
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
});

final myBookingsListProvider = AutoDisposeAsyncNotifierProvider<MyBookingsListNotifier, List<CustomerBookingItem>>(() {
  return MyBookingsListNotifier();
});

class MyBookingsListNotifier extends AutoDisposeAsyncNotifier<List<CustomerBookingItem>> {
  @override
  Future<List<CustomerBookingItem>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated || session.user == null) {
      return [];
    }

    final repo = ref.watch(myBookingsRepositoryProvider);
    final allBookings = await repo.getEnrichedBookingsForUser(session.user!.id);
    final tabIndex = ref.watch(myBookingsTabProvider);
    final now = DateTime.now();

    switch (tabIndex) {
      case 0: // Upcoming: pending, confirmed, handover_ready with future start
        return bookingsSorted(allBookings.where((item) {
          final b = item.booking;
          final status = b.status.toLowerCase();
          final isUpcoming = status == 'confirmed' || status == 'pending' || status == 'handover_ready';
          return isUpcoming && b.endDate.isAfter(now) && (status == 'pending' || b.startDate.isAfter(now));
        }).toList());
      case 1: // Ongoing: ongoing, return_pending, or active date window
        return bookingsSorted(allBookings.where((item) {
          final b = item.booking;
          final status = b.status.toLowerCase();
          return status == 'ongoing' ||
              status == 'return_pending' ||
              (status == 'handover_ready' && b.startDate.isBefore(now)) ||
              (status == 'confirmed' && b.startDate.isBefore(now) && b.endDate.isAfter(now));
        }).toList());
      case 2: // Completed: completed status, or past end date
        return bookingsSorted(allBookings.where((item) {
          final b = item.booking;
          final status = b.status.toLowerCase();
          return status == 'completed' || (status == 'confirmed' && b.endDate.isBefore(now));
        }).toList());
      case 3: // Cancelled: cancelled, refund_pending, refunded, disputed, expired
        return bookingsSorted(allBookings.where((item) {
          final status = item.booking.status.toLowerCase();
          return status == 'cancelled' ||
              status == 'refund_pending' ||
              status == 'refunded' ||
              status == 'disputed' ||
              status == 'expired';
        }).toList());
      default:
        return [];
    }
  }

  List<CustomerBookingItem> bookingsSorted(List<CustomerBookingItem> items) {
    items.sort((a, b) => b.booking.startDate.compareTo(a.booking.startDate));
    return items;
  }

  Future<void> cancel(String bookingId, String reason) async {
    final repo = ref.read(myBookingsRepositoryProvider);
    await repo.cancelBooking(bookingId, reason);
    ref.invalidateSelf();
    await future;
  }

  Future<void> submitBookingReview({
    required String bookingId,
    required String customerId,
    required String vendorId,
    required double rating,
    required String comment,
  }) async {
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
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
