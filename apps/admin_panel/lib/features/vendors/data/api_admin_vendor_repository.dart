import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_vendor_repository.dart';

class ApiAdminVendorRepository implements AdminVendorRepository {
  final ApiClient apiClient;

  ApiAdminVendorRepository({required this.apiClient});

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Map<String, dynamic> _normalizeVendorJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['rating'] != null) {
      copy['rating'] = _toDouble(copy['rating']);
    } else {
      copy['rating'] = 5.0;
    }
    if (copy['user'] != null && copy['ownerName'] == null) {
      copy['ownerName'] = copy['user']['name'] ?? '';
    }
    if (copy['verificationStatus'] != null) {
      copy['verificationStatus'] = copy['verificationStatus'].toString().toUpperCase();
    }
    if (copy['parentVendor'] != null && copy['parentVendor'] is Map) {
      copy['parentBusinessName'] = copy['parentVendor']['businessName'];
    }
    if (copy['boostExpiresAt'] != null && copy['boostExpiresAt'] is String) {
      copy['boostExpiresAt'] = copy['boostExpiresAt'];
    }
    return copy;
  }

  Map<String, dynamic> _normalizeBookingJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in ['baseFare', 'platformFee', 'gstAmount', 'totalFare', 'netToVendor', 'distanceKm']) {
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

  @override
  Future<List<VendorModel>> getVendors({
    String? city,
    String? status,
    String? searchQuery,
  }) async {
    final queryParams = <String, dynamic>{};
    if (city != null && city.isNotEmpty) queryParams['city'] = city;
    if (status != null && status.isNotEmpty) queryParams['status'] = status.toUpperCase();
    if (searchQuery != null && searchQuery.isNotEmpty) queryParams['search'] = searchQuery;

    final res = await apiClient.dio.get('/vendors', queryParameters: queryParams);
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.map((item) => VendorModel.fromJson(_normalizeVendorJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<VendorModel> getVendorById(String id) async {
    final res = await apiClient.dio.get('/vendors/$id');
    return VendorModel.fromJson(_normalizeVendorJson(res.data as Map<String, dynamic>));
  }

  @override
  Future<int> getCarCountForVendor(String id) async {
    final res = await apiClient.dio.get('/vendors/$id/cars');
    final List list = res.data as List;
    return list.length;
  }

  @override
  Future<int> getBookingCountForVendor(String id) async {
    final res = await apiClient.dio.get('/admin/bookings', queryParameters: {'vendorId': id});
    final rawData = res.data;
    if (rawData is Map && rawData['total'] != null) {
      return rawData['total'] as int;
    }
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.length;
  }

  @override
  Future<List<BookingModel>> getBookingHistoryForVendor(String id) async {
    final res = await apiClient.dio.get('/admin/bookings', queryParameters: {'vendorId': id});
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.map((item) => BookingModel.fromJson(_normalizeBookingJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<void> setVendorStatus(String id, String status) async {
    await apiClient.dio.patch('/vendors/$id/status', data: {
      'status': status.toUpperCase(),
    });
  }

  @override
  Future<void> updateSponsorship(String vendorId, bool isSponsored, DateTime? boostExpiresAt) async {
    await apiClient.dio.patch('/admin/vendors/$vendorId/sponsorship', data: {
      'isSponsored': isSponsored,
      'boostExpiresAt': boostExpiresAt?.toIso8601String(),
    });
  }
}
