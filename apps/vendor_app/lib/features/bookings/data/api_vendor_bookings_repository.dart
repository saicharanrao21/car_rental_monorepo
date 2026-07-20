import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/vendor_bookings_repository.dart';

class ApiVendorBookingsRepository implements VendorBookingsRepository {
  final ApiClient apiClient;

  ApiVendorBookingsRepository({required this.apiClient});

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

  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    final response = await apiClient.dio.get(
      '/vendors/me/bookings',
      queryParameters: {
        if (statusFilter != null) 'status': statusFilter.toUpperCase(),
      },
    );
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(json));
      return BookingModel.fromJson(normalized);
    }).toList();
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    await apiClient.dio.patch(
      '/bookings/$bookingId/status',
      data: {
        'status': newStatus.toUpperCase(),
      },
    );
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    await apiClient.dio.patch(
      '/bookings/$bookingId/status',
      data: {
        'status': 'CANCELLED',
      },
      queryParameters: {
        'reason': reason,
      },
    );
  }
}
