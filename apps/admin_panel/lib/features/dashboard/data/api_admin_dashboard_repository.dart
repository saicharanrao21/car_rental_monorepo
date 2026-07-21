import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/admin_dashboard_repository.dart';

class ApiAdminDashboardRepository implements AdminDashboardRepository {
  final ApiClient apiClient;

  ApiAdminDashboardRepository({required this.apiClient});

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
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
    return copy;
  }

  @override
  Future<AdminKpis> getKpis() async {
    final res = await apiClient.dio.get('/admin/dashboard/kpis');
    final data = res.data;
    return AdminKpis(
      totalUsers: data['totalUsers'] as int? ?? 0,
      totalVendors: data['totalVendors'] as int? ?? 0,
      activeBookings: data['activeBookings'] as int? ?? 0,
      todaysRevenue: _toDouble(data['todaysRevenue']),
    );
  }

  @override
  Future<List<int>> getBookingsPerDay({int days = 30}) async {
    final res = await apiClient.dio.get('/admin/dashboard/bookings-per-day', queryParameters: {'days': days});
    final List list = res.data as List;
    return list.map((item) => (item['count'] as num?)?.toInt() ?? 0).toList();
  }

  @override
  Future<Map<String, double>> getRevenuePerCity() async {
    final res = await apiClient.dio.get('/admin/dashboard/revenue-per-city');
    final List list = res.data as List;
    final Map<String, double> map = {};
    for (final item in list) {
      final city = item['city']?.toString() ?? 'Other';
      final rev = _toDouble(item['revenue']);
      map[city] = rev;
    }
    return map;
  }

  @override
  Future<List<BookingModel>> getRecentBookings({int limit = 10}) async {
    final res = await apiClient.dio.get('/admin/dashboard/recent-bookings', queryParameters: {'limit': limit});
    final List list = res.data as List;
    return list.map((item) => BookingModel.fromJson(_normalizeBookingJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<List<VendorModel>> getPendingVendorApprovals() async {
    final res = await apiClient.dio.get('/admin/dashboard/pending-approvals');
    final List list = res.data as List;
    return list.map((item) => VendorModel.fromJson(_normalizeVendorJson(item as Map<String, dynamic>))).toList();
  }

  @override
  Future<List<VendorModel>> getTopVendorsByBookings({int limit = 5}) async {
    final res = await apiClient.dio.get('/admin/dashboard/top-vendors', queryParameters: {'limit': limit});
    final List list = res.data as List;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return VendorModel(
        id: map['vendorId']?.toString() ?? '',
        businessName: map['businessName']?.toString() ?? '',
        ownerName: map['ownerName']?.toString() ?? '',
        city: 'Active Fleet',
        verificationStatus: 'VERIFIED',
      );
    }).toList();
  }

  @override
  Future<void> setVendorApprovalStatus(String vendorId, String status) async {
    await apiClient.dio.patch('/vendors/$vendorId/status', data: {
      'status': status.toUpperCase(),
    });
  }
}
