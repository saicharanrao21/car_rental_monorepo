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

  CustomerBookingItem _parseCustomerBookingItem(Map<String, dynamic> rawJson) {
    final normalized = _normalizeBookingJson(rawJson);
    final booking = BookingModel.fromJson(normalized);

    CarModel? car;
    if (rawJson['car'] is Map<String, dynamic>) {
      try {
        final carJson = Map<String, dynamic>.from(rawJson['car']);
        // Normalize car pricePerDay & specs
        carJson['pricePerDay'] = double.tryParse(carJson['pricePerDay']?.toString() ?? '') ?? 0.0;
        carJson['depositAmount'] = double.tryParse(carJson['depositAmount']?.toString() ?? '') ?? 0.0;
        car = CarModel.fromJson(carJson);
      } catch (_) {}
    }

    VendorModel? vendor;
    if (rawJson['vendor'] is Map<String, dynamic>) {
      try {
        final vendorJson = Map<String, dynamic>.from(rawJson['vendor']);
        vendorJson['rating'] = double.tryParse(vendorJson['rating']?.toString() ?? '') ?? 0.0;
        vendor = VendorModel.fromJson(vendorJson);
      } catch (_) {}
    }

    return CustomerBookingItem(
      booking: booking,
      car: car,
      vendor: vendor,
      mileagePackageName: rawJson['mileagePackageName'] as String?,
      includedKmPerDay: (rawJson['includedKmPerDay'] as num?)?.toInt(),
      includedKmTotal: (rawJson['includedKmTotal'] as num?)?.toInt(),
      extraKmRate: double.tryParse(rawJson['extraKmRate']?.toString() ?? ''),
      protectionCode: rawJson['protectionCode'] as String?,
      protectionFee: double.tryParse(rawJson['protectionFee']?.toString() ?? ''),
      protectionDeductible: double.tryParse(rawJson['protectionDeductible']?.toString() ?? ''),
      deliveryType: rawJson['deliveryType'] as String?,
      deliveryAddress: rawJson['deliveryAddress'] as String?,
      deliveryFee: double.tryParse(rawJson['deliveryFee']?.toString() ?? ''),
      pickupAddress: rawJson['pickupAddress'] as String?,
      pickupFee: double.tryParse(rawJson['pickupFee']?.toString() ?? ''),
      cancellationReason: rawJson['cancellationReason'] as String?,
      cancellationFee: double.tryParse(rawJson['cancellationFee']?.toString() ?? ''),
      refundAmount: double.tryParse(rawJson['refundAmount']?.toString() ?? ''),
      cancelledAt: rawJson['cancelledAt'] != null ? DateTime.tryParse(rawJson['cancelledAt'].toString()) : null,
      cancelledBy: rawJson['cancelledBy'] as String?,
      paymentStatus: rawJson['payment'] is Map ? rawJson['payment']['status']?.toString() : null,
      razorpayOrderId: rawJson['payment'] is Map ? rawJson['payment']['razorpayOrderId']?.toString() : null,
      razorpayPaymentId: rawJson['payment'] is Map ? rawJson['payment']['razorpayPaymentId']?.toString() : null,
      razorpayRefundId: rawJson['payment'] is Map ? rawJson['payment']['razorpayRefundId']?.toString() : null,
    );
  }

  String? _mapStatusToBackend(String? clientStatus) {
    if (clientStatus == null) return null;
    return clientStatus.toUpperCase();
  }

  @override
  Future<List<CustomerBookingItem>> getEnrichedBookingsForUser(String userId, {String? statusFilter}) async {
    final backendStatus = _mapStatusToBackend(statusFilter);
    final response = await apiClient.dio.get(
      '/bookings/me',
      queryParameters: {
        if (backendStatus != null) 'status': backendStatus,
      },
    );
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) => _parseCustomerBookingItem(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter}) async {
    final items = await getEnrichedBookingsForUser(userId, statusFilter: statusFilter);
    return items.map((e) => e.booking).toList();
  }

  @override
  Future<CustomerBookingItem?> getEnrichedBookingById(String bookingId) async {
    try {
      final response = await apiClient.dio.get('/bookings/$bookingId');
      if (response.data == null) return null;
      return _parseCustomerBookingItem(Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CancellationPreviewModel> getCancellationPreview(String bookingId) async {
    final response = await apiClient.dio.get('/bookings/$bookingId/cancellation-preview');
    return CancellationPreviewModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    await apiClient.dio.post(
      '/bookings/$bookingId/cancel',
      data: {'reason': reason},
    );
  }

  @override
  Future<TripExtensionQuoteModel> getTripExtensionQuote(String bookingId, String requestedEndDate) async {
    final response = await apiClient.dio.post(
      '/bookings/$bookingId/extensions/quote',
      data: {'requestedEndDate': requestedEndDate},
    );
    return TripExtensionQuoteModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<void> requestTripExtension(String bookingId, String requestedEndDate) async {
    await apiClient.dio.post(
      '/bookings/$bookingId/extensions',
      data: {'requestedEndDate': requestedEndDate},
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

  @override
  Future<SecurityDepositModel?> getSecurityDeposit(String bookingId) async {
    try {
      final response = await apiClient.dio.get('/deposits/$bookingId');
      if (response.data == null) return null;
      return SecurityDepositModel.fromJson(Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PaymentOrderModel?> getPaymentForBooking(String bookingId) async {
    try {
      final response = await apiClient.dio.get('/payments/$bookingId');
      if (response.data == null) return null;
      return PaymentOrderModel.fromJson(Map<String, dynamic>.from(response.data));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async {
    try {
      final response = await apiClient.dio.get('/bookings/$bookingId/inspections');
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
      return data.map((item) => InspectionModel.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> sendHandoverOtp(String bookingId, String otpType) async {
    try {
      final response = await apiClient.dio.post(
        '/bookings/$bookingId/handover-otp/send',
        data: {'otpType': otpType},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
