import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_booking_repository.dart';

class ApiAdminBookingRepository implements AdminBookingRepository {
  final ApiClient apiClient;

  ApiAdminBookingRepository({required this.apiClient});

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Map<String, dynamic> _normalizeBookingJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in [
      'baseFare',
      'platformFee',
      'gstAmount',
      'totalFare',
      'netToVendor',
      'distanceKm',
      'deliveryFee',
      'pickupFee',
      'returnFee',
      'oneWayFee',
      'deliveryLatitude',
      'deliveryLongitude',
      'pickupLatitude',
      'pickupLongitude',
    ]) {
      if (copy[field] != null) {
        copy[field] = _toDouble(copy[field]);
      }
    }
    if (copy['status'] != null) {
      copy['status'] = copy['status'].toString().toLowerCase();
    }
    if (copy['tripType'] != null) {
      copy['tripType'] = copy['tripType'].toString().toLowerCase();
    }
    return copy;
  }

  Map<String, dynamic> _normalizeCarJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in ['pricePerKm', 'pricePerDay', 'pricePerHour', 'rating']) {
      if (copy[field] != null) {
        copy[field] = _toDouble(copy[field]);
      } else if (field == 'rating') {
        copy[field] = 5.0;
      }
    }
    return copy;
  }

  Map<String, dynamic> _normalizeVendorJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['rating'] != null) {
      copy['rating'] = _toDouble(copy['rating']);
    } else {
      copy['rating'] = 5.0;
    }
    return copy;
  }

  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['banned'] == null && copy['isBanned'] != null) {
      copy['banned'] = copy['isBanned'];
    }
    return copy;
  }

  @override
  Future<List<BookingModel>> getBookings({
    String? city,
    DateTimeRange? dateRange,
    String? tripType,
    String? status,
    String? vendorId,
    String? carType,
  }) async {
    final queryParams = <String, dynamic>{};
    if (city != null && city.isNotEmpty) queryParams['city'] = city;
    if (dateRange != null) {
      queryParams['startDate'] = dateRange.start.toIso8601String();
      queryParams['endDate'] = dateRange.end.toIso8601String();
    }
    if (tripType != null && tripType.isNotEmpty) queryParams['tripType'] = tripType.toUpperCase();
    if (status != null && status.isNotEmpty) queryParams['status'] = status.toUpperCase();
    if (vendorId != null && vendorId.isNotEmpty) queryParams['vendorId'] = vendorId;
    if (carType != null && carType.isNotEmpty) queryParams['carType'] = carType.toUpperCase();

    final res = await apiClient.dio.get('/admin/bookings', queryParameters: queryParams);
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);

    return list.map((item) => BookingModel.fromJson(_normalizeBookingJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<BookingDetailBundle> getBookingDetail(String bookingId) async {
    final res = await apiClient.dio.get('/bookings/$bookingId');
    final raw = res.data as Map<String, dynamic>;

    final booking = BookingModel.fromJson(_normalizeBookingJson(raw));

    final carJson = raw['car'] is Map ? raw['car'] as Map<String, dynamic> : <String, dynamic>{'id': booking.carId};
    final car = CarModel.fromJson(_normalizeCarJson(carJson));

    final vendorJson = raw['vendor'] is Map ? raw['vendor'] as Map<String, dynamic> : <String, dynamic>{'id': booking.vendorId};
    final vendor = VendorModel.fromJson(_normalizeVendorJson(vendorJson));

    final customerJson = raw['customer'] is Map ? raw['customer'] as Map<String, dynamic> : <String, dynamic>{'id': booking.customerId};
    final customer = UserModel.fromJson(_normalizeUserJson(customerJson));

    return BookingDetailBundle(
      booking: booking,
      car: car,
      vendor: vendor,
      customer: customer,
    );
  }

  @override
  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {
    await apiClient.dio.patch('/admin/bookings/$bookingId/override-status', data: {
      'status': newStatus.toUpperCase(),
    });
  }

  @override
  Future<void> flagBookingDispute(String bookingId, String note) async {
    if (note.trim().isEmpty) {
      await apiClient.dio.post('/admin/bookings/$bookingId/resolve-dispute');
    } else {
      await apiClient.dio.post('/admin/bookings/$bookingId/flag-dispute', data: {
        'note': note.trim(),
      });
    }
  }
}
