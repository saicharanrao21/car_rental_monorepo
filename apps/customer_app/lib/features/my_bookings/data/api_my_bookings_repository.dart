import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/my_bookings_repository.dart';

class ApiMyBookingsRepository implements MyBookingsRepository {
  final ApiClient apiClient;

  ApiMyBookingsRepository({required this.apiClient});

  Map<String, dynamic> _normalizeBookingJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    // Normalize tripType from backend uppercase to client standard
    final rawTripType = copy['tripType'] as String?;
    if (rawTripType != null) {
      if (rawTripType == 'LOCAL') {
        copy['tripType'] = 'Local';
      } else if (rawTripType == 'OUTSTATION') {
        copy['tripType'] = 'Outstation';
      } else if (rawTripType == 'AIRPORT_TRANSFER') {
        copy['tripType'] = 'Airport Transfer';
      } else if (rawTripType == 'SELF_DRIVE') {
        copy['tripType'] = 'Self-Drive';
      }
    }

    // Normalize status to lowercase
    final rawStatus = copy['status'] as String?;
    if (rawStatus != null) {
      copy['status'] = rawStatus.toLowerCase();
    }

    // Parse decimal/numeric values to double
    for (final field in ['totalFare', 'platformFee', 'gstAmount', 'netToVendor']) {
      if (copy[field] != null) {
        copy[field] = double.tryParse(copy[field].toString()) ?? 0.0;
      }
    }

    return copy;
  }

  String? _mapStatusToBackend(String? clientStatus) {
    if (clientStatus == null) return null;
    return clientStatus.toUpperCase();
  }

  @override
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter}) async {
    final backendStatus = _mapStatusToBackend(statusFilter);
    final response = await apiClient.dio.get(
      '/bookings/me',
      queryParameters: {
        if (backendStatus != null) 'status': backendStatus,
      },
    );
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(json));
      return BookingModel.fromJson(normalized);
    }).toList();
  }

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    await apiClient.dio.post(
      '/bookings/$bookingId/cancel',
      data: {'reason': reason},
    );
  }

  @override
  Future<void> submitReview(ReviewModel review) async {
    await apiClient.dio.post(
      '/reviews',
      data: {
        'bookingId': review.bookingId,
        'rating': review.rating.toInt(),
        'comment': review.comment,
      },
    );
  }
}
