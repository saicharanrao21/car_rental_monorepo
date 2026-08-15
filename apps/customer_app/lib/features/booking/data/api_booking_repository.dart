import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/booking_repository.dart';
import '../presentation/providers/booking_flow_providers.dart';

class ApiBookingRepository implements BookingRepository {
  final ApiClient apiClient;
  final Ref? ref;

  ApiBookingRepository({required this.apiClient, this.ref});

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

    // Ensure required string fields are never null
    copy['pickupLocation'] ??= 'Location not specified';
    copy['tripType'] ??= 'Local';
    copy['status'] ??= 'pending';

    // Parse decimal/numeric values to double with 0.0 fallback
    for (final field in ['totalFare', 'platformFee', 'gstAmount', 'netToVendor']) {
      copy[field] = double.tryParse(copy[field]?.toString() ?? '') ?? 0.0;
    }

    return copy;
  }

  String _mapTripTypeToBackend(String clientTripType) {
    switch (clientTripType) {
      case 'Local':
      case 'LOCAL':
        return 'LOCAL';
      case 'Outstation':
      case 'OUTSTATION':
        return 'OUTSTATION';
      case 'Airport':
      case 'Airport Transfer':
      case 'AIRPORT_TRANSFER':
        return 'AIRPORT_TRANSFER';
      case 'Self-Drive':
      case 'SELF_DRIVE':
        return 'SELF_DRIVE';
      default:
        return 'SELF_DRIVE';
    }
  }

  @override
  Future<BookingModel> createBooking(BookingModel draft) async {
    final draftState = ref?.read(bookingDraftProvider);
    final distanceKm = draftState?.estimatedDistanceKm ?? 50;

    final response = await apiClient.dio.post(
      '/bookings',
      data: {
        'carId': draft.carId,
        'tripType': _mapTripTypeToBackend(draft.tripType),
        'pickupLocation': draft.pickupLocation,
        'dropLocation': draft.dropLocation,
        'startDate': draft.startDate.toUtc().toIso8601String(),
        'endDate': draft.endDate.toUtc().toIso8601String(),
        'distanceKm': distanceKm,
      },
    );

    final normalized = _normalizeBookingJson(response.data);
    return BookingModel.fromJson(normalized);
  }

  @override
  Future<List<BookingModel>> getBookingsForCustomer(String customerId) async {
    final response = await apiClient.dio.get('/bookings/me');
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(json));
      return BookingModel.fromJson(normalized);
    }).toList();
  }

  @override
  Future<BookingModel?> getBookingById(String bookingId) async {
    final response = await apiClient.dio.get('/bookings/$bookingId');
    if (response.data == null) return null;
    final normalized = _normalizeBookingJson(Map<String, dynamic>.from(response.data));
    return BookingModel.fromJson(normalized);
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    final response = await apiClient.dio.post(
      '/bookings/$bookingId/cancel',
      data: {'reason': 'Cancelled by customer'},
    );
    final normalized = _normalizeBookingJson(Map<String, dynamic>.from(response.data));
    return BookingModel.fromJson(normalized);
  }

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) {
    return CommissionConfigModel(
      id: 'default',
      tripType: 'All',
      city: 'All',
      carCategory: 'All',
      percentage: 10.0,
      effectiveFrom: DateTime(2026, 1, 1),
    );
  }
}
