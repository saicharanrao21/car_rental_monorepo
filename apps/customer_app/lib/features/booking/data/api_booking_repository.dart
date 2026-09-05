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

    final data = <String, dynamic>{
      'carId': draft.carId,
      'tripType': _mapTripTypeToBackend(draft.tripType),
      'pickupLocation': draft.pickupLocation.isEmpty ? 'Mumbai' : draft.pickupLocation,
      if (draft.dropLocation != null && draft.dropLocation!.isNotEmpty)
        'dropLocation': draft.dropLocation,
      'startDate': draft.startDate.toUtc().toIso8601String(),
      'endDate': draft.endDate.toUtc().toIso8601String(),
      'distanceKm': distanceKm,
    };

    // Forward complete structured fulfillment fields
    final pickupHubId = draft.pickupHubId ?? draftState?.pickupHubId;
    if (pickupHubId != null && pickupHubId.isNotEmpty) {
      data['pickupHubId'] = pickupHubId;
    }
    final returnHubId = draft.returnHubId ?? draftState?.returnHubId;
    if (returnHubId != null && returnHubId.isNotEmpty) {
      data['returnHubId'] = returnHubId;
    }
    final pickupName = draft.pickupName ?? draftState?.pickupName;
    if (pickupName != null && pickupName.isNotEmpty) {
      data['pickupName'] = pickupName;
    }
    final dropName = draft.dropName ?? draftState?.dropName;
    if (dropName != null && dropName.isNotEmpty) {
      data['dropName'] = dropName;
    }
    final pickupAddress = draft.pickupAddress ?? draftState?.pickupAddress;
    if (pickupAddress != null && pickupAddress.isNotEmpty) {
      data['pickupAddress'] = pickupAddress;
    }
    final deliveryAddress = draft.deliveryAddress ?? draftState?.deliveryAddress;
    if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
      data['deliveryAddress'] = deliveryAddress;
    }
    final deliveryType = draft.deliveryType ?? draftState?.deliveryType;
    if (deliveryType != null && deliveryType.isNotEmpty) {
      data['deliveryType'] = deliveryType;
    }
    final deliveryFee = draft.deliveryFee ?? draftState?.deliveryFee;
    if (deliveryFee != null && deliveryFee > 0) {
      data['deliveryFee'] = deliveryFee;
    }
    final pickupFee = draft.pickupFee ?? draftState?.pickupFee;
    if (pickupFee != null && pickupFee > 0) {
      data['pickupFee'] = pickupFee;
    }
    final returnFee = draft.returnFee ?? draftState?.returnFee;
    if (returnFee != null && returnFee > 0) {
      data['returnFee'] = returnFee;
    }
    final oneWayFee = draft.oneWayFee ?? draftState?.oneWayFee;
    if (oneWayFee != null && oneWayFee > 0) {
      data['oneWayFee'] = oneWayFee;
    }
    final delLat = draft.deliveryLatitude ?? draftState?.deliveryLatitude;
    if (delLat != null) data['deliveryLatitude'] = delLat;
    final delLng = draft.deliveryLongitude ?? draftState?.deliveryLongitude;
    if (delLng != null) data['deliveryLongitude'] = delLng;
    final pickLat = draft.pickupLatitude ?? draftState?.pickupLatitude;
    if (pickLat != null) data['pickupLatitude'] = pickLat;
    final pickLng = draft.pickupLongitude ?? draftState?.pickupLongitude;
    if (pickLng != null) data['pickupLongitude'] = pickLng;

    if (draftState != null) {
      if (draftState.appliedCouponCode != null && draftState.appliedCouponCode!.isNotEmpty) {
        data['couponCode'] = draftState.appliedCouponCode;
      }
      if (draftState.selectedProtectionPackageId != null &&
          draftState.selectedProtectionPackageId!.isNotEmpty) {
        data['protectionPackageId'] = draftState.selectedProtectionPackageId;
      }
      if (draftState.selectedMileagePackageId != null &&
          draftState.selectedMileagePackageId!.isNotEmpty) {
        data['mileagePackageId'] = draftState.selectedMileagePackageId;
      }
    }

    final response = await apiClient.dio.post(
      '/bookings',
      data: data,
    );

    final normalized = _normalizeBookingJson(response.data);
    return BookingModel.fromJson(normalized);
  }

  @override
  Future<CouponValidationResultModel> validateCoupon({
    required String code,
    String? carId,
    double? subtotal,
    String? city,
    String? tripType,
    String? carCategory,
  }) async {
    final data = <String, dynamic>{
      'code': code,
      if (carId != null) 'carId': carId,
      if (subtotal != null) 'subtotal': subtotal,
      if (city != null) 'city': city,
      if (tripType != null) 'tripType': _mapTripTypeToBackend(tripType),
      if (carCategory != null) 'carCategory': carCategory,
    };

    final response = await apiClient.dio.post(
      '/coupons/validate',
      data: data,
    );

    final resData = response.data;
    if (resData is Map<String, dynamic>) {
      if (resData.containsKey('valid')) {
        return CouponValidationResultModel.fromJson(resData);
      } else if (resData.containsKey('data') && resData['data'] is Map<String, dynamic>) {
        return CouponValidationResultModel.fromJson(resData['data']);
      }
    }
    throw Exception('Invalid coupon response from server');
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
  Future<BookingModel> getBookingById(String id) async {
    final response = await apiClient.dio.get('/bookings/$id');
    final normalized = _normalizeBookingJson(response.data);
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
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/locations/quote',
        data: {
          'vendorId': vendorId,
          if (pickupLocationId != null && pickupLocationId.isNotEmpty)
            'pickupLocationId': pickupLocationId,
          if (returnLocationId != null && returnLocationId.isNotEmpty)
            'returnLocationId': returnLocationId,
          if (customerLatitude != null) 'customerLatitude': customerLatitude,
          if (customerLongitude != null) 'customerLongitude': customerLongitude,
          if (deliveryAddress != null && deliveryAddress.isNotEmpty)
            'deliveryAddress': deliveryAddress,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return {
          'isAvailable': data['isAvailable'] ?? true,
          'distanceKm': (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
          'deliveryFee': (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
          'pickupFee': (data['pickupFee'] as num?)?.toDouble() ?? 0.0,
          'returnFee': (data['returnFee'] as num?)?.toDouble() ?? 0.0,
          'oneWayFee': ((data['oneWaySurcharge'] ?? data['oneWayFee']) as num?)?.toDouble() ?? 0.0,
          'totalFulfillmentFee': (data['totalFulfillmentFee'] as num?)?.toDouble() ?? 0.0,
          'reason': data['reason']?.toString(),
          'pricingModel': data['pricingModel']?.toString(),
          'maxDeliveryRadiusKm': (data['maxDeliveryRadiusKm'] as num?)?.toDouble(),
        };
      }
    } catch (err) {
      return {
        'isAvailable': false,
        'distanceKm': 0.0,
        'deliveryFee': 0.0,
        'pickupFee': 0.0,
        'returnFee': 0.0,
        'oneWayFee': 0.0,
        'totalFulfillmentFee': 0.0,
        'reason': err.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', ''),
      };
    }
    return {
      'isAvailable': true,
      'distanceKm': 0.0,
      'deliveryFee': 0.0,
      'pickupFee': 0.0,
      'returnFee': 0.0,
      'oneWayFee': 0.0,
      'totalFulfillmentFee': 0.0,
    };
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

  @override
  Future<VehicleAvailabilityResult> checkVehicleAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? hubId,
  }) async {
    final queryParams = {
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      if (hubId != null) 'hubId': hubId,
    };
    final response = await apiClient.dio.get('/cars/$carId/availability', queryParameters: queryParams);
    return VehicleAvailabilityResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<VehicleHoldModel> createVehicleHold({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    int ttlSeconds = 900,
    String? idempotencyKey,
  }) async {
    final data = {
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'ttlSeconds': ttlSeconds,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
    final response = await apiClient.dio.post('/cars/$carId/holds', data: data);
    return VehicleHoldModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> releaseVehicleHold(String holdId) async {
    final response = await apiClient.dio.delete('/cars/holds/$holdId');
    return response.data?['success'] == true;
  }
}
