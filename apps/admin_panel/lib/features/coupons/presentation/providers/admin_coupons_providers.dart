import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import '../../../../core/providers/api_providers.dart';

final adminCouponsProvider =
    AsyncNotifierProvider<AdminCouponsNotifier, List<CouponModel>>(
        AdminCouponsNotifier.new);

class AdminCouponsNotifier extends AsyncNotifier<List<CouponModel>> {
  late final ApiClient _apiClient;

  @override
  Future<List<CouponModel>> build() async {
    _apiClient = ref.watch(apiClientProvider);
    return fetchCoupons();
  }

  Future<List<CouponModel>> fetchCoupons() async {
    final response = await _apiClient.dio.get('/admin/coupons');
    final List<dynamic> data =
        response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) => CouponModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  Future<void> createCoupon(Map<String, dynamic> couponData) async {
    await _apiClient.dio.post('/admin/coupons', data: couponData);
    ref.invalidateSelf();
  }

  Future<void> updateCoupon(String id, Map<String, dynamic> couponData) async {
    await _apiClient.dio.patch('/admin/coupons/$id', data: couponData);
    ref.invalidateSelf();
  }

  Future<void> deleteCoupon(String id) async {
    await _apiClient.dio.delete('/admin/coupons/$id');
    ref.invalidateSelf();
  }

  Future<void> toggleStatus(String id, bool isActive) async {
    await _apiClient.dio.post('/admin/coupons/$id/toggle-status', data: {'isActive': isActive});
    ref.invalidateSelf();
  }

  Future<void> archiveCoupon(String id) async {
    await _apiClient.dio.post('/admin/coupons/$id/archive');
    ref.invalidateSelf();
  }

  Future<Map<String, dynamic>> fetchCouponUsages(String id, {int skip = 0, int take = 50}) async {
    final response = await _apiClient.dio.get(
      '/admin/coupons/$id/usages',
      queryParameters: {'skip': skip, 'take': take},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
