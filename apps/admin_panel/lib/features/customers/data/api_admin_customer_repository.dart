import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_customer_repository.dart';

class ApiAdminCustomerRepository implements AdminCustomerRepository {
  final ApiClient apiClient;

  ApiAdminCustomerRepository({required this.apiClient});

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['banned'] == null && copy['isBanned'] != null) {
      copy['banned'] = copy['isBanned'];
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
  Future<List<UserModel>> getCustomers({String? searchQuery}) async {
    final queryParams = <String, dynamic>{};
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }
    final res = await apiClient.dio.get('/users', queryParameters: queryParams);
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.map((item) => UserModel.fromJson(_normalizeUserJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<UserModel> getCustomerById(String id) async {
    final res = await apiClient.dio.get('/users/$id');
    return UserModel.fromJson(_normalizeUserJson(res.data as Map<String, dynamic>));
  }

  @override
  Future<List<BookingModel>> getBookingHistoryForCustomer(String id) async {
    final res = await apiClient.dio.get('/users/$id/bookings');
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.map((item) => BookingModel.fromJson(_normalizeBookingJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<void> setCustomerBanned(String id, bool banned) async {
    await apiClient.dio.patch('/users/$id/ban', data: {
      'banned': banned,
    });
  }
}
