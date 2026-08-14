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
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {
    await apiClient.dio.patch(
      '/bookings/$bookingId/status',
      data: {
        'status': newStatus.toUpperCase(),
        if (handoverOtp != null && handoverOtp.isNotEmpty) 'handoverOtp': handoverOtp,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
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

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async {
    final response = await apiClient.dio.get('/bookings/$bookingId/inspections');
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) => InspectionModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<InspectionModel> upsertInspection(
    String bookingId, {
    required String type,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool finalize = true,
  }) async {
    final response = await apiClient.dio.post(
      '/bookings/$bookingId/inspections',
      data: {
        'type': type.toUpperCase(),
        'odometer': odometer,
        'fuelPercent': fuelPercent,
        if (conditionNotes != null && conditionNotes.isNotEmpty) 'conditionNotes': conditionNotes,
        if (damagePhotos != null) 'damagePhotos': damagePhotos,
        'finalize': finalize,
      },
    );
    final data = response.data is Map<String, dynamic> ? response.data : (response.data['data'] ?? response.data);
    return InspectionModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> sendHandoverOtp(String bookingId, String otpType) async {
    await apiClient.dio.post(
      '/bookings/$bookingId/handover-otp/send',
      data: {
        'otpType': otpType.toUpperCase(),
      },
    );
  }

  @override
  Future<List<DamageClaimModel>> getDamageClaims(String bookingId) async {
    final response = await apiClient.dio.get('/bookings/$bookingId/damage-claims');
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) => DamageClaimModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<DamageClaimModel> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  }) async {
    final response = await apiClient.dio.post(
      '/bookings/$bookingId/damage-claims',
      data: {
        'claimedAmount': claimedAmount,
        'description': description,
        'damagePhotos': damagePhotos,
        if (vendorNotes != null && vendorNotes.isNotEmpty) 'vendorNotes': vendorNotes,
      },
    );
    final data = response.data is Map<String, dynamic> ? response.data : (response.data['data'] ?? response.data);
    return DamageClaimModel.fromJson(Map<String, dynamic>.from(data));
  }
}
