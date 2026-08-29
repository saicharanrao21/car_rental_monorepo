import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import '../domain/repositories/dashboard_repository.dart';

class ApiDashboardRepository implements DashboardRepository {
  final ApiClient apiClient;

  ApiDashboardRepository({required this.apiClient});

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

    // Convert decimal-as-string fields to double for models that expect double
    for (final field in ['totalFare', 'platformFee', 'gstAmount', 'netToVendor']) {
      if (copy[field] != null) {
        copy[field] = double.tryParse(copy[field].toString()) ?? 0.0;
      }
    }

    return copy;
  }

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    // Helper to perform individual requests with a 15s timeout and fallback to empty data on failure.
    // This prevents one slow or failing non-critical endpoint from blocking the entire dashboard.
    Future<Response> safeGet(String path, {dynamic fallbackData}) async {
      try {
        return await apiClient.dio
            .get(path)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        // Log locally for debugging but fail gracefully by returning the fallback data
        debugPrint('Dashboard API partial failure: $path -> $e');
        return Response(
          requestOptions: RequestOptions(path: path),
          data: fallbackData,
          statusCode: 500,
        );
      }
    }

    final responses = await Future.wait([
      safeGet('/vendors/me/bookings', fallbackData: []),
      safeGet('/vendors/me/cars', fallbackData: []),
      safeGet('/vendors/me/earnings/summary', fallbackData: {}),
    ]);

    final bookingsResponse = responses[0];
    final carsResponse = responses[1];
    final earningsResponse = responses[2];

    // 1. Bookings calculation
    final List<dynamic> bookingsData = bookingsResponse.data is List ? bookingsResponse.data : (bookingsResponse.data['data'] ?? []);
    final referenceToday = DateTime.now();
    int todaysBookings = 0;
    int pendingRequests = 0;

    for (final b in bookingsData) {
      final status = (b['status'] as String?)?.toLowerCase();
      final startDateStr = b['startDate'] as String?;
      if (startDateStr != null) {
        final startDate = DateTime.parse(startDateStr);
        final isSameDay = startDate.year == referenceToday.year &&
            startDate.month == referenceToday.month &&
            startDate.day == referenceToday.day;
        final isOngoingOrConfirmed = status == 'ongoing' || status == 'confirmed';
        if (isSameDay && isOngoingOrConfirmed) {
          todaysBookings++;
        }
      }
      if (status == 'pending') {
        pendingRequests++;
      }
    }

    // 2. Cars calculation
    final List<dynamic> carsData = carsResponse.data is List ? carsResponse.data : (carsResponse.data['data'] ?? []);
    int activeCars = 0;
    int inactiveCars = 0;
    for (final c in carsData) {
      final isAvailable = c['isAvailable'] as bool? ?? false;
      if (isAvailable) {
        activeCars++;
      } else {
        inactiveCars++;
      }
    }

    // 3. Earnings calculation
    final earningsData = earningsResponse.data;
    final thisMonthEarnings = double.tryParse(earningsData['thisMonthEarnings']?.toString() ?? '0.0') ?? 0.0;

    return DashboardStats(
      todaysBookings: todaysBookings,
      pendingRequests: pendingRequests,
      thisMonthEarnings: thisMonthEarnings,
      activeCars: activeCars,
      inactiveCars: inactiveCars,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async {
    final response = await apiClient.dio.get(
      '/vendors/me/bookings',
      queryParameters: {
        'status': 'PENDING',
      },
    );
    final List<dynamic> bookingsData = response.data is List ? response.data : (response.data['data'] ?? []);
    final bookings = bookingsData.map((b) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(b));
      return BookingModel.fromJson(normalized);
    }).toList();

    // Sort by createdAt descending
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings.take(limit).toList();
  }

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {
    await apiClient.dio.patch(
      '/bookings/$bookingId/status',
      data: {
        'status': accept ? 'CONFIRMED' : 'CANCELLED',
      },
    );
  }
}
